apiVersion: kubeadm.k8s.io/v1beta3
bootstrapTokens:
- description: kubeadm bootstrap token
  groups:
  - system:bootstrappers:kubeadm:default-node-token
  token: wi19h5.n18aqn376cwny601
  ttl: 1h0m0s
  usages:
  - signing
  - authentication
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: ${control_plane_ip}
  bindPort: 6443
nodeRegistration:
  criSocket: unix:///var/run/containerd/containerd.sock
  imagePullPolicy: IfNotPresent
  kubeletExtraArgs:
    cloud-provider: external
    feature-gates: SeccompDefault=true
    node-labels: ingress-ready=true
    seccomp-default: "true"
  name: ${control_plane_name}
  taints:
  - effect: NoSchedule
    key: node-role.kubernetes.io/master
  - effect: NoSchedule
    key: node-role.kubernetes.io/control-plane
---
apiServer:
  extraArgs:
    audit-log-maxage: "1"
    audit-log-maxbackup: "1"
    audit-log-maxsize: "100"
    audit-log-path: /var/log/kubernetes/k8s-audit.log
    audit-policy-file: /etc/kubernetes/audit-policy.yaml
    default-not-ready-toleration-seconds: "30"
    default-unreachable-toleration-seconds: "30"
    feature-gates: EphemeralContainers=True,SeccompDefault=True,ServerSideApply=True,PodSecurity=True
    admission-control-config-file: "/etc/kubernetes/kind-admissionconfiguration.yaml" # for PSS/PSA defaulting
  extraVolumes:
  - hostPath: /etc/kubernetes/kind-admissionconfiguration.yaml
    mountPath: /etc/kubernetes/kind-admissionconfiguration.yaml
    name: admission-control
    pathType: File
    readOnly: true
  - hostPath: /etc/kubernetes/audit-policy.yaml
    mountPath: /etc/kubernetes/audit-policy.yaml
    name: audit-policy
    pathType: File
    readOnly: true
  - hostPath: /var/log/kubernetes
    mountPath: /var/log/kubernetes
    name: audit-log
    pathType: DirectoryOrCreate
  timeoutForControlPlane: 4m0s
apiVersion: kubeadm.k8s.io/v1beta3
certificatesDir: /etc/kubernetes/pki
clusterName: ${cluster_name}
controllerManager:
  extraArgs:
    node-monitor-grace-period: 16s
    node-monitor-period: 2s
dns: {}
etcd:
  local:
    dataDir: /var/lib/etcd
imageRepository: k8s.gcr.io
kind: ClusterConfiguration
kubernetesVersion: ${kubernetes_version}
networking:
  dnsDomain: cluster.local
  podSubnet: ${pod_subnet}
  serviceSubnet: 10.96.0.0/12
scheduler: {}
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: JoinConfiguration
caCertPath: /etc/kubernetes/pki/ca.crt
discovery:
  bootstrapToken:
    apiServerEndpoint: ${control_plane_ip}:6443
    token: wi19h5.n18aqn376cwny601
    unsafeSkipCAVerification: true
  timeout: 5m0s
  tlsBootstrapToken: wi19h5.n18aqn376cwny601
nodeRegistration:
  criSocket: unix:///var/run/containerd/containerd.sock
  imagePullPolicy: IfNotPresent
  kubeletExtraArgs:
    cloud-provider: external
  taints: null
