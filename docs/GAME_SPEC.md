# City Spirits Game Spec

## Vision

City Spirits 是一个单机优先、支持局域网联机的 GPS 雷达捕捉游戏。玩家在小范围真实空间内移动，通过游戏内雷达发现虚构的城市精灵，并在轻量捕捉界面中完成收集。

首批目标是给朋友安装 Android APK 试玩。项目不使用云服务器、不接入真实地图、不实现 AR，也不依赖第三方 Godot 插件。

## Phase 1 Scope

本阶段只建立 Godot 4.6 项目骨架：

- 主菜单：单机模式、局域网模式、图鉴。
- 单机模式进入雷达场景。
- 图鉴进入图鉴场景。
- 雷达、捕捉、图鉴先使用占位 UI。
- 建立核心脚本：`GameState`、`EventBus`、`Constants`。
- 建立基础文档，方便后续阶段继续开发。

## Phase 2 Scope

第二阶段实现单机雷达原型，不接入真实 GPS：

- 使用 `MockLocationService` 保存和移动模拟玩家坐标。
- `RadarScene` 中玩家点始终显示在雷达中心。
- 雷达周围显示 5-10 个怪物点，当前固定生成 8 个。
- 上、下、左、右按钮每次移动模拟玩家 25 米。
- 玩家移动后，怪物点按世界坐标相对玩家位置重新计算屏幕位置。
- 点击怪物点进入 `CaptureScene`。
- `CaptureScene` 展示怪物名称、ID、距离、世界坐标和提示文本。
- `CollectionScene` 仍保持占位，不实现图鉴存档。

## Phase 3 Scope

第三阶段实现基础捕捉、JSON 本地存档和图鉴：

- `CaptureSystem` 根据基础捕捉率和投掷倍率计算成功或失败。
- `CaptureScene` 显示怪物名称、ID、稀有度、基础捕捉率、距离、世界坐标和提示。
- 投掷方式：
  - 普通投掷：倍率 1.0。
  - 精准投掷：倍率 1.2。
  - 冒险投掷：倍率 1.5；失败后怪物逃跑，本次不能继续投掷。
- 捕捉成功后，怪物写入玩家图鉴。
- `SaveManager` 使用 JSON 保存本地数据。
- 默认存档路径是 `user://save/collection.json`。
- 文件不存在时自动创建默认存档。
- JSON 损坏时回退到默认存档并打印 warning，不让游戏崩溃。
- `CollectionScene` 显示已捕捉怪物列表。

## Phase 4 Scope

第四阶段接入统一定位服务，并保留 PC 模拟位置模式：

- 新增 `LocationService` 作为雷达唯一定位入口。
- PC、Editor、Windows 使用 `MockLocationService`，继续显示上、下、左、右模拟移动按钮。
- Android 真机使用前台定位权限。
- Android 导出声明 `ACCESS_FINE_LOCATION` 和 `ACCESS_COARSE_LOCATION`。
- Android 不请求后台定位权限。
- 权限被拒绝、定位服务不可用、精度过低、暂时没有定位结果时，雷达显示明确状态文本，不崩溃。
- Android 首个有效经纬度作为雷达原点，后续经纬度换算成米制相对坐标。
- `RadarScene` 不直接依赖 `MockLocationService`。

## Out of Scope for Phase 1

- GPS 定位、位置权限、距离计算。
- 局域网发现、房间、同步、协议。
- AR 摄像头、真实地图、地图瓦片。
- 云端账号、排行榜、远程存档。
- 精灵数值、捕捉判定、图鉴数据表。

## Out of Scope for Phase 2

- 真实 GPS、Android 定位权限、定位误差处理。
- 局域网发现、房间、同步、协议。
- 真实地图、AR、摄像头。
- 捕捉概率、捕捉结果、图鉴存档。
- 云服务和远程数据。

## Out of Scope for Phase 3

- GPS、局域网、真实地图、AR。
- 复杂背包、道具消耗、捕捉动画、精灵成长。
- 云同步、账号、远程存档。
- Android 导出配置调整。

## Out of Scope for Phase 4

- 后台定位。
- 连续高频轨迹记录。
- 局域网、真实地图、AR、云服务。
- 捕捉系统或存档格式调整。
- 第三方 Android 插件。

## Core Loop Target

后续完整核心循环：

1. 玩家从主菜单进入单机或局域网模式。
2. 雷达场景根据本地规则显示附近精灵线索。
3. 玩家触发捕捉入口，进入捕捉场景。
4. 捕捉结果写入本地状态。
5. 图鉴场景展示已收集精灵。

## Scene List

- `MainMenu.tscn`：游戏入口与模式选择。
- `RadarScene.tscn`：mock 单机雷达探索界面。
- `CaptureScene.tscn`：展示被点击怪物的基础信息并执行捕捉。
- `CollectionScene.tscn`：展示本地已捕捉怪物列表。

## Development Constraints

- Godot 4.6。
- GDScript。
- 单机优先。
- Android APK 试玩优先。
- 不引入第三方插件。
- 优先保持结构清晰和可扩展。
