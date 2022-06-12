package e2e

import (
	"context"
	"github.com/onsi/ginkgo"
	"github.com/onsi/gomega"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/klog"
	"k8s.io/kubernetes/test/e2e/framework"
	e2ekubectl "k8s.io/kubernetes/test/e2e/framework/kubectl"
	e2epod "k8s.io/kubernetes/test/e2e/framework/pod"
)

const (
	//podNetworkAnnotation = "k8s.ovn.org/pod-networks"
	//agnhostImage         = "k8s.gcr.io/e2e-test-images/agnhost:2.26"
	//certManagerFullYaml = "../assets/cert-manager-full-generated-v1.4.1.yaml"
	certManagerNamespace string = "cert-manager"
	certManagerMinPods   int32  = 3
	frameworkName        string = "certmanager"
)

var _ = ginkgo.Describe("e2e cert-manager", func() {

	f := framework.NewDefaultFramework(frameworkName)

	tk := e2ekubectl.NewTestKubeconfig(framework.TestContext.CertDir, framework.TestContext.Host, framework.TestContext.KubeConfig, framework.TestContext.KubeContext, framework.TestContext.KubectlPath, "")

	ginkgo.BeforeEach(func() {
		//ensure if cert-manager and Issuer(s) is installed
		//ginkgo.By("Executing cert-manager installation")
		//applyManifest(certManagerFullYaml)

		ginkgo.By("Waiting to cert-manager's pods ready")
		err := e2epod.WaitForPodsRunningReady(f.ClientSet, certManagerNamespace, certManagerMinPods, 0, framework.PodStartShortTimeout, make(map[string]string))
		framework.ExpectNoError(err)

		ginkgo.By("Executing certs and Issuer objects")
		applyManifest(tk, "../assets/k8s/ca/cert-manager-issuer-kind-test.yaml")
		applyManifest(tk, "../assets/k8s/ca/cert-manager-issuer-kind-ca-test.yaml")
		applyManifest(tk, "../assets/k8s/certs/cert-manager-certificate-test1.yaml")
		applyManifest(tk, "../assets/k8s/certs/cert-manager-certificate-test2.yaml")

	})

	var _ = ginkgo.Describe("--> Server", func() {
		ginkgo.It("should pods running", func() {
			str := framework.RunKubectlOrDie(certManagerNamespace, "get", "pods")
			gomega.Expect(str).Should(gomega.MatchRegexp("cert-manager-"))
			gomega.Expect(str).Should(gomega.MatchRegexp("cert-manager-cainjector-"))
			gomega.Expect(str).Should(gomega.MatchRegexp("cert-manager-webhook-"))
		})
	})

	var _ = ginkgo.Describe("--> Issuers", func() {
		ginkgo.It("should Issuer exists in namespace cert-manager-local-ca", func() {
			ret, err := getCrdObjects(f.ClientSet, "/apis/cert-manager.io/v1/namespaces/cert-manager-local-ca/issuers")
			if err != nil {
				klog.Infof("get crd err: %v", err)
			}
			//klog.Infof("XXX crd list: %v", ret)
			gomega.Expect(ret.Items[0].Name).Should(gomega.MatchRegexp("kind-test-issuer"))
		})
		ginkgo.It("should Issuer exists in namespace cert-manager-local-ca2", func() {
			ret, err := getCrdObjects(f.ClientSet, "/apis/cert-manager.io/v1/namespaces/cert-manager-local-ca2/issuers")
			if err != nil {
				klog.Infof("get crd err: %v", err)
			}
			//klog.Infof("XXX crd list: %v", ret)
			gomega.Expect(ret.Items[0].Name).Should(gomega.MatchRegexp("ca-issuer"))
		})
	})

	var _ = ginkgo.Describe("--> Certificates/Secrets", func() {
		ginkgo.It("should provide cert-key for cert-manager-local-ca", func() {
			ret, err := f.ClientSet.CoreV1().
				Secrets("cert-manager-local-ca").
				Get(context.TODO(), "test1-tls", metav1.GetOptions{})
			if err != nil {
				klog.Infof("get secret err: %v", err)
			}
			//klog.Infof("get secret ret: %v", ret)
			gomega.Expect(ret.Name).Should(gomega.MatchRegexp("test1-tls"))
		})
		ginkgo.It("should provide cert-key for cert-manager-local-ca2", func() {
			ret, err := f.ClientSet.CoreV1().
				Secrets("cert-manager-local-ca2").
				Get(context.TODO(), "test2-tls", metav1.GetOptions{})
			if err != nil {
				klog.Infof("get secret err: %v", err)
			}
			//klog.Infof("get secret ret: %v", ret)
			gomega.Expect(ret.Name).Should(gomega.MatchRegexp("test2-tls"))
		})
	})

})
