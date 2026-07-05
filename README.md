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
