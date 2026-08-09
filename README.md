# Portless

Manage your local dev services by port: see what's listening, identify the process, and open or stop it — without hunting through the terminal.

> Not a task manager — a local dev tool designed around **ports**.

## Features

- List listening ports (TCP / UDP)
- Inspect PID, process name, full path, command line, working directory
- Copy localhost address · open in browser
- Stop (SIGTERM) / Force kill (SIGKILL)
- Search by port / PID / process name / project
- Auto-refresh every 2 seconds
- Reveal executable in Finder / Explorer
- Favorite ports
- Detect dev processes (Vite / Next / Postgres …)
- Find Port + suggest free ports
- CPU / RAM per process
- DeepSeek AI insight per process

## Requirements

- Rust toolchain (cargo)
- Flutter SDK (desktop)

## Build & Run

### 1. Build the Rust core

```bash
cd <repo>
./scripts/build_agent.sh
# or
cd native && cargo build --release --bins
```

### 2. Run the desktop app

```bash
cd <repo>
flutter pub get
flutter run -d macos
# Windows: flutter run -d windows
```

The app auto-discovers the agent at `native/target/release/portless_agent`. To point at another build:

```bash
export PORTLESS_AGENT=/path/to/portless_agent
```

## AI Insights (DeepSeek)

Select any port → click **AI 解读** to get an analysis of that process (what it is, whether it's safe to stop, what to do next). Results are cached per port for 30 minutes; clear the cache from Settings.

### Configure

Priority from high to low — pick any one:

1. **Environment variables**

   ```bash
   export DEEPSEEK_API_KEY=sk-...
   export DEEPSEEK_MODEL=deepseek-v4-flash
   export DEEPSEEK_BASE_URL=https://api.deepseek.com
   ```

2. **Project-local file `.portless.local.json`** (gitignored — do not commit)

   ```json
   {
     "api_key": "sk-...",
     "base_url": "https://api.deepseek.com",
     "model": "deepseek-v4-flash",
     "thinking": false
   }
   ```

3. **User-level `~/.portless/config.json`** — saved from the Settings dialog.

OpenAI-compatible API: `POST https://api.deepseek.com/chat/completions`

### In the Settings dialog

Click the **Settings** button → **AI 解读** group:

- **模型 (Model)** — model name (default `deepseek-v4-flash`)
- **Base URL** — API endpoint (default `https://api.deepseek.com`)
- **API Key** — show/hide; leave blank to keep using the env var
- **深度思考 (Deep thinking)** — enable reasoning mode (slower, deeper insights)
- **保存 AI 配置 (Save)** — writes `~/.portless/config.json` (highest priority)

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| ⌘K / Ctrl+K | Focus search |
| ⌘F / Ctrl+F | Find Port |
| ⌘R / Ctrl+R | Refresh now |

## CLI Reference

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

## License

MIT — see [LICENSE](LICENSE).
