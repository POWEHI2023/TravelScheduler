# TravelScheduler

TravelScheduler 是一个基于 SwiftUI、Observation 和 MapKit 的 iOS / iPadOS 多地点行程路线规划应用。它更偏向“按既定顺序组织旅行路线”的规划工具，而不是自动求最优路径的导航软件。

你先决定要去哪些地点、这些地点的顺序，以及每一段使用什么出行方式，应用再负责生成路线、展示地图结果、整理分段信息，并导出 Markdown 格式的路线文档。

## 当前实现包含的能力

- 搜索景点、地标或地址，并把结果加入当前行程。
- 对重复地点做语义去重，避免同一地点被重复加入。
- 按列表顺序管理地点，支持删除、拖拽重排。
- 支持环线模式，开启后最后一段会自动回到起点。
- 为每一段路线选择 `driving`、`walking`、`transit` 三种通行方式。
- 在地图中按分段着色展示路线，并支持逐段隐藏 / 显示。
- 查看总时长、总路程、整体出行建议和分段详情。
- 对应用内无法完整承载的公共交通分段，提供 Apple 地图跳转。
- 生成 Markdown 路线规划文档，并在应用内预览、复制。

## 使用方式

1. 搜索地点并加入行程。
2. 通过拖拽调整地点顺序。
3. 视需要开启环线模式。
4. 为每一段选择交通方式。
5. 生成路线，查看地图、摘要和分段详情。
6. 需要时导出 Markdown 路线规划文档。

## 路线生成规则

- 路线严格按当前地点顺序生成，不会自动重排为“最优路线”。
- 起点是列表中的第一个地点，终点是最后一个地点；开启环线后，终点会回到起点。
- `driving` 和 `walking` 优先通过 `MKDirections` 生成应用内路线。
- `transit` 会优先尝试获取公共交通耗时与外部路线参考。
- 当公共交通无法直接提供完整应用内路线时，应用会视情况：
  - 回退为步行或驾车分段。
  - 保留该段并给出估算时长。
  - 提供 Apple 地图跳转以查看完整公共交通详情。
- 当地图服务无法返回可用路线时，个别分段可能退化为直线连接，并在详情中给出提示。
- 若路线中包含外部公共交通段，总路程不代表完整公共交通实际轨迹。

## 当前实现边界

- 不提供自动旅行商式最优排序。
- 不在应用内实现完整公共交通逐步导航。
- 不包含账户体系、云同步或本地持久化。
- 当前重点是“旅行路线规划与展示”，不是 turn-by-turn 导航。

## 项目结构

- `TravelScheduler/Presentation`
  SwiftUI 页面和 `TripPlannerViewModel`
- `TravelScheduler/Application`
  地点搜索、路线规划、Markdown 文档生成服务
- `TravelScheduler/Domain`
  `TripStop`、`RouteSegment`、`TravelMode`、`TripPlanDraft`、`TransitRouteReference`
- `TravelScheduler/Shared`
  本地化、格式化、颜色和 MapKit 扩展支持

## 技术栈

- SwiftUI
- Observation
- MapKit
- 本地化资源：`Localizable.xcstrings`

本项目当前没有第三方依赖。

## 运行项目

### Xcode

1. 使用 Xcode 打开 `TravelScheduler.xcodeproj`。
2. 选择 `TravelScheduler` scheme。
3. 选择 iPhone / iPad 模拟器或真机运行。

当前工程配置为：

- Bundle Identifier: `Austrini.TravelScheduler`
- Marketing Version: `1.0`
- Supported Device Family: iPhone / iPad
- Deployment Target: `iOS / iPadOS 26.2`

### 命令行构建

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild \
  -project TravelScheduler.xcodeproj \
  -scheme TravelScheduler \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  build
```

## License

本项目采用 [GPL-3.0](LICENSE) 许可证。
