# ClaudeBridge

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="ClaudeBridgeApp/Assets.xcassets/AppIcon.appiconset/icon_128x128@2x.png">
    <img src="ClaudeBridgeApp/Assets.xcassets/AppIcon.appiconset/icon_128x128@2x.png" width="128" height="128" alt="ClaudeBridge Icon">
  </picture>
</p>

macOS 菜单栏应用，管理 [copilot-api](https://github.com/ericc-ch/copilot-api) 代理服务。通过 GitHub Copilot 订阅为 Claude Code 提供 API 代理。

## ✨ Features

- **Setup Wizard** — 首次启动自动弹出 4 步引导（安装 → 登录 → 选择模型 → 就绪）
- **一键安装 copilot-api** — 无需手动打开终端，直接在 App 内通过 npm 安装
- **菜单栏常驻** — 一键 Start / Stop / Restart 代理
- **GitHub Copilot 登录** — Device Flow 认证，自动检测账户类型
- **动态模型选择** — 从服务器获取可用模型列表，必须选择 Claude 模型
- **自动配置 Claude Code** — 自动写入 `~/.claude/settings.json`，支持一键还原
- **实时日志查看** — 查看代理运行日志
- **用量查看** — 内置 Usage Viewer 链接
- **开机自启动** — 支持 Launch at Login
- **自动更新** — 通过 Sparkle 框架自动检查更新
- **多语言** — 支持英文 / 简体中文

## 📸 Screenshots

### Setup Wizard
首次启动时自动引导完成配置：

```
① Install  →  ② Login  →  ③ Models  →  ④ Ready
```


## 🚀 Getting Started

### 方式一：下载安装（推荐）

1. 前往 [Releases](https://github.com/xuhaoyuan/ClaudeBridgeApp/releases/latest) 下载最新版 `ClaudeBridge.zip`
2. 解压后拖入 `/Applications`
3. 启动 App，按照 Setup Wizard 引导完成配置

### 方式二：从源码构建

```bash
git clone https://github.com/xuhaoyuan/ClaudeBridgeApp.git
cd ClaudeBridgeApp
open ClaudeBridgeApp.xcodeproj
```

在 Xcode 中 Build & Run 即可。

## 📖 Usage

### 首次使用

1. **安装 copilot-api** — Setup Wizard 第一步支持一键安装，或手动执行：
   ```bash
   npm install -g copilot-api
   ```
2. **登录 GitHub** — 通过 Device Code 认证登录你的 GitHub Copilot 账号
3. **选择模型** — 选择 Claude 模型（⚠️ 请选择 Claude 系列模型，非 Claude 模型可能导致不可用）
4. **开始使用** — 代理启动后，直接在终端运行 `claude` 即可

### 日常使用

App 会常驻菜单栏，提供：

- **Start / Stop / Restart** — 控制代理服务
- **Copy Claude Command** — 复制带环境变量的 claude 启动命令
- **Settings** — 修改端口、模型、账户类型等
- **Reconfigure** — 重新运行 Setup Wizard
- **Restore Claude Config** — 还原 `~/.claude/settings.json` 中的代理设置

### Claude Code 配置

App 会自动在 `~/.claude/settings.json` 中写入以下配置：

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "http://localhost:4141",
    "ANTHROPIC_API_KEY": "copilot",
    "CLAUDE_MODEL": "your-selected-model",
    "ANTHROPIC_SMALL_FAST_MODEL": "your-selected-small-model"
  },
  "model": "your-selected-model",
  "smallModel": "your-selected-small-model"
}
```

不再需要手动设置环境变量，直接运行 `claude` 即可。

## ⚙️ Requirements

- macOS 14+
- [Node.js](https://nodejs.org/) (用于安装 copilot-api)
- [copilot-api](https://github.com/ericc-ch/copilot-api)
- GitHub Copilot 订阅

## 🔧 Development

### Build Release

```bash
./scripts/release.sh 1.1.0
```

脚本会自动构建 Release 版本、压缩、Sparkle EdDSA 签名，并输出 appcast.xml 更新内容。

## 📄 License

MIT
