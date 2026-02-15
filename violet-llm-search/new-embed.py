import nltk
from nltk.sentiment.vader import SentimentIntensityAnalyzer
from sentence_transformers import SentenceTransformer
from sklearn.metrics.pairwise import cosine_similarity
import numpy as np
import matplotlib.pyplot as plt

# 필요한 NLTK 데이터 다운로드 (최초 한 번 실행)
nltk.download("vader_lexicon")

# 설정값
CHUNK_SIZE = 2000
CHUNK_OVERLAP = 400
SEPARATORS = ["\n\n", "\n", ".", " ", "", "*", ":", '"']


# 재귀적 텍스트 분할 함수 (RecursiveCharacterTextSplitter와 유사한 역할)
def recursive_text_splitter(
    text,
    chunk_size=CHUNK_SIZE,
    chunk_overlap=CHUNK_OVERLAP,
    separators=SEPARATORS,
    length_function=len,
):
    """
    주어진 text를 chunk_size 이하로 분할합니다.
    분할 시 지정된 separators 리스트에 따라 가능한 마지막 분리 기호 위치를 찾으며,
    분할 청크들은 chunk_overlap 만큼 겹치게 됩니다.
    """
    if length_function(text) <= chunk_size:
        return [text]

    # chunk_size 내에서 가장 좋은 separator 위치 찾기
    split_index = -1
    for sep in separators:
        if sep:  # 빈 문자열은 건너뜁니다.
            idx = text.rfind(sep, 0, chunk_size)
            # 가능한 가장 늦게 발견된 separator를 선택 (청크가 너무 짧아지지 않도록)
            if idx > split_index:
                split_index = idx + len(sep)
    # 적절한 separator를 찾지 못했거나 너무 앞에 있다면 단순하게 chunk_size에서 자릅니다.
    if split_index == -1 or split_index < chunk_size * 0.5:
        split_index = chunk_size

    # 첫 청크 추출
    chunk = text[:split_index]
    # 다음 청크 시작점은 현재 청크 끝에서 chunk_overlap 만큼 되돌아간 지점
    next_start = max(0, split_index - chunk_overlap)
    # 재귀적으로 나머지 텍스트 분할
    rest_chunks = recursive_text_splitter(
        text[next_start:], chunk_size, chunk_overlap, separators, length_function
    )
    return [chunk] + rest_chunks


# 예시: 여러 문서를 리스트로 정의 (실제 사용 시 파일 등에서 읽어올 수 있음)
documents = [
    """
    이 문서는 예시를 위해 작성된 첫 번째 긴 텍스트입니다.
    첫 문장은 긍정적인 느낌을 줍니다. 정말 멋진 날씨와 따뜻한 햇살이 마음을 편안하게 해줍니다.
    그러나 중간에 약간의 우울함과 슬픔이 섞인 문장이 있습니다.
    하지만 결국 다시 희망과 긍정으로 가득 찬 결말로 이어집니다.
    """
    * 10,  # 반복해서 길게 만듦
    """
    두 번째 문서는 다소 부정적인 감정을 포함합니다.
    비극적인 사건들로 인해 슬픔과 고통이 문서 전반에 퍼져 있습니다.
    전체적으로 매우 우울한 분위기지만, 가끔은 희망의 불씨가 보이기도 합니다.
    그러나 대부분은 부정적인 감정이 우세합니다.
    """
    * 8,
    """
    세 번째 문서는 중립적인 내용을 담고 있습니다.
    이 문서는 단순한 정보 전달에 초점을 맞추고 있으며, 특별한 감정 표현 없이 객관적인 사실들만 나열합니다.
    """
    * 12,
]

# VADER 감성 분석기 초기화
sid = SentimentIntensityAnalyzer()

# 다국어 지원 임베딩 모델 로드 (한국어 지원)
embedding_model = SentenceTransformer("paraphrase-multilingual-MiniLM-L12-v2")

# 각 문서에서 CHUNK_SIZE와 OVERLAP 설정을 적용해 청크를 생성하고, 감성 분석 및 임베딩 수행
all_chunks = []  # 전체 청크 텍스트
chunk_sentiments = []  # 각 청크의 감성 점수 (compound)
chunk_embeddings = []  # 각 청크의 임베딩 벡터
chunk_doc_indices = []  # 각 청크가 속한 문서 인덱스

for doc_idx, doc in enumerate(documents):
    # 텍스트를 CHUNK_SIZE와 OVERLAP 설정을 이용해 분할
    chunks = recursive_text_splitter(doc)
    for chunk in chunks:
        all_chunks.append(chunk)
        # 청크 전체에 대해 감성 분석 (compound 점수)
        score = sid.polarity_scores(chunk)["compound"]
        chunk_sentiments.append(score)
        # 청크 임베딩 계산
        emb = embedding_model.encode(chunk)
        chunk_embeddings.append(emb)
        chunk_doc_indices.append(doc_idx)

chunk_embeddings = np.array(chunk_embeddings)

# (선택) 전체 청크 감성 점수 시각화
plt.figure(figsize=(8, 4))
plt.plot(chunk_sentiments, marker="o", linestyle="-")
plt.title("청크별 감성 점수 추이")
plt.xlabel("청크 인덱스")
plt.ylabel("Compound 감성 점수")
plt.grid(True)
plt.show()


# 검색 기능: 전체 문서의 청크(문맥을 반영한 단위)에서 쿼리와 유사한 청크 검색
def search_in_chunks(query, chunks, embeddings, doc_indices, top_k=5):
    """
    주어진 쿼리에 대해 전체 청크 임베딩과 코사인 유사도를 계산하여,
    상위 top_k 개의 청크, 해당 문서 인덱스, 유사도 점수를 반환합니다.
    """
    query_embedding = embedding_model.encode([query])
    sim_scores = cosine_similarity(query_embedding, embeddings)[0]
    top_indices = np.argsort(sim_scores)[::-1][:top_k]
    results = [(doc_indices[i], chunks[i], sim_scores[i]) for i in top_indices]
    return results


# 예시 쿼리 입력 (여러 문장에 걸친 문맥을 반영하는 쿼리)
query = "우울하지만 곧 행복해짐"
results = search_in_chunks(
    query, all_chunks, chunk_embeddings, chunk_doc_indices, top_k=5
)

print("검색 결과 (문맥 고려):")
for doc_idx, chunk_text, score in results:
    print(f"문서 {doc_idx + 1} (청크):\n{chunk_text}\n유사도: {score:.3f}\n")
