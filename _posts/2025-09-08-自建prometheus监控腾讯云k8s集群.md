---
layout: post
title: "自建prometheus监控腾讯云k8s集群"
date: 2025-09-08
categories: [tutorials]
tags: [Prometheus, 腾讯云, Kubernetes, TKE, 监控]
author: g66x
---

# 自建prometheus监控腾讯云k8s集群

## 使用场景

k8s集群（腾讯云容器服务）

promtheus (外部自建服务)

腾讯云提供了容器内部自建 Prometheus 监控 TKE 集群的文档，[参考](https://cloud.tencent.com/document/product/457/82640?from=console_top_search)。

当前的环境promethues建在k8S外的云服务器上，与上面链接文档略有差异，以下给出集群外自建prometheus监控腾讯云k8s集群正确的步骤。

## 配置步骤

创建serviceAccount

```
 kubectl create sa prometheus-sa
```

创建ClusterRole

vi ClusterRole.yml

```
kind: ClusterRole
metadata:
  name: prometheus-kubelet-ro
rules:
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["nodes/metrics"]
  verbs: ["get"]
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
```

```
kubectl apply -f ClusterRole.yml
```

创建clusterrolebinding

```
kubectl create clusterrolebinding prometheus-sa-binding   --clusterrole=prometheus-kubelet-ro   --serviceaccount=default:prometheus-sa
```

验证权限

```
kubectl auth can-i get nodes/metrics --as=system:serviceaccount:default:prometheus-sa
kubectl auth can-i get nodes --as=system:serviceaccount:default:prometheus-sa
```

生成token

```
#替换成正确目录
kubectl -n default get secret prometheus-sa-token -o jsonpath='{.data.token}' | base64 -d > $prometheus_dir/secret/kube-token
```



prometheus配置

```
  - job_name: 'tke-cadvisor'
    scrape_interval: 15s
    scrape_timeout: 10s
    metrics_path: /metrics/cadvisor
    scheme: https
    
    kubernetes_sd_configs:
      - role: node
        api_server: "https://<apiserver>:<port>"
        ##针对sd_服务的tls配置
        bearer_token_file: /etc/prometheus/secrets/kube-token
        #针对sd_服务的tls配置
        tls_config:
          insecure_skip_verify: true
    # scrape的token配置
    bearer_token_file: /etc/prometheus/secrets/kube-token    
    # scrape的tls配置
    tls_config:
      insecure_skip_verify: true
    
    relabel_configs:
      - source_labels: [__meta_kubernetes_node_label_node_kubernetes_io_instance_type]
        regex: eklet
        action: drop
      - source_labels: [__meta_kubernetes_node_address_InternalIP]
        target_label: __address__
        replacement: "${1}:10250"
      - action: labelmap
        regex: __meta_kubernetes_node_label_(.+)
        
       
       
  - job_name: 'tke-node'
    scrape_interval: 15s
    scrape_timeout: 10s
    metrics_path: /metrics
    scheme: http

    kubernetes_sd_configs:
      - role: node
        api_server: "https://<apiserver>:<port>"
        bearer_token_file: /etc/prometheus/secrets/kube-token
        tls_config:
          insecure_skip_verify: true
    bearer_token_file: /etc/prometheus/secrets/kube-token


    relabel_configs:
      - source_labels: [__meta_kubernetes_node_label_node_kubernetes_io_instance_type]
        regex: eklet
        action: drop
      - source_labels: [__meta_kubernetes_node_address_InternalIP]
        target_label: __address__
        replacement: "${1}:9100"
      - action: labelmap
        regex: __meta_kubernetes_node_label_(.+)
```

> [!NOTE]
>
> 1.TKE 节点上的 kubelet 证书是自签的，需要忽略证书校验，所以 `insecure_skip_verify` 要置为 true。
>
> 2.`kubernetes_sd_configs:`和`job级别配置`都需要添加`bearer_token_file`和`insecure_skip_verify`
>
> kubernetes_sd_configs不添加会导致sd不能正常发现节点 kubernetes，job配置不添加会导致prometheus抓取/metrics/cadvisor返回401未授权错误
