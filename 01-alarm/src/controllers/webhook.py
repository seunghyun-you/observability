import asyncio
import logging

import httpx
from fastapi import APIRouter, Depends, Request
from fastapi.responses import JSONResponse

from models.grafana import GrafanaWebhookPayload
from models.response import WebhookResponse
from services.dedup import DedupCache
from services.notifier import BaseNotifier
from services.transformer import build_adaptive_card

logger = logging.getLogger(__name__)
router = APIRouter()

# main.py 직접 import 시 순환 참조 발생 → request.app 으로 우회
def get_notifier(request: Request) -> BaseNotifier:
    """app.state 에서 Notifier 인스턴스를 주입합니다."""
    return request.app.state.notifier


def get_dedup(request: Request) -> DedupCache:
    """app.state 에서 DedupCache 인스턴스를 주입합니다."""
    return request.app.state.dedup


# ──────────────────────────────────────────
# 수신: Grafana Webhook 엔드포인트
# ──────────────────────────────────────────
@router.post("/webhook", response_model=WebhookResponse)
async def receive_grafana_webhook(
    payload: GrafanaWebhookPayload,
    notifier: BaseNotifier = Depends(get_notifier),
    dedup: DedupCache = Depends(get_dedup),
):
    """Grafana 알람 Webhook을 수신하여 Teams로 중계합니다."""
    logger.info(
        "Grafana Webhook 수신: receiver=%s, alerts=%d",
        payload.receiver,
        len(payload.alerts),
    )

    if payload.truncated_alerts > 0:
        logger.warning("알람 %d건이 잘려서 전송되지 않았습니다.", payload.truncated_alerts)

    if not payload.alerts:
        logger.warning("alerts 배열이 비어 있습니다. 전송을 건너뜁니다.")
        return WebhookResponse(status="skipped")

    async def process(alert) -> str | None:
        """단일 alert 처리. 실패 시 에러 문자열 반환, 성공 시 None."""
        try:
            alertname   = alert.labels.get("alertname", "")
            datasource  = alert.labels.get("datasource", "")
            cluster     = alert.labels.get("cluster") or alert.annotations.get("cluster", "")
            severity    = alert.labels.get("severity", "")

            if not dedup.should_send(alertname, datasource, cluster, alert.status, alert.fingerprint, severity):
                logger.info(
                    "중복 skip: alertname=%s status=%s severity=%s cluster=%s datasource=%s fingerprint=%s",
                    alertname, alert.status, severity, cluster, datasource, alert.fingerprint,
                )
                return None

            logger.info(
                "알람 전송: alertname=%s status=%s severity=%s cluster=%s datasource=%s fingerprint=%s",
                alertname, alert.status, severity, cluster, datasource, alert.fingerprint,
            )
            card = build_adaptive_card(alert, payload.external_url)
            await notifier.send(card)
            return None
        except httpx.HTTPStatusError as e:
            logger.error("Teams 전송 실패: %s", e)
            return str(e)
        except Exception as e:
            logger.error("처리 중 오류: [%s] %s", type(e).__name__, e)
            return f"{type(e).__name__}: {e}"

    # 모든 alert 병렬 처리 — 성공: None, 실패: 에러 문자열
    results = await asyncio.gather(*[process(a) for a in payload.alerts])
    errors = [r for r in results if r is not None]
    forwarded = len(payload.alerts) - len(errors)

    if errors:
        return JSONResponse(
            status_code=502,
            content=WebhookResponse(
                status="partial_error" if forwarded else "error",
                forwarded=forwarded,
                errors=errors,
            ).model_dump(),
        )

    return WebhookResponse(status="ok", forwarded=forwarded)


# ──────────────────────────────────────────
# 헬스 체크
# ──────────────────────────────────────────
@router.get("/health")
async def health():
    return {"status": "healthy"}
