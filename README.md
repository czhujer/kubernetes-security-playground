# kubernetes-security-playground

# kind
- for kind-based setup use Makefile

# Digital Ocean
- for DO setup use terraform/scripts in k8s-the-easy-way folder
- originally forked from: https://github.com/jimangel/kubernetes-the-easy-way

# TODO
## terraform 
- re-enable hubble for cilium
- improve config of Loki stack
  - add sending audit logs into Loki
- add falco exporter
- add starboard exporter
- add ServiceMonitor/Metrics for CCM
- enable k8s audit logging
- fix fetching external ip from ingress svc
- add non-hardcoded token
  - https://github.com/weibeld/terraform-aws-kubeadm/blob/master/main.tf#L109-L129
- add IPv6
- add g-visor
- add Grafana Tempo
- add grafana dashboards
  - ingress https://grafana.com/grafana/dashboards/9614
  - node exporter full https://grafana.com/grafana/dashboards/1860
  - kube state metrics https://grafana.com/grafana/dashboards/13332
  - prometheus 2.0 https://grafana.com/grafana/dashboards/3662
  - loki and promtail https://grafana.com/grafana/dashboards/15443
  - promtail https://grafana.com/grafana/dashboards/14055

# docs
- https://github.com/falcosecurity/charts/tree/master/falco#introduction
- https://github.com/digitalocean/digitalocean-cloud-controller-manager#expose-prometheus-metrics
- https://blog.scottlowe.org/2021/10/12/using-the-external-aws-cloud-provider-for-kubernetes/
- https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/
- 