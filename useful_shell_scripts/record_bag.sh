#!/bin/bash

WORKSPACE="/root/workspace"

RUN_NAME="${1:-flight_$(date +%Y%m%d_%H%M%S)}"
LOG_DIR="$WORKSPACE/flight_logs/$RUN_NAME"

source /opt/ros/humble/setup.bash 2>/dev/null || true
source /opt/ros/humble/install/setup.bash 2>/dev/null || true
source $WORKSPACE/install/setup.bash 2>/dev/null || true

cd $WORKSPACE

mkdir -p "$WORKSPACE/flight_logs"

echo "Recording rosbag to:"
echo "  $LOG_DIR"

ros2 bag record \
  --storage mcap \
  --output "$LOG_DIR" \
  --max-bag-duration 60 \
  --max-cache-size 8388608 \
  /ap/state/synced \
  /ap/state/correction

echo
echo "rosbag stopped. Shell staying open."
exec bash