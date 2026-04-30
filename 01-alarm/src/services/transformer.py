import re
from datetime import datetime, timezone, timedelta
from typing import Any
from urllib.parse import urlencode, urlparse, parse_qs, urlunparse

from models.grafana import GrafanaAlert


# severity → (이모지, AdaptiveCard 색상) 매핑
# 새로운 severity 추가 시 이 dict만 수정하면 됩니다.
_SEVERITY_MAP: dict[str, tuple[str, str]] = {
    "critical": ("🔴", "attention"),  # 빨강
    "warning":  ("🟡", "warning"),    # 노랑/주황
    "info":     ("🔵", "accent"),     # 파랑
}
_DEFAULT_SEVERITY: tuple[str, str] = ("⚪", "default")

# resolved는 severity 무관하게 항상 초록
_RESOLVED_COLOR = "good"
_RESOLVED_EMOJI = "🟢"

# 에스컬레이션 resolved: 현재값이 여전히 임계값 이상 (상위 band로 상승 중)
_ESCALATION_COLOR = "default"
_ESCALATION_EMOJI = "⬆️"

# 디에스컬레이션 resolved: 해당 band는 해소됐으나 하위 band 잔류 중
_DEESCALATION_COLOR = "good"
_DEESCALATION_EMOJI = "⬇️"

# Grafana가 datasource 장애 시 자동 생성하는 synthetic alert 이름
_DATASOURCE_ALERT_NAMES = {"DatasourceNoData", "DatasourceError"}

KST = timezone(timedelta(hours=9))


def _extract_threshold(alertname: str) -> int | None:
    """alertname 끝의 숫자를 임계값으로 추출합니다. (예: PodCPUUsageHigh70 → 70)
    숫자가 없으면 None 반환 → 단일 임계값 알람으로 간주하여 일반 resolved 처리.
    """
    m = re.search(r"(\d+)$", alertname)
    return int(m.group(1)) if m else None


def _parse_min_threshold(raw: str | None) -> int | None:
    """annotation의 min_threshold 값을 int로 변환합니다. 없거나 파싱 불가시 None 반환."""
    if raw is None:
        return None
    try:
        return int(raw)
    except (TypeError, ValueError):
        return None


def _build_resolved_context(threshold: int, current: float, min_threshold: int | None = None) -> tuple[str, str, str]:
    """다단계 임계값 알람의 resolved 메세지 컨텍스트를 반환합니다.

    min_threshold가 주어지면 3분기, 없으면 2분기로 처리합니다.

    Returns:
        (emoji, color, message) 튜플
        - 에스컬레이션  (current >= threshold)               : 상위 band로 상승 중
        - 디에스컬레이션 (min_threshold <= current < threshold): 해당 band 해소, 하위 band 잔류
        - 완전 해소     (current < min_threshold)            : 모든 임계값 아래로 복귀
        - 안정화 fallback (min_threshold 없음, current < threshold): annotation 미설정 룰 대응
    """
    if current >= threshold:
        message = f"{threshold}% 구간 초과 지속 (현재 {current:.1f}%)"
        return _ESCALATION_EMOJI, _ESCALATION_COLOR, message

    if min_threshold is not None:
        if current >= min_threshold:
            # 디에스컬레이션: 해당 band는 해소됐으나 하위 band 잔류
            message = f"{threshold}% 구간 해소 (현재 {current:.1f}%)"
            return _DEESCALATION_EMOJI, _DEESCALATION_COLOR, message
        else:
            # 완전 해소: 최하위 임계값 아래로 복귀
            message = f"정상 범위 복귀 (현재 {current:.1f}%)"
            return _RESOLVED_EMOJI, _RESOLVED_COLOR, message

    # min_threshold annotation 미설정 → 기존 2분기 안정화 처리
    message = f"{threshold}% 구간 해소 (현재 {current:.1f}%)"
    return _RESOLVED_EMOJI, _RESOLVED_COLOR, message


def _parse_fired_at(iso_string: str) -> str:
    """ISO 8601 문자열을 KST 시각 문자열로 변환합니다."""
    try:
        dt = datetime.fromisoformat(iso_string.replace("Z", "+00:00"))
        return dt.astimezone(KST).strftime("%Y-%m-%d %H:%M:%S KST")
    except ValueError:
        return iso_string or "알 수 없음"


def _build_dashboard_url(dashboard_url: str, labels: dict[str, Any]) -> str:
    """dashboard_url의 기존 쿼리 파라미터를 유지하면서
    labels의 namespace/datasource 값으로 var-* 파라미터를 교체합니다.
    (Grafana가 보낸 from/to/timezone 등은 그대로 유지)
    """
    if not dashboard_url:
        return ""

    parsed = urlparse(dashboard_url)
    # parse_qs는 멀티밸류 dict 반환 → {key: [value, ...]}
    params = parse_qs(parsed.query, keep_blank_values=True)

    # alert labels 값으로 덮어쓰기 (없으면 기존 값 유지)
    if ns := labels.get("namespace"):
        params["var-namespace"] = [ns]
    if ds := labels.get("datasource"):
        params["var-datasource"] = [ds]

    new_query = urlencode({k: v[0] for k, v in params.items()})
    return urlunparse(parsed._replace(query=new_query))


def _format_current_value(values: dict[str, Any], alertname: str = "") -> str:
    """alert values에서 의미 있는 수치(B > A 우선)를 소수점 1자리로 포맷합니다.
    C는 threshold 평가 결과(0/1)이므로 제외합니다.
    alertname에 cpu/memory/mem/filesystem/fs/disk 키워드가 있으면 % 단위를 붙입니다.
    """
    if not values:
        return "-"

    # B가 reduce된 최종 값, A가 원본 PromQL 결과 — 둘 다 없으면 C 이외의 첫 번째 값 사용
    raw = values.get("B") if values.get("B") is not None else values.get("A")
    if raw is None:
        raw = next((v for k, v in values.items() if k != "C"), None)

    if raw is None:
        return "-"

    try:
        val = float(raw)
    except (TypeError, ValueError):
        return str(raw)

    name = alertname.lower()
    if any(k in name for k in ("cpu", "memory", "mem", "filesystem", "fs", "disk", "pvc", "usage")):
        return f"{val:.1f}%"
    return f"{val:.1f}"


def _fact(title: str, value: str) -> dict | None:
    """값이 없거나 '-'이면 None을 반환하여 FactSet에서 제외합니다."""
    return {"title": title, "value": value} if value and value != "-" else None


def _build_facts(
    cluster: str, namespace: str, instance: str,
    device: str, mountpoint: str, fstype: str,
    pvc: str, container: str,
    current_val: str, time_at: str,
) -> list[dict]:
    """AdaptiveCard FactSet용 facts 목록을 조립합니다.
    - device/mountpoint가 있으면 파일시스템 정보를 포함합니다 (NodeFilesystem).
    - pvc가 있으면 PVC 이름을 표시하고 의미없는 instance를 제외합니다 (PVCUsage/PVCNotBound).
    - 그 외에는 네임스페이스/인스턴스(pod)/컨테이너를 표시합니다 (Pod/Node 알림).
    심각도는 헤더에 표시되므로 FactSet에서 제외합니다.
    값이 없거나 '-'인 항목은 제외합니다.
    """
    candidates: list[dict | None] = [
        {"title": "클러스터", "value": cluster},  # 항상 표시
    ]

    if device or mountpoint:
        # 파일시스템 알림: 디바이스/마운트 경로/파일시스템 타입 표시 (네임스페이스 제외)
        candidates += [
            _fact("인스턴스",    instance),
            _fact("디바이스",    device),
            _fact("마운트 경로", mountpoint),
            _fact("파일시스템",  fstype),
        ]
    elif pvc:
        # PVC 알림: PVC 이름 표시, kubelet/kube-state-metrics instance는 의미없으므로 제외
        candidates += [
            _fact("네임스페이스", namespace),
            _fact("PVC",         pvc),
        ]
    else:
        candidates += [
            _fact("네임스페이스", namespace),
            _fact("인스턴스",    instance),
            _fact("컨테이너",    container),  # 값 있을 때만 표시 (CrashLoopBackOff, OOMKilled 등)
        ]

    candidates += [
        _fact("현재 값", current_val),
        {"title": "발생 시각", "value": time_at},  # 항상 표시
    ]

    return [f for f in candidates if f is not None]


def build_adaptive_card(alert: GrafanaAlert, external_url: str = "") -> dict:
    """Grafana alert 객체를 MS Teams AdaptiveCard dict로 변환합니다."""
    raw_alertname = alert.labels.get("alertname", "알 수 없는 알람")
    # "[GLOBAL-DEV] PodCPUUsageHigh90" → "PodCPUUsageHigh90"
    alert_name    = raw_alertname.split("] ", 1)[1] if raw_alertname.startswith("[") and "] " in raw_alertname else raw_alertname
    time_at       = _parse_fired_at(alert.starts_at)
    cluster       = alert.annotations.get("cluster", "-")                         # 클러스터 식별자 (예: [GLOBAL-DEV])
    severity      = alert.labels.get("severity", "")                              # 심각도 (critical, warning, info 등)
    namespace     = alert.labels.get("namespace", "-")                            # K8s 네임스페이스
    instance      = alert.labels.get("pod") or alert.labels.get("instance", "-") # Pod 이름 우선, 없으면 인스턴스 IP (node 알림)
    device        = alert.labels.get("device", "")                               # 파일시스템 디바이스 (예: /dev/sda1)
    mountpoint    = alert.labels.get("mountpoint", "")                            # 마운트 경로 (예: /var)
    fstype        = alert.labels.get("fstype", "")                                # 파일시스템 타입 (예: ext4)
    pvc           = alert.labels.get("persistentvolumeclaim", "")                 # PVC 이름 (PVC 알림 전용)
    container     = alert.labels.get("container", "")                             # 컨테이너 이름 (CrashLoopBackOff, OOMKilled 등)
    current_val   = _format_current_value(alert.values, alert_name)
    dashboard_url = _build_dashboard_url(alert.dashboard_url, alert.labels)

    severity_emoji, severity_color = _SEVERITY_MAP.get(severity.lower(), _DEFAULT_SEVERITY)

    # resolved는 severity 무관하게 초록, firing은 severity 기반 색상
    # 다단계 임계값 알람(alertname 끝이 숫자)의 resolved는 현재값과 임계값을 비교하여
    # 에스컬레이션(상위 band 상승) 또는 안정화(정상 복귀)로 구분합니다.
    if alert.status == "resolved":
        status_text = "[RESOLVED]"
        threshold   = _extract_threshold(alert_name)
        raw_b       = alert.values.get("B")

        if threshold is not None and raw_b is not None:
            try:
                min_thr = _parse_min_threshold(alert.annotations.get("min_threshold"))
                emoji, header_color, message = _build_resolved_context(threshold, float(raw_b), min_thr)
            except (TypeError, ValueError):
                # float 변환 실패 → 일반 resolved fallback
                emoji        = _RESOLVED_EMOJI
                header_color = _RESOLVED_COLOR
                message      = alert.annotations.get("summary") or alert.annotations.get("description", "")
        else:
            # 단일 임계값 알람이거나 values.B 없음 → 일반 resolved
            emoji        = _RESOLVED_EMOJI
            header_color = _RESOLVED_COLOR
            message      = alert.annotations.get("summary") or alert.annotations.get("description", "")
    else:
        emoji        = severity_emoji
        header_color = severity_color
        status_text  = "[FIRING]"

    is_datasource_alert = alert_name in _DATASOURCE_ALERT_NAMES
    if is_datasource_alert:
        # summary/description은 원래 룰의 annotation이 오염되어 전달되므로 무시
        message = ""
    elif alert.status != "resolved":
        # firing: 원래 annotation에서 메세지 구성
        message = alert.annotations.get("summary") or alert.annotations.get("description", "")

    body: list[dict] = [
        # 제목: "🔴 CRITICAL [FIRING] alertname" 형태 — 이모지 + severity 색상으로 표시
        {
            "type": "TextBlock",
            "text": f"{emoji}{' ' + severity.upper() if severity else ''} {status_text} {alert_name}",
            "weight": "Bolder",
            "size": "Medium",
            "color": header_color,
        },
        # 주요 정보 FactSet (심각도는 헤더에 표시되므로 제외)
        {
            "type": "FactSet",
            "facts": _build_facts(cluster, namespace, instance, device, mountpoint, fstype, pvc, container, current_val, time_at),
        },
    ]

    # summary 또는 description 이 있을 때만 메시지 블록 추가 (구분선 포함)
    if message:
        body.append({
            "type": "TextBlock",
            "text": message,
            "wrap": True,
            "weight": "Bolder",
            "separator": True,  # FactSet과 시각적으로 구분
        })

    card: dict = {
        "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
        "type": "AdaptiveCard",
        "version": "1.0",
        "body": body,
    }

    # 액션 버튼: dashboardURL / silenceURL 있을 때만 추가
    actions: list[dict] = []
    if is_datasource_alert:
        # datasource alert는 dashboard 대신 datasource edit 페이지로 연결
        datasource_uid = alert.labels.get("datasource", "")
        if external_url and datasource_uid:
            actions.append({
                "type": "Action.OpenUrl",
                "title": "Grafana 데이터소스 열기",
                "url": f"{external_url.rstrip('/')}/connections/datasources/edit/{datasource_uid}",
            })
    elif dashboard_url:
        actions.append({
            "type": "Action.OpenUrl",
            "title": "Grafana 대시보드 열기",
            "url": dashboard_url,
        })
    if alert.silence_url:
        actions.append({
            "type": "Action.OpenUrl",
            "title": "알람 무음 처리",
            "url": alert.silence_url,
        })
    if actions:
        card["actions"] = actions

    return card
