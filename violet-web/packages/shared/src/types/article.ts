export interface Article {
  Id: number;
  Title: string;
  EHash: string | null;
  Type: string | null;
  Artists: string | null;
  Characters: string | null;
  Groups: string | null;
  Language: string | null;
  Series: string | null;
  Tags: string | null;
  Uploader: string | null;
  Published: number | null;
  Files: number | null;
  Class: string | null;
  PublishedEH: string | null;
  Thumbnail: string | null;
  URL: string | null;
  ExistOnHitomi: number | null;
}

export interface ArticleSearchResult {
  articles: Article[];
  totalCount: number;
  page: number;
  pageSize: number;
}

export interface ImageList {
  urls: string[];
  bigThumbnails: string[];
  smallThumbnails: string[];
}
