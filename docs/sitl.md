# SITL Runbook: Host ArduPlane + Docker Micro-ROS Agent

## Goal

Run fixed-wing SITL on the host while Docker exposes its AP_DDS topics to ROS 2.

```text
Host machine:
  ArduPlane SITL
    ├── MAVProxy console/map
    └── AP_DDS UDP → 127.0.0.1:2019

Docker:
  Micro-ROS Agent
    └── ROS 2 graph / your ROS 2 nodes
```

This mirrors the real-aircraft architecture conceptually:

```text
Real hardware:
  Cube Orange DDS serial → Jetson Micro-ROS Agent container

SITL:
  ArduPlane DDS UDP → host-network Micro-ROS Agent container
```

---

## 1. Build the Docker DDS-agent image

Use the existing `Dockerfile` based on:

```dockerfile
FROM ardupilot/ardupilot-dev-ros:latest
```

Create `docker-compose.sitl.yaml`:

```yaml
services:
  ap-dds-agent:
    build:
      context: .
      dockerfile: Dockerfile

    image: local/ardupilot-ros2-dds-agent:humble
    container_name: ap-dds-agent

    # Linux host networking lets host SITL reach UDP 2019 directly.
    network_mode: host

    environment:
      ROS_DOMAIN_ID: ${ROS_DOMAIN_ID:-0}

    command:
      [
        "ros2",
        "run",
        "micro_ros_agent",
        "micro_ros_agent",
        "udp4",
        "-p",
        "2019",
        "-v4"
      ]

    stdin_open: true
    tty: true
    restart: unless-stopped
```

Build and start the agent before launching SITL:

```bash
cd ~/cube_jetson_stack

docker compose -f docker-compose.sitl.yaml build
docker compose -f docker-compose.sitl.yaml up -d

docker compose -f docker-compose.sitl.yaml logs -f ap-dds-agent
```

The agent should listen on UDP port `2019`.

---

## 2. Build DDS-enabled ArduPlane SITL on the host

This occurs outside Docker.

```bash
cd /home/justin/coding_projects/ros2_trajectory_docker/ardupilot
```

Confirm the DDS generator can be found:

```bash
which microxrceddsgen
microxrceddsgen -help
```

Clean and build fixed-wing SITL with DDS:

```bash
./waf distclean
./waf configure --board sitl --enable-DDS
./waf plane -j"$(nproc)"
```

For a normal rebuild after only changing source files:

```bash
./waf plane -j"$(nproc)"
```

Use `distclean` again when changing build flags, changing DDS generator versions, or when Waf appears to reuse an outdated configuration.

---

## 3. Launch ArduPlane SITL

Run SITL on the host:

```bash
cd /home/justin/coding_projects/ros2_trajectory_docker/ardupilot

Tools/autotest/sim_vehicle.py \
  -v ArduPlane \
  -f plane \
  --console \
  --map \
  --enable-DDS
```

For a fresh SITL parameter set:

```bash
Tools/autotest/sim_vehicle.py \
  -w \
  -v ArduPlane \
  -f plane \
  --console \
  --map \
  --enable-DDS
```

`-w` wipes saved SITL parameters. Use it only when you want to reset parameters.

---

## 4. Configure SITL DDS in MAVProxy

In the MAVProxy console opened by SITL, configure the host-network Micro-ROS Agent endpoint:

```text
param set DDS_ENABLE 1

param set DDS_IP0 127
param set DDS_IP1 0
param set DDS_IP2 0
param set DDS_IP3 1

param set DDS_UDP_PORT 2019
param set DDS_DOMAIN_ID 0

# Keep trying if the agent is restarted or starts late.
param set DDS_MAX_RETRY 0

reboot
```

After SITL reboots, wait a few seconds for it to reconnect to the Docker agent.

Verify:

```text
param show DDS_ENABLE
param show DDS_IP0
param show DDS_IP1
param show DDS_IP2
param show DDS_IP3
param show DDS_UDP_PORT
param show DDS_DOMAIN_ID
param show DDS_MAX_RETRY
```

Expected values:

```text
DDS_ENABLE      1
DDS_IP0         127
DDS_IP1         0
DDS_IP2         0
DDS_IP3         1
DDS_UDP_PORT    2019
DDS_DOMAIN_ID   0
DDS_MAX_RETRY   0
```

---

## 5. Verify ROS 2 DDS topics

Open another terminal:

```bash
cd ~/cube_jetson_stack

docker compose -f docker-compose.sitl.yaml exec ap-dds-agent bash
```

Inside the container:

```bash
ros2 node list
ros2 topic list
```

You should see the ArduPilot node:

```text
/ap
```

Check the high-rate IMU topic:

```bash
ros2 topic hz /ap/imu/experimental/data --window 500
```

Inspect one message:

```bash
ros2 topic echo /ap/imu/experimental/data --once
```

Useful topic checks:

```bash
ros2 topic hz /ap/imu/experimental/data --window 500
ros2 topic hz /ap/pose/filtered --window 200
ros2 topic hz /ap/twist/filtered --window 200

ros2 topic echo /ap/geopose/filtered
ros2 topic echo /ap/pose/filtered
```

The IMU message contains a quaternion, gyro, and acceleration under one ROS timestamp:

```text
/ap/imu/experimental/data
  orientation          quaternion
  angular_velocity     gyro
  linear_acceleration  accelerometer
```

---

## 6. Test ROS 2 control separately from MAVLink control

Use only one command authority at a time.

For DDS topic inspection:

```bash
docker compose -f docker-compose.sitl.yaml exec ap-dds-agent bash
ros2 topic list | grep '^/ap/'
```

For MAVLink/MAVProxy control, use the host MAVProxy console.

Do not send conflicting mode, arm, waypoint, or velocity commands from both ROS 2 and MAVLink/Pymavlink while validating the system.

---

## 7. Optional MAVLink clients for SITL

SITL already starts MAVProxy. To connect an additional MAVProxy instance:

```bash
mavproxy.py --master=:14550 --console --map
```

For a simple Pymavlink test:

```python
from pymavlink import mavutil

mav = mavutil.mavlink_connection("udp:127.0.0.1:14550")
mav.wait_heartbeat(timeout=15)

print(
    f"Connected to system={mav.target_system}, "
    f"component={mav.target_component}"
)
```

Use separate MAVLink source IDs for each companion client.

---

## 8. Troubleshooting

### `/ap` does not appear

Check the agent:

```bash
docker compose -f docker-compose.sitl.yaml logs --tail=200 ap-dds-agent
```

Check SITL DDS parameters in MAVProxy:

```text
param show DDS_ENABLE
param show DDS_UDP_PORT
param show DDS_DOMAIN_ID
```

Confirm the host is sending DDS packets:

```bash
sudo tcpdump -ni lo udp port 2019
```

Packets visible means SITL is transmitting to the agent.

### ROS domain mismatch

The container and SITL must match:

```bash
echo "$ROS_DOMAIN_ID"
```

For the default setup:

```text
ROS_DOMAIN_ID = 0
DDS_DOMAIN_ID = 0
```

### DDS agent starts after SITL

Restart the agent first, then reboot SITL:

```bash
docker compose -f docker-compose.sitl.yaml restart ap-dds-agent
```

Then in MAVProxy:

```text
reboot
```

### Source changes do not affect SITL

Force a rebuild:

```bash
cd /home/justin/coding_projects/ros2_trajectory_docker/ardupilot

./waf distclean
./waf configure --board sitl --enable-DDS
./waf plane -j"$(nproc)"
```

Then restart SITL with `--enable-DDS`.

---

## 9. Recommended startup order

```text
1. Start Docker Micro-ROS Agent.
2. Confirm it is listening on UDP 2019.
3. Start ArduPlane SITL with --enable-DDS.
4. Confirm DDS parameters point to 127.0.0.1:2019.
5. Reboot SITL after parameter changes.
6. Verify /ap appears in the ROS 2 graph.
7. Start your ROS 2 guidance/control nodes.
8. Test MAVLink/Pymavlink control separately.
```
