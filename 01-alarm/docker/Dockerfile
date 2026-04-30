# ──────────────────────────────────────────
# Stage 1: 의존성 설치 (builder)
# ──────────────────────────────────────────
FROM python:3.11-slim AS builder

WORKDIR /build

# 의존성만 먼저 복사하여 레이어 캐시를 최대한 활용
COPY requirements.txt .

RUN pip install --upgrade pip \
    && pip install --no-cache-dir --prefix=/install -r requirements.txt


# ──────────────────────────────────────────
# Stage 2: 실행 이미지 (runtime)
# ──────────────────────────────────────────
FROM python:3.11-slim AS runtime

# 보안: root가 아닌 전용 사용자로 실행
RUN groupadd --system appgroup \
    && useradd --system --gid appgroup --no-create-home appuser

WORKDIR /app

# builder 스테이지에서 설치된 패키지만 복사
COPY --from=builder /install /usr/local

# 소스 코드 복사
COPY src/ ./src/

# src 디렉토리를 Python 모듈 탐색 경로에 추가
ENV PYTHONPATH=/app/src

# 파일 소유권을 appuser로 변경
RUN chown -R appuser:appgroup /app

USER appuser

# 환경 변수 기본값 (실제 값은 컨테이너 실행 시 주입)
ENV APP_PORT=8000

EXPOSE ${APP_PORT}

# 헬스 체크
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:${APP_PORT}/health')"

ENTRYPOINT ["python", "src/main.py"]
