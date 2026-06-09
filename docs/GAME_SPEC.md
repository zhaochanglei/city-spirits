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
- `CaptureScene.tscn`：展示被点击怪物的基础信息。
- `CollectionScene.tscn`：精灵图鉴界面。

## Development Constraints

- Godot 4.6。
- GDScript。
- 单机优先。
- Android APK 试玩优先。
- 不引入第三方插件。
- 优先保持结构清晰和可扩展。
