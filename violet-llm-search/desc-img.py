import os
import requests
import base64
from PIL import Image
import argparse
from dotenv import load_dotenv
import io

# 환경 변수 로드
load_dotenv()


def analyze_image(image_path, analysis_type="detailed"):
    # Grok API 키 설정
    api_key = os.getenv("GROK_API_KEY")
    if not api_key:
        raise ValueError("GROK_API_KEY 환경 변수가 설정되지 않았습니다.")

    # 이미지 파일 열기
    image = Image.open(image_path)

    # 이미지를 base64로 인코딩
    buffered = io.BytesIO()
    image.save(buffered, format=image.format if image.format else "JPEG")
    img_str = base64.b64encode(buffered.getvalue()).decode("utf-8")

    # 분석 유형에 따른 프롬프트 설정
    prompts = {
        "detailed": "이 이미지를 자세히 설명해주세요. 색상, 구도, 주요 요소들을 포함해서 설명해주세요.",
        "person": "이 사진 속 인물에 대해 설명해주세요. 표정, 자세, 의상 등을 자세히 설명해주세요.",
        "object": "이 이미지에서 볼 수 있는 모든 사물들을 나열하고 설명해주세요.",
    }

    # Grok-3 API 요청 준비
    headers = {"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"}

    payload = {
        "messages": [
            {"role": "user", "content": prompts[analysis_type]},
            {
                "role": "user",
                "content": [
                    {
                        "type": "image_url",
                        "image_url": {"url": f"data:image/jpeg;base64,{img_str}"},
                    }
                ],
            },
        ],
        "model": "grok-2-vision-1212",
        # "temperature": 0.1,
        # "max_tokens": 1000,
    }

    # API 요청
    response = requests.post(
        "https://api.x.ai/v1/chat/completions", headers=headers, json=payload
    )

    if response.status_code != 200:
        raise Exception(f"API 요청 실패: {response.status_code} - {response.text}")

    response_data = response.json()
    return response_data["choices"][0]["message"]["content"]


def main():
    parser = argparse.ArgumentParser(description="이미지 분석 프로그램")
    parser.add_argument("image_path", type=str, help="분석할 이미지 파일 경로")
    parser.add_argument(
        "--type",
        type=str,
        choices=["detailed", "person", "object"],
        default="detailed",
        help="분석 유형 선택",
    )

    args = parser.parse_args()

    try:
        result = analyze_image(args.image_path, args.type)
        print("\n분석 결과:")
        print(result)
    except Exception as e:
        print(f"오류 발생: {str(e)}")


if __name__ == "__main__":
    main()
