import uvicorn
from fastapi import FastAPI, HTTPException, Body
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional, List
from search import VectorSearch
import typer
from contextlib import asynccontextmanager
import requests
import os

app = typer.Typer()

# 전역 변수로 벡터 검색 인스턴스 저장
vector_search = None
# 서버에서 사용할 모델과 프롬프트 타입 설정을 위한 전역 변수
server_model = os.environ.get("SERVER_MODEL", "gemini")
server_prompt_type = os.environ.get("SERVER_PROMPT_TYPE", "general")


@asynccontextmanager
async def lifespan(app: FastAPI):
    """FastAPI 애플리케이션의 수명 주기 이벤트 핸들러"""
    global vector_search, server_model, server_prompt_type

    # 환경 변수에서 설정 가져오기
    if "SERVER_MODEL" in os.environ:
        server_model = os.environ["SERVER_MODEL"]
    if "SERVER_PROMPT_TYPE" in os.environ:
        server_prompt_type = os.environ["SERVER_PROMPT_TYPE"]

    print(
        f"lifespan 시작 - 서버 모델: {server_model}, 프롬프트 타입: {server_prompt_type}"
    )

    try:
        print("벡터 검색 인스턴스 초기화 중...")
        # 서버 설정된 모델과 프롬프트 타입으로 초기화
        vector_search = VectorSearch(model=server_model, prompt_type=server_prompt_type)
        vector_search.create_or_load_index()
        print(
            f"벡터 검색 인스턴스 초기화 완료 - 모델: {vector_search.model}, 프롬프트 타입: {vector_search.prompt_type}"
        )
    except Exception as e:
        print(f"벡터 검색 인스턴스 초기화 실패: {e}")

    yield

    # 종료 시 정리 작업이 필요하면 여기에 추가


api_app = FastAPI(
    title="벡터 검색 API",
    description="벡터 검색 시스템을 위한 REST API",
    lifespan=lifespan,
)

# CORS 설정
api_app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# 요청 모델 정의
class SearchRequest(BaseModel):
    query: str
    search_query: Optional[str] = None
    k: int = 50


# 응답 모델 정의
class SearchResponse(BaseModel):
    result: str


@api_app.get("/models", response_model=List[str])
async def get_models():
    """사용 가능한 모델 목록 반환"""
    return ["groq", "gemini", "grok", "grok-unofficial"]


@api_app.get("/prompt-types", response_model=List[str])
async def get_prompt_types():
    """사용 가능한 프롬프트 타입 목록 반환"""
    return ["general", "relevance", "keyword"]


@api_app.post("/search", response_model=SearchResponse)
async def search(
    request: SearchRequest = Body(...),
):
    """벡터 검색 수행"""
    global vector_search, server_model, server_prompt_type

    if vector_search is None:
        try:
            # 환경 변수에서 설정 가져오기
            if "SERVER_MODEL" in os.environ:
                server_model = os.environ["SERVER_MODEL"]
            if "SERVER_PROMPT_TYPE" in os.environ:
                server_prompt_type = os.environ["SERVER_PROMPT_TYPE"]

            print(
                f"검색 함수에서 벡터 검색 초기화 - 모델: {server_model}, 프롬프트 타입: {server_prompt_type}"
            )
            # 서버 설정 사용
            vector_search = VectorSearch(
                model=server_model, prompt_type=server_prompt_type
            )
            vector_search.create_or_load_index()
        except Exception as e:
            raise HTTPException(
                status_code=400, detail=f"벡터 검색 인스턴스 초기화 실패: {str(e)}"
            )

    try:
        print(
            f"검색 수행 - 모델: {vector_search.model}, 프롬프트 타입: {vector_search.prompt_type}"
        )

        # 서버 설정 사용
        vector_search.model = server_model
        vector_search.prompt_type = server_prompt_type

        result = vector_search.search(
            query=request.query, search_query=request.search_query, k=request.k
        )
        return {
            "result": result,
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"검색 중 오류 발생: {str(e)}")


@app.command()
def server(
    host: str = "127.0.0.1",
    port: int = 8000,
    reload: bool = False,
    model: str = typer.Option(
        "gemini", help="사용할 모델 (groq, gemini, grok, grok-unofficial)"
    ),
    prompt_type: str = typer.Option(
        "general", help="사용할 프롬프트 타입 (general, relevance, keyword)"
    ),
):
    """REST API 서버 실행"""
    global server_model, server_prompt_type

    # 서버 설정 업데이트
    server_model = model
    server_prompt_type = prompt_type

    print(
        f"서버 시작 전 설정 - 모델: {server_model}, 프롬프트 타입: {server_prompt_type}"
    )

    print(f"서버를 시작합니다: http://{host}:{port}")
    print(f"기본 모델: {server_model}, 기본 프롬프트 타입: {server_prompt_type}")

    # reload 모드에서는 전역 변수가 초기화될 수 있으므로 환경 변수로 전달
    os.environ["SERVER_MODEL"] = server_model
    os.environ["SERVER_PROMPT_TYPE"] = server_prompt_type

    uvicorn.run("server:api_app", host=host, port=port, reload=reload)


@app.command()
def search_cli(
    model: str = typer.Option(
        "gemini", help="사용할 모델 (groq, gemini, grok, grok-unofficial)"
    ),
    prompt_type: str = typer.Option(
        "general", help="사용할 프롬프트 타입 (general, relevance, keyword)"
    ),
    separate_query: bool = typer.Option(
        False, help="벡터 검색 쿼리와 프롬프트 쿼리를 분리하여 입력"
    ),
):
    """기존 CLI 검색 기능"""
    global vector_search

    if vector_search is None:
        try:
            vector_search = VectorSearch(model=model, prompt_type=prompt_type)
            vector_search.create_or_load_index()
        except Exception as e:
            print(f"오류: {e}")
            return

    # 모델과 프롬프트 타입 설정
    vector_search.model = model
    vector_search.prompt_type = prompt_type

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
def test_api(
    host: str = typer.Option("127.0.0.1", help="API 서버 호스트"),
    port: int = typer.Option(8000, help="API 서버 포트"),
    model: str = typer.Option(None, help="사용할 모델 (서버 설정 오버라이드)"),
    prompt_type: str = typer.Option(
        None, help="사용할 프롬프트 타입 (서버 설정 오버라이드)"
    ),
):
    """API 서버의 /search 엔드포인트를 테스트합니다"""
    base_url = f"http://{host}:{port}"

    # 사용 가능한 모델 확인
    try:
        response = requests.get(f"{base_url}/models")
        if response.status_code == 200:
            print(f"사용 가능한 모델: {response.json()}")
        else:
            print(f"모델 목록 가져오기 실패: {response.status_code}")
            return
    except Exception as e:
        print(f"API 서버 연결 실패: {e}")
        print(f"서버가 {base_url}에서 실행 중인지 확인하세요.")
        return

    # 사용 가능한 프롬프트 타입 확인
    try:
        response = requests.get(f"{base_url}/prompt-types")
        if response.status_code == 200:
            print(f"사용 가능한 프롬프트 타입: {response.json()}")
        else:
            print(f"프롬프트 타입 목록 가져오기 실패: {response.status_code}")
            return
    except Exception as e:
        print(f"API 서버 연결 실패: {e}")
        return

    # 검색 테스트
    while True:
        query = input("\n검색할 내용을 입력하세요 (종료하려면 'q' 입력): ")
        if query.lower() == "q":
            break

        search_query = None
        use_separate_query = (
            input("벡터 검색에 별도의 키워드를 사용하시겠습니까? (y/n): ").lower()
            == "y"
        )

        if use_separate_query:
            search_query = input("벡터 검색에 사용할 키워드를 입력하세요: ")

        k = input("검색할 문서 수를 입력하세요 (기본값: 50): ")
        k = int(k) if k.isdigit() else 50

        # 요청 데이터 준비
        payload = {"query": query, "k": k}

        if search_query:
            payload["search_query"] = search_query

        # API 요청
        try:
            print(f"\n검색 중...")
            response = requests.post(
                f"{base_url}/search",
                json=payload,
            )

            if response.status_code == 200:
                result = response.json()
                print("\n=== 검색 결과 ===")
                print(result["result"])
                print("================")
            else:
                print(f"검색 실패: {response.status_code}")
                print(response.text)
        except Exception as e:
            print(f"API 요청 중 오류 발생: {e}")


if __name__ == "__main__":
    app()
