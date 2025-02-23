import os
from pathlib import Path
from typing import List, Dict
from langchain_huggingface import HuggingFaceEmbeddings
from tqdm import tqdm
import numpy as np
from sklearn.cluster import KMeans
import pickle
from collections import defaultdict


class TextCluster:
    def __init__(self):
        """텍스트 클러스터링을 위한 초기화"""
        self.embeddings = HuggingFaceEmbeddings(
            model_name="BAAI/bge-m3",
            model_kwargs={
                "device": "cuda",
            },
            encode_kwargs={
                "normalize_embeddings": True,
            },
        )
        self.clusters = None
        self.article_embeddings = {}
        self.id_to_cluster = {}
        self.cluster_to_ids = defaultdict(list)

    def load_documents(self) -> Dict[str, str]:
        """result 폴더의 문서들을 로드"""
        documents = {}
        result_dir = Path("result")

        if not result_dir.exists():
            raise FileNotFoundError("result 디렉토리가 없습니다.")

        print("문서 로딩 중...")
        for file_path in tqdm(result_dir.glob("*.txt")):
            with open(file_path, "r", encoding="utf-8") as f:
                content = f.read()
                doc_id = file_path.stem
                documents[doc_id] = content

        return documents

    def create_embeddings(self, documents: Dict[str, str], batch_size: int = 8):
        """문서들의 임베딩 생성"""
        print("임베딩 생성 중...")

        # 문서 ID와 텍스트 리스트 준비
        doc_ids = list(documents.keys())
        texts = list(documents.values())

        # 배치 처리로 임베딩 생성
        embeddings_list = []
        for i in tqdm(range(0, len(texts), batch_size)):
            batch_texts = texts[i : i + batch_size]
            batch_embeddings = self.embeddings.embed_documents(batch_texts)
            embeddings_list.extend(batch_embeddings)

        # 문서 ID와 임베딩을 매핑
        for doc_id, embedding in zip(doc_ids, embeddings_list):
            self.article_embeddings[doc_id] = embedding

    def perform_clustering(self, n_clusters: int = 10):
        """K-means 클러스터링 수행"""
        print("클러스터링 수행 중...")

        # 임베딩 배열 생성
        embeddings_array = np.array(list(self.article_embeddings.values()))

        # K-means 클러스터링
        kmeans = KMeans(n_clusters=n_clusters, random_state=42)
        self.clusters = kmeans.fit_predict(embeddings_array)

        # 클러스터 결과 매핑
        for doc_id, cluster_id in zip(self.article_embeddings.keys(), self.clusters):
            self.id_to_cluster[doc_id] = cluster_id
            self.cluster_to_ids[cluster_id].append(doc_id)

    def save_clusters(self, filename: str = "clusters.pkl"):
        """클러스터링 결과 저장"""
        data = {
            "id_to_cluster": self.id_to_cluster,
            "cluster_to_ids": dict(self.cluster_to_ids),
        }
        with open(filename, "wb") as f:
            pickle.dump(data, f)
        print(f"클러스터링 결과가 {filename}에 저장되었습니다.")

    def load_clusters(self, filename: str = "clusters.pkl"):
        """저장된 클러스터링 결과 로드"""
        with open(filename, "rb") as f:
            data = pickle.load(f)
        self.id_to_cluster = data["id_to_cluster"]
        self.cluster_to_ids = defaultdict(list, data["cluster_to_ids"])
        print("클러스터링 결과를 로드했습니다.")

    def get_similar_articles(self, article_id: str, top_k: int = 5) -> List[str]:
        """특정 작품과 같은 클러스터에 있는 작품들 반환"""
        if article_id not in self.id_to_cluster:
            raise ValueError(f"작품 ID {article_id}를 찾을 수 없습니다.")

        cluster_id = self.id_to_cluster[article_id]
        similar_ids = self.cluster_to_ids[cluster_id]

        # 자기 자신을 제외하고 상위 k개 반환
        return [id for id in similar_ids if id != article_id][:top_k]


def main():
    # 클러스터링 수행 또는 로드
    cluster = TextCluster()

    if not os.path.exists("clusters.pkl"):
        print("새로운 클러스터링을 수행합니다...")
        documents = cluster.load_documents()
        cluster.create_embeddings(documents)
        cluster.perform_clustering()
        cluster.save_clusters()
    else:
        print("저장된 클러스터링 결과를 로드합니다...")
        cluster.load_clusters()

    # 대화형 검색
    while True:
        article_id = input("\n작품 ID를 입력하세요 (종료하려면 'q' 입력): ")
        if article_id.lower() == "q":
            break

        try:
            similar_articles = cluster.get_similar_articles(article_id)
            print(f"\n작품 {article_id}와(과) 비슷한 작품들:")
            for similar_id in similar_articles:
                print(f"- {similar_id}")
        except ValueError as e:
            print(f"오류: {e}")
        except Exception as e:
            print(f"처리 중 오류 발생: {e}")


if __name__ == "__main__":
    main()
