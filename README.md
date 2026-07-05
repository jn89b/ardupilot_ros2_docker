# README

# Quick Start If you already installed

Start the docker container and enter it
```bash
cd docker_jetson
docker compose up -d 
docker exec -it ardupilot-ros2-dds-agent bash
source /opt/ros/humble/install/setup.bash 
```
Now run the simulator 
```bash
cd useful_shell_scripts
./run_ardupilot_sitl_dds.sh
```

# Preliminaries

## Install the ardupilot_dev_docker image
Make sure to clone the `ardupilot_dev_docker` repo cloned 
```bash
git clone https://github.com/ArduPilot/ardupilot_dev_docker.git
```
```bash
docker run -it --name ardupilot-dds ardupilot/ardupilot-dev-ros
```
Then verify that you can enter the container by running 
```
docker container exec -it ardupilot-dds /bin/bash
```
