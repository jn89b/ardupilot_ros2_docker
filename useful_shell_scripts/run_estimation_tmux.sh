#!/bin/bash

SESSION="traj_estimation"
WORKSPACE="/root/workspace"

SEQUENCE_LENGTH=30
MODEL_TYPE="lstm"
DEVICE="cuda"

# Change this per flight if you want a named log folder.
RUN_NAME="flight_$(date +%Y%m%d_%H%M%S)"

# Kill the old session so you start clean.
tmux has-session -t "$SESSION" 2>/dev/null && tmux kill-session -t "$SESSION"

# Create the session and split into three panes.
tmux new-session -d -s "$SESSION" -n estimation

# Pane 0 and pane 1: side-by-side.
tmux split-window -h -t "$SESSION:0"

# Split the right pane vertically to create pane 2.
tmux split-window -v -t "$SESSION:0.1"

# Pane 0: interpolation node.
tmux send-keys -t "$SESSION:0.0" \
  "source /opt/ros/humble/setup.bash 2>/dev/null || true; \
   source /opt/ros/humble/install/setup.bash 2>/dev/null || true; \
   source $WORKSPACE/install/setup.bash 2>/dev/null || true; \
   cd $WORKSPACE; \
   ros2 run traj_estimation interpolate_node.py; \
   echo; \
   echo 'interpolate_node exited. Pane will stay open.'; \
   exec bash" C-m

# Pane 1: RNN prediction node.
tmux send-keys -t "$SESSION:0.1" \
  "source /opt/ros/humble/setup.bash 2>/dev/null || true; \
   source /opt/ros/humble/install/setup.bash 2>/dev/null || true; \
   source $WORKSPACE/install/setup.bash 2>/dev/null || true; \
   cd $WORKSPACE; \
   ros2 run traj_estimation prediction_node.py --ros-args \
     -p sequence_length:=$SEQUENCE_LENGTH \
     -p model_type:=$MODEL_TYPE \
     -p device:=$DEVICE; \
   echo; \
   echo 'prediction_node exited. Pane will stay open.'; \
   exec bash" C-m

# Pane 2: real-time JSONL logger.
tmux send-keys -t "$SESSION:0.2" \
  "source /opt/ros/humble/setup.bash 2>/dev/null || true; \
   source /opt/ros/humble/install/setup.bash 2>/dev/null || true; \
   source $WORKSPACE/install/setup.bash 2>/dev/null || true; \
   cd $WORKSPACE; \
   ros2 run traj_estimation logger_node.py --ros-args \
     -p run_name:=$RUN_NAME \
     -p queue_size:=10000 \
     -p batch_size:=256 \
     -p flush_interval_s:=0.25 \
     -p fsync_interval_s:=1.0; \
   echo; \
   echo 'realtime_logger_node exited. Pane will stay open.'; \
   exec bash" C-m

# Make the three panes fit neatly.
tmux select-layout -t "$SESSION:0" tiled

# Start focused on the interpolation pane.
tmux select-pane -t "$SESSION:0.0"

# Attach to the tmux session.
tmux attach -t "$SESSION"