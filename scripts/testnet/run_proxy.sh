#!/usr/bin/env bash
# Runs the Proxy in its own dedicated terminal window.
# Usage:
#   ./run_proxy.sh                 — resume: launch with existing config
#   ./run_proxy.sh start           — same as above
#   ./run_proxy.sh start --fresh   — copy configs from repo before launching
#   ./run_proxy.sh stop            — kill the proxy process and its tmux session
# Prerequisite: ./config.sh has been run at least once; nodes should already be running.
# Start order matters: run ./run_seednode.sh and ./run_nodes.sh first.

export MULTIVERSXTESTNETSCRIPTSDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

source "$MULTIVERSXTESTNETSCRIPTSDIR/variables.sh"
source "$MULTIVERSXTESTNETSCRIPTSDIR/include/config.sh"
source "$MULTIVERSXTESTNETSCRIPTSDIR/include/build.sh"
source "$MULTIVERSXTESTNETSCRIPTSDIR/include/tools.sh"   # also sources include/terminal.sh

PROXY_SESSION="multiversx-proxy"
ACTION="${1:-start}"
FRESH=0
for arg in "$@"; do
  [ "$arg" == "--fresh" ] && FRESH=1
done

# ── STOP ──────────────────────────────────────────────────────────────────────
if [ "$ACTION" == "stop" ]; then
  if [ $USE_PROXY -ne 1 ]; then
    echo "USE_PROXY is disabled ($USE_PROXY) in variables.sh - nothing to do."
    exit 1
  fi
  echo "Stopping proxy (port $PORT_PROXY)..."
  stopProcessByPort $PORT_PROXY
  tmux kill-session -t "$PROXY_SESSION" 2>/dev/null
  echo "Proxy stopped."
  exit 0
fi

# ── START ─────────────────────────────────────────────────────────────────────
if [ $USE_PROXY -ne 1 ]; then
  echo "USE_PROXY is disabled ($USE_PROXY) in variables.sh - nothing to do."
  exit 1
fi

if [ ! -d "$PROXYDIR" ]; then
  echo "ERROR: proxy repository not found at $PROXYDIR"
  exit 1
fi

prepareFolders_Proxy

# Build the proxy binary unless QUICK=1 or already deployed
if [ ! -f "$TESTNETDIR/proxy/proxy" ] || [ -z "$QUICK" ]; then
  buildProxy
fi

# Only copy configs on --fresh or first run
if [ $FRESH -eq 1 ]; then
  echo "Fresh mode: copying proxy configs from repo..."
  copyProxyConfig
  updateProxyConfig
else
  echo "Resume mode: using deployed proxy config (skipped copyProxyConfig)."
fi

# Launch the proxy in its OWN tmux session -> own terminal window
setTerminalSession "$PROXY_SESSION"
setTerminalLayout "even-vertical"
setWorkdirForNextCommands "$TESTNETDIR/proxy"

runCommandInTerminal "./proxy --start-swagger-ui -log-save -log-level $LOGLEVEL |& tee stdout.txt"

echo "Proxy started in tmux session '$PROXY_SESSION'."

# Show the session: switch to it if inside tmux, otherwise open a new window
if [ -n "$TMUX" ]; then
  tmux switch-client -t "$PROXY_SESSION" 2>/dev/null
else
  showTerminalSession "$PROXY_SESSION"
  if [ "$TERMWRAPPER" == "none" ]; then
    echo "No terminal emulator found. Attach manually with:"
    echo "  tmux attach-session -t $PROXY_SESSION"
  fi
fi
echo "Done. Proxy listens on port $PORT_PROXY."
