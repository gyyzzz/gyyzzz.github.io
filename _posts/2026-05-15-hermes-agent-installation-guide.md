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

## 在线安装

### 方式一：官方安装脚本（推荐）

```bash
curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash
```

安装完成后，`hermes`命令即可使用。

### 方式二：Homebrew（macOS）

```bash
brew tap nousresearch/hermes
brew install hermes-agent
```

### 方式三：pip安装

```bash
pip install hermes-agent
```

### 验证安装

```bash
hermes --version
hermes doctor
```

## 离线安装

对于无法访问外网的环境，可以采用以下方式：

### 方式一：下载Release包

1. 从GitHub Releases下载对应平台的压缩包：
   - https://github.com/NousResearch/hermes-agent/releases

2. 解压并配置：

```bash
# Linux/macOS
tar -xzf hermes-agent-*.tar.gz
cd hermes-agent
./install.sh --offline

# Windows
unzip hermes-agent-*.zip
cd hermes-agent
python install.py --offline
```

### 方式二：从源码构建

```bash
# 克隆仓库（可从内部镜像获取）
git clone https://github.com/NousResearch/hermes-agent.git
cd hermes-agent

# 创建虚拟环境
python -m venv venv
source venv/bin/activate  # Linux/macOS
# 或 venv\Scripts\activate  # Windows

# 安装依赖
pip install -r requirements.txt
pip install -e .

# 构建可执行文件（可选）
python scripts/build.py
```

### 方式三：Docker镜像

```bash
# 拉取镜像（可从私有仓库）
docker pull nousresearch/hermes-agent:latest

# 运行
docker run -it \
  -v ~/.hermes:/root/.hermes \
  -v $(pwd):/workspace \
  nousresearch/hermes-agent:latest
```

## 配置API密钥

### 交互式配置

```bash
hermes setup
```

按提示选择提供商并输入API密钥。

### 手动配置

编辑 `~/.hermes/.env` 文件：

```bash
# OpenRouter
OPENROUTER_API_KEY=sk-or-xxx

# Anthropic Claude
ANTHROPIC_API_KEY=sk-ant-xxx

# OpenAI
OPENAI_API_KEY=sk-xxx

# DeepSeek
DEEPSEEK_API_KEY=sk-xxx

# Google Gemini
GOOGLE_API_KEY=xxx

# 本地模型（Ollama）
# 无需API密钥，设置base_url即可
```

编辑 `~/.hermes/config.yaml` 选择默认模型：

```yaml
model:
  default: anthropic/claude-sonnet-4
  provider: openrouter
```

## 基本使用

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

## 实用技巧

### 1. 预加载技能

```bash
hermes -s python-debuggy,web
```

### 2. 继续上次会话

```bash
hermes --continue
# 或指定会话ID
hermes --resume 20260515_091000_abc123
```

### 3. YOLO模式（跳过确认）

```bash
hermes --yolo
```

### 4. 查看使用统计

```bash
hermes insights --days 7
```

## 常见问题

### Q: 如何使用本地Ollama模型？

编辑 `~/.hermes/config.yaml`：

```yaml
model:
  provider: custom
  base_url: http://localhost:11434/v1
  default: llama3
```

### Q: 工具不生效怎么办？

```bash
hermes tools
# 检查工具集是否启用
# 启用后需要 /reset 新建会话
```

### Q: Gateway连接失败？

```bash
# 查看日志
cat ~/.hermes/logs/gateway.log

# 重启Gateway
hermes gateway restart
```

## 总结

Hermes Agent是一个灵活、强大的开源AI代理框架。无论你是开发人员、运维工程师还是研究人员，都可以利用Hermes自动化日常工作。关键优势：

- **开源免费** — 无API调用限制（取决于你选择的提供商）
- **提供商灵活** — 随时切换模型，无需改动工作流
- **持续学习** — 技能系统让代理越来越了解你的需求

下一期将介绍如何编写自定义技能，让Hermes更好地服务于你的特定场景。

---

*参考资料：*
- [Hermes Agent官方文档](https://hermes-agent.nousresearch.com/docs/)
- [GitHub仓库](https://github.com/NousResearch/hermes-agent)
- [Skills Catalog](https://hermes-agent.nousresearch.com/docs/reference/skills-catalog)