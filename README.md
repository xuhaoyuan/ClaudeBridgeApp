# ClaudeBridgeApp
macOS 菜单栏应用，管理 copilot-api 代理服务。通过 GitHub Copilot 订阅为 Claude Code 提供 API 代理。
## Features
- 菜单栏常驻，一键 Start/Stop/Restart 代理
- GitHub Copilot 登录/登出（Device Flow）
- 动态获取可用模型列表
- 自动写入 ~/.claude/settings.json
- 实时日志查看
- 用量查看（Usage Viewer）
- 开机自启动
## Requirements
- macOS 13+
- [copilot-api](https://github.com/ericc-ch/copilot-api): `npm install -g copilot-api`

