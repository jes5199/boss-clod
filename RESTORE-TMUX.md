# Restoring the tmux session after reboot

## Prerequisites
- `source ~/.bashrc` (loads `bossclaude` and `workerclaude` functions)
- tmux must be running: `tmux new-session -s main` or `tmux attach`

## Window layout

| Window | Name | Directory | Launch command |
|--------|------|-----------|---------------|
| 0 | weechat | ~ | `weechat` |
| 1 | boss-clod | ~/boss-clod | `bossclaude` |
| 2 | claude-chat | ~/claude-chat | `workerclaude` |
| 3 | commonplace | ~/commonplace | `workerclaude` |
| 4 | commonplace-plan | ~/commonplace-plan | `workerclaude` |
| 5 | hermes | ~/hermes | `workerclaude` |
| 6 | dirigible | ~/dirigible | `workerclaude` |
| 7 | wimble | ~/wimble | `workerclaude` |
| 8 | awakening | ~/awakening | `workerclaude` |
| 9 | tarot | ~/tarot | `workerclaude` |

## Quick restore script

Run this to create all windows and cd to the right directories:

```bash
# Start tmux if not running
tmux new-session -d -s main -n weechat

# Create worker windows
tmux new-window -t main:1 -n boss-clod
tmux new-window -t main:2 -n claude-chat
tmux new-window -t main:3 -n commonplace
tmux new-window -t main:4 -n commonplace-plan
tmux new-window -t main:5 -n hermes
tmux new-window -t main:6 -n dirigible
tmux new-window -t main:7 -n wimble
tmux new-window -t main:8 -n awakening
tmux new-window -t main:9 -n tarot

# cd each window to its project directory
tmux send-keys -t main:0 'weechat' Enter
tmux send-keys -t main:1 'cd ~/boss-clod' Enter
tmux send-keys -t main:2 'cd ~/claude-chat' Enter
tmux send-keys -t main:3 'cd ~/commonplace' Enter
tmux send-keys -t main:4 'cd ~/commonplace-plan' Enter
tmux send-keys -t main:5 'cd ~/hermes' Enter
tmux send-keys -t main:6 'cd ~/dirigible' Enter
tmux send-keys -t main:7 'cd ~/wimble' Enter
tmux send-keys -t main:8 'cd ~/awakening' Enter
tmux send-keys -t main:9 'cd ~/tarot' Enter

# Attach
tmux attach -t main
```

## Launch order

1. **Start weechat** in window 0 (if you use it)
2. **Start boss first** — window 1:
   ```
   cd ~/boss-clod && bossclaude
   ```
   Press Enter when prompted for dev channels confirmation.

3. **Start each worker** — windows 2-9, in each pane run:
   ```
   workerclaude
   ```
   Each will prompt for dev channels confirmation (Enter).

4. **Boss startup tasks** — once boss-clod is running, it will set up:
   - Health check loop (hourly)
   - Usage report loop (every 3h)
   - Quota guard (every 15 min)
   - Peak/off-peak throttle (weekdays 5am/11am PT = 12:00/18:00 UTC)
   - Join IRC (#loom)

## Notes

- `--dangerously-load-development-channels` prompts for Enter on each launch. Cannot be suppressed.
- Only boss-clod loads telegram. Workers get clod-squad only.
- Each worker writes its own mcp-config file (`mcp-config-{name}.json`) to avoid race conditions.
- If workers don't respond to clod-squad messages, poke them with `tmux send-keys -t <window>.0 Enter`.
- If a worker hits a rate limit prompt, send Enter via tmux to select "Stop and wait."
