# kubernetes-security-playground

# kind
- for kind-based setup use Makefile

# Digital Ocean
- for DO setup use terraform/scripts in k8s-the-easy-way folder
- originally forked from: https://github.com/jimangel/kubernetes-the-easy-way

# TODO
## terraform-based stack
- switch PSP -> PSA
- tracing
  - add OTEL collector chart and remove otel operator
  - check/fix tempo/otel collector
  - enable tracing in prometheus/k8s API/....
- re-enable hubble for cilium
- falco
  - add falco exporter
  - seding audit logs into falco
    - https://sysdig.com/blog/kubernetes-audit-log-falco/
- terraform: fix fetching external ip from ingress svc
- terraform: add non-hardcoded token(s) in IaC
  - https://github.com/weibeld/terraform-aws-kubeadm/blob/master/main.tf#L109-L129
- add IPv6
- enable Grafana Exemplars
  - https://grafana.com/docs/grafana/latest/datasources/tempo/#provision-the-tempo-data-source
- add cloudflare DNS records for instances
- test firecracker
  - https://github.com/firecracker-microvm/firecracker-containerd

# docs
## github actions
- https://github.com/ruzickap/k8s-tf-eks-gitops/tree/main/.github/workflows
## digital ocean
- https://github.com/digitalocean/digitalocean-cloud-controller-manager#expose-prometheus-metrics
- https://blog.scottlowe.org/2021/10/12/using-the-external-aws-cloud-provider-for-kubernetes/
## logging
- https://groups.google.com/g/lokiproject/c/PJNvHcTAJy0
- https://codersociety.com/blog/articles/loki-kubernetes-logging
## tracing
- https://isitobservable.io/open-telemetry/what-is-the-opentelemetry-operator
- https://grafana.com/blog/2021/04/13/how-to-send-traces-to-grafana-clouds-tempo-service-with-opentelemetry-collector/
- https://grafana.com/docs/grafana/latest/basics/exemplars/
## gVisor
- https://github.com/google/gvisor
- https://gvisor.dev/docs/
- https://gvisor.dev/docs/user_guide/containerd/quick_start/
- https://github.com/killer-sh/cks-course-environment/blob/master/course-content/microservice-vulnerabilities/container-runtimes/gvisor/install_gvisor.sh
## golang
- https://semaphoreci.com/community/tutorials/getting-started-with-bdd-in-go-using-ginkgo
- https://github.com/kubernetes-sigs/aws-ebs-csi-driver/tree/master/tests/e2e
- https://github.com/kubernetes-sigs/aws-ebs-csi-driver/blob/master/tests/e2e/suite_test.go
- https://github.com/cert-manager/cert-manager/blob/master/test/e2e/suite/issuers/selfsigned/certificate.go#L72-L90
- https://github.com/czhujer/kind-w-cert-manager-demo#ginkgo
- https://github.com/cilium/cilium/blob/master/test/k8s/net_policies.go
- https://github.com/cilium/cilium/blob/master/test/k8s/bookinfo.go
- https://github.com/cilium/cilium/blob/master/test/k8s/health.go
- https://github.com/kubernetes/kubernetes/blob/master/test/integration/deployment/deployment_test.go
- 
## others
- https://github.com/falcosecurity/charts/tree/master/falco#introduction
- https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/
- https://www.bionconsulting.com/blog/monitoring-and-gathering-metrics-from-kubernetes-auditlogs
- https://github.com/WoodProgrammer/kubernetes-audit-dashboards
- https://github.com/ruzickap/cks-notes
