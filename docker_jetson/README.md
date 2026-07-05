# README
- This repo contains a docker environment that implements ros2, ardupilot-dds communication protocol, with pytorch embedded. It requires jetson-containers from https://github.com/dusty-nv/jetson-containers

# Installation
First clone the repository jetson-containers and build the `sandia-container` (later on would probably want to rename this to a generic name) run these following commands 
```
https://github.com/dusty-nv/jetson-containers
cd jetson-containers/
jetson-containers build --name=sandia_container pytorch ros:humble-ros-base
```
To verify the installation is done enter the following
```
docker images
```
You should then see something like this, the critical thing to note is that there is an image called `sandia_container:l4t-r36.4.7`
```bash
sandia_container:l4t-r36.4.7                       fd7ac8335f36       21.5GB             0B    U
sandia_container:l4t-r36.4.7-build-essential       69ad25e59f2f        763MB             0B
sandia_container:l4t-r36.4.7-cmake                 fadda8843b94       11.7GB             0B
sandia_container:l4t-r36.4.7-cuda                  1789f1f95442       5.84GB             0B
sandia_container:l4t-r36.4.7-cudastack_standard    0cb7ae502de6       11.2GB             0B
sandia_container:l4t-r36.4.7-ffmpeg                6615a7556ae1       16.2GB             0B
sandia_container:l4t-r36.4.7-llvm_21               90094b85fc67       12.9GB             0B
sandia_container:l4t-r36.4.7-llvm_22               ab8935a53c26       14.4GB             0B
sandia_container:l4t-r36.4.7-numpy                 58151499ca8a       11.6GB             0B
sandia_container:l4t-r36.4.7-onnx                  c4fb7d368896       11.7GB             0B
sandia_container:l4t-r36.4.7-opencv                7f6d832bc170       20.8GB             0B
sandia_container:l4t-r36.4.7-opengl                31ed247cbe06         13GB             0B
sandia_container:l4t-r36.4.7-pip_cache_cu126       9bed1fe0fc21        763MB             0B
sandia_container:l4t-r36.4.7-pybind11              8be4bbd62a35       20.8GB             0B
sandia_container:l4t-r36.4.7-python                a554c3f2d4bc       11.5GB             0B
sandia_container:l4t-r36.4.7-pytorch               82aee295f30e       12.8GB             0B
sandia_container:l4t-r36.4.7-ros_humble-ros-base   fd7ac8335f36       21.5GB             0B    U
sandia_container:l4t-r36.4.7-video-codec-sdk       b80a8c02cdff         16GB             0B
sandia_container:l4t-r36.4.7-vulkan                32c76e9247a5         16GB             0B
``` 
From there you are good to go now use that as your base image,now do the following
```
cd ardupilot_ros2_docker/docker_jetson
docker compose build -d
```
If installation is correct you should see this 
```
42e3a08cd1b1   local/ardupilot-ros2-dds-agent:jetson   "/ros_entrypoint.sh …"   5 minutes ago   Restarting (127) 59 seconds ago             ardupilot-ros2-dds-agent
```