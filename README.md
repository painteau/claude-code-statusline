# 🎨 Claude Code Status Line — Gruvbox Dark

A custom status line for [Claude Code](https://claude.ai/code) using the Gruvbox Dark color scheme with Powerline separators and Nerd Font icons.

```
 …/git/my-project  main   Sonnet 4.6   110k [████░░░░░░] 55%   you@example.com  5h:45% ( 2h30) / 7d:23% ( 4d)  $2.89  45s / 1m23s
```

## 📦 Segments

| # | Content | Color |
|---|---------|-------|
| 1 | Current directory (last 2 path components) | Yellow |
| 2 | Git branch *(if in a repo)* | Orange |
| 3 | Claude model name | Aqua |
| 4 | Context window: gauge icon + used tokens + bar + % *(after first call)* | Blue |
| 5 | claude.ai usage: account email + 5h / 7d limits + time to reset *(optional)* | Purple |
| 6 | Session cost + API duration / total duration *(after first call)* | Dark |

The context bar color changes dynamically:

| Usage | Color |
|-------|-------|
| 0–24% | 🟢 Green |
| 25–49% | 🟡 Yellow |
| 50–74% | 🟠 Orange |
| 75–100% | 🔴 Red |

## ✅ Requirements

- **Nerd Font Mono** — [JetBrainsMono Nerd Font Mono](https://www.nerdfonts.com/font-downloads) recommended
- **bash** — Git Bash on Windows, native on Linux/macOS
- **grep, sed, awk, curl** — included with Git for Windows and most Linux distros
- **`claude` CLI** in PATH — optional, used to detect the active account email

## 🚀 Installation

### 1. Copy the files

```bash
cp statusline.sh ~/.claude/
chmod +x ~/.claude/statusline.sh

# Windows only
cp statusline.bat ~/.claude/
```

### 2. Configure Claude Code

Edit `~/.claude/settings.json` (create if it doesn't exist):

**Linux / macOS:**
```json
{
  "statusLine": {
    "type": "command",
    "command": "/bin/bash /home/youruser/.claude/statusline.sh"
  }
}
```

**Windows (Git Bash):**
```json
{
  "statusLine": {
    "type": "command",
    "command": "C:/Users/YourUser/.claude/statusline.bat"
  }
}
```

> The `.bat` wrapper forces UTF-8 code page (`chcp 65001`) before running bash, which is required for Nerd Font icons to render correctly.
> Update the Git Bash path in `statusline.bat` if it's installed elsewhere.

### 3. Configure your terminal font

In Windows Terminal, VS Code, or your terminal emulator, set the font to a **Nerd Font Mono** variant.

Example for Windows Terminal (`settings.json`):
```json
{
  "font": {
    "face": "JetBrainsMonoNL Nerd Font Mono",
    "size": 11
  }
}
```

> Use the **Mono** variant, not Propo — Propo causes icon misalignment in terminal environments.

---

## 📊 Usage tracking (optional)

The purple segment shows your claude.ai usage against the 5-hour and 7-day limits, along with the time until reset. It requires credentials from your browser session.

### 1. Create the config file

```bash
cp claude-usage.conf.example ~/.claude/claude-usage.conf
```

### 2. Fill in your credentials

Open `~/.claude/claude-usage.conf` and set:

- **`CLAUDE_ORG_ID`** — found in any XHR request to `claude.ai/api/organizations/<id>/...`, or in the `lastActiveOrg` cookie
- **`CLAUDE_SESSION_KEY`** — DevTools → Application → Cookies → `claude.ai` → `sessionKey`
- **`CLAUDE_ACTIVE_ACCOUNT`** — your email, used as fallback when `claude auth status` is unavailable

```bash
CLAUDE_ACTIVE_ACCOUNT="you@example.com"
CLAUDE_ORG_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
CLAUDE_SESSION_KEY="sk-ant-sid02-..."
```

> The session key expires periodically. When the usage segment disappears, renew it from your browser.

### ⚡ Caching

| Cache file | TTL | Purpose |
|-----------|-----|---------|
| `~/.claude/.usage-cache` | 60s | Usage percentages + reset timestamps |
| `~/.claude/.auth-email-cache` | 300s | Active account email |

To force a refresh, delete the cache files:
```bash
rm ~/.claude/.usage-cache* ~/.claude/.auth-email-cache*
```

---

## 🔧 Troubleshooting

### Icons not showing (squares or question marks)

Install a Nerd Font and set it as your terminal font. Use the **Mono** variant.

### Icons look correct but are misaligned

Switch from the Propo variant to the **Mono** variant of your Nerd Font.

### `bash` resolves to WSL instead of Git Bash (Windows)

The `.bat` wrapper uses the full path `C:\Program Files\Git\bin\bash.exe`. Update it to match your Git installation.

### Usage segment never appears

1. Check that `~/.claude/claude-usage.conf` exists and has valid values
2. Test the API call manually:
   ```bash
   source ~/.claude/claude-usage.conf
   curl -s -H "Cookie: sessionKey=$CLAUDE_SESSION_KEY" \
     "https://claude.ai/api/organizations/$CLAUDE_ORG_ID/usage"
   ```
3. If you get a 401, your session key has expired — renew it from your browser

### Status line shows nothing

Run the script manually to check for errors:
```bash
echo '{"cwd":"/home/user/project"}' | bash ~/.claude/statusline.sh
```

---

## 🔍 How it works

Claude Code calls the status line command on every UI update (tool calls, streaming tokens, state changes). The script reads a JSON object from stdin containing session data, parses it with `grep`/`sed`/`awk` (no `jq` dependency), and outputs ANSI-colored text.

### JSON input fields used

```json
{
  "cwd": "/path/to/project",
  "model": { "display_name": "Sonnet 4.6" },
  "context_window": {
    "context_window_size": 200000,
    "used_percentage": 55
  },
  "cost": {
    "total_cost_usd": 2.89,
    "total_duration_ms": 83000,
    "total_api_duration_ms": 61000
  }
}
```

> `used_percentage × context_window_size / 100` gives the actual token count, since `input_tokens` in the JSON reflects only the last message.

### No `jq` dependency

The script intentionally avoids `jq` since Claude Code runs commands with a minimal PATH where `jq` may not be available. All JSON parsing is done with `grep` and `sed`.

---

## 📄 License

MIT — see [LICENSE](LICENSE)
