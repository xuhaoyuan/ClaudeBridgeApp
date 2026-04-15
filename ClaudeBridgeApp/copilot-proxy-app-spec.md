# Copilot API Proxy - macOS 菜单栏 App 需求文档

## 概述

一个 macOS 菜单栏应用（Menu Bar App），用于管理 `copilot-api` 代理服务。通过 GitHub Copilot 订阅为 Claude Code 提供 API 代理。

## 核心功能

### 1. 菜单栏常驻
- 菜单栏显示一个小图标（建议用 🔌 或自定义 SF Symbol `network`）
- 绿色圆点 = 运行中，红色圆点 = 已停止
- 点击图标弹出菜单

### 2. 菜单内容
```
┌─────────────────────────┐
│ Copilot API Proxy       │
│ ● Running on :4141      │  （或 ○ Stopped）
│─────────────────────────│
│ ▶ Start / ■ Stop        │
│ 🔄 Restart              │
│─────────────────────────│
│ ⚙ Settings...           │
│ 📋 Copy Claude Command  │  → 复制启动 Claude Code 的完整命令到剪贴板
│ 📊 Usage Viewer         │  → 打开浏览器 https://ericc-ch.github.io/copilot-api?endpoint=http://localhost:4141/usage
│ 📄 View Logs            │
│─────────────────────────│
│ Login Status: xuhaoyuan │
│─────────────────────────│
│ Quit                    │
└─────────────────────────┘
```

### 3. Settings 界面
一个简单的设置窗口：

| 设置项 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| Port | 文本框 | 4141 | 代理监听端口 |
| Auto Start | 开关 | ON | 启动 App 时自动开启代理 |
| Launch at Login | 开关 | OFF | 开机自启动 |
| Claude Model | 下拉框 | claude-sonnet-4.6 | 主模型 |
| Small Model | 下拉框 | claude-sonnet-4.6 | 轻量模型 |
| Account Type | 下拉框 | individual | individual / business / enterprise |

### 4. Copy Claude Command
点击后复制以下命令到剪贴板：
```bash
ANTHROPIC_BASE_URL=http://localhost:{port} ANTHROPIC_API_KEY=copilot CLAUDE_MODEL={model} ANTHROPIC_SMALL_FAST_MODEL={smallModel} claude
```
并显示一个系统通知："Command copied to clipboard"

### 5. View Logs
打开一个窗口显示代理的实时日志输出（stdout + stderr），支持滚动和清除。

## 技术实现

### 架构
- **SwiftUI** + **AppKit**（菜单栏部分需要 AppKit）
- 使用 `Process` (Foundation) 管理 `copilot-api` 子进程
- 设置存储用 `UserDefaults` 或 `@AppStorage`

### 进程管理
```swift
// 启动代理
let process = Process()
process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/copilot-api")
process.arguments = ["start", "--port", "\(port)"]
process.environment = [
    "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
]

// 捕获输出用于日志显示
let pipe = Pipe()
process.standardOutput = pipe
process.standardError = pipe
```

### 健康检查
- 每 5 秒 ping 一次 `http://localhost:{port}/` 
- 响应 "Server running" = 健康
- 超时或错误 = 不健康，更新菜单栏图标状态

### 登录状态检查
- 启动时运行 `copilot-api auth --check`（或直接检查 token 文件是否存在）
- 如果未登录，菜单显示 "Not logged in" 并提供 "Login..." 按钮
- Login 按钮执行 `copilot-api auth`，会打开浏览器进行 GitHub OAuth

### Settings 写入
当用户修改 Claude Model 或 Small Model 时，同时更新 `~/.claude/settings.json`：
```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "http://localhost:{port}",
    "ANTHROPIC_API_KEY": "copilot",
    "CLAUDE_MODEL": "{model}",
    "ANTHROPIC_SMALL_FAST_MODEL": "{smallModel}"
  },
  "model": "{model}",
  "smallModel": "{smallModel}"
}
```
注意：保留 settings.json 中已有的其他字段（如 permissions），只合并更新上述字段。

### Launch at Login
使用 `SMAppService.mainApp` (macOS 13+) 或 `LSSharedFileList` 实现开机自启。

## 可用模型列表
从 `copilot-api` 获取，或硬编码常用的：
- claude-opus-4.6
- claude-sonnet-4.6
- gpt-5.4
- gpt-5.3-codex
- gpt-4.1
- gpt-4o

## 依赖
- 需要预先安装 `copilot-api`（npm install -g copilot-api）
- 需要预先完成 `copilot-api auth` 登录
- App 首次启动时检测依赖，缺失则提示用户安装

## 最低系统要求
- macOS 13 Ventura+
- Apple Silicon 或 Intel

## 项目结构建议
```
CopilotProxy/
├── CopilotProxyApp.swift          # App 入口
├── MenuBarView.swift              # 菜单栏 UI
├── SettingsView.swift             # 设置窗口
├── LogView.swift                  # 日志窗口
├── ProxyManager.swift             # 进程管理核心
├── HealthChecker.swift            # 健康检查
├── SettingsStore.swift            # 设置存储
├── ClaudeSettingsManager.swift    # ~/.claude/settings.json 管理
└── Assets.xcassets/               # 图标资源
```
