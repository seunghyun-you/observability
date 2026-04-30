from typing import Literal

from pydantic import model_validator
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """환경 변수 설정 — 필수 값이 없으면 서버 시작 시 ValidationError 발생"""

    notifier_type: Literal["msteams", "slack"] = "msteams"  # 전송 대상 플랫폼

    ms_teams_webhook_url: str | None = None  # MS Teams Webhook URL
    slack_webhook_url: str | None = None     # Slack Webhook URL

    app_port: int = 8000  # 서버 포트

    # os.environ 우선, 없으면 .env 파일에서 로드
    model_config = {"env_file": ".env", "env_file_encoding": "utf-8"}

    @model_validator(mode="after")
    def check_required_webhook_url(self) -> "Settings":
        """NOTIFIER_TYPE에 맞는 Webhook URL이 반드시 설정되어야 합니다."""
        if self.notifier_type == "msteams" and not self.ms_teams_webhook_url:
            raise ValueError("NOTIFIER_TYPE=msteams 일 때 MS_TEAMS_WEBHOOK_URL 이 필요합니다.")
        if self.notifier_type == "slack" and not self.slack_webhook_url:
            raise ValueError("NOTIFIER_TYPE=slack 일 때 SLACK_WEBHOOK_URL 이 필요합니다.")
        return self


# 모듈 임포트 시점에 한 번만 로드하여 상수처럼 사용
settings = Settings()
