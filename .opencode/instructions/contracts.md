# contracts 模块约束与说明

## 目录

contracts/ 目录定义项目中所有共享的类型、接口和常量。**不包含任何业务逻辑实现**，仅做类型声明。

## 通用约束

1. **Package**: 始终为 `package contracts`
2. **Tags**: 所有导出结构体字段必须同时标注 `yaml` 和 `json` 标签
   - 对于通过 viper 加载的配置类型（如 `AppConfig`、`EndpointConfig`），还需添加 `mapstructure` 标签
3. **secrets**: 私密字段（如 SSH 私钥、密码哈希）使用 `json:"-"` 防止泄漏
4. **Interface-only**: "Manager"、"Store"、"Factory"、"Runtime"、"Loader"、"Validator" 等均为接口，实现在 `backend/` 下
5. **无内部依赖**: contracts 只能依赖外部库（如 `gopkg.in/yaml.v3`），**不得** import 项目的 `backend/`、`cli/`、`sdk/` 等包
6. **Go 版本**: 跟随 `go.work` 中的版本

## 命名规范

- 旧名称 `Subscription` → 已统一重命名为 `AppRepo`
  - `SubscriptionManager` → `AppRepoManager`
  - `SubscriptionStore` → `AppRepoStore`
  - 但 YAML 字段仍保留 `subscriptions`（向后兼容）：`AppRepos []AppRepo \`yaml:"subscriptions,..."`
- 迁移相关类型使用 `GenerateAppRequest` 而非旧的 `GenerateTemplateRequest`

## 自定义 YAML 反序列化

以下类型支持灵活的 YAML 输入格式（对象 或 字符串简写）：

| 类型 | 对象格式 | 字符串格式 | 说明 |
|------|---------|-----------|------|
| `PortMapping` | `{host_port, container_port, protocol}` | `"8080"` 或 `"80:80"` 或 `"80:80/tcp"` | |
| `VolumeMount` | `{source, target, read_only, type}` | `"/data:/data:ro"` | 字段名是 `Target`，**不是** `Destination` |
| `DeviceMapping` | `{host_path, container_path, permissions}` | `"/dev/sda:/dev/sda"` | |
| `FlexBool` | `true` / `false` | `"{{ .TLSEnabled }}"` | 支持 Go template 表达式字符串 |
| `PostInstallHookList` | `[{type, command, ...}]` | 单对象 `{message: "..."}` | 自动包装为单元素数组 |
| `TraefikAuthConfig` | `{basic_auth: ...}` | `true` | `true` 表示使用默认 basic auth |

## 关键接口

### 运行时 (runtime.go)

```go
type ContainerRuntime interface {
    ContainerRun(params ContainerRunParams) (string, error)
    ContainerStop(containerID string) error
    ContainerRemove(containerID string, force bool) error
    ContainerInspect(containerID string) (*ContainerInfo, error)
    ContainerExec(containerID string, command []string) (string, error)
    ContainerLogs(containerID string, tail int) (string, error)
    ContainerList(all bool) ([]ContainerInfo, error)
    ContainerUpdateLabels(containerID string, labels map[string]string) error
    PullImage(image string) error
    ImageList() ([]ImageInfo, error)
    NetworkCreate/Remove/Inspect/List/Connect(...)
    VolumeCreate/Remove/Inspect/List(...)
    Ping() error
    Info() (*RuntimeInfo, error)
}
```

### 服务管理 (service.go)

```go
type ServiceManager interface {
    List() ([]*ServiceDefinition, error)
    Get(name string) (*ServiceDefinition, error)
    GetByCategory(category string) ([]*ServiceDefinition, error)
    Search(query string) ([]*ServiceDefinition, error)
    Install(name string, params []*ParamValue, remote string) (string, error)
    Uninstall(name string) error
    Status(name string) (*ServiceStatusResult, error)
    Restart(name string) error
    Update(name string) error
    PreCheck(name string, params []*ParamValue) error
    RenderConfig(name string, params []*ParamValue) (map[string]string, error)
}
```

### 应用仓库 (subscription.go)

```go
type AppRepoManager interface {
    Add(sub *AppRepo) error
    Remove(name string) error
    List() ([]*AppRepo, error)
    Get(name string) (*AppRepo, error)
    Sync(name string) error
    SyncAll() error
    GetLocalPath(name string) (string, error)
}
```

### 迁移 (migrate.go)

```go
type MigrateService interface {
    Analyze(epName string) ([]*MigrationCandidate, error)
    Execute(req *MigrationRequest) (string, error)
    Generate(req *GenerateAppRequest) (*GenerateAppResult, error)
    Adopt(req *AdoptRequest) (*AdoptResult, error)
}
```

## 标签系统 (label.go)

通过 `selfhosted.` 前缀标记托管的容器：

```
selfhosted.managed    = "true"
selfhosted.service    = "<service-name>"
selfhosted.repo       = "<app-repo-name>"
selfhosted.version    = "<version>"
selfhosted.host       = "<traefik-host>"
selfhosted.engine     = "docker|podman"
```

## 服务定义 (ServiceDefinition)

核心结构，描述一个可安装服务：

```yaml
api_version: "v1"
name: jellyfin
image: jellyfin/jellyfin
params:
  - name: port
    type: number
    default: 8096
container:
  image: "{{ .Service.Image }}"
  ports:
    - "8096:{{ .Params.port }}"
  volumes:
    - "/data/jellyfin:/config"
traefik:
  enabled: true
  host: "jellyfin.example.com"
```

## 常量

- `ParamType`: string, password, array, bool, number, select
- `ConnectionType`: unix, tcp, http, https, ssh
- `EngineType`: docker, podman, auto
- `RestartPolicy`: no, always, on-failure, unless-stopped
- `NetworkDriver`: bridge, host, overlay, macvlan, none
- `ServiceStatus`: installed, not_installed, running, stopped, error, unknown
- `RenderMode`: plain, masked, json, env, volume

## 修改注意事项

- 新增类型时，确保已注册所有必要的 yaml/json 标签
- 修改已有类型字段时，同步更新所有引用的实现（`backend/`、`cli/`、`sdk/`）
- 修改 YAML 反序列化逻辑时，确保兼容旧的 YAML 格式
- 修改接口签名时，更新所有实现该接口的模块
- 不要破坏 `AppConfig` 中 `subscriptions` 的 YAML 向后兼容性
