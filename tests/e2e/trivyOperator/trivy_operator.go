package trivyOperator

/* docs
https://github.com/kubernetes/kubernetes/blob/v1.23.7/test/e2e/apps/statefulset.go
https://github.com/kubernetes/kubernetes/blob/v1.23.7/test/e2e/framework/deployment/wait.go
https://github.com/kubernetes/kubernetes/blob/42c05a547468804b2053ecf60a3bd15560362fc2/test/utils/deployment.go#L199
k8s.ovn.org/pod-networks
https://github.com/kubernetes/kubernetes/blob/4569e646ef161c0262d433aed324fec97a525572/test/e2e/autoscaling/dns_autoscaling.go
*/

import (
	"context"
	"github.com/onsi/ginkgo"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/labels"
	"k8s.io/kubernetes/test/e2e/framework"
	e2epod "k8s.io/kubernetes/test/e2e/framework/pod"
)

const (
	frameworkName      string = "trivyOperator"
	namespace          string = "trivy-system"
	operatorLabelKey   string = "app.kubernetes.io/name"
	operatorLabelValue string = "trivy-operator"
	operatorMinPods    int    = 1
)

var f = framework.NewDefaultFramework(frameworkName)

var _ = ginkgo.Describe("e2e trivy-operator", func() {
	f.SkipNamespaceCreation = true

	//ginkgo.BeforeEach(func() {
	//	ginkgo.By("Waiting to prometheus-operator's pod(s) ready")
	//	label := labels.SelectorFromSet(labels.Set(map[string]string{operatorLabelKey: operatorLabelValue}))
	//	_, err := e2epod.WaitForPodsWithLabelRunningReady(f.ClientSet, namespace, label, operatorMinPods, framework.PodStartShortTimeout)
	//	framework.ExpectNoError(err)
	//})

	var _ = ginkgo.Describe("namespace", func() {
		ginkgo.It("namespace should exists", func() {
			_, err := f.ClientSet.CoreV1().Namespaces().Get(context.TODO(), namespace, metav1.GetOptions{})
			framework.ExpectNoError(err)
		})
	})

	var _ = ginkgo.Describe("pod(s)", func() {
		ginkgo.It("pod(s) should be running", func() {
			label := labels.SelectorFromSet(labels.Set(map[string]string{operatorLabelKey: operatorLabelValue}))
			_, err := e2epod.WaitForPodsWithLabelRunningReady(f.ClientSet, namespace, label, operatorMinPods, framework.PodStartShortTimeout)
			framework.ExpectNoError(err)
		})
	})

})
