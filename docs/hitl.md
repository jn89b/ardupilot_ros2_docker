# Cube Orange + Jetson Setup: AP_DDS in Docker and MAVLink Router for MAVROS/Pymavlink

## Goal

Run two independent links between the Cube Orange and Jetson:

```text
Cube Orange TELEM1  <── DDS XRCE ──>  Jetson UART 1  <──>  Micro-ROS Agent in Docker  <──> ROS 2 nodes

Cube Orange TELEM2  <── MAVLink2 ──>  Jetson UART 2  <──>  MAVLink Router  ──┬── MAVROS
                                                                               └── Pymavlink
```

Use DDS for ROS 2 state/control interfaces and MAVLink for MAVROS, parameters, missions, modes, arming, and Pymavlink commands.

A DDS/XRCE serial port uses `SERIALx_PROTOCOL=45`; it cannot also carry MAVLink. MAVLink Router can route one FC UART to several TCP and UDP clients.

> **Safety:** bench-test props-off first. Use one command authority at a time; keep MAVROS telemetry-focused when Pymavlink is commanding the aircraft.

---

## 1. Hardware wiring

Use two separate Cube telemetry ports.

```text
DDS link: Cube TELEM1                  MAVLink link: Cube TELEM2

Cube TX  ───────> Jetson DDS RX        Cube TX  ───────> Jetson MAVLink RX
Cube RX  <─────── Jetson DDS TX        Cube RX  <─────── Jetson MAVLink TX
Cube GND ──────── Jetson GND           Cube GND ──────── Jetson GND
```

Do not power the Jetson from a Cube telemetry connector. Use the Jetson’s normal regulated power supply.

The examples below assume:

```text
TELEM1 = SERIAL1 = DDS
TELEM2 = SERIAL2 = MAVLink2
```

Verify this on your specific Cube carrier board before changing parameters. Also ensure the Jetson UARTs are 3.3 V TTL and are not being used as Linux serial-console ports.

---

## 2. Build custom ArduPlane firmware with DDS enabled

This happens on an Ubuntu development machine or directly on the Jetson. Docker does **not** add DDS support to stock Cube firmware; DDS must be enabled when the firmware is compiled.

### Install ArduPilot build prerequisites

```bash
sudo apt update
sudo apt install -y git openjdk-17-jdk

mkdir -p ~/uas
cd ~/uas

git clone --recurse-submodules https://github.com/ArduPilot/ardupilot.git
cd ardupilot

Tools/environment_install/install-prereqs-ubuntu.sh -y
source ~/.profile
```

### Install Micro-XRCE-DDS-Gen

ArduPilot’s ROS 2 build instructions require Micro-XRCE-DDS-Gen. For ArduPilot 4.7 and newer, use the `v4.7.0` branch.

```bash
cd ~/uas

git clone --recurse-submodules \
  --branch v4.7.0 \
  https://github.com/ArduPilot/Micro-XRCE-DDS-Gen.git

cd Micro-XRCE-DDS-Gen

export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH="$JAVA_HOME/bin:$PATH"

./gradlew clean assemble

echo 'export PATH=$PATH:$HOME/uas/Micro-XRCE-DDS-Gen/scripts' >> ~/.bashrc
source ~/.bashrc

microxrceddsgen -help
```

If you receive `Unsupported class file major version 65`, Java 21 is active. Keep the `JAVA_HOME` and `PATH` exports above so Gradle uses Java 17.

### Optional: customize DDS publication intervals

Edit:

```bash
cd ~/uas/ardupilot
nano libraries/AP_DDS/AP_DDS_config.h
```

Stock ArduPilot uses a 5 ms IMU delay and 33 ms pose/velocity/geopose delays.

For an IMU-focused build, start conservatively:

```cpp
#define AP_DDS_DELAY_IMU_TOPIC_MS 4

#define AP_DDS_DELAY_GEO_POSE_TOPIC_MS 33
#define AP_DDS_DELAY_LOCAL_POSE_TOPIC_MS 33
#define AP_DDS_DELAY_LOCAL_VELOCITY_TOPIC_MS 33
#define AP_DDS_DELAY_AIRSPEED_TOPIC_MS 33
```

Do not assume a `4 ms` interval guarantees 250 Hz. It only removes the configured rate gate; actual rate is limited by the Cube CPU, AP_DDS thread, serial transport, and Micro-ROS Agent.

### Build ArduPlane for Cube Orange

```bash
cd ~/uas/ardupilot

./waf distclean
./waf configure --board CubeOrange --enable-DDS
./waf plane -j"$(nproc)"
```

The firmware file should be:

```bash
ls -lh build/CubeOrange/bin/arduplane.apj
```

Upload it through Mission Planner’s custom firmware loader, or connect the Cube by USB and run:

```bash
./waf plane --upload
```

---

## 3. Configure Cube parameters

After flashing, set these in Mission Planner or MAVProxy.

```text
# Enable AP_DDS
DDS_ENABLE = 1
DDS_DOMAIN_ID = 0
DDS_USE_NS = 0
DDS_MAX_RETRY = 0

# TELEM1 / SERIAL1: DDS XRCE to Jetson
SERIAL1_PROTOCOL = 45
SERIAL1_BAUD = 921

# TELEM2 / SERIAL2: MAVLink2 to Jetson
SERIAL2_PROTOCOL = 2
SERIAL2_BAUD = 921

# Disable flow control unless CTS/RTS are physically wired.
BRD_SER1_RTSCTS = 0
BRD_SER2_RTSCTS = 0
```

Reboot the Cube after setting protocol or baud-rate parameters.

`45` is the ArduPilot serial protocol value for DDS XRCE; the AP_DDS reference documents `DDS_ENABLE` and the serial protocol setup.

---

## 4. Prepare Docker on the Jetson

Install Docker if needed:

```bash
sudo apt update
sudo apt install -y docker.io docker-compose-plugin

sudo usermod -aG docker "$USER"
newgrp docker
```

Confirm the Jetson UART devices:

```bash
ls -l /dev/ttyTHS* /dev/ttyUSB* /dev/ttyACM* 2>/dev/null
```

For this guide, assume:

```text
DDS UART:     /dev/ttyTHS1
MAVLink UART: /dev/ttyTHS2
```

Create the project directory:

```bash
mkdir -p ~/cube_jetson_stack
cd ~/cube_jetson_stack
```

### `.env`

```bash
cat > .env <<'EOF'
DDS_UART=/dev/ttyTHS1
MAVLINK_UART=/dev/ttyTHS2
DDS_BAUD=921600
MAVLINK_BAUD=921600
ROS_DOMAIN_ID=0
EOF
```

### `Dockerfile`

```dockerfile
FROM ardupilot/ardupilot-dev-ros:latest

ARG ROS_DISTRO=humble

ENV DEBIAN_FRONTEND=noninteractive \
    ROS_DISTRO=${ROS_DISTRO} \
    ROS_DOMAIN_ID=0

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        python3-colcon-common-extensions \
        python3-rosdep \
        python3-vcstool \
        mavlink-router \
        python3-pymavlink \
        ros-humble-mavros \
        ros-humble-mavros-extras \
    && rm -rf /var/lib/apt/lists/*

RUN rosdep init 2>/dev/null || true \
    && rosdep update

WORKDIR /root/ardu_ws

RUN mkdir -p src \
    && vcs import --recursive \
        --input https://raw.githubusercontent.com/ArduPilot/ardupilot/master/Tools/ros2/ros2.repos \
        src

RUN apt-get update \
    && source /opt/ros/${ROS_DISTRO}/setup.bash \
    && rosdep install \
        --from-paths src/micro_ros_agent \
        --ignore-src \
        -r -y \
    && rm -rf /var/lib/apt/lists/*

RUN source /opt/ros/${ROS_DISTRO}/setup.bash \
    && colcon build --merge-install \
        --packages-select micro_ros_agent ardupilot_msgs

RUN cat > /ros_entrypoint.sh <<'EOF'
#!/usr/bin/env bash
set -e

source "/opt/ros/${ROS_DISTRO}/setup.bash"
source "/root/ardu_ws/install/setup.bash"

exec "$@"
EOF

RUN chmod +x /ros_entrypoint.sh

ENTRYPOINT ["/ros_entrypoint.sh"]
CMD ["bash"]
```

ArduPilot’s documented Docker workflow uses the `ardupilot-dev-ros` image, then creates the `ardu_ws` workspace and imports the ArduPilot and Micro-ROS Agent repositories.

### `docker-compose.yaml`

```yaml
services:
  ap-dds-agent:
    build: .
    image: local/cube-jetson-ros:humble
    container_name: ap-dds-agent
    network_mode: host

    environment:
      ROS_DOMAIN_ID: ${ROS_DOMAIN_ID}

    devices:
      - ${DDS_UART}:/dev/fcu_dds

    command:
      [
        "ros2",
        "run",
        "micro_ros_agent",
        "micro_ros_agent",
        "serial",
        "-b",
        "${DDS_BAUD}",
        "-D",
        "/dev/fcu_dds",
        "-v4"
      ]

    restart: unless-stopped

  mavlink-router:
    image: local/cube-jetson-ros:humble
    container_name: mavlink-router
    network_mode: host

    devices:
      - ${MAVLINK_UART}:/dev/fcu_mav

    command:
      [
        "mavlink-routerd",
        "-e",
        "127.0.0.1:14550",
        "/dev/fcu_mav:${MAVLINK_BAUD}"
      ]

    restart: unless-stopped

  mavros:
    image: local/cube-jetson-ros:humble
    container_name: mavros
    network_mode: host

    environment:
      ROS_DOMAIN_ID: ${ROS_DOMAIN_ID}

    depends_on:
      - mavlink-router

    command:
      [
        "ros2",
        "launch",
        "mavros",
        "apm.launch",
        "fcu_url:=tcp://127.0.0.1:5760",
        "gcs_url:="
      ]

    restart: unless-stopped
```

`network_mode: host` is appropriate on a Linux Jetson because the containers use the host network directly and avoid Docker NAT.

Build and start:

```bash
docker compose build --no-cache
docker compose up -d

docker compose ps
docker compose logs -f ap-dds-agent
```

Start the DDS agent **before** powering or rebooting the Cube. The official AP_DDS sequence also starts the agent before SITL.

---

## 5. Verify DDS

Open a shell in the ROS container:

```bash
docker compose exec ap-dds-agent bash
```

Then:

```bash
ros2 node list
ros2 topic list
ros2 topic hz /ap/imu/experimental/data --window 500
```

Expected useful topics include:

```text
/ap/imu/experimental/data
/ap/pose/filtered
/ap/twist/filtered
/ap/geopose/filtered
/ap/navsat
```

ArduPilot documents `/ap/imu/experimental/data` as a `sensor_msgs/msg/Imu` topic, and it is published alongside the other AP_DDS state topics.

If topics do not appear:

```bash
docker compose logs --tail=200 ap-dds-agent
```

Then verify Cube parameters and reboot the Cube after the agent is already running.

---

## 6. Verify MAVLink Router and MAVROS

MAVLink Router creates a TCP server on port `5760` by default. MAVROS and Pymavlink can independently connect to that server.

Check router logs:

```bash
docker compose logs -f mavlink-router
```

Check MAVROS:

```bash
docker compose exec mavros bash

ros2 topic list | grep mavros
ros2 topic echo /mavros/state
```

The ROS 2 MAVROS ArduPilot launch file accepts `fcu_url` and defaults to an ArduPilot-compatible plugin/configuration set.

---

## 7. Pymavlink connection

Run your Pymavlink command process on the Jetson host or inside a container using host networking.

```python
from pymavlink import mavutil

mav = mavutil.mavlink_connection(
    "tcp:127.0.0.1:5760",
    source_system=245,
    source_component=190,
)

mav.wait_heartbeat(timeout=15)

print(
    f"Connected to system={mav.target_system}, "
    f"component={mav.target_component}"
)
```

Use a unique companion `source_system` and `source_component`. Do not reuse the Cube’s flight-controller system ID.

MAVLink Router routes target-addressed MAVLink messages based on system and component IDs, while broadcast messages are delivered to all eligible endpoints.

Recommended authority split:

```text
DDS:
  High-rate ROS 2 state and AP_DDS control interfaces.

MAVROS:
  ROS compatibility, telemetry, services, parameter access.

Pymavlink:
  Designated command authority for mode, arm/disarm, missions,
  and Guided commands.
```

Avoid issuing flight commands from MAVROS and Pymavlink at the same time.

---

## 8. Rate validation

Measure actual DDS rate on the Jetson:

```bash
docker compose exec ap-dds-agent \
  ros2 topic hz /ap/imu/experimental/data --window 1000
```

The stock AP_DDS configuration uses a 5 ms IMU interval but actual frequency can be lower because the publication loop, Cube CPU, XRCE serialization, UART throughput, and Jetson agent all contribute to timing. The source constants are rate gates, not guaranteed real-time deadlines.

For initial hardware validation:

```text
1. Keep nonessential DDS topics at stock rates.
2. Measure only /ap/imu/experimental/data.
3. Confirm no DDS reconnects, serial errors, or Cube CPU issues.
4. Change one DDS interval at a time.
5. Bench-test before flight-testing.
```
