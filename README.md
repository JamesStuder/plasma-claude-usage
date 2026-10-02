# plasma-claude-usage

A KDE Plasma 6 panel widget for **Claude Code**: your background sessions (which ones
need input, which are done) and where you stand on your plan — how much of each limit is
used, when it resets, whether you're on pace to run out, and how many tokens you used
today and this week.

- **Badges** on the icon: current 5-hour session usage in percent, coloured by your
  highest limit (green, orange from 70 %, red from 90 %), and the number of background
  sessions waiting for input.
- **Left click** opens the panel. The left column lists your background sessions:
  - **Needs input**, **Working**, **Completed** (newest 10, *Show all* for the rest) and
    **Failed**, each with its last status line or result and how long ago it changed
  - **Click** a session to open it in its own terminal window (or raise the window if
    it's already open). Finished sessions open too, so you can carry on the conversation.
  - **✕** then **Remove** takes a session off the list (`claude rm`). Its conversation
    log is kept, so `claude --resume` still finds it.

  The right column shows your usage:
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
- The session list uses `claude agents` / `claude attach` / `claude rm` (background
  sessions, `claude --bg`)

## Install

```sh
git clone https://github.com/JamesStuder/plasma-claude-usage
cd plasma-claude-usage
./install.sh
```

Then right-click your panel → **Add or Manage Widgets** → **Claude Code Usage**, and
drag it where you want it (next to the system tray works well).

It's a panel widget rather than a system-tray entry because the system tray gives every
popup the same fixed size, which is too narrow for the two columns. On the panel the
popup sizes itself so the usage column fits without scrolling.

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
| `session_command` | `konsole --separate -p tabtitle={name} -e {claude} attach {id}` | Terminal a session opens in; `{claude}` is the first word of `claude_command`, `{id}` / `{name}` the session's. Keep the terminal in the foreground so its window can be raised later. |

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

- **Sessions** come from `claude agents --json --all`; the status line and result come
  from Claude Code's `~/.claude/jobs/<id>/state.json`. The list refreshes every 15 s,
  every 3 s while the panel is open. An open session window is raised with a one-shot
  KWin script.

Nothing is sent anywhere except the usage request to the same Anthropic endpoint Claude
Code itself uses.

## License

MIT. Not affiliated with or endorsed by Anthropic; "Claude" and "Claude Code" are
trademarks of Anthropic.
