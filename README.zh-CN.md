# Portless

按端口管理本机开发服务：查看谁在监听、识别进程、打开或停止——不用再翻终端。

> 不是任务管理器，而是围绕 **端口** 设计的本地开发工具。

## 功能

- 查看监听端口（TCP / UDP）
- 查看 PID、进程名、完整路径、启动参数、工作目录
- 复制 localhost 地址 · 浏览器打开
- 停止（SIGTERM）/ 强制结束（SIGKILL）
- 按端口 / PID / 进程名 / 项目搜索
- 每 2 秒自动刷新
- 在 Finder / 资源管理器中定位程序
- 收藏端口
- 识别开发进程（Vite / Next / Postgres …）
- Find Port + 推荐空闲端口
- 查看 CPU / 内存
- DeepSeek AI 进程解读

## 环境要求

- Rust 工具链（cargo）
- Flutter SDK（桌面端）

## 构建与运行

### 1. 构建 Rust 核心

```bash
cd <仓库目录>
./scripts/build_agent.sh
# 或
cd native && cargo build --release --bins
```

### 2. 运行桌面应用

```bash
cd <仓库目录>
flutter pub get
flutter run -d macos
# Windows: flutter run -d windows
```

应用会自动发现 `native/target/release/portless_agent`。如需指定其他构建：

```bash
export PORTLESS_AGENT=/path/to/portless_agent
```

## AI 进程解读（DeepSeek）

选中任意端口 → 点击 **AI 解读**，分析该进程（是什么、能否安全停止、接下来怎么做）。解读结果按端口缓存 30 分钟；可在设置中清除缓存。

### 配置

优先级从高到低，任选其一：

1. **环境变量**

   ```bash
   export DEEPSEEK_API_KEY=sk-...
   export DEEPSEEK_MODEL=deepseek-v4-flash
   export DEEPSEEK_BASE_URL=https://api.deepseek.com
   ```

2. **项目本地文件 `.portless.local.json`**（已 gitignore，勿提交）

   ```json
   {
     "api_key": "sk-...",
     "base_url": "https://api.deepseek.com",
     "model": "deepseek-v4-flash",
     "thinking": false
   }
   ```

3. **用户级 `~/.portless/config.json`** — 由设置对话框保存。

OpenAI 兼容接口：`POST https://api.deepseek.com/chat/completions`

### 在设置界面配置

点击 **设置** 按钮 → **AI 解读** 分组：

- **模型** — 模型名称（默认 `deepseek-v4-flash`）
- **Base URL** — API 端点（默认 `https://api.deepseek.com`）
- **API Key** — 可显隐；留空则沿用环境变量
- **深度思考** — 启用推理模式（较慢但解读更深入）
- **保存 AI 配置** — 写入 `~/.portless/config.json`（优先级最高）

## 快捷键

| 快捷键 | 动作 |
|--------|------|
| ⌘K / Ctrl+K | 聚焦搜索 |
| ⌘F / Ctrl+F | Find Port |
| ⌘R / Ctrl+R | 立即刷新 |

## 命令行参考

```bash
portless_agent list
portless_agent find --port 3000
portless_agent free --from 3000 --count 5
portless_agent kill --pid 1234
portless_agent kill --pid 1234 --force
portless_agent detail --pid 1234
portless_agent reveal --path /path/to/bin
portless_agent ai-status
portless_agent ping
```

## 许可证

MIT — 见 [LICENSE](LICENSE)。
