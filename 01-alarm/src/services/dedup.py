import time


# DatasourceError/NoData 중복 제거 대상 alertname
DATASOURCE_ALERT_NAMES = {"DatasourceNoData", "DatasourceError"}

# severity별 TTL = repeat_interval과 동일하게 맞춰야
# group_interval 재발송(억제 대상)과 repeat_interval 재발송(허용 대상)을 구분할 수 있음
_SEVERITY_TTL: dict[str, int] = {
    "critical": 3600,   # 1h
    "warning":  14400,  # 4h
    "info":     86400,  # 24h
}
_DEFAULT_TTL = 3600


class DedupCache:
    """알람 중복 전송 방지 캐시.

    1) DatasourceError/NoData: (datasource, cluster) 기준 TTL 내 첫 firing만 전송
    2) 일반 알람: fingerprint 기준으로 이미 전송한 firing을 TTL(=repeat_interval) 내 억제
       - group_interval로 재포함된 already-firing 알람을 억제하는 것이 목적
       - TTL 만료 후 재수신 = repeat_interval 도달 → 허용
       - resolved는 항상 전송하고 캐시 삭제
    """

    def __init__(self, ttl_seconds: int = 3600):
        self._default_ttl = ttl_seconds
        self._cache: dict[tuple, float] = {}  # key → 만료 시각(monotonic)

    def _make_datasource_key(self, datasource: str, cluster: str) -> tuple:
        return ("ds", datasource, cluster)

    def _make_fingerprint_key(self, fingerprint: str) -> tuple:
        return ("fp", fingerprint)

    def _evict_expired(self) -> None:
        now = time.monotonic()
        expired = [k for k, exp in self._cache.items() if now >= exp]
        for k in expired:
            del self._cache[k]

    def _ttl_for_severity(self, severity: str) -> int:
        return _SEVERITY_TTL.get(severity.lower(), _DEFAULT_TTL)

    def should_send(
        self,
        alertname: str,
        datasource: str,
        cluster: str,
        status: str,
        fingerprint: str = "",
        severity: str = "",
    ) -> bool:
        """True면 전송, False면 skip.

        - resolved: 항상 True (캐시 삭제)
        - DatasourceError/NoData firing: (datasource, cluster) 기준 중복 억제
        - 일반 알람 firing: fingerprint 기준, TTL(=repeat_interval) 내 중복 억제
        """
        self._evict_expired()

        # DatasourceError/NoData 전용 로직
        if alertname in DATASOURCE_ALERT_NAMES:
            key = self._make_datasource_key(datasource, cluster)
            if status == "resolved":
                self._cache.pop(key, None)
                return True
            if key in self._cache:
                return False
            self._cache[key] = time.monotonic() + self._default_ttl
            return True

        # 일반 알람: fingerprint 기반
        if not fingerprint:
            return True

        key = self._make_fingerprint_key(fingerprint)

        if status == "resolved":
            self._cache.pop(key, None)
            return True

        # firing: 캐시에 있으면 억제 (group_interval 재포함된 already-firing)
        if key in self._cache:
            return False

        self._cache[key] = time.monotonic() + self._ttl_for_severity(severity)
        return True
