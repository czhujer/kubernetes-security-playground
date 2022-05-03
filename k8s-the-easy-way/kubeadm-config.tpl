apiVersion: kubeadm.k8s.io/v1beta2
kind: InitConfiguration
bootstrapTokens:
- token: wi19h5.n18aqn376cwny601
  description: "kubeadm bootstrap token"
  ttl: "1h"
nodeRegistration:
  kubeletExtraArgs:
    cloud-provider: external
    node-labels: "ingress-ready=true"
    seccomp-default: "true"
    feature-gates: "SeccompDefault=true"
---
apiVersion: kubeadm.k8s.io/v1beta2
kind: ClusterConfiguration
clusterName: ${cluster_name}
kubernetesVersion: ${kubernetes_version}
networking:
  podSubnet: "${pod_subnet}"
controllerManager:
  extraArgs:
    node-monitor-grace-period: "16s"
    node-monitor-period: "2s"
apiServer:
  extraArgs:
    default-not-ready-toleration-seconds: "30"
    default-unreachable-toleration-seconds: "30"
    # FG
    feature-gates: "EphemeralContainers=True,SeccompDefault=True,ServerSideApply=True"
    # enable-admission-plugins: NodeRestriction,PodSecurityPolicy
    # Audit
    audit-log-path: /var/log/kubernetes/k8s-audit.log
    audit-policy-file: /etc/kubernetes/audit-policy.yaml
    audit-log-maxage: "1"
    audit-log-maxsize: "100"
    audit-log-maxbackup: "1"
  extraVolumes:
    - name: audit-policy
      hostPath: /etc/kubernetes/audit-policy.yaml
      mountPath: /etc/kubernetes/audit-policy.yaml
      readOnly: true
      pathType: File
    - name: audit-log
      hostPath: /var/log/kubernetes
      mountPath: /var/log/kubernetes
      readOnly: false
      pathType: DirectoryOrCreate
---
apiVersion: kubeadm.k8s.io/v1beta2
kind: JoinConfiguration
discovery:
  bootstrapToken:
    apiServerEndpoint: ${control_plane_ip}:6443
    token: wi19h5.n18aqn376cwny601
    unsafeSkipCAVerification: true
  timeout: 5m0s
  tlsBootstrapToken: wi19h5.n18aqn376cwny601
nodeRegistration:
  kubeletExtraArgs:
    cloud-provider: external
---
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
cgroupDriver: cgroupfs
