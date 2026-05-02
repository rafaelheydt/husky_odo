#!/usr/bin/env bash
set -e

IMAGE="odo_vs_dc_ros"
PROJECT="$(cd "$(dirname "$0")" && pwd)"

echo "==> Building Docker image (downloads lar_gazebo, ~10 min first time)..."
docker build -t "$IMAGE" "$PROJECT"

echo "==> Allowing X11 forwarding..."
xhost +local:docker 2>/dev/null || true

echo "==> Starting container..."
docker run -it --rm \
    --net=host \
    -e DISPLAY="$DISPLAY" \
    -e LIBGL_ALWAYS_SOFTWARE=1 \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -v "$PROJECT:/catkin_ws/src/odo_vs_dc" \
    "$IMAGE" \
    bash -c "
        set -e
        trap 'kill \$(jobs -p) 2>/dev/null; exit' INT TERM EXIT

        source /opt/ros/melodic/setup.bash
        source /lar_ws/devel/setup.bash

        chmod +x /catkin_ws/src/odo_vs_dc/src/source.py

        echo '==> Building odo_vs_dc...'
        cd /catkin_ws && catkin_make -DCATKIN_ENABLE_TESTING=OFF
        source /catkin_ws/devel/setup.bash

        echo '==> Starting roscore...'
        roscore &
        sleep 3

        # Gazebo inicia pausado (paused:=true em lar_husky.launch).
        # O bag e o node sao lancados antes do unpause para garantir
        # que estao prontos quando a simulacao comecar.
        echo '==> Launching Gazebo + Husky in empty world (starts paused)...'
        roslaunch husky_gazebo husky_empty_world.launch gui:=true paused:=true \
            x:=0.730655756085 y:=-0.112224212486 z:=0.0 yaw:=0.2936 &

        echo '==> Waiting for Gazebo to be ready...'
        until rosservice list 2>/dev/null | grep -q '/gazebo/unpause_physics'; do
            echo '  Gazebo not ready yet, waiting 3s...'
            sleep 3
        done
        echo '  Gazebo is ready.'

        # A bag tem /joy_teleop/cmd_vel (teleop joystick) e
        # /husky_velocity_controller/odom (odometria real).
        # Remapeamos /joy_teleop/cmd_vel -> /cmd_vel para:
        #   - acionar o no odo_vs_dc (que subscreve /cmd_vel)
        #   - enviar comandos ao Husky simulado no Gazebo
        # O Gazebo fornece /husky_velocity_controller/odom/ e /imu/data.
        echo '==> Playing bag (/joy_teleop/cmd_vel remapped to /cmd_vel)...'
        rosbag play \
            /catkin_ws/src/odo_vs_dc/bags/husky_odom_real.bag \
            --topics /joy_teleop/cmd_vel \
            /joy_teleop/cmd_vel:=/cmd_vel &
        sleep 2

        echo '==> Launching odo_vs_dc node and rqt_plot windows...'
        roslaunch odo_vs_dc loc0.launch &
        sleep 3

        echo '==> Unpausing Gazebo...'
        rosservice call /gazebo/unpause_physics

        echo '==> All systems running. Ctrl+C to stop.'
        wait
    "
