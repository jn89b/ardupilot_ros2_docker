# Install Micro-XRCE-DDS-Gen for ArduPilot SITL Running Outside Docker

> **Important:** This setup assumes ArduPilot SITL is built and run directly on the host machine, not inside Docker.
>
> `microxrceddsgen` must be installed on the same machine and available in the same shell environment where you run:
>
> ```bash
> ./waf configure --board sitl --enable-DDS
> ```
>
> Installing the generator only inside a Docker container will not help a host-side SITL build.

## 1. Set project paths on the host machine

Run these commands in your normal host terminal:

```bash
export PROJECT_ROOT=/home/mide/ardupilot_ros2_docker
export ARDUPILOT_DIR="$PROJECT_ROOT/ardupilot"
export GEN_DIR="$PROJECT_ROOT/Micro-XRCE-DDS-Gen"
```

Verify that the ArduPilot checkout exists:

```bash
ls "$ARDUPILOT_DIR"
```

You should see directories and files such as:

```text
ArduCopter
ArduPlane
Tools
libraries
waf
```

---

## 2. Install Git and Java 17 on the host

```bash
sudo apt update
sudo apt install -y git openjdk-17-jdk
```

Set Java 17 explicitly for the current shell:

```bash
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH="$JAVA_HOME/bin:$PATH"

java -version
javac -version
```

Both commands should report Java 17.

> Java 17 is recommended because Gradle 7.6 can fail when old caches were built with Java 21 or another incompatible version.

---

## 3. Clone the ArduPilot-compatible Micro-XRCE-DDS generator

ArduPilot DDS builds use the ArduPilot fork of `Micro-XRCE-DDS-Gen` on version `v4.7.0`.

```bash
if [ -d "$GEN_DIR/.git" ]; then
    git -C "$GEN_DIR" fetch --tags
    git -C "$GEN_DIR" checkout v4.7.0
    git -C "$GEN_DIR" submodule sync --recursive
    git -C "$GEN_DIR" submodule update --init --recursive
else
    git clone --recurse-submodules \
        --branch v4.7.0 \
        https://github.com/ardupilot/Micro-XRCE-DDS-Gen.git \
        "$GEN_DIR"
fi
```

---

## 4. Build `microxrceddsgen`

```bash
cd "$GEN_DIR"

# Remove Gradle 7.6 cache files that may have been built using another Java version.
rm -rf "$HOME/.gradle/caches/7.6" "$HOME/.gradle/daemon/7.6"

./gradlew --stop || true
./gradlew clean assemble
```

This creates the `microxrceddsgen` wrapper script inside:

```text
/home/mide/ardupilot_ros2_docker/Micro-XRCE-DDS-Gen/scripts/
```

---

## 5. Add `microxrceddsgen` to your host PATH

For the current terminal only:

```bash
export PATH="$GEN_DIR/scripts:$PATH"
```

To make this persistent across new host terminals:

```bash
grep -qF "# ArduPilot Micro-XRCE-DDS-Gen" ~/.bashrc || cat >> ~/.bashrc <<'EOF'

# ArduPilot Micro-XRCE-DDS-Gen for host-side SITL builds
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH="$JAVA_HOME/bin:$HOME/ardupilot_ros2_docker/Micro-XRCE-DDS-Gen/scripts:$PATH"
EOF

source ~/.bashrc
```

---

## 6. Verify the generator is available

Run:

```bash
which microxrceddsgen
microxrceddsgen -help
microxrceddsgen -version
```

Expected path:

```text
/home/mide/ardupilot_ros2_docker/Micro-XRCE-DDS-Gen/scripts/microxrceddsgen
```

If `which microxrceddsgen` returns nothing, check:

```bash
echo "$PATH"
ls -la "$GEN_DIR/scripts"
```

Then re-run:

```bash
export PATH="$GEN_DIR/scripts:$PATH"
```

---

## 7. Build DDS-enabled ArduPilot SITL on the host

Build Plane SITL:

```bash
cd "$ARDUPILOT_DIR"

./waf distclean
./waf configure --board sitl --enable-DDS
./waf plane -j"$(nproc)"
```

Build Copter SITL instead:

```bash
cd "$ARDUPILOT_DIR"

./waf distclean
./waf configure --board sitl --enable-DDS
./waf copter -j"$(nproc)"
```

> The capitalization is usually accepted either way, but use `--enable-DDS` to match ArduPilot documentation and build examples.

---

## 8. Confirm DDS was detected during configuration

After running `./waf configure`, inspect the config log:

```bash
grep -iE "dds|microxrce" "$ARDUPILOT_DIR/build/config.log"
```

You should no longer see:

```text
Could not find the program ['microxrceddsgen']
```

You should see output indicating that `microxrceddsgen` was found and DDS support was enabled.

---

## 9. Docker note

Your ROS 2 nodes, MAVROS, Micro XRCE-DDS Agent, or other tooling can still run inside Docker.

However, because SITL is built outside Docker:

* `microxrceddsgen` must be installed on the host.
* The host terminal must have `microxrceddsgen` in `PATH`.
* The host must run the DDS-enabled `./waf configure` and build command.
* Docker does not need the generator unless you later decide to build ArduPilot SITL inside Docker.
