# Set environment variables
export CLUSTER_NAME?=security-playground
export CILIUM_VERSION?=1.11.6
export CERT_MANAGER_CHART_VERSION=1.8.1
export ARGOCD_CHART_VERSION=4.9.4
export SPO_VERSION=0.4.3
export TRIVY_IMAGE_CHECK=0

export ARGOCD_OPTS="--grpc-web --insecure --server argocd.127.0.0.1.nip.io"

# kind image list
#for kind v0.12.x
# kindest/node:v1.21.10@sha256:84709f09756ba4f863769bdcabe5edafc2ada72d3c8c44d6515fc581b66b029c
# kindest/node:v1.22.7@sha256:1dfd72d193bf7da64765fd2f2898f78663b9ba366c2aa74be1fd7498a1873166
# kindest/node:v1.23.4@sha256:0e34f0d0fd448aa2f2819cfd74e99fe5793a6e4938b328f657c8e3f81ee0dfb9
# kindest/node:v1.23.5@sha256:a69c29d3d502635369a5fe92d8e503c09581fcd406ba6598acc5d80ff5ba81b1"
# kindest/node:v1.24.1@sha256:fd82cddc87336d91aa0a2fc35f3c7a9463c53fd8e9575e9052d2c75c61f5b083
export KIND_NODE_IMAGE="kindest/node:v1.24.2@sha256:1f0cee2282f43150b52dc7933183ed96abdcfc8d293f30ec07082495874876f1"

.PHONY: kind-basic
kind-basic: kind-prepare-files kind-create kx-kind kind-install-crds cilium-prepare-images cilium-install argocd-deploy nginx-ingress-deploy

.PHONY: kind-spo
kind-spo: kind-basic cert-manager-deploy spo-deploy

.PHONY: kind-security
kind-security: kind-basic starboard-deploy

.PHONY: kind-prepare-files
kind-prepare-files:
	# change resources for control plane pods
	# https://github.com/kubernetes/kubeadm/pull/2184/files
	mkdir -p /tmp/kind/kubeadm-patches
	cp -a kind/kubeadm-patches/* /tmp/kind/kubeadm-patches
	# prepare files for control-plane extra config
	mkdir -p /tmp/kind/kubeadm-configs
	cp kind/kubeadm-configs/kind-admissionconfiguration.yaml /tmp/kind/kubeadm-configs

.PHONY: kind-create
kind-create:
ifeq ($(TRIVY_IMAGE_CHECK), 1)
	trivy image --severity=HIGH --exit-code=0 "$(KIND_NODE_IMAGE)"
endif
	kind --version
	kind create cluster --name "$(CLUSTER_NAME)" \
 		--config="kind/kind-config.yaml" \
 		--image="$(KIND_NODE_IMAGE)" \
 		--retain
# for testing PSP
#	kubectl apply -f https://github.com/appscodelabs/tasty-kube/raw/master/psp/privileged-psp.yaml
#	kubectl apply -f https://github.com/appscodelabs/tasty-kube/raw/master/psp/baseline-psp.yaml
#	kubectl apply -f https://github.com/appscodelabs/tasty-kube/raw/master/psp/restricted-psp.yaml
#	kubectl apply -f https://github.com/appscodelabs/tasty-kube/raw/master/kind/psp/cluster-roles.yaml
#	kubectl apply -f https://github.com/appscodelabs/tasty-kube/raw/master/kind/psp/role-bindings.yaml
# for more control planes, but no workers
	kubectl taint nodes --all node-role.kubernetes.io/master- || true

.PHONY: kind-debug
kind-debug:
	kubectl -n kube-system get pods -o wide --show-labels || true
	kubectl -n kube-system exec kube-apiserver-security-playground-control-plane -- stat /kubeadm-configs || true
	kubectl -n kube-system exec kube-apiserver-security-playground-control-plane -- stat /kubeadm-configs/kind-admissionconfiguration.yaml || true
	docker ps || true
	docker exec $(CLUSTER_NAME)-control-plane crictl pods || true
	docker exec $(CLUSTER_NAME)-control-plane ls -lRh /kubeadm-configs /kubeadm-patches || true
	docker exec $(CLUSTER_NAME)-control-plane cat /etc/kubernetes/manifests/kube-apiserver.yaml || true

.PHONY: kind-delete
kind-delete:
	kind delete cluster --name $(CLUSTER_NAME)

.PHONY: kx-kind
kx-kind:
	kind export kubeconfig --name $(CLUSTER_NAME)

.PHONY: kind-install-crds
kind-install-crds:
	# fix prometheus-operator's CRDs
	kubectl apply -f https://raw.githubusercontent.com/prometheus-community/helm-charts/main/charts/kube-prometheus-stack/crds/crd-servicemonitors.yaml

.PHONY: cilium-prepare-images
cilium-prepare-images:
	# pull image locally
	docker pull quay.io/cilium/cilium:v$(CILIUM_VERSION)
	docker pull quay.io/cilium/hubble-ui:v0.8.5
	docker pull quay.io/cilium/hubble-ui-backend:v0.8.5
	docker pull quay.io/cilium/hubble-relay:v$(CILIUM_VERSION)
	docker pull docker.io/envoyproxy/envoy:v1.18.4@sha256:e5c2bb2870d0e59ce917a5100311813b4ede96ce4eb0c6bfa879e3fbe3e83935
ifeq ($(TRIVY_IMAGE_CHECK), 1)
	trivy image --severity=HIGH --exit-code=0 quay.io/cilium/cilium:v$(CILIUM_VERSION)
	trivy image --severity=HIGH --exit-code=0 quay.io/cilium/hubble-ui:v0.8.5
	trivy image --severity=HIGH --exit-code=0 quay.io/cilium/hubble-ui-backend:v0.8.5
	trivy image --severity=HIGH --exit-code=0 quay.io/cilium/hubble-relay:v$(CILIUM_VERSION)
	trivy image --severity=HIGH --exit-code=0 docker.io/envoyproxy/envoy:v1.18.4@sha256:e5c2bb2870d0e59ce917a5100311813b4ede96ce4eb0c6bfa879e3fbe3e83935
endif
	# Load the image onto the cluster
	kind load docker-image --name $(CLUSTER_NAME) quay.io/cilium/cilium:v$(CILIUM_VERSION)
	kind load docker-image --name $(CLUSTER_NAME) quay.io/cilium/hubble-ui:v0.8.5
	kind load docker-image --name $(CLUSTER_NAME) quay.io/cilium/hubble-ui-backend:v0.8.5
	kind load docker-image --name $(CLUSTER_NAME) quay.io/cilium/hubble-relay:v$(CILIUM_VERSION)
	kind load docker-image --name $(CLUSTER_NAME) docker.io/envoyproxy/envoy:v1.18.4@sha256:e5c2bb2870d0e59ce917a5100311813b4ede96ce4eb0c6bfa879e3fbe3e83935

.PHONY: cilium-install
cilium-install:
	# Add the Cilium repo
	helm repo add cilium https://helm.cilium.io/
	# install/upgrade the chart
	helm upgrade --install cilium cilium/cilium --version $(CILIUM_VERSION) \
	   -f kind/kind-values-cilium.yaml \
	   -f kind/kind-values-cilium-hubble.yaml \
	   -f kind/kind-values-cilium-service-monitors.yaml \
	   --namespace kube-system \
	   --wait

.PHONY: cert-manager-deploy
cert-manager-deploy:
	# prepare image(s)
	docker pull quay.io/jetstack/cert-manager-controller:v$(CERT_MANAGER_CHART_VERSION)
	docker pull quay.io/jetstack/cert-manager-webhook:v$(CERT_MANAGER_CHART_VERSION)
	docker pull quay.io/jetstack/cert-manager-cainjector:v$(CERT_MANAGER_CHART_VERSION)
	docker pull quay.io/jetstack/cert-manager-ctl:v$(CERT_MANAGER_CHART_VERSION)
	kind load docker-image --name $(CLUSTER_NAME) quay.io/jetstack/cert-manager-controller:v$(CERT_MANAGER_CHART_VERSION)
	kind load docker-image --name $(CLUSTER_NAME) quay.io/jetstack/cert-manager-webhook:v$(CERT_MANAGER_CHART_VERSION)
	kind load docker-image --name $(CLUSTER_NAME) quay.io/jetstack/cert-manager-cainjector:v$(CERT_MANAGER_CHART_VERSION)
	kind load docker-image --name $(CLUSTER_NAME) quay.io/jetstack/cert-manager-ctl:v$(CERT_MANAGER_CHART_VERSION)
	#
	helm repo add cert-manager https://charts.jetstack.io
	helm upgrade --install \
		cert-manager cert-manager/cert-manager \
		--version "v${CERT_MANAGER_CHART_VERSION}" \
	   --namespace cert-manager \
	   --create-namespace \
	   --values kind/cert-manager.yaml \
	   --wait

.PHONY: argocd-deploy
argocd-deploy:
	# prepare image(s)
	docker pull quay.io/argoproj/argocd:v2.4.0
	docker pull quay.io/argoproj/argocd-applicationset:v0.4.1
	docker pull redis:7.0.0-alpine
	docker pull bitnami/redis-exporter:1.26.0-debian-10-r2
	kind load docker-image --name $(CLUSTER_NAME) quay.io/argoproj/argocd:v2.4.0
	kind load docker-image --name $(CLUSTER_NAME) quay.io/argoproj/argocd-applicationset:v0.4.1
	kind load docker-image --name $(CLUSTER_NAME) redis:7.0.0-alpine
	kind load docker-image --name $(CLUSTER_NAME) bitnami/redis-exporter:1.26.0-debian-10-r2
	# install
	helm repo add argo https://argoproj.github.io/argo-helm
	helm upgrade --install \
		argocd-single \
		argo/argo-cd \
		--namespace argocd \
		--create-namespace \
		--version "${ARGOCD_CHART_VERSION}" \
		-f kind/kind-values-argocd.yaml \
		-f kind/kind-values-argocd-service-monitors.yaml \
		--wait
	# update CRDs
	kubectl -n argocd apply -f argocd/argo-cd-crds.yaml
	# kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo ""

.PHONY: spo-deploy
spo-deploy:
	# wait to cert-manager up and running
	kubectl wait -n cert-manager --timeout=2m --for=condition=available deployment cert-manager
	kubectl wait -n cert-manager --timeout=2m --for=condition=available deployment cert-manager-webhook
	kubectl wait -n cert-manager --timeout=2m --for=condition=available deployment cert-manager-cainjector
	# install over argo-cd
#	kubectl -n argocd apply -f argocd/projects/security-profiles-operator.yaml
#	kubectl -n argocd apply -f argocd/security-profiles-operator.yaml
	# install over kubectl
	kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/security-profiles-operator/v$(SPO_VERSION)/deploy/operator.yaml
	# wait to spo up and running
	sleep 2
	kubectl -n security-profiles-operator wait --for condition=ready ds/spod
	kubectl -n security-profiles-operator patch deployments.apps security-profiles-operator --type=merge -p '{"spec":{"replicas":1}}'
	kubectl -n security-profiles-operator patch deployments.apps security-profiles-operator-webhook --type=merge -p '{"spec":{"replicas":1}}'
	kubectl -n security-profiles-operator patch spod spod --type=merge -p '{"spec":{"hostProcVolumePath":"/hostproc"}}'
	kubectl -n security-profiles-operator patch spod spod --type=merge -p '{"spec":{"enableLogEnricher":true}}'

.PHONY: nginx-ingress-deploy
nginx-ingress-deploy:
	docker pull k8s.gcr.io/ingress-nginx/controller:v1.2.1
	kind load docker-image --name $(CLUSTER_NAME) k8s.gcr.io/ingress-nginx/controller:v1.2.1
	# ingress
	kubectl -n argocd apply -f argocd/nginx-ingress.yaml
	kubectl -n argocd apply -f argocd/gateway-api-crds.yaml
#
#	kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/provider/kind/deploy.yaml
#	kubectl delete validatingwebhookconfigurations.admissionregistration.k8s.io ingress-nginx-admission

.PHONY: metrics-server-deploy
metrics-server-deploy:
	kubectl -n argocd apply -f argocd/projects/system-kube.yaml
	kubectl -n argocd apply -f argocd/metrics-server.yaml

.PHONY: prometheus-stack-deploy
prometheus-stack-deploy:
	# projects
	kubectl -n argocd apply -f argocd/projects/system-monitoring.yaml
	# (update) CRDs
	kubectl -n argocd apply -f argocd/prometheus-stack-crds.yaml
	sleep 10
	#monitoring
	kubectl -n argocd apply -f argocd/prometheus-stack.yaml
	kubectl -n argocd apply -f argocd/prometheus-adapter.yaml

.PHONY: starboard-deploy
starboard-deploy:
	kubectl -n argocd apply -f argocd/projects/security-starboard.yaml
	kubectl -n argocd apply -f argocd/security-starboard.yaml

.PHONY: falco-deploy
falco-deploy:
	kubectl -n argocd apply -f argocd/projects/security-falco.yaml
	kubectl -n argocd apply -f argocd/security-falco.yaml

.PHONY: test-network-apply-assets
test-network-apply-assets:
	kubectl get ns test-network 1>/dev/null 2>/dev/null || kubectl create ns test-network
	kubectl apply -n test-network -k tests/assets/k8s/podinfo --wait=true
	kubectl apply -n test-network -f tests/assets/k8s/client  --wait=true
	kubectl apply -n test-network -f tests/assets/k8s/networkpolicy --wait=true

.PHONY: test-network-check-status
test-network-check-status:
#	linkerd top deployment/podinfo --namespace test-network
#	linkerd tap deployment/client --namespace test-network
	kubectl exec -n test-network deploy/client -c client -- curl -s podinfo:9898

.PHONY: run-ginkgo
run-ginkgo:
	cd tests/e2e && go test
