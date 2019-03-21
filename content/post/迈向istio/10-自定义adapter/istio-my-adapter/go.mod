module istio-my-adapter

replace (
	golang.org/x/net v0.0.0-20181106065722-10aee1819953 => github.com/golang/net v0.0.0-20181106065722-10aee1819953
	golang.org/x/sys v0.0.0-20181206074257-70b957f3b65e => github.com/golang/sys v0.0.0-20181206074257-70b957f3b65e
	golang.org/x/text v0.3.0 => github.com/golang/text v0.3.0
	golang.org/x/tools v0.0.0-20180221164845-07fd8470d635 => github.com/golang/tools v0.0.0-20180221164845-07fd8470d635
	golang.org/x/tools v0.0.0-20180828015842-6cd1fcedba52 => github.com/golang/tools v0.0.0-20180828015842-6cd1fcedba52
	google.golang.org/genproto v0.0.0-20190201180003-4b09977fb922 => github.com/google/go-genproto v0.0.0-20190201180003-4b09977fb922
	google.golang.org/grpc v1.16.0 => github.com/grpc/grpc-go v1.16.0
)

require (
	github.com/BurntSushi/toml v0.3.1 // indirect
	github.com/gogo/googleapis v1.1.0 // indirect
	github.com/gogo/protobuf v1.2.1
	github.com/hashicorp/go-multierror v1.0.0 // indirect
	github.com/inconshreveable/mousetrap v1.0.0 // indirect
	github.com/natefinch/lumberjack v2.0.0+incompatible // indirect
	github.com/pkg/errors v0.8.1 // indirect
	github.com/spf13/cobra v0.0.3 // indirect
	github.com/spf13/pflag v1.0.3 // indirect
	github.com/stretchr/testify v1.3.0 // indirect
	go.uber.org/atomic v1.3.2 // indirect
	go.uber.org/multierr v1.1.0 // indirect
	go.uber.org/zap v1.9.1 // indirect
	golang.org/x/net v0.0.0-20181106065722-10aee1819953
	golang.org/x/sys v0.0.0-20181206074257-70b957f3b65e // indirect
	google.golang.org/genproto v0.0.0-20190201180003-4b09977fb922 // indirect
	google.golang.org/grpc v1.16.0
	gopkg.in/natefinch/lumberjack.v2 v2.0.0 // indirect
	gopkg.in/yaml.v2 v2.2.2 // indirect
	istio.io/api v0.0.0-20190215181734-2b2fabd45153
	istio.io/istio v0.0.0-20190216013735-f62b4fa7d7ad
)
