#!/usr/bin/env bash
# Runs the Observer and Validator nodes in their own dedicated terminal window.
# Usage:
#   ./run_nodes.sh                 — resume: launch with existing deployed configs
#   ./run_nodes.sh start           — same as above
#   ./run_nodes.sh start --fresh   — copy configs from repo before launching
#   ./run_nodes.sh stop            — kill all node processes and their tmux session
# Prerequisite: ./config.sh has been run at least once (configs + genesis present).
# Start order matters: run ./run_seednode.sh first.

export MULTIVERSXTESTNETSCRIPTSDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

source "$MULTIVERSXTESTNETSCRIPTSDIR/variables.sh"
source "$MULTIVERSXTESTNETSCRIPTSDIR/include/config.sh"
source "$MULTIVERSXTESTNETSCRIPTSDIR/include/build.sh"
source "$MULTIVERSXTESTNETSCRIPTSDIR/include/validators.sh"
source "$MULTIVERSXTESTNETSCRIPTSDIR/include/observers.sh"

NODES_SESSION="multiversx-nodes"
ACTION="${1:-start}"
FRESH=0
for arg in "$@"; do
  [ "$arg" == "--fresh" ] && FRESH=1
done

# ── STOP ──────────────────────────────────────────────────────────────────────
if [ "$ACTION" == "stop" ]; then
  echo "Stopping observers and validators..."
  stopValidators
  stopObservers
  tmux kill-session -t "$NODES_SESSION" 2>/dev/null
  echo "All nodes stopped."
  exit 0
fi

# ── START ─────────────────────────────────────────────────────────────────────
# Sanity check: configs must already exist (created by ./config.sh)
if [ ! -f "$NODEDIR/config/config.toml" ] || [ ! -f "$TESTNETDIR/node/config/genesis.json" ]; then
  echo "ERROR: node configuration not found."
  echo "Run ./config.sh first to generate configs, keys, genesis.json and nodesSetup.json."
  exit 1
fi

prepareFolders

# Build the node binary unless QUICK=1 or already deployed
if [ ! -f "$TESTNETDIR/node/node" ] || [ -z "$QUICK" ]; then
  buildNode
fi

# Only copy configs on --fresh or first run; otherwise use deployed configs as-is
if [ $FRESH -eq 1 ]; then
  echo "Fresh mode: copying configs from repo..."
  copyConfig
  if [ $ALWAYS_UPDATE_CONFIGS -eq 1 ]; then
    copyNodeConfig
    updateNodeConfig
  fi
else
  echo "Resume mode: using deployed configs (skipped copyConfig)."
  echo "  To refresh from repo: ./run_nodes.sh start --fresh"
fi

# Launch observers + validators in their own tmux session
setTerminalSession "$NODES_SESSION"
setTerminalLayout "tiled"

startObservers
startValidators

# Kill the initial empty pane created by tmux new-session (the shell prompt)
# then re-apply tiled layout so the remaining panes form a clean 4x3 grid.
tmux kill-pane -t "$NODES_SESSION":0.0 2>/dev/null
tmux select-layout -t "$NODES_SESSION" tiled 2>/dev/null

echo "Observers and validators started in tmux session '$NODES_SESSION'."
echo "Waiting for the nodes to start ($NODE_DELAY s)..."
sleep $NODE_DELAY
echo "Done. Validators on ports ${PORT_ORIGIN_VALIDATOR}+ , observers REST on ports ${PORT_ORIGIN_OBSERVER_REST}+ ."

# Show the session: switch to it if inside tmux, otherwise open a new window
if [ -n "$TMUX" ]; then
  tmux switch-client -t "$NODES_SESSION" 2>/dev/null
else
  showTerminalSession "$NODES_SESSION"
  if [ "$TERMWRAPPER" == "none" ]; then
    echo "No terminal emulator found. Attach manually with:"
    echo "  tmux attach-session -t $NODES_SESSION"
  fi
fi
