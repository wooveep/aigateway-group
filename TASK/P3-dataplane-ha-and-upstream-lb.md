# P3 数据面高可用与上游负载

- 状态：`done`
- 依赖：`P2`

## 目标

- 完成 Higress 数据面对外高可用。
- 完成请求上游 API 时的多副本负载能力。

## 任务

- [ ] 为 `gateway/controller/pluginServer/console/portal` 增加正式发布副本值收口。
- [ ] 增加 `PDB / anti-affinity / topologySpread / rollingUpdate / HPA` 发布入口。
- [ ] 新增发布模板渲染上游 `DestinationRule`。
- [ ] 为外部 API 上游补 `ServiceEntry`。
- [ ] 统一 `release.upstreams[]` 配置面，覆盖 `k8sService` 与 `external`。
- [ ] 默认上游负载策略固定为 `consistentHash`。
- [ ] 支持切换 `roundRobin / leastRequest / consistentHash(sourceIp|header|cookie)`。

## 验收点

- [ ] 发布 values 可以同时控制入口多副本与上游多副本负载。
- [ ] 不需要手工额外补 Istio 资源就能跑常见上游负载场景。
- [ ] `release.upstreams[]` 同时覆盖 K8S Service 和外部 API endpoints。

## 测试

- [ ] `helm template` 验证多副本和 `PDB / topologySpread / affinity / HPA` 配置。
- [ ] `helm template` 验证 `DestinationRule / ServiceEntry`。
- [ ] K3D 场景验证多 endpoint 上游请求分发。
