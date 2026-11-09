中文
|
[English](README.en.md)

# Fcitx iOS Evolve

基于 [Fcitx5](https://github.com/fcitx/fcitx5) 的 iOS 拼音输入法，支持 iOS 16.3 及以上，专注于在AI时代进行传统手搓输入体验把打字手感做好。

本项目 fork 自 [fcitx5-ios](https://github.com/fcitx-contrib/fcitx5-ios)。

> 状态：个人项目，日常在用，尚未正式发布。暂无现成的 IPA，请自行构建（见下文）。

## 与 fcitx5-ios 的不同

### 外观
- 默认 iOS 风格：跟随系统配色、半透明背景、圆角按键，与系统键盘一致；也可切换为经典风格
- 两种风格都可开关按键边框，深浅色跟随系统
- 重新调校的按键间距、键盘高度和候选栏间距

### 手感
- 触摸感知纠错：用二维高斯按键模型给触摸点周围的按键打分，拼音引擎据此尝试可能误触的相邻键
  （例如只有当 q 点在靠近 a 的位置时，`nihqo` 才会纠正为“你好”）
- 精细调校的手势参数：滑动距离、长按时长、空格滑动移动光标、退格连删、按键间滑动的迟滞判定
- 点第一排按键不会误选候选词，只有按键上方间隙的上沿才会选中候选
- 按键震动（弱／中／强）与按键气泡

### 拼音与词库
- 优化词库导入
- 改进编码排序效率
- 大幅度优化中英混输

### 符号与表情
- 分类符号键盘
- 表情面板（长按逗号）：最近使用与分类浏览；支持用中文或英文搜索表情（猫／cat）

### 设置
- 在键盘的“…”面板中切换主题
- 配置 App Group 后，App 与键盘直接共享配置和用户数据，无需手动同步

## 构建

本项目不使用 Xcode 工程管理，但需要 Xcode 27.1 提供 iOS SDK。
以下以 Apple Silicon 为例；Intel Mac 请把 `SIMULATORARM64` 换成 `SIMULATOR64`。

### 依赖与补丁
```sh
git clone --recursive https://github.com/Yumeri0913/Fcitx-iOS-Evolve.git && cd Fcitx-iOS-Evolve
brew install cmake ninja gettext pkg-config
./scripts/install-deps.sh SIMULATORARM64
./scripts/patch.sh
```

### 模拟器
```sh
cmake -B build/SIMULATORARM64 -G Ninja -DCMAKE_BUILD_TYPE=Debug -DPLATFORM=SIMULATORARM64 \
  -DPINYIN_ONLY=ON -DHALLELUJAH=OFF -DMOZC=OFF -DRIME=OFF
cmake --build build/SIMULATORARM64 && ./scripts/code-sign.sh SIMULATORARM64
xcrun simctl install booted build/SIMULATORARM64/src/Fcitx5.app
```
然后在“设置 → 通用 → 键盘 → 键盘 → 添加新键盘”中添加。

### 真机
```sh
./scripts/install-deps.sh OS64
cmake -B build/OS64 -G Ninja -DCMAKE_BUILD_TYPE=Release -DPLATFORM=OS64 \
  -DPINYIN_ONLY=ON -DHALLELUJAH=OFF -DMOZC=OFF -DRIME=OFF
cmake --build build/OS64
cd build/OS64/src && rm -rf Payload Fcitx5.ipa && mkdir Payload
cp -r Fcitx5.app Payload && zip -r Fcitx5.ipa Payload
```

**有付费开发者账号**（推荐）：注册自己的 Bundle ID 和 App Group，然后配置：
```sh
cmake -DBUNDLE_IDENTIFIER=com.example.fcitx5 -DAPP_GROUP_IDENTIFIER=group.com.example.fcitx5 build/OS64
```
键盘扩展的 ID 为 `<bundle>.Chinese` 等。每个 bundle 用各自的描述文件签名，entitlements 中需包含
`com.apple.security.application-groups`。

**没有付费账号**：用 [SideStore](https://github.com/SideStore/SideStore) 安装未签名的 IPA。
此时无法使用 App Group，需要给键盘开启“完全访问”，并在修改设置或数据后到 App 里点“同步配置”。

## 测试
```sh
cd build/SIMULATORARM64 && ctest
```
端到端测试使用 Appium，见 [appium](appium)。

## 真机调试

- **内存**：键盘扩展超过 77 MB 会被系统杀掉，排查方法见 [docs/memory.md](docs/memory.md)。
- **崩溃**：设置 → 隐私与安全性 → 分析与改进 → 分析数据，传到 Mac 上用“控制台”App 打开。

## 上游

通用的修复欢迎回馈给 [fcitx5-ios](https://github.com/fcitx-contrib/fcitx5-ios)。感谢 fcitx5-ios 的作者和
[Fcitx](https://github.com/fcitx) 项目。

## 许可证

[GPL-3.0](LICENSE)。使用的第三方开源项目见 [CREDITS.md](CREDITS.md)。
