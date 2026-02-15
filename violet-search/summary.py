import argparse
import os

import requests
from dotenv import load_dotenv

load_dotenv()

parser = argparse.ArgumentParser()
parser.add_argument("input", help="dialog.log 경로")
parser.add_argument("--article-id", help="작품 ID (미지정시 입력 파일명에서 추출)")
parser.add_argument(
    "--max-tokens", type=int, default=4096, help="최대 출력 토큰 (기본: 4096)"
)
args = parser.parse_args()

api_key = os.environ.get("DEEPSEEK_API_KEY")
if not api_key:
    print("오류: DEEPSEEK_API_KEY가 설정되지 않았습니다. .env 파일을 확인하세요.")
    exit(1)

with open(args.input, encoding="utf-8") as f:
    dialogues = f.read()

script_dir = os.path.dirname(os.path.abspath(__file__))
prompt_path = os.path.join(script_dir, "system-prompt.txt")
if os.path.exists(prompt_path):
    with open(prompt_path, encoding="utf-8") as f:
        system_prompt = f.read()
else:
    system_prompt = "만화/웹툰 대사 목록을 받아 스토리를 한국어로 요약하라."

resp = requests.post(
    "https://api.deepseek.com/chat/completions",
    headers={
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    },
    json={
        "model": "deepseek-chat",
        "messages": [
            {
                "role": "system",
                "content": system_prompt,
            },
            {
                "role": "user",
                "content": f"다음은 만화 한 화의 페이지별 대사 목록이다. 분석하라.\n\n{dialogues}",
            },
        ],
        "max_tokens": args.max_tokens,
    },
)

if resp.status_code != 200:
    print(f"API 오류 ({resp.status_code}): {resp.text}")
    exit(1)

summary = resp.json()["choices"][0]["message"]["content"]
print(summary)

article_id = args.article_id or os.path.splitext(os.path.basename(args.input))[0]
script_dir = os.path.dirname(os.path.abspath(__file__))
summary_dir = os.path.join(script_dir, "summary")
os.makedirs(summary_dir, exist_ok=True)
output_path = os.path.join(summary_dir, f"{article_id}.txt")

with open(output_path, "w", encoding="utf-8") as f:
    f.write(summary)

print(f"\n저장: {output_path}")
