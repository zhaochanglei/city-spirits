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
  collection/
  core/
  location/
  monsters/
  radar/
  save/
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
- `SaveManager`：管理 `user://save/collection.json` 的 JSON 读写、默认创建和损坏回退。
- `GameState`：保存当前模式、当前场景路径、当前选中怪物和本地收集状态。

这些脚本保持轻量，避免提前耦合 GPS、局域网、捕捉概率或存档规则。

## Phase 2 Runtime Pieces

- `MockLocationService`：只保存模拟玩家坐标，并通过信号通知位置变化。
- `MonsterDatabase`：从 `data/monsters.json` 读取怪物模板。
- `MonsterSpawner`：根据玩家初始位置生成固定数量的怪物实例，并提供距离和雷达相对坐标计算。
- `RadarController`：连接移动按钮、重绘怪物点、处理点击怪物进入捕捉界面。
- `CaptureController`：从 `GameState` 读取当前选中怪物并展示基础信息。

## Phase 3 Runtime Pieces

- `CaptureSystem`：纯逻辑对象，输入怪物数据、投掷倍率和随机判定值，输出成功/失败、概率、判定值和逃跑状态。
- `SaveManager`：autoload，默认写入 `user://save/collection.json`。缺文件时创建 `{ version, captured_monsters }`，损坏时 warning 后重写默认档。
- `GameState`：捕捉成功时调用 `SaveManager.add_captured_monster()`，并缓存当前图鉴列表给 UI 使用。
- `CollectionController`：进入图鉴时调用 `GameState.load_collection()`，再生成已捕捉怪物列表。

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
  捕捉成功 -> 写入 SaveManager / 更新图鉴缓存

CollectionScene
  返回 -> MainMenu
```

局域网模式当前只记录模式并进入同一个雷达原型，不包含网络实现。

## UI Scripts

- `scripts/ui/MainMenu.gd`：绑定主菜单按钮并执行场景切换。
- `scripts/ui/PlaceholderScreen.gd`：为占位场景提供当前场景记录和返回主菜单逻辑。
- `scripts/radar/RadarController.gd`：雷达原型交互。
- `scripts/capture/CaptureController.gd`：捕捉详情展示。
- `scripts/capture/CaptureSystem.gd`：捕捉概率和结果计算。
- `scripts/save/SaveManager.gd`：本地 JSON 存档。
- `scripts/collection/CollectionController.gd`：图鉴列表。

## Future Architecture Notes

后续建议按功能拆分：

- `scripts/radar/`：雷达扫描、距离提示、附近精灵生成。
- `scripts/capture/`：捕捉状态机、捕捉结果、动画调度。
- `scripts/collection/`：图鉴数据读取、展示过滤。
- `scripts/location/`：Android 定位权限和 GPS 数据适配。
- `scripts/lan/`：局域网发现、主机/客户端会话、状态同步。
- `data/`：精灵配置和本地规则表。

每个阶段先定义接口，再接入具体实现，保持单机路径可独立运行。
