FROM ros:melodic

RUN apt-get update && apt-get install -y \
    git \
    python-catkin-tools \
    ros-melodic-topic-tools \
    ros-melodic-rqt-plot \
    ros-melodic-gazebo-ros \
    ros-melodic-gazebo-plugins \
    ros-melodic-gazebo-ros-control \
    ros-melodic-husky-gazebo \
    ros-melodic-husky-control \
    ros-melodic-husky-description \
    ros-melodic-hector-gazebo-plugins \
    ros-melodic-controller-manager \
    ros-melodic-pointcloud-to-laserscan \
    ros-melodic-joint-state-publisher \
    ros-melodic-robot-state-publisher \
    ros-melodic-rviz \
    ros-melodic-xacro \
    && rm -rf /var/lib/apt/lists/*

# Pre-build lar_gazebo (melodic branch) in a dedicated workspace
RUN /bin/bash -c "\
    mkdir -p /lar_ws/src && \
    cd /lar_ws/src && \
    git clone -b melodic https://github.com/lar-deeufba/lar_gazebo.git && \
    sed -i '/roslaunch_add_file_check/d' /lar_ws/src/lar_gazebo/CMakeLists.txt && \
    sed -i '/laser_enabled/d' /lar_ws/src/lar_gazebo/src/launch/lar_husky.launch && \
    cd /lar_ws && \
    source /opt/ros/melodic/setup.bash && \
    catkin_make -DCATKIN_ENABLE_TESTING=OFF \
"

# Workspace for odo_vs_dc (mounted at runtime via volume)
RUN mkdir -p /catkin_ws/src
WORKDIR /catkin_ws
