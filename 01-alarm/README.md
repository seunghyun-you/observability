# Grafana → MS Teams 알람 중계 서버

Grafana Webhook을 수신하여 **MS Teams**, **Slack** 으로 전달하는 Python 중계 서버
<br>


## Folder Structure

```
src/
├── main.py                   # FastAPI 앱 진입점, lifespan 관리
├── config.py                 # 환경 변수 로드 (Pydantic Settings)
├── controllers/
│   └── webhook.py            # /webhook, /health 엔드포인트
├── models/
│   ├── grafana.py            # Grafana Webhook 수신 모델
│   └── response.py           # API 응답 모델
└── services/
    ├── transformer.py        # Grafana alert → AdaptiveCard 변환
    ├── notifier.py           # 전송 (MSTeamsNotifier / SlackNotifier)
    └── dedup.py              # 중복 알람 제거 (TTL 기반)
```
<br>


## 주요 기능

| 기능                   | 설명                                                                   |
| ---------------------- | ---------------------------------------------------------------------- |
| **플랫폼 추상화**      | `NOTIFIER_TYPE` 환경 변수 하나로 MS Teams / Slack 전환                 |
| **AdaptiveCard 변환**  | Grafana alert payload → 플랫폼별 포맷으로 자동 변환                    |
| **다단계 임계값 처리** | alertname 끝 숫자(70/80/90) 기반으로 에스컬레이션/디에스컬레이션 구분  |
| **중복 제거**          | 동일 alert의 중복 전송을 TTL 캐시로 방지 (기본 1시간)                  |
| **병렬 처리**          | 다수의 alert를 `asyncio.gather`로 병렬 전송                            |
| **Datasource 알람**    | Grafana datasource 장애 알람을 별도 처리 (datasource 편집 페이지 연결) |
<br>

## 환경 변수

> `NOTIFIER_TYPE`에 맞는 URL이 없으면 서버 시작 시 즉시 오류가 발생합니다.

| 변수명                 | 필수              | 기본값    | 설명                                    |
| ---------------------- | ----------------- | --------- | --------------------------------------- |
| `NOTIFIER_TYPE`        |                   | `msteams` | 전송 대상 플랫폼 (`msteams` \| `slack`) |
| `MS_TEAMS_WEBHOOK_URL` | `msteams` 사용 시 | -         | MS Teams Incoming Webhook URL           |
| `SLACK_WEBHOOK_URL`    | `slack` 사용 시   | -         | Slack Incoming Webhook URL              |
| `APP_PORT`             |                   | `8000`    | 서버 포트                               |

<br>

## 배포

### 이미지 빌드 및 Push

```bash
# build.sh 내 TAG 수정 후 실행
# 빌드 → Nexus Docker 레지스트리 Push
bash build.sh
```

Nexus 레지스트리: `<BUILD_NODE_IP>:8082/apps/ms-teams-alarm:<TAG>`

### Helm 배포

```bash
# values.yaml 내 플레이스홀더 채운 후 배포
helm upgrade --install ms-teams-alarm ./helm \
  -n infra-manager --create-namespace
```

#### Nexus imagePullSecret 사전 생성

```bash
kubectl create secret docker-registry nexus-secret \
  --docker-server=<BUILD_NODE_IP>:8082 \
  --docker-username=admin \
  --docker-password=<PASSWORD> \
  -n infra-manager
```

#### values.yaml 주요 설정

```yaml
image:
  repository: <BUILD_NODE_IP>:8082/apps/ms-teams-alarm
  tag: "v26.03.17"

imagePullSecrets:
  - name: nexus-secret

env:
  notifierType: "msteams"

secret:
  msTeamsWebhookUrl: "https://xxxxx.webhook.office.com/webhookb2/<WEBHOOK_ID>"
```
<br>

## API

### `POST /webhook`
Grafana 알람 Webhook 수신 엔드포인트.

**Response:**
```json
{ "status": "ok", "forwarded": 1, "errors": [] }
```

| status          | 설명                    |
| --------------- | ----------------------- |
| `ok`            | 전체 성공               |
| `skipped`       | alerts 배열이 비어 있음 |
| `partial_error` | 일부 성공, 일부 실패    |
| `error`         | 전체 실패               |

### `GET /health`
```json
{ "status": "healthy" }
```
<br>

## 기술 스택

| 항목              | 내용                       |
| ----------------- | -------------------------- |
| 언어              | Python 3.11                |
| 웹 프레임워크     | FastAPI + Uvicorn          |
| HTTP 클라이언트   | httpx (비동기)             |
| 설정 관리         | Pydantic Settings          |
| 컨테이너          | Docker (multi-stage build) |
| 배포              | Kubernetes + Helm          |
| 이미지 레지스트리 | Nexus (사설)               |
