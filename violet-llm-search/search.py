import os
from pathlib import Path
from typing import List, Dict, Any
import groq
from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain_community.vectorstores import FAISS
from langchain_huggingface import HuggingFaceEmbeddings
from dotenv import load_dotenv

# 환경 변수 로드
load_dotenv()


class VectorSearch:
    def __init__(self):
        """벡터 검색을 위한 초기화"""
        self.embeddings = HuggingFaceEmbeddings(
            model_name="jhgan/ko-sbert-nli",
            model_kwargs={"device": "cpu"},
            encode_kwargs={"normalize_embeddings": True},
        )
        self.vector_store = None
        self.text_splitter = RecursiveCharacterTextSplitter(
            chunk_size=500,
            chunk_overlap=50,
            separators=["\n\n", "\n", ".", " ", ""],
            length_function=len,
        )
        self.client = groq.Groq(api_key=os.getenv("GROQ_API_KEY"))

    def load_documents(self) -> List[Dict[str, Any]]:
        """result 폴더의 문서들을 로드"""
        documents = []
        result_dir = Path("result")

        if not result_dir.exists():
            raise FileNotFoundError("result 디렉토리가 없습니다.")

        for file_path in result_dir.glob("*.txt"):
            with open(file_path, "r", encoding="utf-8") as f:
                content = f.read()
                doc_id = file_path.stem

                # 청크로 분리
                chunks = self.text_splitter.split_text(content)

                # 각 청크를 문서로 저장
                for i, chunk in enumerate(chunks):
                    documents.append(
                        {
                            "id": f"{doc_id}_{i}",
                            "content": chunk,
                            "metadata": {"article_id": doc_id, "chunk_id": i},
                        }
                    )

        return documents

    def create_or_load_index(self, force_recreate: bool = False):
        """벡터 인덱스 생성 또는 로드"""
        index_path = "vector_index"

        if not force_recreate and os.path.exists(index_path):
            print("기존 인덱스를 로드합니다...")
            self.vector_store = FAISS.load_local(
                index_path, self.embeddings, allow_dangerous_deserialization=True
            )
            return

        print("새로운 인덱스를 생성합니다...")
        documents = self.load_documents()

        if not documents:
            raise ValueError("처리할 문서가 없습니다.")

        texts = [doc["content"] for doc in documents]
        metadatas = [doc["metadata"] for doc in documents]

        self.vector_store = FAISS.from_texts(
            texts=texts, embedding=self.embeddings, metadatas=metadatas
        )

        # 인덱스 저장
        self.vector_store.save_local(index_path)
        print("인덱스가 생성되었습니다.")

    def search(self, query: str, k: int = 10) -> str:
        """쿼리에 대한 검색 수행"""
        if not self.vector_store:
            raise ValueError("먼저 인덱스를 생성하거나 로드해야 합니다.")

        # 벡터 검색 수행
        results = self.vector_store.similarity_search_with_score(query, k=k)

        # 컨텍스트 구성
        contexts = []
        for doc, score in results:
            contexts.append(
                f"[작품 ID: {doc.metadata['article_id']}]\n{doc.page_content}\n(유사도: {score:.4f})"
            )

        context_text = "\n\n".join(contexts)

        # LLM을 통한 답변 생성
        prompt = f"""아래는 검색 결과로 나온 여러 문서의 내용들이야. 이 내용들을 기반으로 질문에 한국어로 답변해줘.
        
질문: {query}

검색된 문서들:
{context_text}

위 문서들의 내용을 종합해서 질문에 답변해줘. 문서에 없는 내용은 추측하지 말고, 문서에 있는 내용만 사용해서 한국어로 답변해줘."""

        completion = self.client.chat.completions.create(
            model="deepseek-r1-distill-llama-70b",
            messages=[{"role": "user", "content": prompt}],
            temperature=0.1,
            max_tokens=1000,
        )

        return completion.choices[0].message.content


def main():
    # 사용 예시
    vector_search = VectorSearch()

    # 인덱스 생성 또는 로드
    vector_search.create_or_load_index()

    # 검색 예시
    while True:
        query = input("\n검색할 내용을 입력하세요 (종료하려면 'q' 입력): ")
        if query.lower() == "q":
            break

        try:
            result = vector_search.search(query)
            print("\n=== 검색 결과 ===")
            print(result)
            print("================")
        except Exception as e:
            print(f"검색 중 오류 발생: {e}")


if __name__ == "__main__":
    main()
