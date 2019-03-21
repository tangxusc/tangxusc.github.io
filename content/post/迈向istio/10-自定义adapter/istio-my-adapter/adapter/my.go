//go:generate $GOPATH/src/istio.io/istio/bin/mixer_codegen.sh -a myadapter/my.proto -x "-s=false -n myadapter -t authorization"

package adapter

import (
	"encoding/json"
	"fmt"
	"golang.org/x/net/context"
	"istio.io/api/mixer/adapter/model/v1beta1"
	"istio.io/istio/mixer/pkg/status"
	"istio.io/istio/mixer/template/authorization"
)

var _ authorization.HandleAuthorizationServiceServer = &MyAuth{}

type MyAuth struct {
}

func (*MyAuth) HandleAuthorization(ctx context.Context, request *authorization.HandleAuthorizationRequest) (*v1beta1.CheckResult, error) {
	bytes, e := json.Marshal(request)
	if e != nil {
		fmt.Println("序列化失败,", e.Error())
	}
	fmt.Printf("%s \n", string(bytes))
	return &v1beta1.CheckResult{
		Status: status.OK,
	}, nil
}
