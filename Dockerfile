# syntax=docker/dockerfile:1
# ROS 2 / AP_DDS bridge image only.
# ArduPilot SITL runs on the host. This container runs Micro-ROS Agent.

FROM ardupilot/ardupilot-dev-ros:latest

ARG ROS_DISTRO=humble
ARG ARDUPILOT_REF=master

ENV DEBIAN_FRONTEND=noninteractive \
    ROS_DISTRO=${ROS_DISTRO} \
    ROS_DOMAIN_ID=0 \
    DDS_AGENT_PORT=2019 \
    PYTHONUNBUFFERED=1

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# The base image already includes ArduPilot tooling, ROS 2, Java,
# and Micro-XRCE-DDS-Gen. Install only ROS workspace tools needed here.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        python3-colcon-common-extensions \
        python3-rosdep \
        python3-vcstool \
    && rm -rf /var/lib/apt/lists/*

RUN rosdep init 2>/dev/null || true \
    && rosdep update

# Create the ArduPilot ROS 2 workspace and import the repositories
# referenced by ArduPilot's ROS 2 documentation.
WORKDIR /root/ardu_ws

RUN mkdir -p src \
    && vcs import --recursive \
        --input "https://raw.githubusercontent.com/ArduPilot/ardupilot/${ARDUPILOT_REF}/Tools/ros2/ros2.repos" \
        src

RUN apt-get update \
    && source "/opt/ros/${ROS_DISTRO}/setup.bash" \
    && rosdep update \
    && rosdep install \
        --rosdistro "${ROS_DISTRO}" \
        --from-paths src \
        --ignore-src \
        -r -y \
    && rm -rf /var/lib/apt/lists/*

# Build only the ROS messages and Micro-ROS Agent.
# SITL is intentionally not built or launched in this container.
RUN source "/opt/ros/${ROS_DISTRO}/setup.bash" \
    && colcon build --merge-install \
        --packages-select ardupilot_msgs micro_ros_agent

RUN cat > /ros_entrypoint.sh <<'EOF'
#!/usr/bin/env bash
set -e

source "/opt/ros/${ROS_DISTRO}/setup.bash"
source "/root/ardu_ws/install/setup.bash"

exec "$@"
EOF

RUN chmod +x /ros_entrypoint.sh

WORKDIR /root/ardu_ws

ENTRYPOINT ["/ros_entrypoint.sh"]

EXPOSE 2019/udp

# Start the AP_DDS / Micro-ROS UDP agent.
CMD ["bash", "-lc", "exec ros2 run micro_ros_agent micro_ros_agent udp4 -p ${DDS_AGENT_PORT} -v4"]