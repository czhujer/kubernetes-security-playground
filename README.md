# kubernetes-security-playground

# kind
- for kind-based setup use Makefile

# Digital Ocean
- for DO setup use terraform/scripts in k8s-the-easy-way folder
- originally forked from: https://github.com/jimangel/kubernetes-the-easy-way

# TODO
## terraform 
- remove docker
- add ServiceMonitor/Metrics for CCM
- add Loki stack
- add/check falco GUI
- enable k8s audit logging
- add auto-detect nginx LB external IP and change ingress hosts

# docs
- https://github.com/falcosecurity/charts/tree/master/falco#introduction
- https://github.com/digitalocean/digitalocean-cloud-controller-manager#expose-prometheus-metrics
- https://blog.scottlowe.org/2021/10/12/using-the-external-aws-cloud-provider-for-kubernetes/
- https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/
- 