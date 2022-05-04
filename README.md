# kubernetes-security-playground

# kind
- for kind-based setup use Makefile

# Digital Ocean
- for DO setup use terraform/scripts in k8s-the-easy-way folder
- originally forked from: https://github.com/jimangel/kubernetes-the-easy-way

# TODO
## terraform 
- re-enable hubble for cilium
- falco
  - add falco exporter
  - seding audit logs into falco
    - https://sysdig.com/blog/kubernetes-audit-log-falco/
- add ServiceMonitor/Metrics for CCM
- fix fetching external ip from ingress svc
- add non-hardcoded token
  - https://github.com/weibeld/terraform-aws-kubeadm/blob/master/main.tf#L109-L129
- add IPv6
- fix gvisor (sandbox notReady)
- add Grafana Tempo

# docs
- https://github.com/falcosecurity/charts/tree/master/falco#introduction
- https://github.com/digitalocean/digitalocean-cloud-controller-manager#expose-prometheus-metrics
- https://blog.scottlowe.org/2021/10/12/using-the-external-aws-cloud-provider-for-kubernetes/
- https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/
- https://www.bionconsulting.com/blog/monitoring-and-gathering-metrics-from-kubernetes-auditlogs
- https://github.com/WoodProgrammer/kubernetes-audit-dashboards
- https://groups.google.com/g/lokiproject/c/PJNvHcTAJy0
- https://codersociety.com/blog/articles/loki-kubernetes-logging
- https://github.com/ruzickap/cks-notes
- https://github.com/google/gvisor
- https://gvisor.dev/docs/
- https://gvisor.dev/docs/user_guide/containerd/quick_start/
- https://github.com/killer-sh/cks-course-environment/blob/master/course-content/microservice-vulnerabilities/container-runtimes/gvisor/install_gvisor.sh
