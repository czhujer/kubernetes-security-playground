package util

import (
	"bytes"
	"context"
	"fmt"
	apiextensionsv1 "k8s.io/apiextensions-apiserver/pkg/apis/apiextensions/v1"
	"k8s.io/client-go/kubernetes"
	restclient "k8s.io/client-go/rest"
	"k8s.io/kubernetes/test/e2e/framework"
	e2ekubectl "k8s.io/kubernetes/test/e2e/framework/kubectl"
	e2elog "k8s.io/kubernetes/test/e2e/framework/log"
	"time"
)

func ApplyManifest(testContext *e2ekubectl.TestKubeconfig, yamlFile string) {
	var stdout, stderr bytes.Buffer
	var err error

	cmd := testContext.KubectlCmd("apply", "-f", yamlFile, "--wait=true")
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

func GetCrdObjects(c kubernetes.Interface, absPath string) (*apiextensionsv1.CustomResourceDefinitionList, error) {
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

// https://github.com/cilium/cilium/blob/a8b2af8c9ec421e74fd322c0afcd6ab7d988c2f8/test/ginkgo-ext/scopes.go#L660

// SkipContextIf is a wrapper for the Context block which is being executed
// if the given condition is NOT met.
//func SkipContextIf(condition func() bool, text string, body func()) bool {
//	if condition() {
//		return ginkgo.It(text, func() {
//			ginkgo.Skip("skipping due to unmet condition")
//		})
//	}
//
//	return ginkgo.Context(text, body)
//}
