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

## Out of Scope for Phase 1

- GPS 定位、位置权限、距离计算。
- 局域网发现、房间、同步、协议。
- AR 摄像头、真实地图、地图瓦片。
- 云端账号、排行榜、远程存档。
- 精灵数值、捕捉判定、图鉴数据表。

## Core Loop Target

后续完整核心循环：

1. 玩家从主菜单进入单机或局域网模式。
2. 雷达场景根据本地规则显示附近精灵线索。
3. 玩家触发捕捉入口，进入捕捉场景。
4. 捕捉结果写入本地状态。
5. 图鉴场景展示已收集精灵。

## Scene List

- `MainMenu.tscn`：游戏入口与模式选择。
- `RadarScene.tscn`：雷达探索界面。
- `CaptureScene.tscn`：捕捉交互界面。
- `CollectionScene.tscn`：精灵图鉴界面。

## Development Constraints

- Godot 4.6。
- GDScript。
- 单机优先。
- Android APK 试玩优先。
- 不引入第三方插件。
- 优先保持结构清晰和可扩展。
