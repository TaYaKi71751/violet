import os
from pathlib import Path
from typing import List, Dict
from langchain_huggingface import HuggingFaceEmbeddings
from tqdm import tqdm
import numpy as np
from sklearn.cluster import KMeans
import pickle
from collections import defaultdict
from enum import Enum
from scipy.spatial.distance import cdist


class ClusteringMethod(Enum):
    KMEANS = "kmeans"
    ALL_DISTANCES = "all_distances"


class TextCluster:
    def __init__(self):
        """텍스트 클러스터링을 위한 초기화"""
        self.embeddings = HuggingFaceEmbeddings(
            # model_name="BAAI/bge-m3",
            model_name="dragonkue/BGE-m3-ko",
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
        self.distance_matrix = None
        self.article_ids = None

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

    def create_embeddings(self, documents: Dict[str, str], batch_size: int = 4):
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

    def get_cluster_filename(self, method: ClusteringMethod) -> str:
        """클러스터링 방식에 따른 파일 이름 반환"""
        if method == ClusteringMethod.KMEANS:
            return f"clusters_kmeans_{self.n_clusters}.pkl"
        else:
            return f"clusters_distances_{str(self.distance_threshold).replace('.', '_')}.pkl"

    def save_clusters(self):
        """클러스터링 결과 저장"""
        method = (
            ClusteringMethod.ALL_DISTANCES
            if self.distance_matrix is not None
            else ClusteringMethod.KMEANS
        )
        filename = self.get_cluster_filename(method)

        data = {
            "id_to_cluster": self.id_to_cluster,
            "cluster_to_ids": dict(self.cluster_to_ids),
            "distance_matrix": self.distance_matrix,
            "article_ids": self.article_ids,
            "article_embeddings": self.article_embeddings,
            "clustering_method": method.value,
            "n_clusters": getattr(self, "n_clusters", None),
            "distance_threshold": getattr(self, "distance_threshold", None),
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
        self.distance_matrix = data["distance_matrix"]
        self.article_ids = data["article_ids"]
        self.article_embeddings = data["article_embeddings"]
        method = data["clustering_method"]
        print(f"클러스터링 결과를 로드했습니다. (방식: {method})")

    def get_similar_articles(self, article_id: str, top_k: int = 20) -> List[str]:
        """특정 작품과 비슷한 작품들 반환"""
        if article_id not in self.article_embeddings:
            raise ValueError(f"작품 ID {article_id}를 찾을 수 없습니다.")

        if self.distance_matrix is not None:
            # ALL_DISTANCES 방식을 사용한 경우
            idx = self.article_ids.index(article_id)
            distances = self.distance_matrix[idx]
            # 거리가 가까운 순서대로 정렬 (자기 자신 제외)
            similar_indices = np.argsort(distances)[1 : top_k + 1]
            return [self.article_ids[i] for i in similar_indices]
        else:
            # KMEANS 방식을 사용한 경우
            cluster_id = self.id_to_cluster[article_id]
            similar_ids = self.cluster_to_ids[cluster_id]
            return [id for id in similar_ids if id != article_id][:top_k]

    def perform_clustering(
        self,
        method: ClusteringMethod = ClusteringMethod.KMEANS,
        n_clusters: int = 10,
        distance_threshold: float = 0.5,
    ):
        """클러스터링 수행"""
        print(f"클러스터링 수행 중... (방식: {method.value})")

        # 파라미터 저장
        self.n_clusters = n_clusters
        self.distance_threshold = distance_threshold

        # 임베딩 배열 생성
        self.article_ids = list(self.article_embeddings.keys())
        embeddings_array = np.array(
            [self.article_embeddings[id] for id in self.article_ids]
        )

        if method == ClusteringMethod.KMEANS:
            # K-means 클러스터링
            kmeans = KMeans(n_clusters=n_clusters, random_state=42)
            self.clusters = kmeans.fit_predict(embeddings_array)

            # 클러스터 결과 매핑
            for doc_id, cluster_id in zip(self.article_ids, self.clusters):
                self.id_to_cluster[doc_id] = cluster_id
                self.cluster_to_ids[cluster_id].append(doc_id)

        else:  # ALL_DISTANCES
            # 모든 문서 쌍 간의 거리 계산
            print("문서 간 거리 계산 중...")
            self.distance_matrix = cdist(
                embeddings_array, embeddings_array, metric="cosine"
            )

            # 거리 행렬을 기반으로 유사도 그룹 생성
            for i, doc_id in enumerate(self.article_ids):
                # 현재 문서와 다른 모든 문서 간의 거리
                distances = self.distance_matrix[i]
                # 임계값보다 가까운 문서들을 같은 클러스터로 그룹화
                similar_indices = np.where(distances <= distance_threshold)[0]
                similar_ids = [
                    self.article_ids[idx] for idx in similar_indices if idx != i
                ]
                self.cluster_to_ids[doc_id] = similar_ids


def main():
    import argparse

    parser = argparse.ArgumentParser(description="텍스트 클러스터링 시스템")
    parser.add_argument(
        "--method",
        type=str,
        choices=["kmeans", "all_distances"],
        default="kmeans",
        help="클러스터링 방식 선택",
    )
    parser.add_argument(
        "--n_clusters",
        type=int,
        default=10,
        help="K-means 클러스터 수 (method가 kmeans일 때만 사용)",
    )
    parser.add_argument(
        "--distance_threshold",
        type=float,
        default=0.5,
        help="유사도 임계값 (method가 all_distances일 때만 사용)",
    )

    args = parser.parse_args()
    method = ClusteringMethod(args.method)
    filename = f"clusters_{args.method}"
    if args.method == "kmeans":
        filename += f"_{args.n_clusters}.pkl"
    else:
        filename += f"_{str(args.distance_threshold).replace('.', '_')}.pkl"

    cluster = TextCluster()

    if not os.path.exists(filename):
        print("새로운 클러스터링을 수행합니다...")
        documents = cluster.load_documents()
        cluster.create_embeddings(documents)
        cluster.perform_clustering(
            method=method,
            n_clusters=args.n_clusters,
            distance_threshold=args.distance_threshold,
        )
        cluster.save_clusters()
    else:
        print("저장된 클러스터링 결과를 로드합니다...")
        cluster.load_clusters(filename)

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
