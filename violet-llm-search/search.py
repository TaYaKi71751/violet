import os
from pathlib import Path
from typing import List, Dict, Any
import groq
import google.generativeai as genai
from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain_community.vectorstores import FAISS
from langchain_huggingface import HuggingFaceEmbeddings
from dotenv import load_dotenv
import argparse
from tqdm import tqdm
import requests
import typer


# 환경 변수 로드
load_dotenv()

# 청크 설정
CHUNK_SIZE = 2000
CHUNK_OVERLAP = 400

# 인덱스 경로 설정
INDEX_PATH = f"vector_index_{CHUNK_SIZE}_{CHUNK_OVERLAP}"

# Gemini 설정
genai.configure(api_key=os.getenv("GEMINI_API_KEY"))

# Typer 앱 생성
app = typer.Typer()


class VectorSearch:
    def __init__(self, model: str = "groq", prompt_type: str = "general"):
        """벡터 검색을 위한 초기화"""
        self.embeddings = HuggingFaceEmbeddings(
            model_name="BAAI/bge-m3",
            model_kwargs={
                "device": "cuda",
            },
            encode_kwargs={
                "normalize_embeddings": True,
            },
        )
        self.vector_store = None
        self.text_splitter = RecursiveCharacterTextSplitter(
            chunk_size=CHUNK_SIZE,
            chunk_overlap=CHUNK_OVERLAP,
            separators=["\n\n", "\n", ".", " ", "", "*", ":", '"'],
            length_function=len,
        )
        self.model = model
        self.prompt_type = prompt_type

        if model == "groq":
            self.client = groq.Groq(api_key=os.getenv("GROQ_API_KEY"))
        elif model == "gemini":
            self.client = genai.GenerativeModel("gemini-2.0-flash")
        elif model == "grok":
            # Grok API는 클라이언트 라이브러리가 아닌 직접 API 호출 방식 사용
            self.grok_api_key = os.getenv("GROK_API_KEY")
            if not self.grok_api_key:
                raise ValueError("GROK_API_KEY 환경 변수가 설정되지 않았습니다.")
        else:
            raise ValueError(
                "지원하지 않는 모델입니다. 'groq', 'gemini', 또는 'grok'을 선택하세요."
            )

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
        if not force_recreate and os.path.exists(INDEX_PATH):
            print(
                f"기존 인덱스를 로드합니다... (chunk_size: {CHUNK_SIZE}, chunk_overlap: {CHUNK_OVERLAP})"
            )
            self.vector_store = FAISS.load_local(
                INDEX_PATH, self.embeddings, allow_dangerous_deserialization=True
            )
            return

        print(
            f"새로운 인덱스를 생성합니다... (chunk_size: {CHUNK_SIZE}, chunk_overlap: {CHUNK_OVERLAP})"
        )
        documents = self.load_documents()

        if not documents:
            raise ValueError("처리할 문서가 없습니다.")

        texts = [doc["content"] for doc in documents]
        metadatas = [doc["metadata"] for doc in documents]

        # 청크 단위로 임베딩 생성 및 진행률 표시
        embeddings_list = []
        batch_size = 128  # 배치 크기 설정

        for i in tqdm(range(0, len(texts), batch_size), desc="임베딩 생성 중"):
            batch_texts = texts[i : i + batch_size]
            batch_embeddings = self.embeddings.embed_documents(batch_texts)
            embeddings_list.extend(batch_embeddings)

        print("FAISS 인덱스 생성 중...")
        self.vector_store = FAISS.from_embeddings(
            text_embeddings=list(zip(texts, embeddings_list)),
            embedding=self.embeddings,
            metadatas=metadatas,
        )

        # 인덱스 저장
        print("인덱스 저장 중...")
        self.vector_store.save_local(INDEX_PATH)
        print("인덱스가 생성되었습니다.")

    def get_prompt(self, query: str, context_text: str) -> str:
        """프롬프트 타입에 따른 프롬프트 반환"""
        prompts = {
            "general": f"""아래는 벡터 DB에서 검색된 여러 문서의 내용입니다. 이 문서들은 사용자의 질문에 답변하는 데 필요한 정보를 담고 있으며, 답변은 반드시 이 문서들에 포함된 내용만을 기반으로 작성해야 합니다. 문서에 없는 정보는 추측하거나 추가하지 말고, 오직 제공된 문서 데이터만 사용하여 한국어로 답변해 주세요.

**질문:** {query}

**검색된 문서들:**  
{context_text}

**답변 작성 지침:**  
1. 문서에서 질문과 직접적으로 관련된 정보만을 추출하여 답변에 포함하세요.  
2. 여러 문서에서 정보를 가져올 경우, 내용이 모순되지 않도록 일관된 흐름으로 통합하여 작성하세요.  
3. 답변은 간결하고 명확하게 작성하되, 질문에 대한 충분한 설명이 필요할 경우 세부 사항을 추가하세요.  
4. 문서에 사용된 전문 용어나 표현이 있다면, 이를 그대로 사용하여 답변의 정확성과 전문성을 유지하세요.  
5. 답변은 반드시 한국어로 작성하며, 다른 언어는 사용하지 마세요.

위 지침을 엄격히 준수하여, 제공된 문서의 내용을 종합하고 질문에 답변해 주세요.""",
            "relevance": f"""아래는 벡터 DB에서 검색된 여러 문서의 내용입니다. 이 문서들은 사용자의 질문과 관련된 정보를 담고 있으며, 결과는 반드시 이 문서들에 포함된 article id와 "질문과 가장 알맞는 답변의 정도"만을 기반으로 작성해야 합니다. 문서에 없는 정보는 추가하지 말고, 오직 제공된 문서 데이터만 사용하세요.

질문: {query}

검색된 문서들:
{context_text}

결과 작성 지침:
1. 문서에서 article id와 "질문과 가장 알맞는 답변의 정도"를 추출하여 출력하세요. 
2. "질문과 가장 알맞는 답변의 정도"는 해당 문서가 질문에 답변하는 데 얼마나 적합한지를 0~1 사이 값으로 평가한 것입니다(0은 전혀 관련 없음, 1은 완벽히 적합함).
3. 여러 문서가 포함된 경우, 각 문서의 article id와 "질문과 가장 알맞는 답변의 정도"를 개별적으로 나열하되, 해당 값 기준으로 내림차순 정렬하세요.
4. 결과는 간결하고 명확하게 작성하며, 추가 설명이나 해석은 포함시키지 마세요.""",
            "keyword": f"""아래는 벡터 DB에서 검색된 여러 문서의 내용입니다. 이 문서들은 사용자가 제공한 키워드 조합과 관련된 정보를 담고 있으며, 결과는 반드시 이 문서들에 포함된 article id와 해당 문서가 키워드와 관련된 이유만을 기반으로 작성해야 합니다. 문서에 없는 정보는 추측하거나 추가하지 말고, 오직 제공된 문서 데이터만 사용하여 한국어로 작성하세요.

키워드: {query}

검색된 문서들:
{context_text}

결과 작성 지침:
1. 문서에서 제공된 키워드와 직접적으로 관련된 정보를 기반으로 article id와 해당 문서가 키워드와 관련된 이유를 추출하세요.
2. 여러 문서가 포함된 경우, 각 문서의 article id와 이유를 개별적으로 나열하되, 키워드와의 관련성 높은 순으로 정렬하세요.
3. 이유는 간결하고 명확하게 작성하며, 문서 내용에서 키워드와 연결되는 구체적인 부분을 간략히 설명하세요.
4. 문서에 사용된 전문 용어나 표현이 있다면, 이를 그대로 사용하여 결과의 정확성과 전문성을 유지하세요.
5. 결과는 반드시 한국어로 작성하며, 다른 언어는 사용하지 마세요.""",
        }

        return prompts.get(self.prompt_type, prompts["general"])

    def search(self, query: str, search_query: str = None, k: int = 50) -> str:
        """쿼리에 대한 검색 수행
        Args:
            query: 프롬프트에 사용될 쿼리
            search_query: 벡터 검색에 사용될 쿼리 (None인 경우 query 사용)
            k: 검색할 문서 수
        """
        if not self.vector_store:
            raise ValueError("먼저 인덱스를 생성하거나 로드해야 합니다.")

        # 벡터 검색에 사용할 쿼리 결정
        vector_query = search_query if search_query is not None else query

        # 전체 인덱스에 저장된 문서 수를 가져와 fetch_k로 사용합니다.
        # (self.vector_store.index.ntotal이 FAISS 인덱스의 총 벡터 수입니다.)
        total_docs = (
            self.vector_store.index.ntotal
            if hasattr(self.vector_store, "index")
            else k * 20
        )

        results = self.vector_store.similarity_search_with_score(
            vector_query, k=k, fetch_k=total_docs
        )

        contexts = []
        for doc, score in results:
            contexts.append(
                f"[작품 ID: {doc.metadata['article_id']}]\n{doc.page_content}\n(유사도: {score:.4f})"
            )

        context_text = "\n\n".join(contexts)
        prompt = self.get_prompt(query, context_text)

        if self.model == "groq":
            completion = self.client.chat.completions.create(
                model="deepseek-r1-distill-llama-70b",
                messages=[{"role": "user", "content": prompt}],
                temperature=0.1,
                max_tokens=1000,
            )
            return completion.choices[0].message.content
        elif self.model == "gemini":
            response = self.client.generate_content(prompt)
            return response.text
        elif self.model == "grok":
            # Grok API 호출
            headers = {
                "Authorization": f"Bearer {self.grok_api_key}",
                "Content-Type": "application/json",
            }

            payload = {
                "messages": [{"role": "user", "content": prompt}],
                "model": "grok-2-1212",  # TODO: grok-3
                "temperature": 0.1,
                "max_tokens": 1000,
            }

            response = requests.post(
                "https://api.x.ai/v1/chat/completions", headers=headers, json=payload
            )

            if response.status_code != 200:
                raise Exception(
                    f"Grok API 오류: {response.status_code} - {response.text}"
                )

            result = response.json()
            return result["choices"][0]["message"]["content"]

    def get_existing_article_ids(self) -> set:
        """벡터 스토어에 저장된 문서 ID 목록 반환"""
        if not self.vector_store:
            return set()

        article_ids = set()
        for doc in self.vector_store.docstore._dict.values():
            article_ids.add(doc.metadata["article_id"])
        return article_ids

    def update_index(self, force_recreate: bool = False) -> tuple[list[str], list[str]]:
        """새로운 문서를 찾아 임베딩하여 인덱스 업데이트

        Returns:
            tuple[list[str], list[str]]: (추가된 문서 ID 목록, 실패한 문서 ID 목록)
        """
        # 기존 문서 ID 목록 가져오기
        existing_ids = self.get_existing_article_ids()

        # result 폴더의 모든 문서 가져오기
        result_dir = Path("result")
        if not result_dir.exists():
            raise FileNotFoundError("result 디렉토리가 없습니다.")

        all_files = list(result_dir.glob("*.txt"))
        if not all_files:
            print("처리할 문서가 없습니다.")
            return [], []

        # 새로운 문서만 필터링
        new_files = [f for f in all_files if f.stem not in existing_ids]
        if not new_files and not force_recreate:
            print("추가할 새로운 문서가 없습니다.")
            return [], []

        print(f"새로운 문서 {len(new_files)}개를 임베딩합니다...")

        # 새로운 문서 처리
        texts = []
        metadatas = []
        added_ids = []
        failed_ids = []

        for file_path in tqdm(new_files, desc="문서 처리 중"):
            try:
                with open(file_path, "r", encoding="utf-8") as f:
                    content = f.read()
                    doc_id = file_path.stem

                    # 청크로 분리
                    chunks = self.text_splitter.split_text(content)

                    # 각 청크를 문서로 저장
                    for i, chunk in enumerate(chunks):
                        texts.append(chunk)
                        metadatas.append({"article_id": doc_id, "chunk_id": i})

                added_ids.append(doc_id)
            except Exception as e:
                print(f"문서 {file_path.name} 처리 실패: {e}")
                failed_ids.append(file_path.stem)

        if not texts:
            return added_ids, failed_ids

        print("임베딩 생성 중...")
        # 청크 단위로 임베딩 생성 및 진행률 표시
        embeddings_list = []
        batch_size = 128  # 배치 크기 설정

        for i in tqdm(range(0, len(texts), batch_size), desc="임베딩 생성 중"):
            batch_texts = texts[i : i + batch_size]
            batch_embeddings = self.embeddings.embed_documents(batch_texts)
            embeddings_list.extend(batch_embeddings)

        # 기존 인덱스가 없으면 새로 생성
        if not self.vector_store:
            print("새로운 FAISS 인덱스 생성 중...")
            self.vector_store = FAISS.from_embeddings(
                text_embeddings=list(zip(texts, embeddings_list)),
                embedding=self.embeddings,
                metadatas=metadatas,
            )
        else:
            print("기존 FAISS 인덱스에 추가 중...")
            self.vector_store.add_embeddings(
                text_embeddings=list(zip(texts, embeddings_list)),
                metadatas=metadatas,
            )

        # 인덱스 저장
        print("인덱스 저장 중...")
        self.vector_store.save_local(INDEX_PATH)
        print("인덱스가 업데이트되었습니다.")

        return added_ids, failed_ids


@app.command()
def search(
    model: str = typer.Option("gemini", help="사용할 모델 (groq, gemini, grok)"),
    prompt_type: str = typer.Option(
        "general", help="사용할 프롬프트 타입 (general, relevance, keyword)"
    ),
    separate_query: bool = typer.Option(
        False, help="벡터 검색 쿼리와 프롬프트 쿼리를 분리하여 입력"
    ),
):
    """검색 기능"""
    try:
        vector_search = VectorSearch(model=model, prompt_type=prompt_type)
    except ImportError as e:
        print(f"오류: {e}")
        return
    except ValueError as e:
        print(f"오류: {e}")
        return

    # 인덱스 생성 또는 로드
    vector_search.create_or_load_index()

    # 검색 예시
    while True:
        if separate_query:
            search_query = input(
                "\n벡터 검색에 사용할 키워드를 입력하세요 (종료하려면 'q' 입력): "
            )
            if search_query.lower() == "q":
                break
            prompt_query = input("프롬프트에 사용할 질문을 입력하세요: ")
        else:
            prompt_query = input("\n검색할 내용을 입력하세요 (종료하려면 'q' 입력): ")
            if prompt_query.lower() == "q":
                break
            search_query = None

        try:
            result = vector_search.search(prompt_query, search_query)
            print("\n=== 검색 결과 ===")
            print(result)
            print("================")
        except Exception as e:
            print(f"검색 중 오류 발생: {e}")


@app.command()
def update(
    force: bool = typer.Option(
        False, help="기존 문서도 포함하여 모든 문서를 다시 임베딩"
    ),
):
    """벡터 인덱스 업데이트"""
    try:
        vector_search = VectorSearch()
        if not force:
            vector_search.create_or_load_index()

        added_ids, failed_ids = vector_search.update_index(force_recreate=force)

        if added_ids:
            print("\n추가된 문서:")
            for doc_id in added_ids:
                print(f"- {doc_id}")

        if failed_ids:
            print("\n실패한 문서:")
            for doc_id in failed_ids:
                print(f"- {doc_id}")

    except Exception as e:
        print(f"업데이트 중 오류 발생: {e}")
        return


if __name__ == "__main__":
    app()
