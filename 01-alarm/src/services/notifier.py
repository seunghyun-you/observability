import logging
from abc import ABC, abstractmethod

import httpx

logger = logging.getLogger(__name__)


# ──────────────────────────────────────────
# 공통 인터페이스
# ──────────────────────────────────────────
class BaseNotifier(ABC):
    """모든 Notifier가 구현해야 하는 공통 인터페이스"""

    def __init__(self, webhook_url: str, timeout: float = 10.0) -> None:
        self._webhook_url = webhook_url
        self._timeout = timeout
        self._client: httpx.AsyncClient | None = None

    async def start(self) -> None:
        """앱 시작 시 HTTP 클라이언트를 초기화합니다."""
        self._client = httpx.AsyncClient(timeout=self._timeout)

    async def stop(self) -> None:
        """앱 종료 시 HTTP 클라이언트를 정리합니다."""
        if self._client:
            await self._client.aclose()
            self._client = None

    @abstractmethod
    async def send(self, card: dict) -> None:
        """AdaptiveCard dict를 각 플랫폼 포맷에 맞게 전송합니다."""

    def _ensure_started(self) -> httpx.AsyncClient:
        if self._client is None:
            raise RuntimeError(
                f"{self.__class__.__name__} 가 시작되지 않았습니다. start()를 먼저 호출하세요."
            )
        return self._client


# ──────────────────────────────────────────
# MS Teams
# ──────────────────────────────────────────
class MSTeamsNotifier(BaseNotifier):
    """MS Teams Incoming Webhook 전송 — Adaptive Card를 attachments로 감쌉니다."""

    async def send(self, card: dict) -> None:
        client = self._ensure_started()

        # MS Teams 스펙: card를 attachments[].content 에 객체로 포함합니다.
        payload = {
            "type": "message",
            "attachments": [
                {
                    "contentType": "application/vnd.microsoft.card.adaptive",
                    "content": card,
                }
            ],
        }

        resp = await client.post(
            self._webhook_url,
            json=payload,
            headers={"Content-Type": "application/json"},
        )
        resp.raise_for_status()
        logger.info("MS Teams 전송 성공: status=%s", resp.status_code)


# ──────────────────────────────────────────
# Slack
# ──────────────────────────────────────────
class SlackNotifier(BaseNotifier):
    """Slack Incoming Webhook 전송 — AdaptiveCard를 Slack Block Kit 포맷으로 변환합니다."""

    async def send(self, card: dict) -> None:
        client = self._ensure_started()
        payload = {"blocks": self._to_slack_blocks(card)}

        resp = await client.post(
            self._webhook_url,
            json=payload,
            headers={"Content-Type": "application/json"},
        )
        resp.raise_for_status()
        logger.info("Slack 전송 성공: status=%s", resp.status_code)

    @staticmethod
    def _to_slack_blocks(card: dict) -> list[dict]:
        """AdaptiveCard body를 Slack Block Kit 블록 목록으로 변환합니다."""
        blocks: list[dict] = []

        for item in card.get("body", []):
            item_type = item.get("type")

            if item_type == "TextBlock":
                # 헤더 텍스트 → Slack header 블록
                blocks.append({
                    "type": "header",
                    "text": {"type": "plain_text", "text": item.get("text", ""), "emoji": True},
                })

            elif item_type == "FactSet":
                # FactSet → section with fields (mrkdwn)
                facts = item.get("facts", [])
                fields = [
                    {"type": "mrkdwn", "text": f"*{f['title']}*\n{f['value']}"}
                    for f in facts
                ]
                # Slack section fields 최대 10개 제한
                for i in range(0, len(fields), 10):
                    blocks.append({"type": "section", "fields": fields[i:i + 10]})

        return blocks


# ──────────────────────────────────────────
# Factory
# ──────────────────────────────────────────
def create_notifier(
    notifier_type: str,
    msteams_url: str | None,
    slack_url: str | None,
) -> BaseNotifier:
    """NOTIFIER_TYPE 에 따라 알맞은 Notifier 인스턴스를 반환합니다."""
    if notifier_type == "slack":
        return SlackNotifier(webhook_url=slack_url)  # type: ignore[arg-type]
    return MSTeamsNotifier(webhook_url=msteams_url)  # type: ignore[arg-type]
