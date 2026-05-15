---
title: "Hermes Agent：开源AI代理框架安装与使用指南"
layout: post
category: tutorials
date: 2026-05-15
---

Hermes Agent是Nous Research开源的AI代理框架，可以在终端、消息平台和IDE中运行。与Claude Code、OpenAI Codex类似，Hermes通过工具调用与系统交互，支持20+种LLM提供商（OpenRouter、Anthropic、OpenAI、DeepSeek、本地模型等）。

## Hermes的核心特性

- **技能自学习** — 从经验中积累可复用的技能，越用越聪明
- **跨会话记忆** — 记住你的偏好、环境细节、经验教训
- **多平台Gateway** — 同一代理运行在Telegram、Discord、Slack、微信等10+平台
- **提供商无关** — 中途切换模型/提供商无需其他改动
- **Profiles** — 运行多个独立实例，隔离配置、会话、技能
- **可扩展** — 插件、MCP服务器、自定义工具、Webhook触发、Cron调度

## 快速安装

### Linux / macOS / WSL2

```bash
curl -fsSL https://res1.hermesagent.org.cn/install.sh | bash
```

适合：
- Linux 桌面 / 服务器
- macOS
- Windows + WSL2（推荐给大多数 Windows 用户）

### Windows 原生 PowerShell

```powershell
irm https://res1.hermesagent.org.cn/install.ps1 | iex
```

适合：
- 想先在 Windows 本机快速体验
- 不想先折腾 WSL2 的用户

**PowerShell 直装小白步骤**：

1. 按 Windows 键，输入 `PowerShell`
2. 点击 Windows PowerShell
3. 粘贴命令：`irm https://res1.hermesagent.org.cn/install.ps1 | iex`
4. 等安装完成，关闭当前 PowerShell
5. 重新打开 PowerShell，输入 `hermes`

### Android / Termux

```bash
curl -fsSL https://res1.hermesagent.org.cn/install.sh | bash
```

安装程序会自动检测 Termux 并切换到 Android 流程：
- 优先复用系统已有的 Python
- 自动补齐 Android 构建所需的基础工具链
- 默认跳过浏览器/WhatsApp 等额外 Node 组件

## 手动安装

如果你希望对安装过程拥有完全控制，请遵循以下步骤。

> **注意**：以下命令适用于类 Unix shell（Linux/macOS/WSL2），不适合直接在 PowerShell 中执行。Windows 用户请使用上面的 `install.ps1`。

### 步骤 1：克隆仓库

使用 `--recurse-submodules` 克隆以拉取所需子模块：

```bash
git clone --recurse-submodules https://github.com/NousResearch/hermes-agent.git
cd hermes-agent
```

如果之前没有带 `--recurse-submodules` 克隆：

```bash
git submodule update --init --recursive
```

### 步骤 2：安装 uv 并创建虚拟环境

```bash
# 安装 uv（如果尚未安装）
curl -LsSf https://astral.sh/uv/install.sh | sh

# 使用 Python 3.11 创建虚拟环境（若本机不存在，uv 会自动下载）
uv venv venv --python 3.11
```

> 你无需激活虚拟环境即可使用 hermes。入口点已硬编码指向虚拟环境的 Python，因此一旦创建符号链接，即可全局使用。

### 步骤 3：安装 Python 依赖项

```bash
# 告诉 uv 要安装到哪个虚拟环境
export VIRTUAL_ENV="$(pwd)/venv"

# 安装完整推荐依赖
uv pip install -e ".[all]"
```

如果仅需要核心 Agent（无 Telegram/Discord/cron 支持）：

```bash
uv pip install -e "."
```

### 步骤 4：安装可选子模块（如需）

```bash
# 强化学习训练后端（可选）
uv pip install -e "./tinker-atropos"
```

### 步骤 5：安装 Node.js 依赖项（可选）

仅在需要浏览器自动化和 WhatsApp 桥接时：

```bash
npm install
```

### 步骤 6：创建配置目录

```bash
# 创建目录结构
mkdir -p ~/.hermes/{cron,sessions,logs,memories,skills,pairing,hooks,image_cache,audio_cache,whatsapp/session}

# 复制示例配置文件
cp cli-config.yaml.example ~/.hermes/config.yaml

# 创建用于保存 API 密钥的空 `.env` 文件
touch ~/.hermes/.env
```

### 步骤 7：添加 API 密钥

打开 `~/.hermes/.env` 文件，添加 LLM 提供商的密钥：

```bash
# 必填：至少配置一个大语言模型提供商
OPENROUTER_API_KEY=sk-or-v1-your-key-here

# 可选：启用额外工具能力
FIRECRAWL_API_KEY=fc-your-key          # 网络搜索和抓取
FAL_KEY=your-fal-key                   # 图像生成（FLUX）
```

或通过 CLI 设置：

```bash
hermes config set OPENROUTER_API_KEY sk-or-v1-your-key-here
```

### 步骤 8：将 hermes 添加到 PATH

```bash
mkdir -p ~/.local/bin
ln -sf "$(pwd)/venv/bin/hermes" ~/.local/bin/hermes
```

如果 `~/.local/bin` 不在 PATH 中，添加到 shell 配置：

```bash
# Bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc

# Zsh
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc && source ~/.zshrc

# Fish
fish_add_path $HOME/.local/bin
```

### 步骤 9：配置提供方

```bash
hermes model       # 选择大语言模型提供商和具体模型
```

### 步骤 10：验证安装

```bash
hermes version    # 检查命令是否可用
hermes doctor     # 运行诊断，确认环境工作正常
hermes status     # 检查当前配置
hermes chat -q "你好，告诉我你当前可用的工具。"
```

## 手动安装精简版

适用于只想获取命令的用户：

```bash
# 安装 uv
curl -LsSf https://astral.sh/uv/install.sh | sh

# 克隆仓库并进入目录
git clone --recurse-submodules https://github.com/NousResearch/hermes-agent.git
cd hermes-agent

# 使用 Python 3.11 创建虚拟环境
uv venv venv --python 3.11
export VIRTUAL_ENV="$(pwd)/venv"

# 安装完整依赖
uv pip install -e ".[all]"
uv pip install -e "./tinker-atropos"
npm install  # 可选：浏览器工具和 WhatsApp 桥接需要它

# 准备配置文件
mkdir -p ~/.hermes/{cron,sessions,logs,memories,skills,pairing,hooks,image_cache,audio_cache,whatsapp/session}
cp cli-config.yaml.example ~/.hermes/config.yaml
touch ~/.hermes/.env
echo 'OPENROUTER_API_KEY=sk-or-v1-your-key' >> ~/.hermes/.env

# 让 hermes 成为全局命令
mkdir -p ~/.local/bin
ln -sf "$(pwd)/venv/bin/hermes" ~/.local/bin/hermes

# 验证安装
hermes doctor
hermes
```

## 安装后操作

### 类 Unix / WSL2

```bash
source ~/.bashrc   # 或：source ~/.zshrc
hermes             # 开始聊天
```

### Windows PowerShell

```powershell
# 关闭并重新打开 PowerShell 后再运行
hermes
```

如需重新配置：

```bash
hermes model          # 选择大语言模型提供商和模型
hermes tools          # 配置启用哪些工具
hermes gateway setup  # 设置消息平台
hermes config set     # 单独设置某个配置项
hermes setup          # 或再次运行完整设置向导
```

## 埸本使用

### 启动交互式对话

```bash
hermes
```

### 单次查询

```bash
hermes chat -q "解释一下RAG的工作原理"
```

### 切换模型

```bash
hermes model
# 交互式选择提供商和模型

# 或直接指定
hermes chat -m deepseek/deepseek-chat -q "..."
```

### 指定工具集

```bash
# 只使用web搜索
hermes -t web

# 终端+文件+web
hermes -t terminal,file,web
```

## 常用CLI命令

| 命令 | 说明 |
|------|------|
| `hermes` | 启动交互式对话 |
| `hermes chat -q "问题"` | 单次查询 |
| `hermes setup` | 配置向导 |
| `hermes model` | 切换模型/提供商 |
| `hermes config` | 查看配置 |
| `hermes config edit` | 编辑配置文件 |
| `hermes doctor` | 检查依赖和配置 |
| `hermes tools` | 管理工具集 |
| `hermes skills list` | 列出已安装技能 |
| `hermes skills install ID` | 安装技能 |

## 会话内斜杠命令

在对话中使用 `/` 开头的命令：

| 命令 | 说明 |
|------|------|
| `/help` | 显示帮助 |
| `/new` | 新建会话 |
| `/model` | 切换模型 |
| `/tools` | 管理工具 |
| `/skills` | 搜索安装技能 |
| `/voice on` | 开启语音模式 |
| `/yolo` | 跳过危险命令确认 |
| `/quit` | 退出 |

## Gateway：消息平台集成

将Hermes连接到Telegram、Discord等平台：

```bash
# 配置平台
hermes gateway setup

# 启动Gateway
hermes gateway run

# 安装为后台服务
hermes gateway install
hermes gateway start
```

支持的平台：Telegram、Discord、Slack、微信、钉钉、飞书、Email、SMS等。

## Cron：定时任务

创建定期运行的AI任务：

```bash
# 创建每天9点运行的任务
hermes cron create "0 9 * * *" \
  --prompt "生成每日技术简报" \
  --deliver telegram:你的频道

# 查看任务列表
hermes cron list
```

## Profiles：多实例隔离

创建独立配置的Hermes实例：

```bash
# 创建profile
hermes profile create work

# 使用profile
hermes -p work

# 查看profile列表
hermes profile list
```

## 故障排除

| 问题 | 解决方案 |
|------|----------|
| `hermes: command not found` | 重新加载 shell（`source ~/.bashrc`）或检查 PATH |
| `API key not set` | 运行 `hermes model` 配置，或 `hermes config set OPENROUTER_API_KEY your_key` |
| `hermes 不是内部或外部命令` | 关闭并重新打开 PowerShell；WSL2 用户请重新加载 shell |
| 更新后配置丢失 | 运行 `hermes config check`，然后 `hermes config migrate` |

运行 `hermes doctor` 可获取详细诊断信息。

## 总结

Hermes Agent是一个灵活、强大的开源AI代理框架。无论你是开发人员、运维工程师还是研究人员，都可以利用Hermes自动化日常工作。关键优势：

- **开源免费** — 无API调用限制（取决于你选择的提供商）
- **提供商灵活** — 随时切换模型，无需改动工作流
- **持续学习** — 技能系统让代理越来越了解你的需求
- **中文社区支持** — 国内镜像加速，中文文档完善

下一期将介绍如何编写自定义技能，让Hermes更好地服务于你的特定场景。

---

*参考资料：*
- [Hermes Agent 中文社区](https://hermesagent.org.cn)
- [官方安装文档](https://hermesagent.org.cn/docs/getting-started/installation)
- [GitHub仓库](https://github.com/NousResearch/hermes-agent)