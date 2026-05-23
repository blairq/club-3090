#!/bin/bash
# ===========================================================================
# 📋 AI SERVICES LOGS STREAMER SCRIPT
# Usage: ./ai-logs.sh [engine]
#   - [engine]: club-3090 OR beellama.cpp (Auto-detects if omitted)
# ===========================================================================

ENGINE=$1

show_club3090_logs() {
    echo "📋 Mostrando logs de vLLM (club-3090)..."
    # Check if the dual container is active, and if so, show its logs
    DUAL_ACTIVE=$(docker ps --filter "name=vllm-qwen36-27b-dual" --quiet)
    if [ -n "$DUAL_ACTIVE" ]; then
        cd /home/usuario/Proyectos/club-3090/models/qwen3.6-27b/vllm/compose/dual || exit 1
    else
        cd /home/usuario/Proyectos/club-3090/models/qwen3.6-27b/vllm/compose/single || exit 1
    fi
    docker compose logs -f --tail=100
}

show_beellama_logs() {
    echo "📋 Mostrando logs de BeeLlama.cpp Speculative Server..."
    cd /home/usuario/Proyectos/llm_tests/beellama.cpp || exit 1
    docker compose logs -f --tail=100
}

# Auto-detection logic if no parameter is given
if [ -z "$ENGINE" ]; then
    echo "🔍 Detectando motor activo..."
    BEELLAMA_ACTIVE=$(docker ps --filter "name=beellama-server" --quiet)
    VLLM_ACTIVE=$(docker ps --filter "name=vllm-qwen36-27b" --quiet)
    if [ -z "$VLLM_ACTIVE" ]; then
        VLLM_ACTIVE=$(docker ps --filter "name=vllm-qwen36-27b-dual" --quiet)
    fi
    
    if [ -n "$BEELLAMA_ACTIVE" ]; then
        show_beellama_logs
    elif [ -n "$VLLM_ACTIVE" ]; then
        show_club3090_logs
    else
        echo "❌ No se detectó ningún motor de API actualmente en ejecución."
        echo "Uso: $0 [club-3090|beellama.cpp]"
        exit 1
    fi
else
    if [ "$ENGINE" == "club-3090" ]; then
        show_club3090_logs
    elif [ "$ENGINE" == "beellama.cpp" ]; then
        show_beellama_logs
    else
        echo "❌ Error: Motor '$ENGINE' no reconocido."
        echo "Uso: $0 [club-3090|beellama.cpp]"
        exit 1
    fi
fi
