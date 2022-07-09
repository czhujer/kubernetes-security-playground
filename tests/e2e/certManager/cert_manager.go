package certManager

import (
	"context"
	"e2e/util"
	v1 "github.com/cert-manager/cert-manager/pkg/apis/certmanager/v1"
	cmmeta "github.com/cert-manager/cert-manager/pkg/apis/meta/v1"
	cmFramework "github.com/cert-manager/cert-manager/test/e2e/framework"
	cmUtil "github.com/cert-manager/cert-manager/test/e2e/util"
	"github.com/onsi/ginkgo"
	"github.com/onsi/gomega"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/klog"
	"k8s.io/kubernetes/test/e2e/framework"
	e2ekubectl "k8s.io/kubernetes/test/e2e/framework/kubectl"
	e2epod "k8s.io/kubernetes/test/e2e/framework/pod"
	"time"
)

const (
	//podNetworkAnnotation = "k8s.ovn.org/pod-networks"
	//agnhostImage         = "k8s.gcr.io/e2e-test-images/agnhost:2.26"
	//certManagerFullYaml = "../assets/cert-manager-full-generated-v1.4.1.yaml"
	certManagerNamespace string = "cert-manager"
	certManagerMinPods   int32  = 3
	frameworkName        string = "certmanager"
)

var (
	f    = framework.NewDefaultFramework(frameworkName)
	cmFw = cmFramework.NewDefaultFramework(frameworkName)
)

var _ = ginkgo.Describe("e2e cert-manager", func() {
	f.SkipNamespaceCreation = true

	ginkgo.BeforeEach(func() {
		ginkgo.By("Waiting to cert-manager's pods ready")
		err := e2epod.WaitForPodsRunningReady(f.ClientSet, certManagerNamespace, certManagerMinPods, 0, framework.PodStartShortTimeout, make(map[string]string))
		framework.ExpectNoError(err)

		tk := e2ekubectl.NewTestKubeconfig(framework.TestContext.CertDir, framework.TestContext.Host, framework.TestContext.KubeConfig, framework.TestContext.KubeContext, framework.TestContext.KubectlPath, "")

		ginkgo.By("creating certs and issuer objects")
		util.ApplyManifest(tk, "../../assets/k8s/ca/cert-manager-issuer-kind-test.yaml")
		util.ApplyManifest(tk, "../../assets/k8s/ca/cert-manager-issuer-kind-ca-test.yaml")
		util.ApplyManifest(tk, "../../assets/k8s/certs/cert-manager-certificate-test1.yaml")
		util.ApplyManifest(tk, "../../assets/k8s/certs/cert-manager-certificate-test2.yaml")

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
			ret, err := util.GetCrdObjects(f.ClientSet, "/apis/cert-manager.io/v1/namespaces/cert-manager-local-ca/issuers")
			if err != nil {
				klog.Infof("get crd err: %v", err)
			}
			//klog.Infof("XXX crd list: %v", ret)
			gomega.Expect(ret.Items[0].Name).Should(gomega.MatchRegexp("kind-test-issuer"))
		})

		ginkgo.It("should Issuer be in ready in namespace cert-manager-local-ca", func() {
			ginkgo.By("Waiting for Issuer to become Ready")
			err := cmUtil.WaitForIssuerCondition(cmFw.CertManagerClientSet.CertmanagerV1().Issuers("cert-manager-local-ca"),
				"kind-test-issuer",
				v1.IssuerCondition{
					Type:   v1.IssuerConditionReady,
					Status: cmmeta.ConditionTrue,
				})
			gomega.Expect(err).NotTo(gomega.HaveOccurred())
		})

		ginkgo.It("should Issuer exists in namespace cert-manager-local-ca2", func() {
			ret, err := util.GetCrdObjects(f.ClientSet, "/apis/cert-manager.io/v1/namespaces/cert-manager-local-ca2/issuers")
			if err != nil {
				klog.Infof("get crd err: %v", err)
			}
			//klog.Infof("DEBUG: issuers crd list: %v", ret)
			gomega.Expect(ret.Items[0].Name).Should(gomega.MatchRegexp("ca-issuer"))
		})

		ginkgo.It("should Issuer be in ready in namespace cert-manager-local-ca2", func() {
			ginkgo.By("Waiting for Issuer to become Ready")
			err := cmUtil.WaitForIssuerCondition(cmFw.CertManagerClientSet.CertmanagerV1().Issuers("cert-manager-local-ca2"),
				"ca-issuer",
				v1.IssuerCondition{
					Type:   v1.IssuerConditionReady,
					Status: cmmeta.ConditionTrue,
				})
			gomega.Expect(err).NotTo(gomega.HaveOccurred())
		})
	})

	var _ = ginkgo.Describe("--> Certificates/Secrets", func() {
		ginkgo.It("should provide cert-key for cert-manager-local-ca", func() {

			ginkgo.By("Waiting for the Certificate to be issued...")
			certContext, _ := cmFw.CertManagerClientSet.CertmanagerV1().Certificates("cert-manager-local-ca").Get(context.TODO(), "certificate-test1", metav1.GetOptions{})
			_, err := cmFw.Helper().WaitForCertificateReadyAndDoneIssuing(certContext, time.Minute*5)
			gomega.Expect(err).NotTo(gomega.HaveOccurred())

			ginkgo.By("Fetching secret's details...")
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

			ginkgo.By("Waiting for the Certificate to be issued...")
			certContext, _ := cmFw.CertManagerClientSet.CertmanagerV1().Certificates("cert-manager-local-ca2").Get(context.TODO(), "certificate-test2", metav1.GetOptions{})
			_, err := cmFw.Helper().WaitForCertificateReadyAndDoneIssuing(certContext, time.Minute*5)
			gomega.Expect(err).NotTo(gomega.HaveOccurred())

			ginkgo.By("Fetching secret's details...")
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
