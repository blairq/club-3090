#!/bin/bash
# ===========================================================================
# 🛑 AI SERVICES SHUTDOWN CONTROL SCRIPT
# Usage: ./ai-down.sh [engine]
#   - [engine]: club-3090 OR beellama.cpp (Optional, stops both if omitted)
# ===========================================================================

ENGINE=$1

stop_club3090() {
    if [ -d "/home/usuario/Proyectos/club-3090/models/qwen3.6-27b/vllm/compose/single" ]; then
        echo "🛑 Deteniendo el contenedor de IA vLLM (club-3090, 1 GPU)..."
        cd /home/usuario/Proyectos/club-3090/models/qwen3.6-27b/vllm/compose/single && docker compose down
    fi
    if [ -d "/home/usuario/Proyectos/club-3090/models/qwen3.6-27b/vllm/compose/dual" ]; then
        echo "🛑 Deteniendo el contenedor de IA vLLM (club-3090, Dual GPU)..."
        cd /home/usuario/Proyectos/club-3090/models/qwen3.6-27b/vllm/compose/dual && docker compose down
    fi
}

stop_beellama() {
    if [ -d "/home/usuario/Proyectos/llm_tests/beellama.cpp" ]; then
        echo "🛑 Deteniendo el contenedor de BeeLlama.cpp Speculative Server..."
        cd /home/usuario/Proyectos/llm_tests/beellama.cpp && docker compose down
    fi
}

stop_openwebui() {
    if [ -d "/home/usuario/Proyectos/open-webui" ]; then
        echo "🛑 Deteniendo los contenedores de Open WebUI y dependencias..."
        cd /home/usuario/Proyectos/open-webui && docker compose down
    fi
}

# Orchestrate the shutdown based on input arguments
if [ -n "$ENGINE" ]; then
    if [ "$ENGINE" == "club-3090" ]; then
        stop_club3090
        stop_openwebui
    elif [ "$ENGINE" == "beellama.cpp" ]; then
        stop_beellama
        stop_openwebui
    else
        echo "❌ Error: Motor '$ENGINE' no reconocido."
        echo "Uso: $0 [club-3090|beellama.cpp]"
        exit 1
    fi
else
    # Default: Stop everything to ensure a clean slate and free RTX 3090 VRAM completely
    echo "🛑 Deteniendo TODOS los motores de IA activos para liberar VRAM..."
    stop_beellama
    stop_club3090
    stop_openwebui
fi

echo "=========================================================="
echo "✅ Todos los servicios seleccionados fueron desactivados."
echo "=========================================================="
