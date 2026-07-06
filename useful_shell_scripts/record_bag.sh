#!/usr/bin/env bash
set -Eeuo pipefail

source /opt/ros/humble/setup.bash
source /ardu_ws/install/setup.bash

RUN_NAME="${1:-flight_$(date +%Y%m%d_%H%M%S)}"
LOG_DIR="/ardu_ws/flight_logs/${RUN_NAME}"

mkdir -p /ardu_ws/flight_logs

echo "Recording rosbag to:"
echo "  ${LOG_DIR}"

exec ros2 bag record \
  --storage mcap \
  --output "${LOG_DIR}" \
  --max-bag-duration 60 \
  --max-cache-size 8388608 \
  /ap/state/synced \
  /ap/state/correction