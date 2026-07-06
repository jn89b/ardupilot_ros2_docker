COMMON_SETUP=$(cat <<EOF
source /opt/ros/humble/setup.bash 2>/dev/null || true
source /opt/ros/humble/install/setup.bash 2>/dev/null || true

if [[ -f /opt/micro_ros_agent_ws/install/setup.bash ]]; then
    source /opt/micro_ros_agent_ws/install/setup.bash
fi

if ! cd $(printf '%q' "${WORKSPACE}"); then
    echo "ERROR: Could not enter workspace: ${WORKSPACE}"
    exec bash -i
fi

if [[ -f install/setup.bash ]]; then
    source install/setup.bash
fi
EOF
)

CHECKPOINT_ARG=""
if [[ -n "${MODEL_CHECKPOINT}" ]]; then
    CHECKPOINT_ARG="-p model_checkpoint:=$(printf '%q' "${MODEL_CHECKPOINT}")"
fi

INTERPOLATE_CMD="${COMMON_SETUP}

echo 'Starting interpolate node...'
echo

set +e
ros2 run traj_estimation ${INTERPOLATE_EXECUTABLE}
exit_code=\$?
set -e

echo
echo '=============================================='
echo \"interpolate node exited with code \$exit_code.\"
echo 'Keeping this tmux pane open for debugging.'
echo 'Press Ctrl+D or type exit when finished.'
echo '=============================================='
exec bash -i
"

PREDICTION_CMD="${COMMON_SETUP}

echo 'Starting prediction node...'
echo

set +e
ros2 run traj_estimation ${PREDICTION_EXECUTABLE} --ros-args \
    -p sequence_length:=${SEQUENCE_LENGTH} \
    -p model_type:=${MODEL_TYPE} \
    -p device:=${DEVICE} \
    ${CHECKPOINT_ARG}
exit_code=\$?
set -e

echo
echo '=============================================='
echo \"prediction node exited with code \$exit_code.\"
echo 'Keeping this tmux pane open for debugging.'
echo 'Press Ctrl+D or type exit when finished.'
echo '=============================================='
exec bash -i
"

# Left pane: interpolation node.
tmux new-session -d \
    -s "${SESSION_NAME}" \
    -n estimation \
    "bash -lc $(printf '%q' "${INTERPOLATE_CMD}")"

# Right pane: prediction/RNN node.
tmux split-window -h \
    -t "${SESSION_NAME}:0" \
    "bash -lc $(printf '%q' "${PREDICTION_CMD}")"