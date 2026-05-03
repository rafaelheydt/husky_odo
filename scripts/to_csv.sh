#!/usr/bin/env bash

RESULTS="${1:-/catkin_ws/src/odo_vs_dc/resultados_empty_theta}"
BAG="$RESULTS/trajetorias.bag"

source /opt/ros/melodic/setup.bash 2>/dev/null || true

echo "==> Convertendo $BAG para CSV..."

rostopic echo -b "$BAG" -p /gt          > "$RESULTS/gt.csv"
rostopic echo -b "$BAG" -p /odo         > "$RESULTS/odo.csv"
rostopic echo -b "$BAG" -p /dr          > "$RESULTS/dr.csv"
rostopic echo -b "$BAG" -p /odo_husky   > "$RESULTS/odo_husky.csv"

echo "==> CSVs salvos em $RESULTS:"
ls -lh "$RESULTS"/*.csv
