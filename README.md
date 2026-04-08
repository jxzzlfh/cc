# Claude Code 一键安装与配置脚本

交互式菜单工具，用于安装、配置、更新和卸载 [Claude Code](https://code.claude.com)。  
参考官方文档: [高级设置](https://code.claude.com/docs/zh-CN/setup)

<img width="578" height="674" alt="image" src="https://github.com/user-attachments/assets/1385d2fb-8f9c-4912-b81b-ae219cb67bc9" />

## 功能一览

| 菜单项 | 说明 |
|--------|------|
| **安装环境依赖** | 自动检测并安装 Node.js、Git，配置 npm 镜像源（中国大陆自动切换淘宝源） |
| **一键安装** | 支持原生安装（推荐）、npm、Homebrew、WinGet 四种方式 |
| **一键配置** | 交互式填写 API Token、代理地址、模型映射，自动生成 `settings.json` 并跳过官方验证 |
| **一键更新** | 智能检测当前安装方式，调用对应更新命令升级到最新版 |
| **一键卸载** | 智能检测安装方式，完整卸载程序并可选清理所有配置/会话残留 |
| **查看当前配置** | 直接查看 `settings.json` 和验证标识文件内容 |
| **npm 迁移原生** | 将已弃用的 npm 安装方式一键迁移到官方原生安装 |
| **运行诊断** | 执行 `claude doctor` 进行环境自检 |
| **设置快捷命令** | 安装 `cc` 命令到 `~/.local/bin/`，之后任意终端输入 `cc` 即可启动面板 |

## 特性

* **跨平台** — Linux (Ubuntu/CentOS/Debian/Alpine/Arch)、macOS、Windows (Git Bash)
* **交互式菜单** — 进入脚本即显示菜单首页，实时展示环境状态
* **智能检测** — 自动识别安装方式（原生/npm/Homebrew/WinGet），更新和卸载自动匹配
* **彻底卸载** — 删除程序本体 + 可选清理 `~/.claude/`、`~/.claude.json`、`cc` 快捷命令、项目级 `.claude/`、`.mcp.json`
* **快捷命令** — 一键安装 `cc` 到 `~/.local/bin/`，下次直接 `cc` 启动面板，支持更新/卸载
* **多安装方式** — 原生安装（推荐，自动更新）、npm、Homebrew、WinGet 任选
* **免密绕过** — 自动生成 `settings.json` 并写入 onboarding 标识，跳过官方账号验证
* **配置纯净** — 所有配置写入 Claude 专属文件，不污染全局环境变量

## 安装要求

* **Linux 云服务器** — 确保网络畅通即可
* **macOS** — 无额外要求
* **Windows** — 需提前安装 [Git for Windows](https://gitforwindows.org/)，在 Git Bash 中运行

## 快速使用

### 方案一：curl（推荐）

```bash
bash <(curl -sL https://cang.zixi.run/claude.sh)
```

### 方案二：wget

```bash
bash <(wget -qO- https://cang.zixi.run/claude.sh)
```

运行后自动进入交互式菜单，按数字键选择功能。

### 设置快捷命令（推荐）

首次运行脚本后，选择菜单中的 **9) 设置快捷命令**，脚本会将自身安装到 `~/.local/bin/cc`。之后在任意终端直接输入：

```bash
cc
```

即可随时启动本面板，无需再记远程地址。

## 配置说明

选择「一键配置」后，按提示输入：

| 参数 | 必填 | 说明 |
|------|------|------|
| `ANTHROPIC_AUTH_TOKEN` | 是 | 第三方 API Key 或服务凭证 |
| `ANTHROPIC_BASE_URL` | 是 | 第三方网关/代理 API 地址 |
| `ANTHROPIC_DEFAULT_OPUS_MODEL` | 否 | Opus 替代模型名 |
| `ANTHROPIC_DEFAULT_SONNET_MODEL` | 否 | Sonnet 替代模型名 |
| `ANTHROPIC_DEFAULT_HAIKU_MODEL` | 否 | Haiku 替代模型名 |
| `CLAUDE_CODE_SUBAGENT_MODEL` | 否 | 子代理替代模型名 |
| `DISABLE_AUTOUPDATER` | 否 | 设为 1 禁用自动更新 |

配置完成后，终端输入 `claude` 即可启动。

## 卸载说明

选择「一键卸载」，脚本会：

1. 自动检测安装方式（原生/npm/Homebrew/WinGet）
2. 调用对应卸载命令删除程序
3. 可选清理所有残留文件：
   - `~/.claude/` — 用户设置、MCP 配置、会话历史
   - `~/.claude.json` — onboarding 标识
   - `~/.local/bin/cc` — 快捷命令
   - `.claude/` — 当前项目的项目级配置
   - `.mcp.json` — 当前项目的 MCP 配置

## 参考

- [Claude Code 官方文档](https://code.claude.com)
- [高级设置 (安装/更新/卸载)](https://code.claude.com/docs/zh-CN/setup)
- [故障排除](https://code.claude.com/zh-CN/troubleshooting)
