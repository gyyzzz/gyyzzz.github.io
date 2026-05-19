---
layout: post
title: "MCP（Model Context Protocol）理论与实践"
date: 2025-04-25
categories: [paper-reading]
tags: [MCP, AI, Agent, ClickHouse, Python]
author: g66x
---

> **本文从CSDN迁移至此**  
> 原文链接: [https://blog.csdn.net/weixin_42697921/article/details/147505261](https://blog.csdn.net/weixin_42697921/article/details/147505261)  
> 迁移时间: 2025-05-19  
> 由 [Hermes Agent](https://github.com/nousresearch/hermes-agent) 协助迁移

---

# MCP

本文主要记录了在学习MCP （Model Context Protocol，模型上下文协议）过程中的相关知识，并用python实现了一个调用deepseek-v3的mcp-client。

## 介绍

### 什么是MCP？

MCP 起源于 2024 年 11 月 25 日 [Anthropic](https://zhida.zhihu.com/search?content_id=254822599&content_type=Article&match_order=1&q=Anthropic&zhida_source=entity) 发布的文章：[Introducing the Model Context Protocol](https://link.zhihu.com/?target=https%3A//www.anthropic.com/news/model-context-protocol)。

 MCP （Model Context Protocol，模型上下文协议）定义了应用程序和 AI 模型之间交换上下文信息的方式。这使得开发者能够**以一致的方式将各种数据源、工具和功能连接到 AI 模型**（一个中间协议层），就像 USB-C 让不同设备能够通过相同的接口连接一样。MCP 的目标是创建一个通用标准，使 AI 应用程序的开发和集成变得更加简单和统一。

**官方架构图：**
![](/images/mcp/image-20250425093552054.png)
MCP的核心组件一般有MCP host、MCP clients、MCP server，下图很好的形容了mcp组件间的关系：

![v2-3a242914e1f4958e631dd158e043b7c3_1440w](/images/mcp/v2-3a242914e1f4958e631dd158e043b7c3_1440w.jpg)


- **MCP hosts**：如 Claude Desktop, IDEs, or AI tools 等应用程序

- **MCP clients**：与服务器保持 1:1 连接的协议客户端，图中为client.py， 只不过Claude Desktop也内置集成了mcp-client的能力

- **MCP**：MCP在图中表示为连接笔记本电脑的扩展坞，作为中间协议层，提供了标准的接口供client连接不同的mcp-server。

- **MCP** **server**：如左下角的gmail，或右下角的访达图标，实际上是一个轻量级程序，每个程序都通过标准化模型上下文协议公开特定功能,如mcp-gmail作为服务端运行时，可能公开提供获取邮件列表、查询邮件的能力或工具。

- **Remote service:**远程服务,MCP 服务器可以通过互联网（例如通过 API）连接到的外部系统，例如gmial服务器

- **Local data sources:**本地数据源,MCP 服务器可以安全访问的您计算机上的文件、数据库和服务，例如如文件系统



**让我们通过一个实际场景来理解这些组件如何协同工作：**

假设你正在使用 Claude Desktop (Host) 询问："我桌面上有哪些文档？"

1. **Host**：Claude Desktop 作为 Host，负责接收你的提问并与 Claude 模型交互。
2. **Client**：当 Claude 模型决定需要访问你的文件系统时，Host 中内置的 MCP Client 会被激活。这个 Client 负责与适当的 MCP Server 建立连接。
3. **Server**：在这个例子中，文件系统 MCP Server 会被调用。它负责执行实际的文件扫描操作，访问你的桌面目录，并返回找到的文档列表。

整个流程是这样的：你的问题 → Claude Desktop(Host) → Claude 模型 → 需要文件信息 → MCP Client 连接 → 文件系统 MCP Server → 执行操作 → 返回结果 → Claude 生成回答 → 显示在 Claude Desktop 上。

### why MCP？（Function Calling 和 MCP）

**大模型进化为智能体agent的关键是能调用外部工具**，Function Calling是openai于2023年6月首次提出的技术方案，通过创建一个外部函数作为中介，大模型通过调用外部函数和外部工具进行交互，从而使大模型拥有调用外部工具的能力。

![image-20250424233333481](/images/mcp/image-20250424233333481.png)


以下内容提取自视频：

😫 智能体开发痛点
但目前通用的借助function calling方法实现外部工具调用存在开发难度高的问题。编写外部函数工作量大，一个简单的外部函数可能上百行代码，还要为每个外部函数编写功能说明和设计提示词模板，像manus处理任务需调用几十个外部工具，编写对应外部函数工作量巨大。

💡 MCP解决方案
本质就是统一Function calling的运行规范、统一mcp客户端和服务器的运行规范,且要求mcp客户端和服务端间按照既定的提示词模版通信。避免了mcp-server（外部函数）的重复开发。

提供SDK：提供一整套MCP客户端服务器开发的SDK，支持Python、tapscript和Java等多种开发语言。借助SDK几行代码就能快速开发MCP服务器，可接入任意MCP客户端构建智能体。

![image-20250424232542236](/images/mcp/image-20250424232542236.png)


参考链接： https://www.bilibili.com/video/BV1uXQzYaEpJ/?share_source=copy_web&vd_source=6ecbe9c068eb72567e4c32361d4a4b34

https://zhuanlan.zhihu.com/p/29001189476

## Mcp开发实践

了解了上面的内容后，我们下面看如何实现一个调用deepseek-api查询clickhouse数据库的场景。

### 工具安装

首先安装uv（uv是一个用 Rust 编写的极快的 Python 包和项目管理器）

执行以下命令安装：

```
#macos或linux
curl -LsSf https://astral.sh/uv/install.sh | sh
#windows
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
```

更多信息参考官方文档：https://docs.astral.sh/uv/

### Mcp-server

mcp-server开发教程：https://modelcontextprotocol.io/quickstart/server

mcp-server案例:https://github.com/punkpeye/awesome-mcp-servers

在MCP协议出现后，互联网上出现了大量的通用mcp-server，除了特殊需求需要定制开发以外，一般都可以找到对应功能的mcp-server，clickhouse官方也提供了clickhouse的mcp-server，能够满足我们的需求。

项目地址：https://github.com/ClickHouse/mcp-clickhouse

mcp-clickhouse实现了的主要功能：

1. 使用FastMCP框架创建一个服务器，提供三个主要工具(API端点)：
   - `list_databases()`: 列出所有可用的ClickHouse数据库
   - `list_tables()`: 列出指定数据库中的所有表，包括它们的模式、注释、行数和列数
   - `run_select_query()`: 在ClickHouse数据库中执行SELECT查询
2. 一些辅助函数：
   - `create_clickhouse_client()`: 创建与ClickHouse的连接
   - `get_readonly_setting()`: 确保查询以只读模式运行，防止数据修改
   - `execute_query()`: 执行查询并格式化结果
3. 配置了线程池执行器来处理异步查询，并设置了30秒的查询超时时间

### MCP-client

我们一般不需要单独开发MCP-client，像claude，curosr等桌面应用都内置了client能力

还有一些开源的client：https://github.com/punkpeye/awesome-mcp-clients

#### Claude Desktop

下面演示通过Claude Desktop连接mcp-clickhouse服务

1. 打开位于以下位置的 Claude Desktop 配置文件：
   - 在 macOS 上：`~/Library/Application Support/Claude/claude_desktop_config.json`
   - 在 Windows 上：`%APPDATA%/Claude/claude_desktop_config.json`
2. 添加以下内容：

```
{
  "mcpServers": {
    "mcp-clickhouse": {
      "command": "uv",
      "args": [
        "run",
        "--with",
        "mcp-clickhouse",
        "--python",
        "3.13",
        "mcp-clickhouse"
      ],
      "env": {
        "CLICKHOUSE_HOST": "<clickhouse-host>",
        "CLICKHOUSE_PORT": "<clickhouse-port>",
        "CLICKHOUSE_USER": "<clickhouse-user>",
        "CLICKHOUSE_PASSWORD": "<your-password>",
        "CLICKHOUSE_SECURE": "true",
        "CLICKHOUSE_VERIFY": "true",
        "CLICKHOUSE_CONNECT_TIMEOUT": "30",
        "CLICKHOUSE_SEND_RECEIVE_TIMEOUT": "30"
      }
    }
  }
```

重启 Claude Desktop，如果配置正确，会出现锤头图标，点击后能列出mcp可用工具。
![image-20250425111359440](/images/mcp/image-20250425111359440.png)

![image-20250425111536937](/images/mcp/image-20250425111536937.png)

测试

![image-20250425112035132](/images/mcp/image-20250425112035132.png)




#### MCP-client代码实现

mcp-server开发教程：https://modelcontextprotocol.io/quickstart/client

假设需要自己定制一个client，以下通过代码实现了一个使用deepseek API的mcp-client

##### 代码解释

完整代码可[在此获取](https://github.com/gyyzzz/mcp_client_by_openai)

代码主要由以下部分组成：

```python
import asyncio
from typing import Optional
from contextlib import AsyncExitStack
import json

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

from openai import OpenAI
import os
from dotenv import load_dotenv

load_dotenv()  # load environment variables from .env

class MCPClient:
    def __init__(self, config_path: str = "config.json"):
        """初始化 MCP 客户端"""
        self.exit_stack = AsyncExitStack()
        self.config_path = config_path
        self.config = self.load_config()
        # 从环境变量读取配置
        self.openai_api_key = os.getenv("OPENAI_API_KEY")  # 读取 OpenAI API Key
        self.base_url = os.getenv("BASE_URL")  # 读取 BASE URL
        self.model = os.getenv("MODEL")  # 读取模型名称

        if not self.openai_api_key:
            raise ValueError("❌ 未找到 OpenAI API Key，请在 .env 文件中设置 OPENAI_API_KEY")

        # 初始化 OpenAI 客户端
        self.client = OpenAI(api_key=self.openai_api_key, base_url=self.base_url)
        self.session: Optional[ClientSession] = None
    def load_config(self):
        """加载 JSON 配置文件"""
        try:
            with open(self.config_path, 'r') as f:
                config = json.load(f)
            return config
        except FileNotFoundError:
            raise FileNotFoundError(f"❌ 配置文件 {self.config_path} 未找到")
        except json.JSONDecodeError:
            raise ValueError(f"❌ 配置文件 {self.config_path} 格式错误")
```

> [!NOTE]
>
> MCPClient核心类，负责加载配置、连接 MCP 服务器、处理用户查询以及清理资源。

```
    def load_config(self):
        """加载 JSON 配置文件"""
        try:
            with open(self.config_path, 'r') as f:
                config = json.load(f)
            return config
        except FileNotFoundError:
            raise FileNotFoundError(f"❌ 配置文件 {self.config_path} 未找到")
        except json.JSONDecodeError:
            raise ValueError(f"❌ 配置文件 {self.config_path} 格式错误")
        
    def get_server_name_and_config(self):
        """自动获取服务器名称和配置"""
        try:
            mcp_servers = self.config.get("mcpServers", {})
            if not mcp_servers:
                raise ValueError("❌ 配置文件中未找到 MCP 服务器配置")
            server_name, server_config = next(iter(self.config["mcpServers"].items()))
            return server_name, server_config
        except Exception as e:
            raise ValueError(f"❌ 获取服务器名称和配置失败: {str(e)}")
```

> [!NOTE]
>
> 服务端配置处理、

```
async def connect_to_server(self, server_name: str = "mcp-clickhouse"):
    """连接到 MCP 服务器"""
    server_name, server_config = self.get_server_name_and_config()
    print(f"Connecting to server: {server_name}")

    command = server_config.get("command")
    args = server_config.get("args", [])
    env = server_config.get("env", {})
    print("Server Command:", command)
    print("Server Args:", args)
    print("Server Env:", env)

    server_params = StdioServerParameters(
        command=command,
        args=args,
        env=env
    )

    stdio_transport = await self.exit_stack.enter_async_context(stdio_client(server_params))
    self.stdio, self.write = stdio_transport
    self.session = await self.exit_stack.enter_async_context(ClientSession(self.stdio, self.write))

    await self.session.initialize()

    response = await self.session.list_tools()
    tools = response.tools
    print("\nConnected to server with tools:", [tool.name for tool in tools])
```

> [!NOTE]
>
> 与服务器建立连接

```
async def process_query(self, query: str) -> str:
    """处理用户查询并调用 MCP 工具"""
    messages = [{"role": "user", "content": query}]
    response = await self.session.list_tools()
    available_tools = [{
        "type": "function",
        "function": {
            "name": tool.name,
            "description": tool.description,
            "input_schema": tool.inputSchema
        }
    } for tool in response.tools]

    response = self.client.chat.completions.create(
        model=self.model,
        messages=messages,
        tools=available_tools
    )

    content = response.choices[0]
    if content.finish_reason == "tool_calls":
        tool_call = content.message.tool_calls[0]
        tool_name = tool_call.function.name
        tool_args = json.loads(tool_call.function.arguments)
        result = await self.session.call_tool(tool_name, tool_args)
        messages.append(content.message.model_dump())
        messages.append({
            "role": "tool",
            "content": result.content[0].text,
            "tool_call_id": tool_call.id,
        })
        response = self.client.chat.completions.create(
            model=self.model,
            messages=messages,
        )
        return response.choices[0].message.content

    return content.message.content
```

> [!NOTE]
>
> 处理用户输入，判断是否调用工具

```
    async def chat_loop(self):
        """Run an interactive chat loop"""
        print("\nMCP Client Started!")
        print("Type your queries or 'quit' to exit.")

        while True:
            try:
                query = input("\nQuery: ").strip()

                if query.lower() == 'quit':
                    break

                response = await self.process_query(query)
                print("\n" + response)

            except Exception as e:
                print(f"\nError: {str(e)}")
```

> [!NOTE]
>
> 提供一个命令行界面，用户可以输入查询并获取响应。

```
async def cleanup(self):
  """清理资源"""
  await self.exit_stack.aclose()
```

> [!NOTE]
>
> 关闭所有异步上下文，释放资源。

```
async def main():
    client = MCPClient()
    try:
        await client.connect_to_server()
        await client.chat_loop()
    finally:
        await client.cleanup()

if __name__ == "__main__":
    asyncio.run(main())

```

> [!NOTE]
>
> 主函数，创建 MCPClient 实例，连接到服务器并启动聊天循环

config.json文件存储 MCP 服务器的配置信息，包括命令、参数和环境变量。

这段代码实现了一个功能完整的 MCP 客户端，支持动态加载配置、连接服务器、调用工具和交互式聊天，适合需要结合 OpenAI API 和 MCP 工具的场景。

##### 快速使用

执行以下内容：

```
uv init MCP_client_by_openai
cd MCP_client_by_openai
uv venv
source .venv/bin/activate

uv add mcp openai
```

复制以上代码到项目文件夹

创建.env文件加载OPENAI_API_KEY、BASE_URL、MODEL等环境变量，例如：

```
❯ cat .env
OPENAI_API_KEY=<your-api-key>
BASE_URL="https://api.deepseek.com"
MODEL="deepseek-chat"
```

**注意：**请将.evn加入.gitignore

mcp_server运行配置

通过config.json执行运行的mcp服务端启动命令参数及环境变量

```
❯ cat config.json.example
{
  "mcpServers": {
    "mcp-clickhouse": {
      "command": "uv",
      "args": [
        "run",
        "--with",
        "mcp-clickhouse",
        "--python",
        "3.13",
        "mcp-clickhouse"
      ],
      "env": {
        "CLICKHOUSE_HOST": "<clickhouse-host>",
        "CLICKHOUSE_PORT": "<clickhouse-port>",
        "CLICKHOUSE_USER": "<clickhouse-user>",
        "CLICKHOUSE_PASSWORD": "<your-password>",
        "CLICKHOUSE_SECURE": "true",
        "CLICKHOUSE_VERIFY": "true",
        "CLICKHOUSE_CONNECT_TIMEOUT": "30",
        "CLICKHOUSE_SEND_RECEIVE_TIMEOUT": "30"
      }
    }
  }
}
```

**注意**：请将config.json加入.gitignore

配置好以上信息后执行

```
uv run main.py
```
![image-20250425115114968](/images/mcp/image-20250425115114968.png)

### Chainit

Chainlit 是一个开源 Python 包，用于构建可用于生产的会话式 AI，主要特点：

1. [快速构建：](https://docs.chainlit.io/examples/openai-sql)只需几行 Python 代码即可开始
2. [身份验证：](https://docs.chainlit.io/authentication/overview)与企业身份提供商和现有身份验证基础设施集成
3. [数据持久性：](https://docs.chainlit.io/data-persistence/overview)收集、监控和分析用户数据
4. [可视化多步骤推理：](https://docs.chainlit.io/concepts/step)一眼就能了解产生输出的中间步骤
5. [多平台：](https://docs.chainlit.io/deploy/overview)编写一次助手逻辑，随处使用

下面尝试基于这个模块，开发一个mcp-client。

~~~python
import os
from typing import Dict, Any, List

from openai import AsyncOpenAI

from mcp import ClientSession
from mcp.types import CallToolResult, TextContent

import chainlit as cl

client = AsyncOpenAI(
    api_key=os.getenv("YOUR_API_KEY"), base_url="https://api.deepseek.com"
)

cl.instrument_openai()

settings = {
    "model": "deepseek-chat",
    "temperature": 0.7,
    "stream": True,
}

mcp_tools_cache = {}

@cl.on_chat_start
async def start():
    cl.user_session.set(
        "message_history",
        [
            {
                "role": "system",
		        "content": """
                    你是一个专业的ClickHouse数据库专家助手，专注于高效查询和分析maintaindata数据库中的主机信息数据。以下是你的核心能力和工作规范：

                    ## 已知数据结构
                    你已掌握maintaindata.klbase_host表的完整结构：
                    ```sql
                    TABLE maintaindata.klbase_host (
                        `datetime` DateTime COMMENT '时间戳，记录数据采集时间',
                        `cluster_name` String COMMENT '集群名称，标识主机所属集群',
                        `host_name` String COMMENT '主机名称，唯一标识符',
                        `cpu_spec` String COMMENT 'CPU规格信息，包括型号和核心数',
                        `memory_spec` String COMMENT '内存规格，总容量信息',
                        `disk_spec` String COMMENT '磁盘规格，包括类型和总容量',
                        `system_version` String COMMENT '操作系统版本详细信息',
                        `account` String COMMENT '主机管理账户信息',
                        `host_type` String COMMENT '主机类型(物理机/虚拟机/容器等)',
                        `serial_number` String COMMENT '设备序列号'
                    )
                    你已掌握maintaindata.klbase_outerconnect表的完整结构：
                    TABLE maintaindata.klbase_outerconnect
                    (
                        `datetime` DateTime COMMENT '时间',
                        `platform` String COMMENT '平台',
                        `connect_name` String COMMENT '外部连接名称',
                        `connect_address` String COMMENT '连接地址'
                    )


                    

                    你的工作流程应该是：
                    1. 首先了解用户的数据需求
                    2. 结合已知的表结构分析用户的查询意图
                    3. 构建合适的ClickHouse SQL查询
                    4. 执行查询并返回格式化的结果
                    5. 解释查询结果并提供分析建议

                """,
	    }
        ],
    )

    await cl.Message(
        content=f"你好! 我是一个基于{settings['model']}的小助手,可以提供数据查询的能力。"
    ).send()

#连接mcp服务，列出可用工具
@cl.on_mcp_connect
async def on_mcp_connect(connection, session: ClientSession):
    await cl.Message(f"Connected to MCP server: {connection.name}").send()

    try:
        result = await session.list_tools()
        tools = [
            {
                "name": t.name,
                "description": t.description,
                "input_schema": t.inputSchema,
            }
            for t in result.tools
        ]

        mcp_tools_cache[connection.name] = tools

        mcp_tools = cl.user_session.get("mcp_tools", {})
        mcp_tools[connection.name] = tools
        cl.user_session.set("mcp_tools", mcp_tools)

        await cl.Message(
            f"Found {len(tools)} tools from {connection.name} MCP server."
        ).send()
    except Exception as e:
        await cl.Message(f"Error listing tools from MCP server: {str(e)}").send()

@cl.on_mcp_disconnect
async def on_mcp_disconnect(name: str, session: ClientSession):
    if name in mcp_tools_cache:
        del mcp_tools_cache[name]

    mcp_tools = cl.user_session.get("mcp_tools", {})
    if name in mcp_tools:
        del mcp_tools[name]
        cl.user_session.set("mcp_tools", mcp_tools)

    await cl.Message(f"Disconnected from MCP server: {name}").send()


@cl.step(type="tool")
async def execute_tool(tool_name: str, tool_input: Dict[str, Any]):
    print("Executing tool:", tool_name)
    print("Tool input:", tool_input)
    mcp_name = None
    mcp_tools = cl.user_session.get("mcp_tools", {})

    for conn_name, tools in mcp_tools.items():
        if any(tool["name"] == tool_name for tool in tools):
            mcp_name = conn_name
            break

    if not mcp_name:
        return {"error": f"Tool '{tool_name}' not found in any connected MCP server"}

     # mcp_sessions 中取出名为 mcp_name 的会话，并把它解包成两个部分，只关心第一部分 mcp_session。
    mcp_session, _ = cl.context.session.mcp_sessions.get(mcp_name)

    try:
        result = await mcp_session.call_tool(tool_name, tool_input)
        return result
    except Exception as e:
        return {"error": f"Error calling tool '{tool_name}': {str(e)}"}
    
async def format_tools_for_openai(tools: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    openai_tools = []

    for tool in tools:
        openai_tool = {
            "type": "function",
            "function": {
                "name": tool["name"],
                "description": tool["description"],
                "parameters": tool["input_schema"],
            },
        }
        openai_tools.append(openai_tool)

    return openai_tools


def format_calltoolresult_content(result):
    """Extract text content from a CallToolResult object.

    The MCP CallToolResult contains a list of content items,
    where we want to extract text from TextContent type items.
    """
    text_contents = []

    if isinstance(result, CallToolResult):
        for content_item in result.content:
            # This script only supports TextContent but you can implement other CallToolResult types
            if isinstance(content_item, TextContent):
                text_contents.append(content_item.text)

    if text_contents:
        return "\n".join(text_contents)
    return str(result)



@cl.on_message
async def on_message(message: cl.Message):
    message_history = cl.user_session.get("message_history", [])
    message_history.append({"role": "user", "content": message.content})

    try:
        # Initial message for the first assistant response
        initial_msg = cl.Message(content="")
        await initial_msg.send()

        mcp_tools = cl.user_session.get("mcp_tools", {})
        all_tools = []
        for connection_tools in mcp_tools.values():
            all_tools.extend(connection_tools)

        chat_params = {**settings}
        if all_tools:
            openai_tools = await format_tools_for_openai(all_tools)
            chat_params["tools"] = openai_tools
            chat_params["tool_choice"] = "auto"
            print("Tools passed:", openai_tools)
        stream = await client.chat.completions.create(
            messages=message_history, **chat_params
        )

        initial_response = ""
        tool_calls = []

        async for chunk in stream:
            delta = chunk.choices[0].delta
            print(delta)

            if token := delta.content or "":
                initial_response += token
                await initial_msg.stream_token(token)

            if delta.tool_calls:
                for tool_call in delta.tool_calls:
                    tc_id = tool_call.index
                    if tc_id >= len(tool_calls):
                        tool_calls.append({"name": "", "arguments": ""})

                    if tool_call.function.name:
                        tool_calls[tc_id]["name"] = tool_call.function.name

                    if tool_call.function.arguments:
                        tool_calls[tc_id]["arguments"] += tool_call.function.arguments

        # First, update message history with the initial response
        if initial_response.strip():
            message_history.append({"role": "assistant", "content": initial_response})

        # Process tool calls if any
        if tool_calls:
            for tool_call in tool_calls:
                tool_name = tool_call["name"]
                try:
                    import json

                    tool_args = json.loads(tool_call["arguments"])

                    # Add the tool call to message history
                    message_history.append(
                        {
                            "role": "assistant",
                            "content": None,
                            "tool_calls": [
                                {
                                    "id": f"call_{len(message_history)}",
                                    "type": "function",
                                    "function": {
                                        "name": tool_name,
                                        "arguments": tool_call["arguments"],
                                    },
                                }
                            ],
                        }
                    )

                    # Execute the tool in a step
                    with cl.Step(name=f"Executing tool: {tool_name}", type="tool"):
                        tool_result = await execute_tool(tool_name, tool_args)

                    # Format the tool result content
                    tool_result_content = format_calltoolresult_content(tool_result)

                    # Display the tool result to the user
                    tool_result_msg = cl.Message(
                        content=f"Tool Result from {tool_name}:\n{tool_result_content}",
                        author="Tool",
                    )
                    await tool_result_msg.send()

                    # Add the tool result to message history
                    message_history.append(
                        {
                            "role": "tool",
                            "tool_call_id": f"call_{len(message_history)-1}",
                            "content": tool_result_content,
                        }
                    )

                    # Create a new message for the follow-up response
                    follow_up_msg = cl.Message(content="")
                    await follow_up_msg.send()

                    # Stream the follow-up response
                    follow_up_stream = await client.chat.completions.create(
                        messages=message_history, **settings
                    )

                    follow_up_text = ""
                    async for chunk in follow_up_stream:
                        if token := chunk.choices[0].delta.content or "":
                            follow_up_text += token
                            await follow_up_msg.stream_token(token)

                    # Add the follow-up response to message history
                    message_history.append(
                        {"role": "assistant", "content": follow_up_text}
                    )

                except Exception as e:
                    error_msg = f"Error executing tool {tool_name}: {str(e)}"
                    error_message = cl.Message(content=error_msg)
                    await error_message.send()

        # Update the session message history
        cl.user_session.set("message_history", message_history)

    except Exception as e:
        error_message = f"Error: {str(e)}"
        await cl.Message(content=error_message).send()

        troubleshooting = (
            "Troubleshooting tips:\n"
            "1.在此提供解决问题的建议。\n"
        )
        await cl.Message(content=troubleshooting).send()


if __name__ == "__main__":
    print("Starting Chainlit app...")


~~~



### Anythingllm

anythingllm中使用mcp,不好使





### mcp查询clickhouse知识库







```

  
  docker mcp server run clickhouse \
	mcp/clickhouse:latest \
  --env CLICKHOUSE_HOST=<your-clickhouse-host> \
  --env CLICKHOUSE_PORT=<your-clickhouse-port> \
  --env CLICKHOUSE_USER=default \
  --env CLICKHOUSE_PASSWORD=<your-password> \
  --env CLICKHOUSE_DATABASE=maintaindata \
  --env CLICKHOUSE_SECURE=false \
  --env CLICKHOUSE_MCP_QUERY_TIMEOUT=30
  

```

