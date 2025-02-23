import groq
import typer
import requests
from pathlib import Path
import json
from tqdm import tqdm
import concurrent.futures
import time
import google.generativeai as genai
from dotenv import load_dotenv
import os

# 환경 변수 로드
load_dotenv()

app = typer.Typer()


def load_system_prompt(prompt_type: str = "prompt-general.txt") -> str:
    """시스템 프롬프트 로드"""
    prompt_path = Path(f"{prompt_type}")
    if not prompt_path.exists():
        raise FileNotFoundError(f"프롬프트 파일을 찾을 수 없습니다: {prompt_path}")

    with open(prompt_path, "r", encoding="utf-8") as f:
        return f.read().strip()


def extract_raw_text(id: str) -> bool:
    """원본 텍스트를 추출하여 raw 디렉토리에 저장"""
    # raw 디렉토리 생성
    raw_dir = Path("raw")
    raw_dir.mkdir(exist_ok=True)

    output_file = raw_dir / f"{id}.txt"
    if output_file.exists():
        return True

    url = f"http://127.0.0.1:12332/article/{id}"

    response = requests.get(url)
    if response.status_code != 200:
        print("데이터를 가져오지 못했습니다. 상태 코드:", response.status_code)
        return False

    data = response.json()

    # 응답이 비어있는지 확인
    if not data:
        print("응답 데이터가 비어있습니다.")
        return False

    with open(output_file, "w", encoding="utf-8") as f:
        for item in data:
            raw_text = item.get("Raw", "")
            if raw_text:
                f.write(raw_text + "\n")

    print(f"데이터가 성공적으로 '{output_file}' 파일에 저장되었습니다.")
    return True


class SummarizeError(Exception):
    """요약 과정에서 발생하는 에러들을 위한 기본 클래스"""

    pass


class APIError(SummarizeError):
    """API 호출 관련 에러"""

    pass


class ContentTooLongError(SummarizeError):
    """컨텐츠가 너무 긴 경우의 에러"""

    pass


class FileError(SummarizeError):
    """파일 처리 관련 에러"""

    pass


# llama-3.3-70b-specdec
# llama-3.3-70b-versatile
# llama3-70b-8192
# llama-3.2-90b-vision-preview
# llama-3.2-11b-vision-preview
# mixtral-8x7b-32768 -> 한국어 잘 못함
# llama-3.2-3b-preview -> 너무 작은 모델
# llama-3.1-8b-instant -> 약간 애메
# deepseek-r1-distill-llama-70b -> 미사여구 너무 김


def get_llm_response(client_type: str, content: str) -> str:
    """LLM API를 호출하여 응답을 받아옵니다"""

    try:
        system_prompt = load_system_prompt()
    except FileNotFoundError as e:
        print(f"경고: {e}")
        print("기본 프롬프트를 사용합니다.")
        system_prompt = """
주어진 대사들로 스토리를 한국어로 아래와 같은 형식으로 요약해줘.
* 스토리 요약: 스토리의 핵심 내용을 자세하게 요약해줘.
* 관련 태그들: 이 대화에 관한 태그들을 단어들로 출력
* 성적인 묘사: 어떤 성적인 묘사들과 장면들이 있는지 단어들로 출력
* 등장인물: 각 등장인물의 나이나 옷차림 등도 포함해서 출력 
            """

    if client_type == "groq":
        client = groq.Groq(api_key=os.getenv("GROQ_API_KEY"))
        completion = client.chat.completions.create(
            model="llama-3.3-70b-specdec",
            messages=[{"role": "user", "content": content}],
            temperature=0.1,
            max_tokens=1000,
        )
        return completion.choices[0].message.content
    elif client_type == "gemini":
        genai.configure(api_key=os.getenv("GOOGLE_API_KEY"))

        # 모델 설정
        # gemini-pro
        # gemini-2.0-flash
        model = genai.GenerativeModel("gemini-2.0-flash")

        # 채팅 시작
        chat = model.start_chat(history=[])

        # 시스템 프롬프트와 컨텐츠를 합쳐서 전송
        response = chat.send_message(
            f"{system_prompt}\n\n다음 대사들로 스토리를 요약해줘.\n\n{content}",
            generation_config=genai.types.GenerationConfig(
                temperature=0.1,
                max_output_tokens=1000,
            ),
        )

        return response.text
    else:
        raise ValueError(f"지원하지 않는 LLM 타입입니다: {client_type}")


def summarize_text(id: str, llm_type: str = "groq") -> bool:
    """추출된 텍스트를 요약하여 result 디렉토리에 저장"""
    try:
        text_path = Path("raw") / f"{id}.txt"
        with open(text_path, "r", encoding="utf-8") as file:
            content = file.read()
    except Exception as e:
        raise FileError(f"파일 읽기 실패: {e}")

    max_chunk_size = 4000
    chunks = [
        content[i : i + max_chunk_size] for i in range(0, len(content), max_chunk_size)
    ]

    if len(chunks) > 1:
        raise ContentTooLongError(f"텍스트가 너무 깁니다 (청크 {len(chunks)}개)")

    summaries = []

    for chunk in chunks:
        try:
            summary = get_llm_response(llm_type, chunk)
            summaries.append(summary)
        except Exception as e:
            raise APIError(f"API 호출 실패: {e}")

    final_summary = "\n\n".join(summaries)

    result_dir = Path("result")
    result_dir.mkdir(exist_ok=True)

    result_file = result_dir / f"{id}.txt"
    try:
        with open(result_file, "w", encoding="utf-8") as f:
            f.write(final_summary)
        print(f"\n=== 텍스트 요약 결과가 {result_file}에 저장되었습니다 ===\n")
        print(final_summary)
        print("\n=====================\n")
        return True
    except Exception as e:
        raise FileError(f"결과 저장 실패: {e}")


@app.command()
def process_single(id: str, llm_type: str = "groq") -> None:
    """단일 ID 처리"""
    result_file = Path("result") / f"{id}.txt"
    if result_file.exists():
        tqdm.write(f"ID {id}: 이미 처리됨, 건너뜁니다.")
        return

    tqdm.write(f"\nID {id} 처리 중...")
    try:
        if extract_raw_text(id):
            while True:  # 무한 재시도 루프 추가
                try:
                    summarize_text(id, llm_type)
                    break  # 성공하면 루프 종료
                except APIError as e:
                    tqdm.write(f"ID {id}: {e}")
                    tqdm.write("API 오류 발생. 3분 후 다시 시도합니다...")
                    time.sleep(180)  # 3분 대기
                except Exception as e:
                    tqdm.write(f"ID {id}: 알 수 없는 오류 발생: {e}")
                    raise  # API 오류가 아닌 경우는 중단
        else:
            tqdm.write(f"ID {id}: 텍스트 추출 실패")
    except ContentTooLongError as e:
        tqdm.write(
            f"ID {id}: {e}"
        )  # 긴 텍스트는 정상적인 스킵이므로 프로세스 계속 진행
    except FileError as e:
        tqdm.write(f"ID {id}: {e}")  # 파일 오류는 해당 ID만 스킵
    except Exception as e:
        tqdm.write(f"ID {id}: 알 수 없는 오류 발생: {e}")
        raise  # 알 수 없는 오류는 전체 프로세스 중단


@app.command()
def process_list(workers: int = 1, llm_type: str = "groq"):
    """lists.json에서 ID들을 읽어와서 병렬로 처리

    Args:
        workers: 동시 처리할 작업 수 (기본값: 3)
        llm_type: 사용할 LLM 타입 ("groq" 또는 "gemini", 기본값: "groq")
    """
    try:
        with open("lists.json", "r", encoding="utf-8") as f:
            ids = json.load(f)

        ids.reverse()  # IDs를 반대로 정렬

        if not ids:
            print("처리할 ID가 없습니다.")
            return

        print(f"총 {len(ids)}개의 ID를 {workers}개의 워커로 처리합니다.")

        # 프로그레스바 초기화
        pbar = tqdm(total=len(ids), desc="전체 진행 상황")

        # 스레드풀 생성 및 작업 실행
        with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as executor:
            # 작업 제출
            futures = [executor.submit(process_single, id, llm_type) for id in ids]

            # 작업 완료 대기 및 진행상황 업데이트
            for future in concurrent.futures.as_completed(futures):
                try:
                    future.result()  # 작업 결과 확인 (예외 발생 여부)
                except Exception as e:
                    tqdm.write(f"작업 처리 중 오류 발생: {e}")
                    exit(1)
                finally:
                    pbar.update(1)

        pbar.close()
        print("\n모든 처리가 완료되었습니다.")

    except Exception as e:
        print(f"처리 중 오류 발생: {e}")


if __name__ == "__main__":
    app()
