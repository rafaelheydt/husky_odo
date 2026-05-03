# odo_vs_dc — Odometria vs Dead Reckoning

Pacote ROS 1 (Melodic) para comparar métodos de estimativa de posição do robô Husky:

| Tópico publicado | Descrição |
|---|---|
| `/gt` | Ground truth via serviço Gazebo |
| `/odo` | Odometria por integração de `/cmd_vel` |
| `/dr` | Dead reckoning com IMU |
| `/odo_husky` | Odometria das rodas do Husky |

---

## Requisitos

- Docker
- Sistema com display (X11) para Gazebo e rqt_plot

---

## Estrutura

```
odo_vs_dc/
├── Dockerfile                  # Imagem ROS Melodic + dependências
├── scripts/
│   ├── experiment.sh           # Script principal
│   ├── experiment_config.sh    # Configuração do experimento
│   └── to_csv.sh               # Converte bag gravado para CSV
├── src/
│   └── source.py               # Nó ROS principal
├── launch/
│   └── loc0.launch             # Launch do nó + rqt_plot
└── bags/
    └── husky_odom_real.bag     # Bag com dados reais do Husky
```

---

## 1. Build da imagem Docker

Apenas na primeira vez (ou após alterar o Dockerfile):

```bash
cd ~/odo_vs_dc
docker build -t odo_vs_dc_ros .
```

---

## 2. Configurar o experimento

Edite `scripts/experiment_config.sh`:

```bash
# Mundo: "empty" ou "lar"
WORLD="empty"

# Posição inicial do Husky
X=0.730655756085
Y=-0.112224212486
Z=0.1
YAW=0.2936
```

| WORLD | Descrição |
|---|---|
| `empty` | Mundo vazio (sem obstáculos) |
| `lar` | Laboratório LAR-UFBA com móveis e paredes |

---

## 3. Iniciar o container

```bash
xhost +local:docker

docker run -it --rm \
    --name odo_sim \
    --net=host \
    -e DISPLAY=$DISPLAY \
    -e LIBGL_ALWAYS_SOFTWARE=1 \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -v ~/odo_vs_dc:/catkin_ws/src/odo_vs_dc \
    odo_vs_dc_ros bash
```

---

## 4. Rodar o experimento

Dentro do container:

```bash
bash /catkin_ws/src/odo_vs_dc/scripts/experiment.sh
```

O script irá:
1. Compilar o pacote `odo_vs_dc`
2. Abrir 4 janelas tmux automaticamente
3. Aguardar o Gazebo iniciar
4. Iniciar o nó `odo_vs_dc` e os gráficos `rqt_plot`
5. Iniciar a gravação do bag de resultados

---

## 5. Iniciar a reprodução

Ao entrar no tmux, você estará na janela `bag`. Pressione **ESPAÇO** para iniciar.

### Navegar entre janelas

| Atalho | Janela |
|---|---|
| `Ctrl+B, 0` | Gazebo |
| `Ctrl+B, 1` | Nó odo_vs_dc + plots |
| `Ctrl+B, 2` | Gravação do bag |
| `Ctrl+B, 3` | Reprodução do bag |
| `Ctrl+B, W` | Lista todas as janelas |

---

## 6. Resultados

Quando o bag terminar, automaticamente:
- A gravação é encerrada
- Os CSVs são gerados

Os resultados ficam em:

```
resultados/<mundo>_<timestamp>/
├── config.txt        # Configuração usada
├── trajetorias.bag   # Bag gravado
├── gt.csv            # Ground truth
├── odo.csv           # Odometria por cmd_vel
├── dr.csv            # Dead reckoning (IMU)
└── odo_husky.csv     # Odometria das rodas
```

---

## Dependências ROS

- `husky_gazebo`, `husky_control`, `husky_description`
- `gazebo_ros`, `gazebo_plugins`, `gazebo_ros_control`
- `hector_gazebo_plugins`
- `topic_tools`, `rqt_plot`
- [lar_gazebo (branch melodic)](https://github.com/lar-deeufba/lar_gazebo/tree/melodic)
