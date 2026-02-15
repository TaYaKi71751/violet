"""
Summary 임베딩 스크립트
summary/*.txt → ChromaDB (Gemini embedding)
이미 임베딩된 articleId는 건너뜀.
"""

import os

import chromadb
from dotenv import load_dotenv
from google import genai
from google.genai import types

load_dotenv()

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
SUMMARY_DIR = os.path.join(SCRIPT_DIR, "summary")
CHROMA_DIR = os.path.join(SCRIPT_DIR, "chromadb")
COLLECTION_NAME = "article_summaries"
EMBEDDING_MODEL = "gemini-embedding-001"

api_key = os.environ.get("GEMINI_API_KEY")
if not api_key:
    print("오류: GEMINI_API_KEY가 설정되지 않았습니다. .env 파일을 확인하세요.")
    exit(1)

client_genai = genai.Client(api_key=api_key)

client_chroma = chromadb.PersistentClient(path=CHROMA_DIR)
collection = client_chroma.get_or_create_collection(
    name=COLLECTION_NAME,
    metadata={"hnsw:space": "cosine"},
)

# 이미 임베딩된 ID
existing_ids = set(collection.get()["ids"])

# summary 폴더 스캔
new_items = []
for f in os.listdir(SUMMARY_DIR):
    if not f.endswith(".txt"):
        continue
    article_id = os.path.splitext(f)[0]
    if article_id in existing_ids:
        continue
    path = os.path.join(SUMMARY_DIR, f)
    with open(path, encoding="utf-8") as fh:
        text = fh.read().strip()
    if text:
        new_items.append((article_id, text))

if not new_items:
    print(f"새로운 summary 없음 (기존 {len(existing_ids)}개)")
    exit(0)

print(f"새로운 summary {len(new_items)}개 임베딩 중... (기존 {len(existing_ids)}개)")

# 배치 임베딩 (Gemini batch_embed_contents 지원)
BATCH_SIZE = 100
for i in range(0, len(new_items), BATCH_SIZE):
    batch = new_items[i : i + BATCH_SIZE]
    ids = [item[0] for item in batch]
    texts = [item[1] for item in batch]

    resp = client_genai.models.embed_content(
        model=EMBEDDING_MODEL,
        contents=texts,
        config=types.EmbedContentConfig(task_type="RETRIEVAL_DOCUMENT"),
    )
    embeddings = [e.values for e in resp.embeddings]

    collection.add(
        ids=ids,
        documents=texts,
        embeddings=embeddings,
    )
    print(f"  {i + len(batch)}/{len(new_items)} 완료")

print(f"\n완료! 총 {len(existing_ids) + len(new_items)}개 임베딩")
