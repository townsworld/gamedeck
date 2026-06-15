# GameDeck

[English](README.md)

GameDeck 是一个只读的 Android 应用，用来在一个地方管理多个 Steam 账号的游戏库。它主要关注多账号聚合、游戏搜索、游玩时长、最近游玩、商店信息、中文游戏名和本地缓存。

应用不会执行购买、交易、账号修改或任何 Steam 商店操作。

## 功能

- 通过 SteamID64 或个人主页 URL 添加多个 Steam 账号。
- 合并浏览多个账号的 Steam 游戏库。
- 支持按中文名、英文名和标签搜索游戏。
- 支持按最后游玩时间、总游玩时长、名称、拥有账号数、同步时间排序。
- 首页展示最近玩过、最常玩、重复拥有、未启动等总览信息。
- 展示 Steam 商店信息，包括价格、折扣、评价、截图、Banner、发售日期、开发商、发行商、类型、平台和成就数。
- 使用小黑盒数据补充中文名、小黑盒评分、价格、史低、标签、关注数和截图。
- 同步中心支持分开刷新 Steam 数据、完整详情和小黑盒数据。
- 游戏详情页支持单独刷新当前游戏的完整详情、Steam 详情或小黑盒数据。
- Steam Web API Key 和缓存数据都保存在本机。

## 页面

- **账号**：账号列表、游戏库总览、最近玩过、最常玩和同步中心。
- **游戏库**：可搜索、可筛选、可排序的合并游戏库。
- **游戏详情**：商店信息、评分、价格、图片、拥有账号、游玩时间和外部链接。
- **设置**：Steam Web API Key、每日自动同步 Steam、本地缓存清理。

## 数据来源

GameDeck 会整合以下数据：

- Steam Web API
  - 账号资料
  - 拥有的游戏
  - 总游玩时长
  - 最后游玩时间
- Steam 商店接口
  - 商店详情
  - 价格和折扣
  - 评价
  - 截图和 Banner
- 小黑盒 Web API
  - 中文名
  - 小黑盒评分
  - 本地化价格
  - 史低
  - 标签和截图

## 隐私

- Steam Web API Key 只保存在本机。
- 账号和游戏缓存数据只保存在本机。
- GameDeck 是只读客户端。
- 不实现购买、交易、愿望单、评测或账号修改操作。

## 环境要求

- Flutter SDK
- Android SDK
- Android 真机或模拟器
- Steam Web API Key

## 开发

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

构建 debug APK：

```bash
flutter build apk --debug
```

安装到已连接的 Android 设备：

```bash
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

## 包名

Android 包名：

```text
com.towns.gamedeck
```

## 状态

GameDeck 目前是个人使用的 Android 优先早期项目，当前版本重点是本地 Steam 游戏库管理和游戏元数据聚合。
