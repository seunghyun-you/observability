# Observability System

1st 클러스터에 Grafana + Prometheus를 배포하고, 2nd 클러스터 Prometheus를 원격 데이터소스로 연결하여 단일 Grafana에서 양쪽 클러스터를 관찰
<br>

## Components

| 계층       | 도구                  | 역할                                         |
| ---------- | --------------------- | -------------------------------------------- |
| **수집**   | Node Exporter         | 노드 수준 하드웨어/OS 메트릭                 |
|            | kube-state-metrics    | K8s 오브젝트 상태 메트릭                     |
|            | cAdvisor              | 컨테이너 리소스 사용량 (kubelet 내장)        |
| **저장**   | Prometheus            | 시계열 데이터 수집·저장·PromQL 처리          |
| **시각화** | Grafana               | 대시보드, 알람 규칙 관리                     |
| **알람**   | Grafana Managed Rules | 알람 조건 정의 및 발송 (Alertmanager 미사용) |
<br>


## Directory Staructure

```
02-kube-prometheus-stack/
├── Chart.yaml                     # kube-prometheus-stack 의존 차트 메타데이터
├── Chart.lock
├── values.yaml                    # 공통 기본값 (upstream 기본값 기반 커스터마이징)
├── environments/
│   ├── 1st-cluster-values.yaml   # 1st 클러스터 오버라이드 (Grafana 포함)
│   └── 2nd-cluster-values.yaml   # 2nd 클러스터 오버라이드 (수집/저장 전용)
├── custom-dashboards/
│   ├── cluster-core-resource-status.json       # 클러스터 핵심 리소스 현황
│   └── pod-resource-usage-by-namespace.json    # 네임스페이스별 Pod 리소스 사용률
└── templates/
    └── grafana/
        ├── configmaps-datasources.yaml         # Prometheus 데이터소스 ConfigMap
        └── custom-alerts/
            ├── _alert-rule-groups.tpl          # 알람 룰 Helm 템플릿
            └── alert-rules.yaml                # Grafana Alert Rule ConfigMap
```
<br>


## Deployment

### Helm 

```bash
# NOTE:: 1st Cluster
helm upgrade --install kube-prometheus-stack . \
  -f values.yaml \
  -f environments/1st-cluster-values.yaml \
  -n monitoring --create-namespace

# NOTE:: 2nd Cluster
helm upgrade --install kube-prometheus-stack . \
  -f values.yaml \
  -f environments/2nd-cluster-values.yaml \
  -n monitoring --create-namespace
```
<br>


## Values

### 1st Cluster (`environments/1st-cluster-values.yaml`)

| 항목                   | 값                                                          |
| ---------------------- | ----------------------------------------------------------- |
| Grafana 도메인         | `mgmt.container-wave.com`                                   |
| Contact Point          | MS Teams (`ms-teams-alarm.infra-manager.svc.cluster.local`) |
| 추가 데이터소스        | `prometheus.container-wave.internal` (2nd 클러스터)         |
| externalLabels.cluster | `1st-cluster`                                               |

### 2nd Cluster (`environments/2nd-cluster-values.yaml`)

| 항목                   | 값                                   |
| ---------------------- | ------------------------------------ |
| Grafana                | -                                    |
| Prometheus Ingress     | `prometheus.container-wave.internal` |
| externalLabels.cluster | `2nd-cluster`                        |

<br>


## Tech Stack

| Category         | Detail                                                |
| ---------------- | ----------------------------------------------------- |
| Monitoring Stack | kube-prometheus-stack v78.3.0                         |
| Prometheus       | v3.6.0                                                |
| Grafana          | v12.2.0                                               |
| Alerting Method  | Grafana Managed Rules (Alertmanager not in use)       |
| Alert Channel    | MS Teams ([ms-teams-alarm](../01-alarm) relay server) |
| Deployment       | Helm (ArgoCD)                                         |
