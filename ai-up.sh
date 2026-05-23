#!/bin/bash
# ===========================================================================
# 🚀 AI SERVICES STARTUP CONTROL SCRIPT
# Usage: ./ai-up.sh <engine> [gpu_count]
#   - <engine>   : club-3090 (vLLM) OR beellama.cpp (llama.cpp)
#   - [gpu_count]: 1 or 2 (Only for beellama.cpp, defaults to 2)
# ===========================================================================

ENGINE=$1
GPU_COUNT=$2

# Help/Usage function
print_usage() {
    echo "=========================================================="
    echo "❌ ERROR: Parámetros inválidos o incompletos."
    echo "=========================================================="
    echo "Uso correcto:"
    echo "  $0 <engine> [gpu_count]"
    echo ""
    echo "Motores de API disponibles (<engine>):"
    echo "  • club-3090   : Lanza vLLM Engine (Soporta 1 o 2 GPUs, TP=1 o TP=2)"
    echo "  • beellama.cpp : Lanza BeeLlama.cpp Speculative Engine (Soporta 1 o 2 GPUs)"
    echo ""
    echo "Especificación de GPUs ([gpu_count]):"
    echo "  • 1           : Lanza el motor en 1 GPU [Predeterminado para club-3090]"
    echo "  • 2           : Lanza el motor en Dual GPU [Predeterminado para beellama.cpp]"
    echo "=========================================================="
    exit 1
}

# Validate inputs
if [ -z "$ENGINE" ]; then
    print_usage
fi

if [ "$ENGINE" != "club-3090" ] && [ "$ENGINE" != "beellama.cpp" ]; then
    echo "❌ Error: Motor '$ENGINE' no reconocido."
    print_usage
fi

# Default GPU_COUNT if not provided
if [ -z "$GPU_COUNT" ]; then
    if [ "$ENGINE" == "beellama.cpp" ]; then
        GPU_COUNT=2
    else
        GPU_COUNT=1
    fi
fi

# Ensure valid GPU count
if [ "$GPU_COUNT" -ne 1 ] && [ "$GPU_COUNT" -ne 2 ]; then
    echo "❌ Error: Cantidad de GPUs debe ser 1 o 2."
    print_usage
fi

# Ensure no port conflict or existing instances are running (clean switch)
echo "🧹 Realizando limpieza previa de motores activos para evitar conflictos de VRAM..."
# Stop both club-3090 variants if they could conflict
if [ "$ENGINE" != "club-3090" ] || [ "$GPU_COUNT" -ne 1 ]; then
    if [ -d "/home/usuario/Proyectos/club-3090/models/qwen3.6-27b/vllm/compose/single" ]; then
        cd /home/usuario/Proyectos/club-3090/models/qwen3.6-27b/vllm/compose/single && docker compose down >/dev/null 2>&1 || true
    fi
fi
if [ "$ENGINE" != "club-3090" ] || [ "$GPU_COUNT" -ne 2 ]; then
    if [ -d "/home/usuario/Proyectos/club-3090/models/qwen3.6-27b/vllm/compose/dual" ]; then
        cd /home/usuario/Proyectos/club-3090/models/qwen3.6-27b/vllm/compose/dual && docker compose down >/dev/null 2>&1 || true
    fi
fi
if [ "$ENGINE" != "beellama.cpp" ]; then
    if [ -d "/home/usuario/Proyectos/llm_tests/beellama.cpp" ]; then
        cd /home/usuario/Proyectos/llm_tests/beellama.cpp && docker compose down >/dev/null 2>&1 || true
    fi
fi

# Launch the selected engine
if [ "$ENGINE" == "beellama.cpp" ]; then
    echo "🚀 Levantando BeeLlama.cpp Speculative Server ($GPU_COUNT GPU/s)..."
    cd /home/usuario/Proyectos/llm_tests/beellama.cpp || exit 1
    
    if [ "$GPU_COUNT" -eq 1 ]; then
        export NVIDIA_VISIBLE_DEVICES="0"
        export BEELLAMA_GPUS=1
    else
        export NVIDIA_VISIBLE_DEVICES="all"
        export BEELLAMA_GPUS=2
    fi
    
    export BEELLAMA_API_KEY=${BEELLAMA_API_KEY:-"super-secret-key-123"}
    docker compose up -d
    ACTIVE_CONTAINER="beellama-server"
    ENGINE_NAME="BeeLlama.cpp Speculative Server ($GPU_COUNT GPU/s)"
    API_KEY_INFO="$BEELLAMA_API_KEY"
else
    if [ "$GPU_COUNT" -eq 1 ]; then
        echo "🚀 Levantando vLLM Engine (club-3090, 1 GPU)..."
        cd /home/usuario/Proyectos/club-3090/models/qwen3.6-27b/vllm/compose/single || exit 1
        
        # Extract API Key from vLLM .env
        ENV_FILE="/home/usuario/Proyectos/club-3090/models/qwen3.6-27b/vllm/compose/single/.env"
        if [ -f "$ENV_FILE" ]; then
            API_KEY=$(grep -E "^VLLM_API_KEY=" "$ENV_FILE" | cut -d= -f2-)
        fi
        export VLLM_API_KEY=${API_KEY:-"super-secret-key-123"}
        docker compose up -d
        ACTIVE_CONTAINER="vllm-qwen36-27b"
        ENGINE_NAME="vLLM Engine (Qwen3.6-27b-autoround, 1 GPU)"
        API_KEY_INFO="$VLLM_API_KEY"
    else
        echo "🚀 Levantando vLLM Engine (club-3090, Dual GPU)..."
        cd /home/usuario/Proyectos/club-3090/models/qwen3.6-27b/vllm/compose/dual || exit 1
        
        # Extract API Key from vLLM single .env or use default
        ENV_FILE="/home/usuario/Proyectos/club-3090/models/qwen3.6-27b/vllm/compose/single/.env"
        if [ -f "$ENV_FILE" ]; then
            API_KEY=$(grep -E "^VLLM_API_KEY=" "$ENV_FILE" | cut -d= -f2-)
        fi
        export VLLM_API_KEY=${API_KEY:-"super-secret-key-123"}
        
        # Ensure a .env file exists in the dual directory for local manual invocations
        DUAL_ENV_FILE="/home/usuario/Proyectos/club-3090/models/qwen3.6-27b/vllm/compose/dual/.env"
        if [ ! -f "$DUAL_ENV_FILE" ]; then
            echo "VLLM_API_KEY=$VLLM_API_KEY" > "$DUAL_ENV_FILE"
        fi
        
        docker compose up -d
        ACTIVE_CONTAINER="vllm-qwen36-27b-dual"
        ENGINE_NAME="vLLM Engine (Qwen3.6-27b-autoround, Dual GPU)"
        API_KEY_INFO="$VLLM_API_KEY"
    fi
fi

# Always start Open WebUI
echo "🚀 Levantando el contenedor de Open WebUI..."
cd /home/usuario/Proyectos/open-webui || exit 1
docker compose up -d

echo ""
echo "🔍 Comprobando estado de los servicios activos..."
docker ps --filter "name=$ACTIVE_CONTAINER" --filter "name=open-webui" --filter "name=open-terminal"

# Dynamic host Network IP detection (IPv4 / Globally Routable IPv6)
HOST_IPV4=$(ip -4 addr show br0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1)
if [ -z "$HOST_IPV4" ]; then
    HOST_IPV4=$(ip route get 1.1.1.1 2>/dev/null | grep -oP '(?<=src\s)\d+(\.\d+){3}' | head -n1)
fi
if [ -z "$HOST_IPV4" ]; then
    HOST_IPV4=$(hostname -I | awk '{print $1}')
fi

HOST_IPV6=$(ip -6 addr show br0 2>/dev/null | grep "scope global" | grep -v "temporary" | awk '{print $2}' | cut -d/ -f1 | head -n1)
if [ -z "$HOST_IPV6" ]; then
    HOST_IPV6=$(ip -6 addr show 2>/dev/null | grep "scope global" | grep -v "temporary" | awk '{print $2}' | cut -d/ -f1 | head -n1)
fi

# ===========================================================================
# 🎨 HIGH-PREMIUM SERVICES BORDER CARD STATUS
# ===========================================================================
echo ""
echo -e "\e[1;36m╔══════════════════════════════════════════════════════════════════════════════╗\e[0m"
echo -e "\e[1;36m║               🚀  SERVICIOS DE INTELIGENCIA ARTIFICIAL ACTIVADOS             ║\e[0m"
echo -e "\e[1;36m╚══════════════════════════════════════════════════════════════════════════════╝\e[0m"
echo ""
echo -e "  \e[1;33m1. Motor de Inferencia API Activo:\e[0m \e[1;32m$ENGINE_NAME\e[0m"
echo -e "     \e[90m──────────────────────────────────────────────────────────────────────────\e[0m"
echo -e "     • Endpoint IPv4 Local : \e[1;37mhttp://192.168.1.222:8000/v1\e[0m"
echo -e "     • Endpoint IPv6 Global: \e[1;35mhttp://[2803:9810:b6ea:b800::2]:8000/v1\e[0m"
echo -e "     • API Key Autorizada  : \e[1;33m$API_KEY_INFO\e[0m"
echo -e "     • Probar Endpoint     : \e[36mcurl http://192.168.1.222:8000/v1/models\e[0m"
echo ""
echo -e "  \e[1;33m2. Open WebUI (Interfaz Gráfica):\e[0m"
echo -e "     \e[90m──────────────────────────────────────────────────────────────────────────\e[0m"
echo -e "     • Acceso IPv4 Local   : \e[1;37mhttp://192.168.1.201:8080\e[0m"
echo -e "     • Acceso IPv6 Global  : \e[1;35mhttp://[2803:9810:b6ea:b800::3]:8080\e[0m"
echo -e "     • Primer Uso          : Crea la cuenta administrador en tu primer acceso"
echo ""
echo -e "  \e[1;33m3. Open Terminal (Entorno Integrado CLI):\e[0m"
echo -e "     \e[90m──────────────────────────────────────────────────────────────────────────\e[0m"
echo -e "     • Endpoint IPv4 Local : \e[1;37mhttp://192.168.1.203:8000\e[0m"
echo -e "     • Endpoint IPv6 Global: \e[1;35mhttp://[2803:9810:b6ea:b800::4]:8000\e[0m"
echo -e "     • API Key             : super-secret-terminal-key"
echo ""
echo -e "\e[1;31m  ⚠️  REQUISITO CRÍTICO DE ACCESO EXTERNO (RED BRIDGED TRANS-LAN):\e[0m"
echo -e "     \e[90m──────────────────────────────────────────────────────────────────────────\e[0m"
echo -e "     • Las direcciones IPv6 detalladas son \e[1;32mGLOBALES RUTEABLES (Bridge br0)\e[0m."
echo -e "     • Para acceder desde Internet o redes remotas de forma nativa,"
echo -e "       debes utilizar los endpoints IPv6 globales directamente (ej: desde tu cliente)."
echo -e "     • IP Pública/Local del Servidor Host (br0):"
echo -e "       - IPv4 Host Local : \e[1;32m$HOST_IPV4\e[0m"
if [ -n "$HOST_IPV6" ]; then
echo -e "       - IPv6 Host Global: \e[1;35m$HOST_IPV6\e[0m"
else
echo -e "       - IPv6 Host Global: \e[1;31m(No detectada IPv6 global en br0 host)\e[0m"
fi
echo ""
echo -e "\e[1;36m╚══════════════════════════════════════════════════════════════════════════════╝\e[0m"
echo ""
