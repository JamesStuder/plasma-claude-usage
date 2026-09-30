# plasma-claude-usage

A KDE Plasma 6 system-tray widget that shows where you stand on your **Claude Code**
plan: how much of each limit is used, when it resets, whether you're on pace to run out,
and how many tokens you used today and this week.

- **Badge** on the tray icon: current 5-hour session usage in percent, coloured by your
  highest limit (green, orange from 70 %, red from 90 %).
- **Left click** opens the panel:
  - **Limits** — every limit on your plan (session, weekly, per-model weekly limits),
    with a meter and the time until it resets
  - **Pace** — a straight-line projection: "on pace for 62 % by reset", or the time you'd
    hit 100 % if that's before the reset
  - **Tokens by day** — the last 7 days, today in bold
  - **Tokens by model** — today's tokens per model, with the input / output / cache split
  - **Model** — optional buttons that switch the model of a Claude Code session running
    in tmux
  - **Refresh**, **Restart** (tmux only), **Open Claude Code**, **Usage on claude.ai**
- **Right click** opens Claude Code.
- **Hover** for a short summary.

There's also a terminal view: `claude-usage --text`

```
Session (5 h)           15%  resets 6:00 PM (in 3h 55m)  — on pace for 70% by reset
Weekly · all models     65%  resets 4:00 PM (in 1h 55m)  — on pace for 66% by reset
Today: 131.6M tokens (385.6k output)
```

## Requirements

- KDE Plasma 6
- Python 3.11+
- Claude Code, signed in with a Claude subscription (Pro / Max / Team) — the limits
  come from your Claude Code login
- Optional: `tmux` for the model and restart buttons, `notify-send` for their confirmations

## Install

```sh
git clone https://github.com/JamesStuder/plasma-claude-usage
cd plasma-claude-usage
./install.sh
```

Then right-click the system tray arrow → **Configure System Tray** → **Entries** →
**Claude Code Usage** → *Always shown*.

**Panel height:** the system tray gives every popup the same size. If the panel scrolls,
drag the popup's top edge to make it taller (Plasma remembers it); about 800 px fits
everything.

Remove with `./uninstall.sh`.

## Configure

`~/.config/claude-usage/config.toml` (created from
[`config.example.toml`](config.example.toml)):

| Key | Default | What it does |
|---|---|---|
| `open_command` | `konsole -e claude` | What right click / *Open Claude Code* runs |
| `tmux_target` | *(empty)* | e.g. `-L claude -t claude` — tmux socket and pane of your Claude Code session; enables the **Model** and **Restart** buttons |
| `claude_command` | `claude` | What **Restart** starts in the pane (with `--resume <session id>`) |
| `models` | current models | The model buttons: `[label, model id]` pairs |

`CLAUDE_CONFIG_DIR` is honoured if you keep Claude Code's files somewhere other than
`~/.claude`.

## How it works

- **Limits** come from the same endpoint Claude Code's own `/usage` command uses, called
  with Claude Code's existing login (read from its credentials file) at most every
  5 minutes and cached in `~/.cache/claude-usage/`. The login is only read, never
  refreshed, so the widget can't interfere with Claude Code. If the token has expired
  the panel keeps showing the last numbers and says so, until Claude Code renews it.
  This endpoint isn't a documented public API and could change.
- **Tokens** are added up from Claude Code's local session logs
  (`~/.claude/projects/**/*.jsonl`), de-duplicated per message and grouped by local day.
  Totals include cached input, which is usually the largest part.
- **Pace** assumes you keep using the plan at the same average rate for the rest of the
  window.
- **Model buttons** type `/model <id>` into the tmux pane you configured. Use them when
  Claude Code's input box is empty.
- **Restart** ends the Claude Code in that tmux pane and starts it again with
  `--resume <session id>`, so the same conversation continues — handy after an update or
  a settings change that needs a restart. The session id comes from Claude Code's
  `~/.claude/sessions/<pid>.json`; if none is found it starts a fresh session.

Nothing is sent anywhere except the usage request to the same Anthropic endpoint Claude
Code itself uses.

## License

MIT. Not affiliated with or endorsed by Anthropic; "Claude" and "Claude Code" are
trademarks of Anthropic.
