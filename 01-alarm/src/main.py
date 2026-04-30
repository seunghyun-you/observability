import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI

from config import settings
from controllers.webhook import router as webhook_router
from services.dedup import DedupCache
from services.notifier import create_notifier

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


# ──────────────────────────────────────────
# 앱 생명 주기: Notifier HTTP 클라이언트 공유
# ──────────────────────────────────────────
@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.notifier = create_notifier(
        notifier_type=settings.notifier_type,
        msteams_url=settings.ms_teams_webhook_url,
        slack_url=settings.slack_webhook_url,
    )
    app.state.dedup = DedupCache(ttl_seconds=3600)
    await app.state.notifier.start()
    logger.info("%s 시작 완료 (type=%s)", app.state.notifier.__class__.__name__, settings.notifier_type)
    yield
    await app.state.notifier.stop()
    logger.info("%s 종료 완료", app.state.notifier.__class__.__name__)


# ──────────────────────────────────────────
# FastAPI 앱
# ──────────────────────────────────────────
app = FastAPI(title="Grafana → Teams 알람 중계 서버", lifespan=lifespan)
app.include_router(webhook_router)


# ──────────────────────────────────────────
# 서버 실행
# ──────────────────────────────────────────
if __name__ == "__main__":
    import uvicorn

    # main:app 문자열로 넘겨야 reload 가능 / app 객체 바로 넘기면 reload 불가
    uvicorn.run("main:app", host="0.0.0.0", port=settings.app_port, reload=False)
