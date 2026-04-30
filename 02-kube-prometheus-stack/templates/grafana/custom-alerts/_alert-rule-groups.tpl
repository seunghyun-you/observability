{{- define "custom-alerts.groups" -}}
{{- $ds := .dsUid -}}
{{- $l  := .label -}}
{{- $p  := .uidPrefix -}}
{{- $c  := .cluster -}}
# ──────────────────────────────────────────────────────────
# 1. kube-state-metrics — Cluster / Pod
# ──────────────────────────────────────────────────────────
- orgId: 1
  name: '{{ $l }} k8s-cluster'
  folder: K8s Monitoring
  interval: 1m
  rules:
    - uid: {{ $p }}-node-not-ready
      title: '{{ $l }} NodeNotReady'
      condition: C
      data:
        - refId: A
          relativeTimeRange:
            from: 300
            to: 0
          datasourceUid: {{ $ds }}
          model:
            editorMode: code
            expr: 'kube_node_status_condition{condition="Ready",status="true"}'
            instant: true
            refId: A
        - refId: B
          datasourceUid: __expr__
          model:
            type: reduce
            refId: B
            expression: A
            reducer: last
            settings:
              mode: ""
        - refId: C
          datasourceUid: __expr__
          model:
            type: threshold
            refId: C
            expression: B
            conditions:
              - evaluator:
                  params: [1]
                  type: lt
                operator:
                  type: and
                query:
                  params: [C]
                reducer:
                  type: last
                type: query
      noDataState: Alerting
      execErrState: Alerting
      for: 3m
      labels:
        severity: CRITICAL
        datasource: {{ $ds }}
        cluster: '{{ $c }}'
      annotations:
        cluster: '{{ $c }}'
        summary: 워커노드 NotReady 감지
        description: "노드가 Ready 상태가 아닙니다."
        __dashboardUid__: ad6vdkm
        __panelId__: 2
    - uid: {{ $p }}-pods-pending
      title: '{{ $l }} PodPendingTooLong'
      condition: C
      data:
        - refId: A
          relativeTimeRange:
            from: 300
            to: 0
          datasourceUid: {{ $ds }}
          model:
            editorMode: code
            expr: 'sum(kube_pod_status_phase{phase="Pending"}) by (cluster, namespace, pod)'
            instant: true
            refId: A
        - refId: B
          datasourceUid: __expr__
          model:
            type: reduce
            refId: B
            expression: A
            reducer: last
            settings:
              mode: ""
        - refId: C
          datasourceUid: __expr__
          model:
            type: threshold
            refId: C
            expression: B
            conditions:
              - evaluator:
                  params: [1]
                  type: gt
                operator:
                  type: and
                query:
                  params: [C]
                reducer:
                  type: last
                type: query
      noDataState: OK
      execErrState: Error
      for: 10m
      labels:
        severity: WARNING
        datasource: {{ $ds }}
        cluster: '{{ $c }}'
      annotations:
        cluster: '{{ $c }}'
        summary: Pod이 10분 이상 Pending 상태
        description: "Pending 상태가 지속되고 있습니다. 스케줄링 문제 또는 리소스 부족을 확인하세요."
        __dashboardUid__: ad6vdkm
        __panelId__: 11
# ──────────────────────────────────────────────────────────
# 2. cAdvisor — Pod CPU / Memory (requests 대비 비율)
# ──────────────────────────────────────────────────────────
- orgId: 1
  name: '{{ $l }} k8s-pods'
  folder: K8s Monitoring
  interval: 1m
  rules:
    - uid: {{ $p }}-pod-cpu-70pct
      title: '{{ $l }} PodCPUUsageHigh70'
      condition: D
      data:
        - refId: A
          relativeTimeRange:
            from: 600
            to: 0
          datasourceUid: {{ $ds }}
          model:
            editorMode: code
            expr: 'sum(rate(container_cpu_usage_seconds_total{container!=""}[5m])) by (cluster, namespace, pod) / sum(cluster:namespace:pod_cpu:active:kube_pod_container_resource_requests) by (cluster, namespace, pod) * 100'
            instant: true
            refId: A
        - refId: B
          datasourceUid: __expr__
          model:
            type: reduce
            refId: B
            expression: A
            reducer: last
            settings:
              mode: ""
        - refId: C
          datasourceUid: __expr__
          model:
            type: math
            refId: C
            expression: '($B > 70) * ($B <= 80)'
        - refId: D
          datasourceUid: __expr__
          model:
            type: threshold
            refId: D
            expression: C
            conditions:
              - evaluator:
                  params: [0]
                  type: gt
                operator:
                  type: and
                query:
                  params: [D]
                reducer:
                  type: last
                type: query
      noDataState: NoData
      execErrState: Error
      for: 10m
      labels:
        severity: INFO
        datasource: {{ $ds }}
        cluster: '{{ $c }}'
      annotations:
        cluster: '{{ $c }}'
        min_threshold: "70"
        summary: Pod CPU 사용량 requests 대비 70% 초과
        description: "CPU 사용량이 requests의 70%를 초과했습니다."
        __dashboardUid__: 85a562078cdf77779eaa1add43ccec22
        __panelId__: 5
    - uid: {{ $p }}-pod-cpu-80pct
      title: '{{ $l }} PodCPUUsageHigh80'
      condition: D
      data:
        - refId: A
          relativeTimeRange:
            from: 600
            to: 0
          datasourceUid: {{ $ds }}
          model:
            editorMode: code
            expr: 'sum(rate(container_cpu_usage_seconds_total{container!=""}[5m])) by (cluster, namespace, pod) / sum(cluster:namespace:pod_cpu:active:kube_pod_container_resource_requests) by (cluster, namespace, pod) * 100'
            instant: true
            refId: A
        - refId: B
          datasourceUid: __expr__
          model:
            type: reduce
            refId: B
            expression: A
            reducer: last
            settings:
              mode: ""
        - refId: C
          datasourceUid: __expr__
          model:
            type: math
            refId: C
            expression: '($B > 80) * ($B <= 90)'
        - refId: D
          datasourceUid: __expr__
          model:
            type: threshold
            refId: D
            expression: C
            conditions:
              - evaluator:
                  params: [0]
                  type: gt
                operator:
                  type: and
                query:
                  params: [D]
                reducer:
                  type: last
                type: query
      noDataState: NoData
      execErrState: Error
      for: 5m
      labels:
        severity: WARNING
        datasource: {{ $ds }}
        cluster: '{{ $c }}'
      annotations:
        cluster: '{{ $c }}'
        min_threshold: "70"
        summary: Pod CPU 사용량 requests 대비 80% 초과
        description: "CPU 사용량이 requests의 80%를 초과했습니다."
        __dashboardUid__: 85a562078cdf77779eaa1add43ccec22
        __panelId__: 5
    - uid: {{ $p }}-pod-cpu-90pct
      title: '{{ $l }} PodCPUUsageHigh90'
      condition: C
      data:
        - refId: A
          relativeTimeRange:
            from: 600
            to: 0
          datasourceUid: {{ $ds }}
          model:
            editorMode: code
            expr: 'sum(rate(container_cpu_usage_seconds_total{container!=""}[5m])) by (cluster, namespace, pod) / sum(cluster:namespace:pod_cpu:active:kube_pod_container_resource_requests) by (cluster, namespace, pod) * 100'
            instant: true
            refId: A
        - refId: B
          datasourceUid: __expr__
          model:
            type: reduce
            refId: B
            expression: A
            reducer: last
            settings:
              mode: ""
        - refId: C
          datasourceUid: __expr__
          model:
            type: threshold
            refId: C
            expression: B
            conditions:
              - evaluator:
                  params: [90]
                  type: gt
                operator:
                  type: and
                query:
                  params: [C]
                reducer:
                  type: last
                type: query
      noDataState: NoData
      execErrState: Error
      for: 3m
      labels:
        severity: CRITICAL
        datasource: {{ $ds }}
        cluster: '{{ $c }}'
      annotations:
        cluster: '{{ $c }}'
        min_threshold: "70"
        summary: Pod CPU 사용량 requests 대비 90% 초과
        description: "CPU 사용량이 requests의 90%를 초과했습니다."
        __dashboardUid__: 85a562078cdf77779eaa1add43ccec22
        __panelId__: 5
    - uid: {{ $p }}-pod-mem-70pct
      title: '{{ $l }} PodMemoryUsageHigh70'
      condition: D
      data:
        - refId: A
          relativeTimeRange:
            from: 300
            to: 0
          datasourceUid: {{ $ds }}
          model:
            editorMode: code
            expr: 'sum(container_memory_working_set_bytes{container!=""}) by (cluster, namespace, pod) / sum(cluster:namespace:pod_memory:active:kube_pod_container_resource_requests) by (cluster, namespace, pod) * 100'
            instant: true
            refId: A
        - refId: B
          datasourceUid: __expr__
          model:
            type: reduce
            refId: B
            expression: A
            reducer: last
            settings:
              mode: ""
        - refId: C
          datasourceUid: __expr__
          model:
            type: math
            refId: C
            expression: '($B > 70) * ($B <= 80)'
        - refId: D
          datasourceUid: __expr__
          model:
            type: threshold
            refId: D
            expression: C
            conditions:
              - evaluator:
                  params: [0]
                  type: gt
                operator:
                  type: and
                query:
                  params: [D]
                reducer:
                  type: last
                type: query
      noDataState: NoData
      execErrState: Error
      for: 10m
      labels:
        severity: INFO
        datasource: {{ $ds }}
        cluster: '{{ $c }}'
      annotations:
        cluster: '{{ $c }}'
        min_threshold: "70"
        summary: Pod Memory 사용량 requests 대비 70% 초과
        description: "Memory 사용량이 requests의 70%를 초과했습니다."
        __dashboardUid__: 85a562078cdf77779eaa1add43ccec22
        __panelId__: 7
    - uid: {{ $p }}-pod-mem-80pct
      title: '{{ $l }} PodMemoryUsageHigh80'
      condition: D
      data:
        - refId: A
          relativeTimeRange:
            from: 300
            to: 0
          datasourceUid: {{ $ds }}
          model:
            editorMode: code
            expr: 'sum(container_memory_working_set_bytes{container!=""}) by (cluster, namespace, pod) / sum(cluster:namespace:pod_memory:active:kube_pod_container_resource_requests) by (cluster, namespace, pod) * 100'
            instant: true
            refId: A
        - refId: B
          datasourceUid: __expr__
          model:
            type: reduce
            refId: B
            expression: A
            reducer: last
            settings:
              mode: ""
        - refId: C
          datasourceUid: __expr__
          model:
            type: math
            refId: C
            expression: '($B > 80) * ($B <= 90)'
        - refId: D
          datasourceUid: __expr__
          model:
            type: threshold
            refId: D
            expression: C
            conditions:
              - evaluator:
                  params: [0]
                  type: gt
                operator:
                  type: and
                query:
                  params: [D]
                reducer:
                  type: last
                type: query
      noDataState: NoData
      execErrState: Error
      for: 5m
      labels:
        severity: WARNING
        datasource: {{ $ds }}
        cluster: '{{ $c }}'
      annotations:
        cluster: '{{ $c }}'
        min_threshold: "70"
        summary: Pod Memory 사용량 requests 대비 80% 초과
        description: "Memory 사용량이 requests의 80%를 초과했습니다."
        __dashboardUid__: 85a562078cdf77779eaa1add43ccec22
        __panelId__: 7
    - uid: {{ $p }}-pod-mem-90pct
      title: '{{ $l }} PodMemoryUsageHigh90'
      condition: C
      data:
        - refId: A
          relativeTimeRange:
            from: 300
            to: 0
          datasourceUid: {{ $ds }}
          model:
            editorMode: code
            expr: 'sum(container_memory_working_set_bytes{container!=""}) by (cluster, namespace, pod) / sum(cluster:namespace:pod_memory:active:kube_pod_container_resource_requests) by (cluster, namespace, pod) * 100'
            instant: true
            refId: A
        - refId: B
          datasourceUid: __expr__
          model:
            type: reduce
            refId: B
            expression: A
            reducer: last
            settings:
              mode: ""
        - refId: C
          datasourceUid: __expr__
          model:
            type: threshold
            refId: C
            expression: B
            conditions:
              - evaluator:
                  params: [90]
                  type: gt
                operator:
                  type: and
                query:
                  params: [C]
                reducer:
                  type: last
                type: query
      noDataState: NoData
      execErrState: Error
      for: 3m
      labels:
        severity: CRITICAL
        datasource: {{ $ds }}
        cluster: '{{ $c }}'
      annotations:
        cluster: '{{ $c }}'
        min_threshold: "70"
        summary: Pod Memory 사용량 requests 대비 90% 초과
        description: "Memory 사용량이 requests의 90%를 초과했습니다."
        __dashboardUid__: 85a562078cdf77779eaa1add43ccec22
        __panelId__: 7
    - uid: {{ $p }}-pod-crashloop
      title: '{{ $l }} PodCrashLoopBackOff'
      condition: C
      data:
        - refId: A
          relativeTimeRange:
            from: 300
            to: 0
          datasourceUid: {{ $ds }}
          model:
            editorMode: code
            expr: 'kube_pod_container_status_waiting_reason{reason="CrashLoopBackOff"}'
            instant: true
            refId: A
        - refId: B
          datasourceUid: __expr__
          model:
            type: reduce
            refId: B
            expression: A
            reducer: last
            settings:
              mode: ""
        - refId: C
          datasourceUid: __expr__
          model:
            type: threshold
            refId: C
            expression: B
            conditions:
              - evaluator:
                  params: [0]
                  type: gt
                operator:
                  type: and
                query:
                  params: [C]
                reducer:
                  type: last
                type: query
      noDataState: OK
      execErrState: Error
      for: 2m
      labels:
        severity: CRITICAL
        datasource: {{ $ds }}
        cluster: '{{ $c }}'
      annotations:
        cluster: '{{ $c }}'
        summary: Pod CrashLoopBackOff 감지
        description: "컨테이너가 반복 재시작 중입니다. 로그를 확인하세요."
    - uid: {{ $p }}-pod-oomkilled
      title: '{{ $l }} PodOOMKilled'
      condition: C
      data:
        - refId: A
          relativeTimeRange:
            from: 300
            to: 0
          datasourceUid: {{ $ds }}
          model:
            editorMode: code
            expr: 'kube_pod_container_status_last_terminated_reason{reason="OOMKilled"}'
            instant: true
            refId: A
        - refId: B
          datasourceUid: __expr__
          model:
            type: reduce
            refId: B
            expression: A
            reducer: last
            settings:
              mode: ""
        - refId: C
          datasourceUid: __expr__
          model:
            type: threshold
            refId: C
            expression: B
            conditions:
              - evaluator:
                  params: [0]
                  type: gt
                operator:
                  type: and
                query:
                  params: [C]
                reducer:
                  type: last
                type: query
      noDataState: OK
      execErrState: Error
      for: 0m
      labels:
        severity: CRITICAL
        datasource: {{ $ds }}
        cluster: '{{ $c }}'
      annotations:
        cluster: '{{ $c }}'
        summary: Pod OOMKilled 감지
        description: "컨테이너가 메모리 한도 초과로 강제 종료되었습니다."
        __dashboardUid__: ad6vdkm
        __panelId__: 80
# ──────────────────────────────────────────────────────────
# 3. node_exporter — Worker Node CPU / MEM / Filesystem
# ──────────────────────────────────────────────────────────
- orgId: 1
  name: '{{ $l }} k8s-nodes'
  folder: K8s Monitoring
  interval: 1m
  rules:
    - uid: {{ $p }}-node-mem-70pct
      title: '{{ $l }} NodeMemoryUsageHigh70'
      condition: D
      data:
        - refId: A
          relativeTimeRange:
            from: 300
            to: 0
          datasourceUid: {{ $ds }}
          model:
            editorMode: code
            expr: '(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100'
            instant: true
            refId: A
        - refId: B
          datasourceUid: __expr__
          model:
            type: reduce
            refId: B
            expression: A
            reducer: last
            settings:
              mode: ""
        - refId: C
          datasourceUid: __expr__
          model:
            type: math
            refId: C
            expression: '($B > 70) * ($B <= 80)'
        - refId: D
          datasourceUid: __expr__
          model:
            type: threshold
            refId: D
            expression: C
            conditions:
              - evaluator:
                  params: [0]
                  type: gt
                operator:
                  type: and
                query:
                  params: [D]
                reducer:
                  type: last
                type: query
      noDataState: NoData
      execErrState: Error
      for: 10m
      labels:
        severity: WARNING
        datasource: {{ $ds }}
        cluster: '{{ $c }}'
      annotations:
        cluster: '{{ $c }}'
        min_threshold: "70"
        summary: 워커노드 실메모리 사용률 70% 초과
        description: "노드 실메모리 사용률이 70%를 초과했습니다."
        __dashboardUid__: ad6vdkm
        __panelId__: 16
    - uid: {{ $p }}-node-mem-80pct
      title: '{{ $l }} NodeMemoryUsageHigh80'
      condition: D
      data:
        - refId: A
          relativeTimeRange:
            from: 300
            to: 0
          datasourceUid: {{ $ds }}
          model:
            editorMode: code
            expr: '(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100'
            instant: true
            refId: A
        - refId: B
          datasourceUid: __expr__
          model:
            type: reduce
            refId: B
            expression: A
            reducer: last
            settings:
              mode: ""
        - refId: C
          datasourceUid: __expr__
          model:
            type: math
            refId: C
            expression: '($B > 80) * ($B <= 90)'
        - refId: D
          datasourceUid: __expr__
          model:
            type: threshold
            refId: D
            expression: C
            conditions:
              - evaluator:
                  params: [0]
                  type: gt
                operator:
                  type: and
                query:
                  params: [D]
                reducer:
                  type: last
                type: query
      noDataState: NoData
      execErrState: Error
      for: 5m
      labels:
        severity: WARNING
        datasource: {{ $ds }}
        cluster: '{{ $c }}'
      annotations:
        cluster: '{{ $c }}'
        min_threshold: "70"
        summary: 워커노드 실메모리 사용률 80% 초과
        description: "노드 실메모리 사용률이 80%를 초과했습니다."
        __dashboardUid__: ad6vdkm
        __panelId__: 16
    - uid: {{ $p }}-node-mem-90pct
      title: '{{ $l }} NodeMemoryUsageHigh90'
      condition: C
      data:
        - refId: A
          relativeTimeRange:
            from: 300
            to: 0
          datasourceUid: {{ $ds }}
          model:
            editorMode: code
            expr: '(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100'
            instant: true
            refId: A
        - refId: B
          datasourceUid: __expr__
          model:
            type: reduce
            refId: B
            expression: A
            reducer: last
            settings:
              mode: ""
        - refId: C
          datasourceUid: __expr__
          model:
            type: threshold
            refId: C
            expression: B
            conditions:
              - evaluator:
                  params: [90]
                  type: gt
                operator:
                  type: and
                query:
                  params: [C]
                reducer:
                  type: last
                type: query
      noDataState: NoData
      execErrState: Error
      for: 3m
      labels:
        severity: CRITICAL
        datasource: {{ $ds }}
        cluster: '{{ $c }}'
      annotations:
        cluster: '{{ $c }}'
        min_threshold: "70"
        summary: 워커노드 실메모리 사용률 90% 초과
        description: "노드 실메모리 사용률이 90%를 초과했습니다."
        __dashboardUid__: ad6vdkm
        __panelId__: 16
    - uid: {{ $p }}-node-fs-70pct
      title: '{{ $l }} NodeFilesystemUsageHigh70'
      condition: D
      data:
        - refId: A
          relativeTimeRange:
            from: 300
            to: 0
          datasourceUid: {{ $ds }}
          model:
            editorMode: code
            expr: '(1 - (node_filesystem_avail_bytes{fstype!~"tmpfs|overlay|nfs.*"} / node_filesystem_size_bytes{fstype!~"tmpfs|overlay|nfs.*"})) * 100'
            instant: true
            refId: A
        - refId: B
          datasourceUid: __expr__
          model:
            type: reduce
            refId: B
            expression: A
            reducer: last
            settings:
              mode: ""
        - refId: C
          datasourceUid: __expr__
          model:
            type: math
            refId: C
            expression: '($B > 70) * ($B <= 80)'
        - refId: D
          datasourceUid: __expr__
          model:
            type: threshold
            refId: D
            expression: C
            conditions:
              - evaluator:
                  params: [0]
                  type: gt
                operator:
                  type: and
                query:
                  params: [D]
                reducer:
                  type: last
                type: query
      noDataState: NoData
      execErrState: Error
      for: 30m
      labels:
        severity: WARNING
        datasource: {{ $ds }}
        cluster: '{{ $c }}'
      annotations:
        cluster: '{{ $c }}'
        min_threshold: "70"
        summary: 워커노드 로컬 디스크 사용률 70% 초과
        description: "로컬 디스크 사용률이 70%를 초과했습니다. (tmpfs, overlay, NFS 제외)"
        __dashboardUid__: ad6vdkm
        __panelId__: 1
    - uid: {{ $p }}-node-fs-80pct
      title: '{{ $l }} NodeFilesystemUsageHigh80'
      condition: D
      data:
        - refId: A
          relativeTimeRange:
            from: 300
            to: 0
          datasourceUid: {{ $ds }}
          model:
            editorMode: code
            expr: '(1 - (node_filesystem_avail_bytes{fstype!~"tmpfs|overlay|nfs.*"} / node_filesystem_size_bytes{fstype!~"tmpfs|overlay|nfs.*"})) * 100'
            instant: true
            refId: A
        - refId: B
          datasourceUid: __expr__
          model:
            type: reduce
            refId: B
            expression: A
            reducer: last
            settings:
              mode: ""
        - refId: C
          datasourceUid: __expr__
          model:
            type: math
            refId: C
            expression: '($B > 80) * ($B <= 90)'
        - refId: D
          datasourceUid: __expr__
          model:
            type: threshold
            refId: D
            expression: C
            conditions:
              - evaluator:
                  params: [0]
                  type: gt
                operator:
                  type: and
                query:
                  params: [D]
                reducer:
                  type: last
                type: query
      noDataState: NoData
      execErrState: Error
      for: 15m
      labels:
        severity: WARNING
        datasource: {{ $ds }}
        cluster: '{{ $c }}'
      annotations:
        cluster: '{{ $c }}'
        min_threshold: "70"
        summary: 워커노드 로컬 디스크 사용률 80% 초과
        description: "로컬 디스크 사용률이 80%를 초과했습니다. (tmpfs, overlay, NFS 제외)"
        __dashboardUid__: ad6vdkm
        __panelId__: 1
    - uid: {{ $p }}-node-fs-90pct
      title: '{{ $l }} NodeFilesystemUsageHigh90'
      condition: C
      data:
        - refId: A
          relativeTimeRange:
            from: 300
            to: 0
          datasourceUid: {{ $ds }}
          model:
            editorMode: code
            expr: '(1 - (node_filesystem_avail_bytes{fstype!~"tmpfs|overlay|nfs.*"} / node_filesystem_size_bytes{fstype!~"tmpfs|overlay|nfs.*"})) * 100'
            instant: true
            refId: A
        - refId: B
          datasourceUid: __expr__
          model:
            type: reduce
            refId: B
            expression: A
            reducer: last
            settings:
              mode: ""
        - refId: C
          datasourceUid: __expr__
          model:
            type: threshold
            refId: C
            expression: B
            conditions:
              - evaluator:
                  params: [90]
                  type: gt
                operator:
                  type: and
                query:
                  params: [C]
                reducer:
                  type: last
                type: query
      noDataState: NoData
      execErrState: Error
      for: 5m
      labels:
        severity: CRITICAL
        datasource: {{ $ds }}
        cluster: '{{ $c }}'
      annotations:
        cluster: '{{ $c }}'
        min_threshold: "70"
        summary: 워커노드 로컬 디스크 사용률 90% 초과
        description: "로컬 디스크 사용률이 90%를 초과했습니다. (tmpfs, overlay, NFS 제외)"
        __dashboardUid__: ad6vdkm
        __panelId__: 1
    - uid: {{ $p }}-node-cpu-70pct
      title: '{{ $l }} NodeCPUUsageHigh70'
      condition: D
      data:
        - refId: A
          relativeTimeRange:
            from: 300
            to: 0
          datasourceUid: {{ $ds }}
          model:
            editorMode: code
            expr: '(1 - avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) by (instance)) * 100'
            instant: true
            refId: A
        - refId: B
          datasourceUid: __expr__
          model:
            type: reduce
            refId: B
            expression: A
            reducer: last
            settings:
              mode: ""
        - refId: C
          datasourceUid: __expr__
          model:
            type: math
            refId: C
            expression: '($B > 70) * ($B <= 80)'
        - refId: D
          datasourceUid: __expr__
          model:
            type: threshold
            refId: D
            expression: C
            conditions:
              - evaluator:
                  params: [0]
                  type: gt
                operator:
                  type: and
                query:
                  params: [D]
                reducer:
                  type: last
                type: query
      noDataState: NoData
      execErrState: Error
      for: 10m
      labels:
        severity: WARNING
        datasource: {{ $ds }}
        cluster: '{{ $c }}'
      annotations:
        cluster: '{{ $c }}'
        min_threshold: "70"
        summary: 워커노드 CPU 사용률 70% 초과
        description: "노드 CPU 사용률이 70%를 초과했습니다."
        __dashboardUid__: ad6vdkm
        __panelId__: 15
    - uid: {{ $p }}-node-cpu-80pct
      title: '{{ $l }} NodeCPUUsageHigh80'
      condition: D
      data:
        - refId: A
          relativeTimeRange:
            from: 300
            to: 0
          datasourceUid: {{ $ds }}
          model:
            editorMode: code
            expr: '(1 - avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) by (instance)) * 100'
            instant: true
            refId: A
        - refId: B
          datasourceUid: __expr__
          model:
            type: reduce
            refId: B
            expression: A
            reducer: last
            settings:
              mode: ""
        - refId: C
          datasourceUid: __expr__
          model:
            type: math
            refId: C
            expression: '($B > 80) * ($B <= 90)'
        - refId: D
          datasourceUid: __expr__
          model:
            type: threshold
            refId: D
            expression: C
            conditions:
              - evaluator:
                  params: [0]
                  type: gt
                operator:
                  type: and
                query:
                  params: [D]
                reducer:
                  type: last
                type: query
      noDataState: NoData
      execErrState: Error
      for: 5m
      labels:
        severity: WARNING
        datasource: {{ $ds }}
        cluster: '{{ $c }}'
      annotations:
        cluster: '{{ $c }}'
        min_threshold: "70"
        summary: 워커노드 CPU 사용률 80% 초과
        description: "노드 CPU 사용률이 80%를 초과했습니다."
        __dashboardUid__: ad6vdkm
        __panelId__: 15
    - uid: {{ $p }}-node-cpu-90pct
      title: '{{ $l }} NodeCPUUsageHigh90'
      condition: C
      data:
        - refId: A
          relativeTimeRange:
            from: 300
            to: 0
          datasourceUid: {{ $ds }}
          model:
            editorMode: code
            expr: '(1 - avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) by (instance)) * 100'
            instant: true
            refId: A
        - refId: B
          datasourceUid: __expr__
          model:
            type: reduce
            refId: B
            expression: A
            reducer: last
            settings:
              mode: ""
        - refId: C
          datasourceUid: __expr__
          model:
            type: threshold
            refId: C
            expression: B
            conditions:
              - evaluator:
                  params: [90]
                  type: gt
                operator:
                  type: and
                query:
                  params: [C]
                reducer:
                  type: last
                type: query
      noDataState: NoData
      execErrState: Error
      for: 3m
      labels:
        severity: CRITICAL
        datasource: {{ $ds }}
        cluster: '{{ $c }}'
      annotations:
        cluster: '{{ $c }}'
        min_threshold: "70"
        summary: 워커노드 CPU 사용률 90% 초과
        description: "노드 CPU 사용률이 90%를 초과했습니다."
        __dashboardUid__: ad6vdkm
        __panelId__: 15
# ──────────────────────────────────────────────────────────
# 4. kubelet — PVC 용량 및 상태
# ──────────────────────────────────────────────────────────
- orgId: 1
  name: '{{ $l }} k8s-pvc'
  folder: K8s Monitoring
  interval: 1m
  rules:
    - uid: {{ $p }}-pvc-not-bound
      title: '{{ $l }} PVCNotBound'
      condition: C
      data:
        - refId: A
          relativeTimeRange:
            from: 300
            to: 0
          datasourceUid: {{ $ds }}
          model:
            editorMode: code
            expr: 'kube_persistentvolumeclaim_status_phase{phase!="Bound"} == 1'
            instant: true
            refId: A
        - refId: B
          datasourceUid: __expr__
          model:
            type: reduce
            refId: B
            expression: A
            reducer: last
            settings:
              mode: ""
        - refId: C
          datasourceUid: __expr__
          model:
            type: threshold
            refId: C
            expression: B
            conditions:
              - evaluator:
                  params: [0]
                  type: gt
                operator:
                  type: and
                query:
                  params: [C]
                reducer:
                  type: last
                type: query
      noDataState: OK
      execErrState: Error
      for: 5m
      labels:
        severity: WARNING
        datasource: {{ $ds }}
        cluster: '{{ $c }}'
      annotations:
        cluster: '{{ $c }}'
        summary: PVC Bound 상태 아님 감지
        description: "PVC가 Bound 상태가 아닙니다. 스토리지 프로비저닝 상태를 확인하세요."
        __dashboardUid__: 85a562078cdf77779eaa1add43ccec22
        __panelId__: 15
    - uid: {{ $p }}-pvc-usage-70pct
      title: '{{ $l }} PVCUsageHigh70'
      condition: D
      data:
        - refId: A
          relativeTimeRange:
            from: 300
            to: 0
          datasourceUid: {{ $ds }}
          model:
            editorMode: code
            expr: 'kubelet_volume_stats_used_bytes{persistentvolumeclaim!=""} / on(namespace, persistentvolumeclaim) group_left() kube_persistentvolumeclaim_resource_requests_storage_bytes * 100 unless on(namespace, persistentvolumeclaim) kube_persistentvolumeclaim_info{storageclass=~"nfs-csi|nfs-storage|nfs-subdir-external-sc|nfs-subdir-external-sc-retain|ske-managed"}'
            instant: true
            refId: A
        - refId: B
          datasourceUid: __expr__
          model:
            type: reduce
            refId: B
            expression: A
            reducer: last
            settings:
              mode: ""
        - refId: C
          datasourceUid: __expr__
          model:
            type: math
            refId: C
            expression: '($B > 70) * ($B <= 80)'
        - refId: D
          datasourceUid: __expr__
          model:
            type: threshold
            refId: D
            expression: C
            conditions:
              - evaluator:
                  params: [0]
                  type: gt
                operator:
                  type: and
                query:
                  params: [D]
                reducer:
                  type: last
                type: query
      noDataState: OK
      execErrState: Error
      for: 30m
      labels:
        severity: WARNING
        datasource: {{ $ds }}
        cluster: '{{ $c }}'
      annotations:
        cluster: '{{ $c }}'
        min_threshold: "70"
        summary: PVC 용량 사용률 70% 초과
        description: "PVC 용량 사용률이 70%를 초과했습니다."
        __dashboardUid__: 85a562078cdf77779eaa1add43ccec22
        __panelId__: 15
    - uid: {{ $p }}-pvc-usage-80pct
      title: '{{ $l }} PVCUsageHigh80'
      condition: D
      data:
        - refId: A
          relativeTimeRange:
            from: 300
            to: 0
          datasourceUid: {{ $ds }}
          model:
            editorMode: code
            expr: 'kubelet_volume_stats_used_bytes{persistentvolumeclaim!=""} / on(namespace, persistentvolumeclaim) group_left() kube_persistentvolumeclaim_resource_requests_storage_bytes * 100 unless on(namespace, persistentvolumeclaim) kube_persistentvolumeclaim_info{storageclass=~"nfs-csi|nfs-storage|nfs-subdir-external-sc|nfs-subdir-external-sc-retain|ske-managed"}'
            instant: true
            refId: A
        - refId: B
          datasourceUid: __expr__
          model:
            type: reduce
            refId: B
            expression: A
            reducer: last
            settings:
              mode: ""
        - refId: C
          datasourceUid: __expr__
          model:
            type: math
            refId: C
            expression: '($B > 80) * ($B <= 90)'
        - refId: D
          datasourceUid: __expr__
          model:
            type: threshold
            refId: D
            expression: C
            conditions:
              - evaluator:
                  params: [0]
                  type: gt
                operator:
                  type: and
                query:
                  params: [D]
                reducer:
                  type: last
                type: query
      noDataState: OK
      execErrState: Error
      for: 15m
      labels:
        severity: WARNING
        datasource: {{ $ds }}
        cluster: '{{ $c }}'
      annotations:
        cluster: '{{ $c }}'
        min_threshold: "70"
        summary: PVC 용량 사용률 80% 초과
        description: "PVC 용량 사용률이 80%를 초과했습니다."
        __dashboardUid__: 85a562078cdf77779eaa1add43ccec22
        __panelId__: 15
    - uid: {{ $p }}-pvc-usage-90pct
      title: '{{ $l }} PVCUsageHigh90'
      condition: C
      data:
        - refId: A
          relativeTimeRange:
            from: 300
            to: 0
          datasourceUid: {{ $ds }}
          model:
            editorMode: code
            expr: 'kubelet_volume_stats_used_bytes{persistentvolumeclaim!=""} / on(namespace, persistentvolumeclaim) group_left() kube_persistentvolumeclaim_resource_requests_storage_bytes * 100 unless on(namespace, persistentvolumeclaim) kube_persistentvolumeclaim_info{storageclass=~"nfs-csi|nfs-storage|nfs-subdir-external-sc|nfs-subdir-external-sc-retain|ske-managed"}'
            instant: true
            refId: A
        - refId: B
          datasourceUid: __expr__
          model:
            type: reduce
            refId: B
            expression: A
            reducer: last
            settings:
              mode: ""
        - refId: C
          datasourceUid: __expr__
          model:
            type: threshold
            refId: C
            expression: B
            conditions:
              - evaluator:
                  params: [90]
                  type: gt
                operator:
                  type: and
                query:
                  params: [C]
                reducer:
                  type: last
                type: query
      noDataState: OK
      execErrState: Error
      for: 5m
      labels:
        severity: CRITICAL
        datasource: {{ $ds }}
        cluster: '{{ $c }}'
      annotations:
        cluster: '{{ $c }}'
        min_threshold: "70"
        summary: PVC 용량 사용률 90% 초과
        description: "PVC 용량 사용률이 90%를 초과했습니다."
        __dashboardUid__: 85a562078cdf77779eaa1add43ccec22
        __panelId__: 15
# ──────────────────────────────────────────────────────────
# 5. node_exporter — File Storage (NFS)
# ──────────────────────────────────────────────────────────
- orgId: 1
  name: '{{ $l }} k8s-nfs'
  folder: K8s Monitoring
  interval: 1m
  rules:
    - uid: {{ $p }}-nfs-readonly
      title: '{{ $l }} NFSMountReadOnly'
      condition: C
      data:
        - refId: A
          relativeTimeRange:
            from: 300
            to: 0
          datasourceUid: {{ $ds }}
          model:
            editorMode: code
            expr: 'node_filesystem_readonly{fstype=~"nfs.*"}'
            instant: true
            refId: A
        - refId: B
          datasourceUid: __expr__
          model:
            type: reduce
            refId: B
            expression: A
            reducer: last
            settings:
              mode: ""
        - refId: C
          datasourceUid: __expr__
          model:
            type: threshold
            refId: C
            expression: B
            conditions:
              - evaluator:
                  params: [0]
                  type: gt
                operator:
                  type: and
                query:
                  params: [C]
                reducer:
                  type: last
                type: query
      noDataState: OK
      execErrState: Error
      for: 3m
      labels:
        severity: CRITICAL
        datasource: {{ $ds }}
        cluster: '{{ $c }}'
      annotations:
        cluster: '{{ $c }}'
        summary: NFS 마운트 읽기 전용 상태 감지
        description: "NFS 파일시스템이 읽기 전용으로 마운트되었습니다. 마운트 상태를 확인하세요."
        __dashboardUid__: ad6vdkm
        __panelId__: 1
{{- end }}
