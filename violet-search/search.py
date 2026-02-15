"""
벡터 검색 + DeepSeek 답변 생성
ChromaDB에서 유사 문서 검색 → DeepSeek V3로 답변
"""

import argparse
import os

import chromadb
import google.generativeai as genai
import requests
from dotenv import load_dotenv

load_dotenv()

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CHROMA_DIR = os.path.join(SCRIPT_DIR, "chromadb")
COLLECTION_NAME = "article_summaries"
EMBEDDING_MODEL = "gemini-embedding-001"

parser = argparse.ArgumentParser(description="벡터 검색 + LLM 답변")
parser.add_argument("query", help="검색 질문")
parser.add_argument("--top-k", type=int, default=5, help="검색 문서 수 (기본: 5)")
parser.add_argument(
    "--max-tokens", type=int, default=4096, help="최대 출력 토큰 (기본: 4096)"
)
args = parser.parse_args()

gemini_key = os.environ.get("GEMINI_API_KEY")
deepseek_key = os.environ.get("DEEPSEEK_API_KEY")
if not gemini_key:
    print("오류: GEMINI_API_KEY가 설정되지 않았습니다.")
    exit(1)
if not deepseek_key:
    print("오류: DEEPSEEK_API_KEY가 설정되지 않았습니다.")
    exit(1)

# ── 1. 쿼리 임베딩 ──
genai.configure(api_key=gemini_key)
query_resp = genai.embed_content(
    model=EMBEDDING_MODEL,
    content=args.query,
    task_type="RETRIEVAL_QUERY",
)
query_embedding = query_resp["embedding"]

# ── 2. ChromaDB 검색 ──
client_chroma = chromadb.PersistentClient(path=CHROMA_DIR)
collection = client_chroma.get_collection(name=COLLECTION_NAME)

results = collection.query(
    query_embeddings=[query_embedding],
    n_results=args.top_k,
)

docs = results["documents"][0]
ids = results["ids"][0]
distances = results["distances"][0]

if not docs:
    print("검색 결과가 없습니다.")
    exit(0)

print(
    f"검색 완료: {len(docs)}개 문서 (거리: {', '.join(f'{d:.4f}' for d in distances)})"
)
print()

# ── 3. 컨텍스트 조립 ──
context_parts = []
for i, (doc_id, doc, dist) in enumerate(zip(ids, docs, distances)):
    context_parts.append(
        f"[문서 {i + 1}] (articleId: {doc_id}, 유사도: {1 - dist:.4f})\n{doc}"
    )

context_text = "\n\n---\n\n".join(context_parts)

# ── 4. DeepSeek 답변 생성 (JSON) ──
prompt = f"""아래는 벡터 DB에서 검색된 여러 문서의 내용입니다. 각 문서는 만화/웹툰 한 화의 분석 결과입니다.
사용자의 질문에 대해, 각 작품이 얼마나 관련있는지 평가하고 JSON으로 출력하세요.

**질문:** {args.query}

**검색된 문서들:**
{context_text}

**출력 형식 (반드시 이 JSON 형식만 출력):**
```json
{{
  "query": "사용자 질문",
  "results": [
    {{
      "articleId": "문서의 articleId",
      "score": 0.95,
      "description": "이 작품에 대한 상세 서술형 설명"
    }}
  ],
  "answer": "질문에 대한 종합 답변"
}}
```

**규칙:**
1. score는 0.0~1.0 사이. 질문과의 관련도를 의미하며, 벡터 유사도가 아닌 내용 기반 판단
2. 관련 없는 문서는 score를 낮게 주고, 0.3 미만이면 results에서 제외
3. score 내림차순으로 정렬
4. description은 반드시 한국어 서술형으로 3~5문장 이상 작성. 작품의 장르, 분위기, 등장인물 관계, 핵심 감정/갈등, 대사 스타일, 특징적 요소를 풍부하게 서술하고 마지막에 키워드를 포함할 것.
5. answer도 서술형으로 풍부하게 작성
6. JSON 외에 다른 텍스트를 출력하지 마세요"""

resp = requests.post(
    "https://api.deepseek.com/chat/completions",
    headers={
        "Authorization": f"Bearer {deepseek_key}",
        "Content-Type": "application/json",
    },
    json={
        "model": "deepseek-chat",
        "messages": [
            {"role": "user", "content": prompt},
        ],
        "max_tokens": args.max_tokens,
        "response_format": {"type": "json_object"},
    },
)

if resp.status_code != 200:
    print(f"API 오류 ({resp.status_code}): {resp.text}")
    exit(1)

import json

raw = resp.json()["choices"][0]["message"]["content"]
result = json.loads(raw)

# 보기 좋게 출력
print(json.dumps(result, ensure_ascii=False, indent=2))
