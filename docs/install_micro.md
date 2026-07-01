# Install Micro-XRCE-DDS-Gen for ArduPilot SITL

```bash
# Your existing project root.
export PROJECT_ROOT=/home/justin/coding_projects/ros2_trajectory_docker
export GEN_DIR="$PROJECT_ROOT/Micro-XRCE-DDS-Gen"

# Install Git and Java 17.
# Java 17 avoids the Gradle 7.6 + Java 21 error you saw earlier.
sudo apt update
sudo apt install -y git openjdk-17-jdk

# Use Java 17 explicitly for this shell.
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH="$JAVA_HOME/bin:$PATH"

java -version
javac -version
```

Both commands should report Java 17.

```bash
# Clone the required ArduPilot-compatible generator version.
# If it is already cloned, update it and its submodules instead.
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

cd "$GEN_DIR"

# Remove the cached Gradle 7.6 scripts previously compiled with Java 21.
rm -rf "$HOME/.gradle/caches/7.6" "$HOME/.gradle/daemon/7.6"

./gradlew --stop || true
./gradlew clean assemble
```

Add Java 17 and the generator permanently to your shell environment:

```bash
grep -qF "# ArduPilot Micro-XRCE-DDS-Gen" ~/.bashrc || cat >> ~/.bashrc <<'EOF'

# ArduPilot Micro-XRCE-DDS-Gen
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH="$JAVA_HOME/bin:$HOME/coding_projects/ros2_trajectory_docker/Micro-XRCE-DDS-Gen/scripts:$PATH"
EOF

source ~/.bashrc
```

Verify installation:

```bash
which microxrceddsgen
microxrceddsgen -help
microxrceddsgen -version
```

Expected path:

```text
/home/justin/coding_projects/ros2_trajectory_docker/Micro-XRCE-DDS-Gen/scripts/microxrceddsgen
```

Then rebuild DDS-enabled Plane SITL:

```bash
cd /home/justin/coding_projects/ros2_trajectory_docker/ardupilot

./waf distclean
./waf configure --board sitl --enable-DDS
./waf plane -j"$(nproc)"
```
