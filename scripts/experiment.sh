#!/usr/bin/env bash

SCRIPTS="/catkin_ws/src/odo_vs_dc/scripts"
BAG="/catkin_ws/src/odo_vs_dc/bags/husky_odom_real.bag"
SESSION="odo_exp"
SETUP="source /opt/ros/melodic/setup.bash && source /lar_ws/devel/setup.bash && source /catkin_ws/devel/setup.bash"

# Carrega configuração externa (define WORLD, X, Y, Z, YAW)
source /catkin_ws/src/odo_vs_dc/scripts/experiment_config.sh

# Pasta de resultados com timestamp e nome do mundo
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
RESULTS="/catkin_ws/src/odo_vs_dc/resultados/${WORLD}_${TIMESTAMP}"

if [ "$WORLD" = "lar" ]; then
    LAUNCH="lar_gazebo lar_husky.launch"
else
    LAUNCH="husky_gazebo husky_empty_world.launch"
fi

source /opt/ros/melodic/setup.bash 2>/dev/null || true
source /lar_ws/devel/setup.bash    2>/dev/null || true
source /catkin_ws/devel/setup.bash 2>/dev/null || true

mkdir -p "$RESULTS"

# Salva configuração usada neste experimento
cat > "$RESULTS/config.txt" << EOF
Timestamp : $TIMESTAMP
Mundo     : $WORLD
Launch    : $LAUNCH
Bag       : $BAG
X         : $X
Y         : $Y
Z         : $Z
YAW       : $YAW
EOF

echo "==> Building odo_vs_dc..."
chmod +x /catkin_ws/src/odo_vs_dc/src/source.py
cd /catkin_ws && catkin_make -DCATKIN_ENABLE_TESTING=OFF
source /catkin_ws/devel/setup.bash
cd - > /dev/null

unset TMUX
tmux kill-session -t "$SESSION" 2>/dev/null || true

# Script chamado automaticamente quando o bag terminar
cat > /tmp/finish_experiment.sh << EOF
#!/bin/bash
sleep 1
tmux send-keys -t ${SESSION}:2 C-c
sleep 2
bash $SCRIPTS/to_csv.sh "$RESULTS"
EOF
chmod +x /tmp/finish_experiment.sh

# Janela 0 — Gazebo
tmux new-session -d -s "$SESSION" -n "gazebo"
tmux send-keys -t "$SESSION:0" \
    "$SETUP && roslaunch $LAUNCH x:=$X y:=$Y z:=$Z yaw:=$YAW" Enter

echo "==> Aguardando Gazebo iniciar..."
until rosservice list 2>/dev/null | grep -q '/gazebo/unpause_physics'; do
    sleep 2
done
echo "==> Gazebo pronto."
sleep 2

# Janela 1 — nó odo_vs_dc + rqt_plot
tmux new-window -t "$SESSION:1" -n "node"
tmux send-keys -t "$SESSION:1" "$SETUP && roslaunch odo_vs_dc loc0.launch" Enter
sleep 4

# Janela 2 — gravação
tmux new-window -t "$SESSION:2" -n "record"
tmux send-keys -t "$SESSION:2" \
    "$SETUP && rosbag record \
    /gt /odo /dr /odo_husky \
    /cmd_vel /cmd_vel_raw \
    /husky_velocity_controller/odom \
    /imu/data \
    -O $RESULTS/trajetorias.bag" Enter
sleep 2

# Janela 3 — bag (pausado, pressione ESPAÇO para iniciar)
tmux new-window -t "$SESSION:3" -n "bag"
tmux send-keys -t "$SESSION:3" \
    "$SETUP && rosbag play --pause $BAG \
    --topics /joy_teleop/cmd_vel \
    /joy_teleop/cmd_vel:=/cmd_vel_raw \
    && bash /tmp/finish_experiment.sh" Enter

echo ""
echo "==> Mundo: $WORLD | Posição: x=$X y=$Y z=$Z yaw=$YAW"
echo "==> Resultados em: $RESULTS"
echo ""
echo "==> 4 janelas criadas:"
echo "    Ctrl+B, 0 → gazebo"
echo "    Ctrl+B, 1 → node"
echo "    Ctrl+B, 2 → record"
echo "    Ctrl+B, 3 → bag  ← vá aqui e pressione ESPAÇO para iniciar"
echo ""

tmux select-window -t "$SESSION:3"
tmux attach-session -t "$SESSION"
