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
from scipy.cluster import hierarchy
import matplotlib.pyplot as plt


class ClusteringMethod(Enum):
    KMEANS = "kmeans"
    ALL_DISTANCES = "all_distances"
    HIERARCHICAL = "hierarchical"  # 계층적 클러스터링 추가


class TextCluster:
    def __init__(self):
        """텍스트 클러스터링을 위한 초기화"""
        self.embeddings = HuggingFaceEmbeddings(
            model_name="dragonkue/BGE-m3-ko",
            model_kwargs={"device": "cuda"},
            encode_kwargs={"normalize_embeddings": True},
        )
        self.clusters = None
        self.article_embeddings = {}
        self.id_to_cluster = {}
        self.cluster_to_ids = defaultdict(list)
        self.distance_matrix = None
        self.article_ids = None
        self.linkage_matrix = None  # 계층적 클러스터링 결과 저장

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
        doc_ids = list(documents.keys())
        texts = list(documents.values())
        embeddings_list = []
        for i in tqdm(range(0, len(texts), batch_size)):
            batch_texts = texts[i : i + batch_size]
            batch_embeddings = self.embeddings.embed_documents(batch_texts)
            embeddings_list.extend(batch_embeddings)
        for doc_id, embedding in zip(doc_ids, embeddings_list):
            self.article_embeddings[doc_id] = embedding

    def get_cluster_filename(self, method: ClusteringMethod) -> str:
        """클러스터링 방식에 따른 파일 이름 반환"""
        if method == ClusteringMethod.KMEANS:
            return f"clusters_kmeans_{self.n_clusters}.pkl"
        elif method == ClusteringMethod.ALL_DISTANCES:
            return f"clusters_distances_{str(self.distance_threshold).replace('.', '_')}.pkl"
        else:  # HIERARCHICAL
            return f"clusters_hierarchical_{self.n_clusters}.pkl"

    def save_clusters(self):
        """클러스터링 결과 저장"""
        method = (
            ClusteringMethod.ALL_DISTANCES
            if self.distance_matrix is not None and self.linkage_matrix is None
            else ClusteringMethod.HIERARCHICAL
            if self.linkage_matrix is not None
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
            "linkage_matrix": self.linkage_matrix,  # 계층적 클러스터링 데이터 추가
        }
        with open(filename, "wb") as f:
            pickle.dump(data, f)
        print(f"클러스터링 결과가 {filename}에 저장되었습니다.")

    def load_clusters(self, filename: str):
        """저장된 클러스터링 결과 로드"""
        with open(filename, "rb") as f:
            data = pickle.load(f)
        self.id_to_cluster = data["id_to_cluster"]
        self.cluster_to_ids = defaultdict(list, data["cluster_to_ids"])
        self.distance_matrix = data["distance_matrix"]
        self.article_ids = data["article_ids"]
        self.article_embeddings = data["article_embeddings"]
        self.linkage_matrix = data.get(
            "linkage_matrix"
        )  # 계층적 클러스터링 데이터 로드
        method = data["clustering_method"]
        print(f"클러스터링 결과를 로드했습니다. (방식: {method})")

    def get_similar_articles(self, article_id: str, top_k: int = 20) -> List[str]:
        """특정 작품과 비슷한 작품들 반환"""
        if article_id not in self.article_embeddings:
            raise ValueError(f"작품 ID {article_id}를 찾을 수 없습니다.")
        if self.distance_matrix is not None:
            idx = self.article_ids.index(article_id)
            distances = self.distance_matrix[idx]
            similar_indices = np.argsort(distances)[1 : top_k + 1]
            return [self.article_ids[i] for i in similar_indices]
        else:
            cluster_id = self.id_to_cluster[article_id]
            similar_ids = self.cluster_to_ids[cluster_id]
            return [id for id in similar_ids if id != article_id][:top_k]

    def visualize_clusters(
        self,
        method: ClusteringMethod,
        output_dir: str = "visualizations",
        fig_width: int = 40,  # 크기를 더 작게 조정
        fig_height: int = 30,  # 크기를 더 작게 조정
        dpi: int = 100,  # DPI를 낮춤
        leaf_font_size: int = 6,  # 글꼴 크기도 작게 조정
    ):
        """클러스터링 결과 시각화"""
        if not os.path.exists(output_dir):
            os.makedirs(output_dir)

        if method == ClusteringMethod.HIERARCHICAL:
            if self.linkage_matrix is None:
                raise ValueError("계층적 클러스터링 결과가 없습니다.")

            try:
                # 메모리 정리
                plt.close("all")

                # 고해상도 이미지 생성
                fig = plt.figure(figsize=(fig_width, fig_height), dpi=dpi)
                hierarchy.dendrogram(
                    self.linkage_matrix,
                    labels=self.article_ids,
                    leaf_rotation=90,
                    leaf_font_size=leaf_font_size,
                )
                plt.title("Hierarchical Clustering Dendrogram", fontsize=12)
                plt.xlabel("Article IDs", fontsize=10)
                plt.ylabel("Distance", fontsize=10)
                plt.tight_layout()

                # SVG 파일로 저장
                svg_path = os.path.join(output_dir, "dendrogram.svg")
                plt.savefig(svg_path, format="svg", bbox_inches="tight")
                print(f"덴드로그램이 {svg_path}에 저장되었습니다.")

                # PNG 파일도 함께 저장
                png_path = os.path.join(output_dir, "dendrogram.png")
                plt.savefig(png_path, format="png", bbox_inches="tight")
                print(f"덴드로그램이 {png_path}에도 저장되었습니다.")

            finally:
                # 메모리 정리
                plt.close("all")

    # def visualize_clusters_simple(
    #     self,
    #     method: ClusteringMethod,
    #     output_dir: str = "visualizations",
    #     fig_width: int = 40,
    #     fig_height: int = 30,
    #     dpi: int = 100,
    #     leaf_font_size: int = 6,
    # ):
    #     """클러스터링 결과 시각화"""
    #     if not os.path.exists(output_dir):
    #         os.makedirs(output_dir)

    #     if method == ClusteringMethod.HIERARCHICAL:
    #         if self.linkage_matrix is None:
    #             raise ValueError("계층적 클러스터링 결과가 없습니다.")

    #         try:
    #             # 메모리 정리
    #             plt.close("all")

    #             # 고해상도 이미지 생성
    #             fig = plt.figure(figsize=(fig_width, fig_height), dpi=dpi)
    #             # 덴드로그램을 간소화하고 색상으로 클러스터 구분
    #             hierarchy.dendrogram(
    #                 self.linkage_matrix,
    #                 truncate_mode="level",  # 상위 레벨만 표시
    #                 p=5,  # 표시할 계층 수준 (조정 가능)
    #                 show_leaf_counts=True,  # 잎 노드 수 표시
    #                 color_threshold=self.distance_threshold
    #                 if hasattr(self, "distance_threshold")
    #                 else None,
    #                 above_threshold_color="grey",
    #                 leaf_font_size=leaf_font_size,
    #             )
    #             plt.title("Hierarchical Clustering Dendrogram (Truncated)", fontsize=12)
    #             plt.xlabel("Clusters (Number of Articles)", fontsize=10)
    #             plt.ylabel("Distance", fontsize=10)
    #             plt.tight_layout()

    #             # SVG 파일로 저장
    #             svg_path = os.path.join(output_dir, "dendrogram.svg")
    #             plt.savefig(svg_path, format="svg", bbox_inches="tight")
    #             print(f"덴드로그램이 {svg_path}에 저장되었습니다.")

    #             # PNG 파일도 함께 저장
    #             png_path = os.path.join(output_dir, "dendrogram.png")
    #             plt.savefig(png_path, format="png", bbox_inches="tight")
    #             print(f"덴드로그램이 {png_path}에도 저장되었습니다.")

    #         finally:
    #             # 메모리 정리
    #             plt.close("all")

    # def visualize_clusters_scatter(
    #     self,
    #     method: ClusteringMethod,
    #     output_dir: str = "visualizations",
    #     fig_width: int = 40,
    #     fig_height: int = 30,
    #     dpi: int = 100,
    #     leaf_font_size: int = 6,
    # ):
    #     """클러스터링 결과 시각화"""
    #     if not os.path.exists(output_dir):
    #         os.makedirs(output_dir)

    #     if method == ClusteringMethod.HIERARCHICAL:
    #         if self.linkage_matrix is None:
    #             raise ValueError("계층적 클러스터링 결과가 없습니다.")

    #         try:
    #             # 메모리 정리
    #             plt.close("all")

    #             # t-SNE로 2D 차원 축소 (self.article_embeddings 사용)
    #             from sklearn.manifold import TSNE

    #             tsne = TSNE(
    #                 n_components=2, random_state=42, perplexity=30, learning_rate=200
    #             )
    #             embeddings_array = np.array(
    #                 [self.article_embeddings[id] for id in self.article_ids]
    #             )
    #             reduced_data = tsne.fit_transform(embeddings_array)

    #             # 클러스터 레이블 생성 (예: linkage_matrix와 cut-off 기준)
    #             from scipy.cluster.hierarchy import fcluster

    #             clusters = fcluster(self.linkage_matrix, t=1.0, criterion="distance")

    #             # 고해상도 이미지 생성
    #             fig = plt.figure(figsize=(fig_width, fig_height), dpi=dpi)
    #             plt.scatter(
    #                 reduced_data[:, 0],
    #                 reduced_data[:, 1],
    #                 c=clusters,
    #                 cmap="viridis",
    #                 s=50,
    #             )
    #             plt.title("Hierarchical Clustering (t-SNE Visualization)", fontsize=12)
    #             plt.xlabel("t-SNE Component 1", fontsize=10)
    #             plt.ylabel("t-SNE Component 2", fontsize=10)
    #             plt.colorbar(label="Cluster ID")
    #             plt.tight_layout()

    #             # SVG 파일로 저장
    #             svg_path = os.path.join(output_dir, "cluster_scatter.svg")
    #             plt.savefig(svg_path, format="svg", bbox_inches="tight")
    #             print(f"클러스터 산점도가 {svg_path}에 저장되었습니다.")

    #             # PNG 파일도 함께 저장
    #             png_path = os.path.join(output_dir, "cluster_scatter.png")
    #             plt.savefig(png_path, format="png", bbox_inches="tight")
    #             print(f"클러스터 산점도가 {png_path}에도 저장되었습니다.")

    #         finally:
    #             # 메모리 정리
    #             plt.close("all")

    # def visualize_clusters_heatmap(
    #     self,
    #     method: ClusteringMethod,
    #     output_dir: str = "visualizations",
    #     fig_width: int = 40,
    #     fig_height: int = 30,
    #     dpi: int = 100,
    # ):
    #     """클러스터링 결과 히트맵 시각화"""
    #     if not os.path.exists(output_dir):
    #         os.makedirs(output_dir)

    #     if method == ClusteringMethod.HIERARCHICAL:
    #         if self.distance_matrix is None:
    #             raise ValueError("거리 행렬이 없습니다.")

    #         try:
    #             # 메모리 정리
    #             plt.close("all")

    #             # 거리 행렬 히트맵 생성
    #             fig = plt.figure(figsize=(fig_width, fig_height), dpi=dpi)
    #             plt.imshow(
    #                 self.distance_matrix, cmap="viridis", interpolation="nearest"
    #             )
    #             plt.title(
    #                 "Hierarchical Clustering Distance Matrix (Heatmap)", fontsize=12
    #             )
    #             plt.xlabel("Article IDs", fontsize=10)
    #             plt.ylabel("Article IDs", fontsize=10)
    #             plt.colorbar(label="Distance")
    #             plt.tight_layout()

    #             # SVG 파일로 저장
    #             svg_path = os.path.join(output_dir, "cluster_heatmap.svg")
    #             plt.savefig(svg_path, format="svg", bbox_inches="tight")
    #             print(f"클러스터 히트맵이 {svg_path}에 저장되었습니다.")

    #             # PNG 파일도 함께 저장
    #             png_path = os.path.join(output_dir, "cluster_heatmap.png")
    #             plt.savefig(png_path, format="png", bbox_inches="tight")
    #             print(f"클러스터 히트맵이 {png_path}에도 저장되었습니다.")

    #         finally:
    #             # 메모리 정리
    #             plt.close("all")

    # def visualize_clusters_umap(
    #     self,
    #     method: ClusteringMethod,
    #     output_dir: str = "visualizations",
    #     fig_width: int = 40,
    #     fig_height: int = 30,
    #     dpi: int = 100,
    # ):
    #     """클러스터링 결과 UMAP 시각화"""
    #     if not os.path.exists(output_dir):
    #         os.makedirs(output_dir)

    #     if method == ClusteringMethod.HIERARCHICAL:
    #         if self.linkage_matrix is None:
    #             raise ValueError("계층적 클러스터링 결과가 없습니다.")

    #         try:
    #             # 메모리 정리
    #             plt.close("all")

    #             # UMAP으로 2D 차원 축소
    #             embeddings_array = np.array(
    #                 [self.article_embeddings[id] for id in self.article_ids]
    #             )
    #             reducer = umap.UMAP(
    #                 n_components=2, random_state=42, n_neighbors=15, min_dist=0.1
    #             )
    #             reduced_data = reducer.fit_transform(embeddings_array)

    #             # 클러스터 레이블 생성
    #             from scipy.cluster.hierarchy import fcluster

    #             clusters = fcluster(self.linkage_matrix, t=1.0, criterion="distance")

    #             # 고해상도 이미지 생성
    #             fig = plt.figure(figsize=(fig_width, fig_height), dpi=dpi)
    #             plt.scatter(
    #                 reduced_data[:, 0],
    #                 reduced_data[:, 1],
    #                 c=clusters,
    #                 cmap="viridis",
    #                 s=50,
    #             )
    #             plt.title("Hierarchical Clustering (UMAP Visualization)", fontsize=12)
    #             plt.xlabel("UMAP Component 1", fontsize=10)
    #             plt.ylabel("UMAP Component 2", fontsize=10)
    #             plt.colorbar(label="Cluster ID")
    #             plt.tight_layout()

    #             # SVG 파일로 저장
    #             svg_path = os.path.join(output_dir, "cluster_umap.svg")
    #             plt.savefig(svg_path, format="svg", bbox_inches="tight")
    #             print(f"클러스터 UMAP이 {svg_path}에 저장되었습니다.")

    #             # PNG 파일도 함께 저장
    #             png_path = os.path.join(output_dir, "cluster_umap.png")
    #             plt.savefig(png_path, format="png", bbox_inches="tight")
    #             print(f"클러스터 UMAP이 {png_path}에도 저장되었습니다.")

    #         finally:
    #             # 메모리 정리
    #             plt.close("all")

    # def visualize_clusters_bar(
    #     self,
    #     method: ClusteringMethod,
    #     output_dir: str = "visualizations",
    #     fig_width: int = 40,
    #     fig_height: int = 30,
    #     dpi: int = 100,
    # ):
    #     """클러스터 크기 분포 바 차트 시각화"""
    #     if not os.path.exists(output_dir):
    #         os.makedirs(output_dir)

    #     if method == ClusteringMethod.HIERARCHICAL:
    #         if self.linkage_matrix is None:
    #             raise ValueError("계층적 클러스터링 결과가 없습니다.")

    #         try:
    #             # 메모리 정리
    #             plt.close("all")

    #             # 클러스터 크기 계산
    #             from scipy.cluster.hierarchy import fcluster

    #             clusters = fcluster(self.linkage_matrix, t=1.0, criterion="distance")
    #             cluster_sizes = np.bincount(clusters)

    #             # 바 차트 생성
    #             fig = plt.figure(figsize=(fig_width, fig_height), dpi=dpi)
    #             plt.bar(range(1, len(cluster_sizes) + 1), cluster_sizes)
    #             plt.title("Cluster Size Distribution", fontsize=12)
    #             plt.xlabel("Cluster ID", fontsize=10)
    #             plt.ylabel("Number of Articles", fontsize=10)
    #             plt.tight_layout()

    #             # SVG 파일로 저장
    #             svg_path = os.path.join(output_dir, "cluster_bar.svg")
    #             plt.savefig(svg_path, format="svg", bbox_inches="tight")
    #             print(f"클러스터 크기 분포가 {svg_path}에 저장되었습니다.")

    #             # PNG 파일도 함께 저장
    #             png_path = os.path.join(output_dir, "cluster_bar.png")
    #             plt.savefig(png_path, format="png", bbox_inches="tight")
    #             print(f"클러스터 크기 분포가 {png_path}에도 저장되었습니다.")

    #         finally:
    #             # 메모리 정리
    #             plt.close("all")

    def perform_clustering(
        self,
        method: ClusteringMethod = ClusteringMethod.KMEANS,
        n_clusters: int = 10,
        distance_threshold: float = 0.5,
    ):
        """클러스터링 수행"""
        print(f"클러스터링 수행 중... (방식: {method.value})")
        self.n_clusters = n_clusters
        self.distance_threshold = distance_threshold

        self.article_ids = list(self.article_embeddings.keys())
        embeddings_array = np.array(
            [self.article_embeddings[id] for id in self.article_ids]
        )

        if method == ClusteringMethod.KMEANS:
            kmeans = KMeans(n_clusters=n_clusters, random_state=42)
            self.clusters = kmeans.fit_predict(embeddings_array)
            for doc_id, cluster_id in zip(self.article_ids, self.clusters):
                self.id_to_cluster[doc_id] = cluster_id
                self.cluster_to_ids[cluster_id].append(doc_id)

        elif method == ClusteringMethod.ALL_DISTANCES:
            print("문서 간 거리 계산 중...")
            self.distance_matrix = cdist(
                embeddings_array, embeddings_array, metric="cosine"
            )
            for i, doc_id in enumerate(self.article_ids):
                distances = self.distance_matrix[i]
                similar_indices = np.where(distances <= distance_threshold)[0]
                similar_ids = [
                    self.article_ids[idx] for idx in similar_indices if idx != i
                ]
                self.cluster_to_ids[doc_id] = similar_ids

        elif method == ClusteringMethod.HIERARCHICAL:
            print("계층적 클러스터링 수행 중...")
            self.distance_matrix = cdist(
                embeddings_array, embeddings_array, metric="cosine"
            )
            self.linkage_matrix = hierarchy.linkage(self.distance_matrix, method="ward")
            self.clusters = hierarchy.fcluster(
                self.linkage_matrix, t=n_clusters, criterion="maxclust"
            )
            for doc_id, cluster_id in zip(self.article_ids, self.clusters):
                self.id_to_cluster[doc_id] = cluster_id
                self.cluster_to_ids[cluster_id].append(doc_id)

    def save_embeddings(self, filename: str = "article_embeddings.pkl"):
        """문서 임베딩 저장"""
        data = {
            "article_embeddings": self.article_embeddings,
            # "model_name": self.embeddings.model_name,
        }
        with open(filename, "wb") as f:
            pickle.dump(data, f)
        print(f"임베딩이 {filename}에 저장되었습니다.")

    def load_embeddings(self, filename: str = "article_embeddings.pkl") -> bool:
        """저장된 임베딩 로드. 성공하면 True, 실패하면 False 반환"""
        try:
            if not os.path.exists(filename):
                return False

            with open(filename, "rb") as f:
                data = pickle.load(f)

            # 모델이 다른 경우 임베딩을 재생성
            # if data["model_name"] != self.embeddings.model_name:
            #     print("다른 임베딩 모델이 감지되어 임베딩을 재생성합니다.")
            #     return False

            self.article_embeddings = data["article_embeddings"]
            print(f"임베딩을 {filename}에서 로드했습니다.")
            return True
        except Exception as e:
            print(f"임베딩 로드 중 오류 발생: {e}")
            return False


def main():
    import argparse

    parser = argparse.ArgumentParser(description="텍스트 클러스터링 시스템")
    parser.add_argument(
        "--method",
        type=str,
        choices=["kmeans", "all_distances", "hierarchical"],
        default="kmeans",
        help="클러스터링 방식 선택",
    )
    parser.add_argument(
        "--n_clusters",
        type=int,
        default=10,
        help="클러스터 수 (kmeans 또는 hierarchical에서 사용)",
    )
    parser.add_argument(
        "--distance_threshold",
        type=float,
        default=0.5,
        help="유사도 임계값 (all_distances에서 사용)",
    )
    parser.add_argument(
        "--force-embedding",
        action="store_true",
        help="임베딩을 강제로 재생성",
    )

    args = parser.parse_args()
    method = ClusteringMethod(args.method)
    cluster = TextCluster()
    cluster.n_clusters = args.n_clusters
    cluster.distance_threshold = args.distance_threshold

    filename = cluster.get_cluster_filename(method)

    if not os.path.exists(filename):
        print("새로운 클러스터링을 수행합니다...")
        documents = cluster.load_documents()

        # 임베딩 로드 시도
        if not args.force_embedding and cluster.load_embeddings():
            print("기존 임베딩을 사용합니다.")
        else:
            print("임베딩을 생성합니다...")
            cluster.create_embeddings(documents)
            cluster.save_embeddings()

        cluster.perform_clustering(
            method=method,
            n_clusters=args.n_clusters,
            distance_threshold=args.distance_threshold,
        )
        cluster.save_clusters()
        if method == ClusteringMethod.HIERARCHICAL:
            cluster.visualize_clusters(method)
    else:
        print("저장된 클러스터링 결과를 로드합니다...")
        cluster.load_clusters(filename)
        if method == ClusteringMethod.HIERARCHICAL:
            cluster.visualize_clusters(method)

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
