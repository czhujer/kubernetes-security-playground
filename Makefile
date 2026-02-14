# Set environment variables
export CLUSTER_NAME?=security-playground
export CILIUM_VERSION?=1.19.0
export ARGOCD_CHART_VERSION=9.4.0
export SPO_VERSION=0.4.3
export TRIVY_IMAGE_CHECK=0

export ARGOCD_OPTS="--grpc-web --insecure --server argocd.127.0.0.1.nip.io"

# kind image list
# N.B.: be aware, this image is also used in dru-run GHA workflow
# for kind v0.32.0
# kindest/node:v1.35.0@sha256:452d707d4862f52530247495d180205e029056831160e22870e37e3f6c1ac31f
# kindest/node:v1.34.3@sha256:08497ee19eace7b4b5348db5c6a1591d7752b164530a36f855cb0f2bdcbadd48
# kindest/node:v1.33.7@sha256:d26ef333bdb2cbe9862a0f7c3803ecc7b4303d8cea8e814b481b09949d353040
export KIND_NODE_IMAGE="kindest/node:v1.34.3@sha256:08497ee19eace7b4b5348db5c6a1591d7752b164530a36f855cb0f2bdcbadd48"

.PHONY: kind-basic
kind-basic: kind-prepare-files kind-create kx-kind kind-install-crds cilium-install argocd-deploy nginx-ingress-deploy
# kind-basic: kind-prepare-files kind-create kx-kind kind-install-crds cilium-prepare-images cilium-install argocd-deploy nginx-ingress-deploy

.PHONY: kind-observability
kind-observability: cert-manager-deploy metrics-server-deploy prometheus-stack-deploy

.PHONY: kind-spo
kind-spo: cert-manager-deploy spo-deploy

.PHONY: kind-security
kind-security: trivy-deploy falco-deploy

.PHONY: kind-prepare-files
kind-prepare-files:
	# change resources for control plane pods
	# https://github.com/kubernetes/kubeadm/pull/2184/files
# 	mkdir -p /tmp/kind/kubeadm-patches
# 	cp -a kind/kubeadm-patches/* /tmp/kind/kubeadm-patches
# 	# prepare files for control-plane extra config
# 	mkdir -p /tmp/kind/kubeadm-configs
# 	cp kind/kubeadm-configs/kind-admissionconfiguration.yaml /tmp/kind/kubeadm-configs

.PHONY: kind-create
kind-create:
ifeq ($(TRIVY_IMAGE_CHECK), 1)
	trivy image --severity=HIGH --exit-code=0 "$(KIND_NODE_IMAGE)"
endif
	kind --version
	kind create cluster --name "$(CLUSTER_NAME)" \
 		--config="kind/kind-config.yaml" \
 		--image="$(KIND_NODE_IMAGE)"
# 		 \
#  		--retain
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
	kubectl describe ns || true

.PHONY: kind-delete
kind-delete:
	kind delete cluster --name $(CLUSTER_NAME)

.PHONY: kx-kind
kx-kind:
	kind export kubeconfig --name $(CLUSTER_NAME)

.PHONY: kind-install-crds
kind-install-crds:
	# fix prometheus-operator's CRDs
	kubectl apply -f https://raw.githubusercontent.com/prometheus-community/helm-charts/refs/heads/main/charts/kube-prometheus-stack/charts/crds/crds/crd-servicemonitors.yaml

.PHONY: cilium-prepare-images
cilium-prepare-images:
	# pull image locally
	podman pull quay.io/cilium/cilium:v$(CILIUM_VERSION)
	podman pull quay.io/cilium/operator-generic:v$(CILIUM_VERSION)
	podman pull quay.io/cilium/hubble-ui:v0.13.3
	podman pull quay.io/cilium/hubble-ui-backend:v0.13.3
	podman pull quay.io/cilium/hubble-relay:v$(CILIUM_VERSION)
	podman pull quay.io/cilium/cilium-envoy:v1.35.9-1768828720-c6e4827ebca9c47af2a3a6540c563c30947bae29
ifeq ($(TRIVY_IMAGE_CHECK), 1)
	trivy image --severity=HIGH --exit-code=0 quay.io/cilium/cilium:v$(CILIUM_VERSION)
	trivy image --severity=HIGH --exit-code=0 quay.io/cilium/operator-generic:v$(CILIUM_VERSION)
	trivy image --severity=HIGH --exit-code=0 quay.io/cilium/hubble-ui:v0.13.3
	trivy image --severity=HIGH --exit-code=0 quay.io/cilium/hubble-ui-backend:v0.13.3
	trivy image --severity=HIGH --exit-code=0 quay.io/cilium/hubble-relay:v$(CILIUM_VERSION)
	trivy image --severity=HIGH --exit-code=0 quay.io/cilium/cilium-envoy:v1.35.9-1768828720-c6e4827ebca9c47af2a3a6540c563c30947bae29
endif
	# Load the image onto the cluster
	kind load docker-image --name $(CLUSTER_NAME) quay.io/cilium/cilium:v$(CILIUM_VERSION)
	kind load docker-image --name $(CLUSTER_NAME) quay.io/cilium/operator-generic:v$(CILIUM_VERSION)
	kind load docker-image --name $(CLUSTER_NAME) quay.io/cilium/hubble-ui:v0.13.3
	kind load docker-image --name $(CLUSTER_NAME) quay.io/cilium/hubble-ui-backend:v0.13.3
	kind load docker-image --name $(CLUSTER_NAME) quay.io/cilium/hubble-relay:v$(CILIUM_VERSION)
	kind load docker-image --name $(CLUSTER_NAME) quay.io/cilium/cilium-envoy:v1.35.9-1768828720-c6e4827ebca9c47af2a3a6540c563c30947bae29

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

.PHONY: argocd-deploy
argocd-deploy:
ifeq ($(TRIVY_IMAGE_CHECK), 1)
	# prepare image(s)
	docker pull quay.io/argoproj/argocd:v2.4.9
	docker pull redis:7.0.4-alpine
	docker pull bitnami/redis-exporter:1.26.0-debian-10-r2
	kind load docker-image --name $(CLUSTER_NAME) quay.io/argoproj/argocd:v2.4.9
	kind load docker-image --name $(CLUSTER_NAME) redis:7.0.4-alpine
	kind load docker-image --name $(CLUSTER_NAME) bitnami/redis-exporter:1.26.0-debian-10-r2
endif
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

.PHONY: cert-manager-deploy
cert-manager-deploy:
	kubectl -n argocd apply -f argocd/projects/system-cert-manager.yaml
	kubectl -n argocd apply -f argocd/cert-manager.yaml

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
# 	podman pull k8s.gcr.io/ingress-nginx/controller:v1.2.1
# 	kind load docker-image --name $(CLUSTER_NAME) k8s.gcr.io/ingress-nginx/controller:v1.2.1
	# create namespace with annotations for PSS/PSA
	kubectl apply -f k8s-manifests/namespace-ingress-nginx.yaml
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
	# create namespace with annotations for PSS/PSA
	kubectl apply -f k8s-manifests/namespace-monitoring.yaml
	# projects
	kubectl -n argocd apply -f argocd/projects/system-monitoring.yaml
	# (update) CRDs
	kubectl -n argocd apply -f argocd/prometheus-stack-crds.yaml
	sleep 10
	#monitoring
	kubectl -n argocd apply -f argocd/prometheus-stack.yaml
	kubectl -n argocd apply -f argocd/prometheus-adapter.yaml

.PHONY: trivy-deploy
trivy-deploy:
	kubectl -n argocd apply -f argocd/projects/security-trivy.yaml
	kubectl -n argocd apply -f argocd/security-trivy.yaml

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

.PHONY: run-ginkgo-all
run-ginkgo-all:
	cd tests/e2e && go test ./... -v
