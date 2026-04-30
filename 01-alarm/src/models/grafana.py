from typing import Annotated, Any

from pydantic import BaseModel, Field, field_validator


class GrafanaAlert(BaseModel):
    """Grafana 단일 alert 객체"""

    status: str = ""                                               # 알람 상태 (firing / resolved)
    labels: dict[str, Any] = Field(default_factory=dict)          # 알람 식별 레이블 (alertname, instance 등)
    annotations: dict[str, Any] = Field(default_factory=dict)     # 알람 설명 (summary, description 등)
    starts_at: Annotated[str, Field(alias="startsAt")] = ""         # 알람 발생 시각 (ISO 8601)
    ends_at: Annotated[str, Field(alias="endsAt")] = ""            # 알람 종료 시각 (ISO 8601, resolved 시 채워짐)
    fingerprint: str = ""                                          # 알람 고유 식별자
    generator_url: Annotated[str, Field(alias="generatorURL")] = ""  # 알람을 발생시킨 Grafana 쿼리 URL
    silence_url: Annotated[str, Field(alias="silenceURL")] = ""    # 알람 무음 처리 URL
    dashboard_url: Annotated[str, Field(alias="dashboardURL")] = ""  # 관련 Grafana 대시보드 URL
    panel_url: Annotated[str, Field(alias="panelURL")] = ""        # 관련 Grafana 패널 URL
    values: dict[str, Any] = Field(default_factory=dict)          # 알람 발생 시점의 실제 메트릭 수치

    model_config = {"populate_by_name": True}

    # DatasourceNoData 등 일부 알람 타입이 null을 보내는 경우 빈 dict로 치환
    @field_validator("labels", "annotations", "values", mode="before")
    @classmethod
    def coerce_null_to_dict(cls, v: Any) -> dict:
        return v if isinstance(v, dict) else {}

    # Grafana가 str 필드에 null을 보내는 경우 빈 문자열로 치환
    @field_validator(
        "status", "starts_at", "ends_at", "fingerprint",
        "generator_url", "silence_url", "dashboard_url", "panel_url",
        mode="before",
    )
    @classmethod
    def coerce_null_to_str(cls, v: Any) -> str:
        return v if isinstance(v, str) else ""


class GrafanaWebhookPayload(BaseModel):
    """Grafana Webhook 전체 페이로드"""

    receiver: str = ""                                                                                          # Grafana에서 설정한 수신자 이름
    status: str = ""                                                                                           # 전체 페이로드 상태 (firing / resolved)
    alerts: list[GrafanaAlert] = Field(default_factory=list)                                                   # 알람 목록 (여러 개 동시 전송 가능)
    group_labels: Annotated[dict[str, Any], Field(alias="groupLabels")] = Field(default_factory=dict)          # 알람 그룹 기준 레이블
    common_labels: Annotated[dict[str, Any], Field(alias="commonLabels")] = Field(default_factory=dict)        # 모든 알람에 공통된 레이블
    common_annotations: Annotated[dict[str, Any], Field(alias="commonAnnotations")] = Field(default_factory=dict)  # 모든 알람에 공통된 annotations
    external_url: Annotated[str, Field(alias="externalURL")] = ""                                              # Grafana 서버 외부 접근 URL
    version: str = ""                                                                                          # Grafana Webhook 스펙 버전
    group_key: Annotated[str, Field(alias="groupKey")] = ""                                                    # 같은 그룹으로 묶인 알람들의 키
    truncated_alerts: Annotated[int, Field(alias="truncatedAlerts")] = 0                                       # 알람이 너무 많아 잘렸을 때 잘린 개수
    org_id: Annotated[int, Field(alias="orgId")] = 0                                                           # Grafana 조직 ID
    title: str = ""                                                                                            # 알람 제목
    state: str = ""                                                                                            # 알람 상태 (alerting / ok)
    message: str = ""                                                                                          # 알람 메시지

    model_config = {"populate_by_name": True}

    # Grafana가 dict 필드에 null을 보내는 경우 빈 dict로 치환
    @field_validator("group_labels", "common_labels", "common_annotations", mode="before")
    @classmethod
    def coerce_null_to_dict(cls, v: Any) -> dict:
        return v if isinstance(v, dict) else {}

    # Grafana가 str 필드에 null을 보내는 경우 빈 문자열로 치환
    @field_validator("receiver", "status", "external_url", "version", "group_key", "title", "state", "message", mode="before")
    @classmethod
    def coerce_null_to_str(cls, v: Any) -> str:
        return v if isinstance(v, str) else ""
