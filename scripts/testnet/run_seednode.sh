#!/usr/bin/env bash
# Runs ONLY the seednode in its own dedicated terminal window.
# Usage:
#   ./run_seednode.sh                 — resume: launch with existing config
#   ./run_seednode.sh start           — same as above
#   ./run_seednode.sh start --fresh   — copy configs from repo before launching
#   ./run_seednode.sh stop            — kill the seednode process and its tmux session

export MULTIVERSXTESTNETSCRIPTSDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

source "$MULTIVERSXTESTNETSCRIPTSDIR/variables.sh"
source "$MULTIVERSXTESTNETSCRIPTSDIR/include/config.sh"
source "$MULTIVERSXTESTNETSCRIPTSDIR/include/build.sh"
source "$MULTIVERSXTESTNETSCRIPTSDIR/include/tools.sh"   # also sources include/terminal.sh

SEEDNODE_SESSION="multiversx-seednode"
ACTION="${1:-start}"
FRESH=0
for arg in "$@"; do
  [ "$arg" == "--fresh" ] && FRESH=1
done

# ── STOP ──────────────────────────────────────────────────────────────────────
if [ "$ACTION" == "stop" ]; then
  echo "Stopping seednode (port $PORT_SEEDNODE)..."
  stopProcessByPort $PORT_SEEDNODE
  tmux kill-session -t "$SEEDNODE_SESSION" 2>/dev/null
  echo "Seednode stopped."
  exit 0
fi

# ── START ─────────────────────────────────────────────────────────────────────
prepareFolders

# Build the seednode binary unless QUICK=1 or already deployed
if [ ! -f "$TESTNETDIR/seednode/seednode" ] || [ -z "$QUICK" ]; then
  buildSeednode
fi

# Only copy configs on --fresh or first run
if [ $FRESH -eq 1 ]; then
  echo "Fresh mode: copying seednode configs from repo..."
  copySeednodeConfig
  updateSeednodeConfig
else
  echo "Resume mode: using deployed seednode config (skipped copySeednodeConfig)."
fi

# Launch the seednode in its OWN tmux session -> own terminal window
setTerminalSession "$SEEDNODE_SESSION"
setTerminalLayout "even-horizontal"
setWorkdirForNextCommands "$TESTNETDIR/seednode"

if [ -n "$NODE_NICENESS" ]; then
  seednodeCommand="nice -n $NODE_NICENESS ./seednode"
else
  seednodeCommand="./seednode"
fi

runCommandInTerminal "$seednodeCommand"

echo "Seednode started in tmux session '$SEEDNODE_SESSION'."

# Show the session: switch to it if inside tmux, otherwise open a new window
if [ -n "$TMUX" ]; then
  tmux switch-client -t "$SEEDNODE_SESSION" 2>/dev/null
else
  showTerminalSession "$SEEDNODE_SESSION"
  if [ "$TERMWRAPPER" == "none" ]; then
    echo "No terminal emulator found. Attach manually with:"
    echo "  tmux attach-session -t $SEEDNODE_SESSION"
  fi
fi
echo "Done. Seednode listens on port $PORT_SEEDNODE."
