package e2e

import (
	"bytes"
	"context"
	"fmt"
	"github.com/onsi/ginkgo"
	"github.com/onsi/gomega"
	apiextensionsv1 "k8s.io/apiextensions-apiserver/pkg/apis/apiextensions/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
	restclient "k8s.io/client-go/rest"
	"k8s.io/klog"
	"k8s.io/kubernetes/test/e2e/framework"
	e2ekubectl "k8s.io/kubernetes/test/e2e/framework/kubectl"
	e2elog "k8s.io/kubernetes/test/e2e/framework/log"
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

func applyManifest(yamlFile string) {
	var stdout, stderr bytes.Buffer
	var err error

	//e2elog.Logf("run kubectl apply command with file: %v", yamlFile)

	tk := e2ekubectl.NewTestKubeconfig(framework.TestContext.CertDir, framework.TestContext.Host, framework.TestContext.KubeConfig, framework.TestContext.KubeContext, framework.TestContext.KubectlPath, "")
	cmd := tk.KubectlCmd("apply", "-f", yamlFile)
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	err = cmd.Run()
	if err != nil {
		e2elog.Logf("kubectl apply command finished with error: %v", err)
	}
	//outStr, errStr := string(stdout.Bytes()), string(stderr.Bytes())
	//klog.Infof("command stdout: %v", outStr)
	//klog.Infof("command stderr: %v", errStr)

	framework.ExpectNoError(err)
}

func getCrdObjects(c kubernetes.Interface, absPath string) (*apiextensionsv1.CustomResourceDefinitionList, error) {
	var client restclient.Result
	finished := make(chan struct{}, 1)
	go func() {
		// call chain tends to hang in some cases when Node is not ready. Add an artificial timeout for this call. #22165
		client = c.CoreV1().RESTClient().Get().
			AbsPath(absPath).
			Do(context.TODO())

		finished <- struct{}{}
	}()
	select {
	case <-finished:
		result := &apiextensionsv1.CustomResourceDefinitionList{}
		if err := client.Into(result); err != nil {
			return &apiextensionsv1.CustomResourceDefinitionList{}, err
		}
		return result, nil
	case <-time.After(framework.PodStartShortTimeout):
		return &apiextensionsv1.CustomResourceDefinitionList{}, fmt.Errorf("Waiting up to %v for getting the list of CRDs", framework.PodStartShortTimeout)
	}
}

var _ = ginkgo.Describe("e2e cert-manager", func() {

	f := framework.NewDefaultFramework(frameworkName)

	ginkgo.BeforeEach(func() {
		//ensure if cert-manager and Issuer(s) is installed
		//ginkgo.By("Executing cert-manager installation")
		//applyManifest(certManagerFullYaml)

		ginkgo.By("Waiting to cert-manager's pods ready")
		err := e2epod.WaitForPodsRunningReady(f.ClientSet, certManagerNamespace, certManagerMinPods, 0, framework.PodStartShortTimeout, make(map[string]string))
		framework.ExpectNoError(err)

		ginkgo.By("Executing certs and Issuer objects")
		applyManifest("../assets/k8s/ca/cert-manager-issuer-kind-test.yaml")
		applyManifest("../assets/k8s/ca/cert-manager-issuer-kind-ca-test.yaml")
		applyManifest("../assets/k8s/certs/cert-manager-certificate-test1.yaml")
		applyManifest("../assets/k8s/certs/cert-manager-certificate-test2.yaml")

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
