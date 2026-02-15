"""
전체 파이프라인 실행: OCR → print → summary
articles 디렉토리의 각 작품에 대해 결과가 없는 경우만 실행.
단계별로 전체 작품을 순차 처리.
"""

import os
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ARTICLES_DIR = os.path.join(
    SCRIPT_DIR, "..", "violet-web", "packages", "backend", "data", "articles"
)
RAW_DIR = os.path.join(SCRIPT_DIR, "raw")
DIALOG_DIR = os.path.join(SCRIPT_DIR, "dialog")
SUMMARY_DIR = os.path.join(SCRIPT_DIR, "summary")

python = sys.executable


def get_article_ids():
    ids = []
    for name in os.listdir(ARTICLES_DIR):
        full = os.path.join(ARTICLES_DIR, name)
        if os.path.isdir(full) and name.isdigit():
            ids.append(name)
    ids.sort(key=int)
    return ids


def run(cmd: list[str]) -> bool:
    print(f"  $ {' '.join(cmd)}")
    result = subprocess.run(cmd)
    return result.returncode == 0


def main():
    article_ids = get_article_ids()
    print(f"총 {len(article_ids)}개 작품 발견")
    print()

    # ── 1단계: OCR ──
    print("=" * 50)
    print("1단계: OCR")
    print("=" * 50)
    for article_id in article_ids:
        raw_path = os.path.join(RAW_DIR, f"{article_id}.json")
        if os.path.exists(raw_path):
            print(f"  [건너뜀] {article_id}")
            continue
        article_dir = os.path.join(ARTICLES_DIR, article_id)
        if not run([python, os.path.join(SCRIPT_DIR, "ocr_article.py"), article_dir]):
            print(f"  [실패] {article_id}")
    print()

    # ── 2단계: print ──
    print("=" * 50)
    print("2단계: print")
    print("=" * 50)
    for article_id in article_ids:
        dialog_path = os.path.join(DIALOG_DIR, f"{article_id}.txt")
        if os.path.exists(dialog_path):
            print(f"  [건너뜀] {article_id}")
            continue
        raw_path = os.path.join(RAW_DIR, f"{article_id}.json")
        if not os.path.exists(raw_path):
            print(f"  [스킵] {article_id} - raw 없음")
            continue
        if not run([python, os.path.join(SCRIPT_DIR, "print.py"), raw_path]):
            print(f"  [실패] {article_id}")
    print()

    # ── 3단계: summary (최대 4개 병렬) ──
    print("=" * 50)
    print("3단계: summary (4 병렬)")
    print("=" * 50)
    summary_tasks = []
    for article_id in article_ids:
        summary_path = os.path.join(SUMMARY_DIR, f"{article_id}.txt")
        if os.path.exists(summary_path):
            print(f"  [건너뜀] {article_id}")
            continue
        dialog_path = os.path.join(DIALOG_DIR, f"{article_id}.txt")
        if not os.path.exists(dialog_path):
            print(f"  [스킵] {article_id} - dialog 없음")
            continue
        summary_tasks.append((article_id, dialog_path))

    def run_summary(task):
        article_id, dialog_path = task
        cmd = [python, os.path.join(SCRIPT_DIR, "summary.py"), dialog_path, "--article-id", article_id]
        result = subprocess.run(cmd, capture_output=True, text=True)
        return article_id, result.returncode == 0

    if summary_tasks:
        print(f"  {len(summary_tasks)}개 작품 summary 실행")
        with ThreadPoolExecutor(max_workers=4) as pool:
            futures = {pool.submit(run_summary, t): t[0] for t in summary_tasks}
            for future in as_completed(futures):
                article_id, ok = future.result()
                if ok:
                    print(f"  [완료] {article_id}")
                else:
                    print(f"  [실패] {article_id}")
    print()

    print("완료!")


if __name__ == "__main__":
    main()
