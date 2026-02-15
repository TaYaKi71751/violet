"""
Article OCR Script
==================
작품 이미지들을 페이지 순서대로 OCR하여 하나의 JSON 파일로 합칩니다.
멀티프로세스로 이미지 레벨 병렬화 지원.

사용법:
    python ocr_article.py <article_dir> [--threshold 0.5] [--workers 2] [--output-dir .]

예시:
    python ocr_article.py E:\Dev2\violet-project\violet-web\packages\backend\data\articles\3356663
    python ocr_article.py E:\Dev2\violet-project\violet-web\packages\backend\data\articles\3356663 --workers 3 --threshold 0.7

출력:
    {articleId}-raw.json
"""

import argparse
import json
import os
import sys
import tempfile
import time
from concurrent.futures import ThreadPoolExecutor
from multiprocessing import Pool, current_process

from PIL import Image


# ── 워커 프로세스용 전역 OCR 인스턴스 ──
_worker_ocr = None
_worker_config = None


def _worker_init(config: dict):
    """각 워커 프로세스에서 한 번만 OCR 인스턴스 생성"""
    global _worker_ocr, _worker_config
    _worker_config = config
    from paddleocr import PaddleOCR

    _worker_ocr = PaddleOCR(
        text_detection_model_name="PP-OCRv5_mobile_det",
        text_recognition_model_name="korean_PP-OCRv5_mobile_rec",
        use_doc_orientation_classify=False,
        use_doc_unwarping=False,
        use_textline_orientation=True,
        device=config["device"],
        text_recognition_batch_size=config["rec_batch_size"],
        textline_orientation_batch_size=config["rec_batch_size"],
    )
    pid = current_process().pid
    print(f"  워커 {pid} 초기화 완료 (device={config['device']})", flush=True)


def _worker_process_image(task: dict) -> dict:
    """워커 프로세스에서 단일 이미지 OCR 처리"""
    global _worker_ocr, _worker_config
    target = task["target"]
    page_num = task["page_num"]
    width = task["width"]
    height = task["height"]
    threshold = _worker_config["threshold"]

    result = _worker_ocr.predict(input=target)

    texts = []
    for res in result:
        rec_texts = (
            res.get("rec_texts", [])
            if isinstance(res, dict)
            else getattr(res, "rec_texts", [])
        )
        rec_scores = (
            res.get("rec_scores", [])
            if isinstance(res, dict)
            else getattr(res, "rec_scores", [])
        )
        rec_polys = (
            res.get("rec_polys", [])
            if isinstance(res, dict)
            else getattr(res, "rec_polys", [])
        )
        rec_boxes = (
            res.get("rec_boxes", [])
            if isinstance(res, dict)
            else getattr(res, "rec_boxes", [])
        )
        orientations = (
            res.get("textline_orientation_angles", [])
            if isinstance(res, dict)
            else getattr(res, "textline_orientation_angles", [])
        )

        for i, (text, score) in enumerate(zip(rec_texts, rec_scores)):
            if score < threshold:
                continue
            text = text.strip()
            if not text:
                continue

            entry = {
                "text": text,
                "confidence": round(float(score), 4),
            }
            if i < len(rec_boxes):
                entry["bbox"] = [int(v) for v in rec_boxes[i]]
            if i < len(rec_polys):
                poly = rec_polys[i]
                entry["poly"] = [[int(p[0]), int(p[1])] for p in poly]
            if i < len(orientations):
                entry["orientation"] = int(orientations[i])
            texts.append(entry)

    return {
        "page": page_num,
        "width": width,
        "height": height,
        "textsCount": len(texts),
        "texts": texts,
    }


def parse_args():
    parser = argparse.ArgumentParser(
        description="Article OCR - 페이지별 대사 추출 (멀티프로세스)"
    )
    parser.add_argument("article_dir", help="이미지가 있는 작품 디렉토리 경로")
    parser.add_argument(
        "--threshold",
        type=float,
        default=0.5,
        help="OCR 신뢰도 임계값 (기본: 0.5)",
    )
    parser.add_argument(
        "--workers",
        type=int,
        default=2,
        help="병렬 워커 수 (기본: 2, 4070Ti 12GB 기준 2~3 권장)",
    )
    parser.add_argument(
        "--rec-batch-size",
        type=int,
        default=16,
        help="텍스트 인식 배치 크기 (기본: 16)",
    )
    parser.add_argument(
        "--output-dir",
        default=None,
        help="출력 디렉토리 (기본: article_dir과 같은 위치)",
    )
    parser.add_argument(
        "--device",
        default="gpu:0",
        help="PaddleOCR 디바이스 (기본: gpu:0)",
    )
    return parser.parse_args()


def get_sorted_images(article_dir: str) -> list[tuple[int, str]]:
    """이미지 파일을 페이지 번호 순으로 정렬하여 반환"""
    supported_exts = {".webp", ".png", ".jpg", ".jpeg", ".bmp", ".tiff"}
    images = []
    for f in os.listdir(article_dir):
        name, ext = os.path.splitext(f)
        if ext.lower() in supported_exts and name.isdigit():
            images.append((int(name), os.path.join(article_dir, f)))
    images.sort(key=lambda x: x[0])
    return images


def convert_single(args: tuple[str, str]) -> tuple[str, int, int]:
    """webp/이미지 -> png 변환 + 크기 반환"""
    img_path, tmp_dir = args
    img = Image.open(img_path).convert("RGB")
    width, height = img.size
    basename = os.path.splitext(os.path.basename(img_path))[0]
    ext = os.path.splitext(img_path)[1].lower()
    if ext == ".webp":
        out_path = os.path.join(tmp_dir, f"{basename}.png")
        img.save(out_path)
    else:
        out_path = img_path
    img.close()
    return out_path, width, height


def main():
    args = parse_args()
    article_dir = os.path.abspath(args.article_dir)
    article_id = os.path.basename(article_dir)

    if not os.path.isdir(article_dir):
        print(f"오류: 디렉토리를 찾을 수 없습니다: {article_dir}")
        sys.exit(1)

    images = get_sorted_images(article_dir)
    if not images:
        print(f"오류: 이미지 파일을 찾을 수 없습니다: {article_dir}")
        sys.exit(1)

    print(f"작품 ID: {article_id}")
    print(f"총 페이지: {len(images)}")
    print(f"신뢰도 임계값: {args.threshold}")
    print(f"워커 수: {args.workers}")
    print(f"인식 배치 크기: {args.rec_batch_size}")
    print(f"디바이스: {args.device}")
    print()

    # ── 1단계: 이미지 전처리 (webp→png 변환, 스레드 병렬) ──
    t0 = time.perf_counter()
    tmp_dir = tempfile.mkdtemp()

    print("이미지 전처리 중...")
    convert_args = [(img_path, tmp_dir) for _, img_path in images]
    with ThreadPoolExecutor(max_workers=8) as pool:
        convert_results = list(pool.map(convert_single, convert_args))

    page_nums = [page_num for page_num, _ in images]
    target_paths = [r[0] for r in convert_results]
    dimensions = [(r[1], r[2]) for r in convert_results]

    t1 = time.perf_counter()
    print(f"전처리 완료: {t1 - t0:.2f}초")
    print()

    # ── 2단계: 멀티프로세스 OCR ──
    tasks = [
        {
            "target": target,
            "page_num": page_num,
            "width": w,
            "height": h,
        }
        for page_num, target, (w, h) in zip(page_nums, target_paths, dimensions)
    ]

    worker_config = {
        "device": args.device,
        "threshold": args.threshold,
        "rec_batch_size": args.rec_batch_size,
    }

    total = len(tasks)
    print(f"OCR 실행 중 ({total}장, {args.workers} 워커)...")

    t2 = time.perf_counter()

    with Pool(
        processes=args.workers,
        initializer=_worker_init,
        initargs=(worker_config,),
    ) as pool:
        results_unordered = []
        for i, result in enumerate(pool.imap_unordered(_worker_process_image, tasks)):
            results_unordered.append(result)
            elapsed = time.perf_counter() - t2
            per_img = elapsed / (i + 1)
            eta = per_img * (total - i - 1)
            text_preview = ", ".join(t["text"] for t in result["texts"][:3])
            if len(result["texts"]) > 3:
                text_preview += "..."
            print(
                f"  [{i + 1}/{total}] 페이지 {result['page']}: "
                f"{result['textsCount']}개 텍스트 "
                f"({per_img:.2f}s/장, ETA {eta:.0f}s) - {text_preview}",
                flush=True,
            )

    t3 = time.perf_counter()
    print(f"\nOCR 완료: {t3 - t2:.2f}초 ({total / (t3 - t2):.1f} 장/초)")

    # ── 3단계: 페이지 순서 정렬 후 저장 ──
    results_ordered = sorted(results_unordered, key=lambda x: x["page"])

    output = {
        "articleId": article_id,
        "totalPages": len(images),
        "threshold": args.threshold,
        "pages": results_ordered,
    }

    output_dir = args.output_dir if args.output_dir else article_dir
    os.makedirs(output_dir, exist_ok=True)
    output_path = os.path.join(output_dir, f"{article_id}-raw.json")

    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(output, f, ensure_ascii=False, indent=2)

    # 임시 디렉토리 정리
    import shutil

    shutil.rmtree(tmp_dir, ignore_errors=True)

    total_texts = sum(p["textsCount"] for p in results_ordered)
    t4 = time.perf_counter()
    print()
    print(f"완료! 총 {total_texts}개 텍스트 감지")
    print(f"총 소요시간: {t4 - t0:.2f}초 (전처리 {t1 - t0:.1f}s + OCR {t3 - t2:.1f}s)")
    print(f"저장: {output_path}")


if __name__ == "__main__":
    main()
