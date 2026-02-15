"""
벡터 검색 + DeepSeek 답변 생성 API 서버
ChromaDB에서 유사 문서 검색 → DeepSeek V3로 답변

GET /search?q=질문&top_k=5&mode=fast
GET /search?q=질문&top_k=5&mode=detail
GET /search?q=질문&top_k=5&mode=super_fast
"""

import json
import os

import chromadb
import requests
from dotenv import load_dotenv
from flask import Flask, jsonify, request
from google import genai
from google.genai import types

load_dotenv()

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CHROMA_DIR = os.path.join(SCRIPT_DIR, "chromadb")
COLLECTION_NAME = "article_summaries"
EMBEDDING_MODEL = "gemini-embedding-001"

gemini_key = os.environ.get("GEMINI_API_KEY")
deepseek_key = os.environ.get("DEEPSEEK_API_KEY")
if not gemini_key or not deepseek_key:
    print("오류: GEMINI_API_KEY 또는 DEEPSEEK_API_KEY가 설정되지 않았습니다.")
    exit(1)

client_genai = genai.Client(api_key=gemini_key)
client_chroma = chromadb.PersistentClient(path=CHROMA_DIR)
collection = client_chroma.get_collection(name=COLLECTION_NAME)

app = Flask(__name__)
_cache: dict[str, dict] = {}

PROMPT_FAST = """검색된 문서들을 질문과의 관련도로 평가하여 JSON 출력.

질문: {query}

문서:
{context_text}

출력 형식 (JSON만 출력):
{{"query":"질문","results":[{{"articleId":"ID","score":0.9,"description":"한줄 설명"}}],"answer":"한줄 답변"}}

규칙: score 0~1, 0.3 미만 제외, 내림차순, description은 한국어 한줄, JSON만 출력"""

PROMPT_DETAIL = """아래는 벡터 DB에서 검색된 여러 문서의 내용입니다. 각 문서는 만화/웹툰 한 화의 분석 결과입니다.
사용자의 질문에 대해, 각 작품이 얼마나 관련있는지 평가하고 JSON으로 출력하세요.

**질문:** {query}

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

PROMPT_SUPER_FAST = """검색된 문서들을 질문과의 관련도로 평가하여 JSON 출력. description과 answer는 출력하지 마세요.

질문: {query}

문서:
{context_text}

출력 형식 (JSON만 출력):
{{"query":"질문","results":[{{"articleId":"ID","score":0.9}}]}}

규칙: score 0~1, 0.3 미만 제외, 내림차순, JSON만 출력"""

PROMPTS = {
    "super_fast": PROMPT_SUPER_FAST,
    "fast": PROMPT_FAST,
    "detail": PROMPT_DETAIL,
}

MAX_TOKENS = {
    "super_fast": 2048,
    "fast": 8192,
    "detail": 8192,
}


def do_search(query: str, top_k: int, mode: str) -> dict:
    cache_key = f"{mode}::{query}::{top_k}"
    if cache_key in _cache:
        return _cache[cache_key]

    # 1. 쿼리 임베딩
    query_resp = client_genai.models.embed_content(
        model=EMBEDDING_MODEL,
        contents=query,
        config=types.EmbedContentConfig(task_type="RETRIEVAL_QUERY"),
    )
    query_embedding = query_resp.embeddings[0].values

    # 2. ChromaDB 검색
    results = collection.query(
        query_embeddings=[query_embedding],
        n_results=top_k,
    )

    docs = results["documents"][0]
    ids = results["ids"][0]
    distances = results["distances"][0]

    if not docs:
        return {"query": query, "results": [], "answer": ""}

    # 3. 컨텍스트 조립
    context_parts = []
    for i, (doc_id, doc, dist) in enumerate(zip(ids, docs, distances)):
        context_parts.append(
            f"[문서 {i + 1}] (articleId: {doc_id}, 유사도: {1 - dist:.4f})\n{doc}"
        )
    context_text = "\n\n---\n\n".join(context_parts)

    # 4. DeepSeek 답변 생성
    prompt = PROMPTS[mode].format(query=query, context_text=context_text)
    max_tokens = MAX_TOKENS[mode]

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
            "max_tokens": max_tokens,
            "response_format": {"type": "json_object"},
        },
    )

    if resp.status_code != 200:
        return {"error": f"DeepSeek API 오류 ({resp.status_code})", "detail": resp.text}

    body = resp.json()
    choice = body["choices"][0]
    raw = choice["message"]["content"]

    if choice.get("finish_reason") == "length":
        app.logger.warning("응답이 max_tokens(%d)로 잘림", max_tokens)

    try:
        result = json.loads(raw)
    except json.JSONDecodeError as e:
        app.logger.error("JSON 파싱 실패 (finish_reason=%s) - raw 응답:\n%s", choice.get("finish_reason"), raw)
        return {"error": f"LLM 응답이 잘렸습니다 (max_tokens={max_tokens}). 재시도해주세요.", "raw_response": raw}
    _cache[cache_key] = result
    return result


@app.route("/search")
def search():
    query = request.args.get("q", "")
    if not query:
        return jsonify({"error": "q 파라미터가 필요합니다."}), 400

    mode = request.args.get("mode", "")
    if mode not in PROMPTS:
        return jsonify({"error": f"mode 파라미터가 필요합니다. (super_fast, fast 또는 detail)"}), 400

    top_k = request.args.get("top_k", 5, type=int)

    result = do_search(query, top_k=top_k, mode=mode)
    return jsonify(result)


if __name__ == "__main__":
    port = int(os.environ.get("SEARCH_PORT", 8787))
    print(f"검색 서버 시작: http://localhost:{port}/search?q=질문&mode=fast")
    app.run(host="0.0.0.0", port=port)
