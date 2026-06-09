# City Spirits Architecture

## Project Layout

```text
scenes/
  boot/
  main_menu/
  radar/
  capture/
  collection/
scripts/
  capture/
  core/
  location/
  monsters/
  radar/
  ui/
data/
docs/
tests/
```

## Entry Point

`project.godot` 的主场景指向 `res://scenes/main_menu/MainMenu.tscn`。`scenes/boot/Boot.tscn` 保留为初始工程遗留场景，当前不参与运行入口。

## Autoloads

Godot autoload 配置：

- `Constants`：集中维护场景路径、模式字符串和项目常量。
- `EventBus`：集中声明跨场景信号。
- `GameState`：保存当前模式、当前场景路径、当前选中怪物和本地收集状态。

这些脚本保持轻量，避免提前耦合 GPS、局域网、捕捉概率或存档规则。

## Phase 2 Runtime Pieces

- `MockLocationService`：只保存模拟玩家坐标，并通过信号通知位置变化。
- `MonsterDatabase`：从 `data/monsters.json` 读取怪物模板。
- `MonsterSpawner`：根据玩家初始位置生成固定数量的怪物实例，并提供距离和雷达相对坐标计算。
- `RadarController`：连接移动按钮、重绘怪物点、处理点击怪物进入捕捉界面。
- `CaptureController`：从 `GameState` 读取当前选中怪物并展示基础信息。

## Scene Flow

```text
MainMenu
  单机模式 -> RadarScene
  局域网模式 -> RadarScene
  图鉴     -> CollectionScene

RadarScene
  点击怪物点 -> CaptureScene
  返回 -> MainMenu

CaptureScene
  返回雷达 -> RadarScene

CollectionScene
  返回 -> MainMenu
```

局域网模式当前只记录模式并进入同一个雷达原型，不包含网络实现。

## UI Scripts

- `scripts/ui/MainMenu.gd`：绑定主菜单按钮并执行场景切换。
- `scripts/ui/PlaceholderScreen.gd`：为占位场景提供当前场景记录和返回主菜单逻辑。
- `scripts/radar/RadarController.gd`：雷达原型交互。
- `scripts/capture/CaptureController.gd`：捕捉详情展示。

## Future Architecture Notes

后续建议按功能拆分：

- `scripts/radar/`：雷达扫描、距离提示、附近精灵生成。
- `scripts/capture/`：捕捉状态机、捕捉结果、动画调度。
- `scripts/collection/`：图鉴数据读取、展示过滤。
- `scripts/location/`：Android 定位权限和 GPS 数据适配。
- `scripts/lan/`：局域网发现、主机/客户端会话、状态同步。
- `data/`：精灵配置和本地规则表。

每个阶段先定义接口，再接入具体实现，保持单机路径可独立运行。
