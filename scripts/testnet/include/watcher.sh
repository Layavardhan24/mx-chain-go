function node-start-with-watcher {
  local VALIDATOR_INDEX=$1
  local PORT=$2
  local WORKING_DIR="$(pwd)"
  local TESTNETDIR="../.."
  
  if [ -f "$WORKING_DIR/norestart" ]; then
    rm $WORKING_DIR/norestart
  fi

  echo "Starting watcher for validator $VALIDATOR_INDEX..."
  echo "$$" > "$WORKING_DIR/watcher.pid"
  echo "[$(date)] Watcher for validator $VALIDATOR_INDEX (PID $$) started" > "$WORKING_DIR/watcher-status"
  local node_command=$(cat "$WORKING_DIR/node-command")

  local probedelay=5
  while true; do
    local running=$(isNodeRunning $PORT "$WORKING_DIR")
    if [ "$running" == "0" ]; then
      if [ -f "$WORKING_DIR/norestart" ]; then
        echo "[$(date)] Watcher instructed to stop completely" >> "$WORKING_DIR/watcher-status"
        break
      fi

      local is_shuffled=0
      if [ -d "$WORKING_DIR/logs" ]; then
        if grep -qE "shuffled_out|epoch start data for current shard not found" "$WORKING_DIR/logs"/*.log 2>/dev/null; then
          is_shuffled=1
        fi
      fi

      if [ "$is_shuffled" == "1" ]; then
        echo "[$(date)] Validator $VALIDATOR_INDEX is in waiting queue / shuffled out. Cleaning DB and waiting 60s for next epoch..." >> "$WORKING_DIR/watcher-status"
        sleep 3
        rm -rf "$WORKING_DIR/db"/* 2>/dev/null
        rm -rf "$WORKING_DIR/compiledSCStorage"/* 2>/dev/null
        rm -rf "$WORKING_DIR/logs"/* 2>/dev/null
        sleep 60
      else
        echo "[$(date)] Validator $VALIDATOR_INDEX process stopped. Waiting for locks to clear..." >> "$WORKING_DIR/watcher-status"
        sleep 5
      fi

      echo "[$(date)] Validator $VALIDATOR_INDEX found not to be running" >> "$WORKING_DIR/watcher-status"
      echo "[$(date)] Starting node:\n$node_command" >> "$WORKING_DIR/watcher-status"

      pushd $TESTNETDIR/node
      pwd
      $node_command &
      popd

      probedelay=60
    else
      probedelay=5
    fi
    sleep $probedelay
  done
  echo "[$(date)] Watcher for validator $VALIDATOR_INDEX exiting..." >> "$WORKING_DIR/watcher-status"
}

function isNodeRunning {
  local PORT=$1
  local WORKING_DIR=$2

  local PID_PORT=$(lsof -t -i:$PORT 2>/dev/null)
  if [ -n "$PID_PORT" ]; then
    echo 1
    return
  fi

  if [ -n "$WORKING_DIR" ]; then
    local PID_PROC=$(pgrep -f "./node.*-working-directory $WORKING_DIR" 2>/dev/null)
    if [ -n "$PID_PROC" ]; then
      echo 1
      return
    fi
  fi

  echo 0
}
