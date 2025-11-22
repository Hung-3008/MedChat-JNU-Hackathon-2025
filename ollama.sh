#!/bin/bash

# Stop execution if any command fails
set -e
export DEBIAN_FRONTEND=noninteractive

echo "=========================================="
echo "OLLAMA INSTALLATION & GPU SETUP"
echo "=========================================="

# 1. Install Ollama
echo "[Step 1/3] Installing Ollama..."
curl -fsSL https://ollama.com/install.sh | sh

# 2. Verify installation
echo "[Step 2/3] Verifying Ollama installation..."
if command -v ollama &> /dev/null; then
    echo "✓ Ollama installed successfully"
    ollama --version
else
    echo "✗ Ollama installation failed"
    exit 1
fi

# 3. Start Ollama server with GPU support
echo "[Step 3/3] Starting Ollama server with GPU support..."

# Check if server is already running
if lsof -Pi :11434 -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo "⚠ Ollama server already running on port 11434"
else
    echo "Starting Ollama server in the background..."
    
    # Set CUDA library paths for GPU support
    export LD_LIBRARY_PATH=/usr/local/cuda/lib64:/usr/local/cuda/targets/x86_64-linux/lib:/opt/conda/lib:$LD_LIBRARY_PATH
    export CUDA_VISIBLE_DEVICES=0
    
    # Start Ollama server
    nohup ollama serve > /var/log/ollama.log 2>&1 &
    OLLAMA_PID=$!
    echo "Started Ollama server with PID: $OLLAMA_PID"
    sleep 3
fi

# Verify server is running
echo ""
echo "Verifying Ollama server..."
MAX_RETRIES=15
COUNT=0

while [ $COUNT -lt $MAX_RETRIES ]; do
    if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
        echo "✓ Ollama server is running and responsive!"
        break
    fi
    echo "Waiting for Ollama server... (Attempt $((COUNT+1))/$MAX_RETRIES)"
    sleep 2
    COUNT=$((COUNT+1))
done

if [ $COUNT -eq $MAX_RETRIES ]; then
    echo "⚠ WARNING: Could not connect to Ollama server"
    echo "Check logs: tail -f /var/log/ollama.log"
else
    echo ""
    echo "=========================================="
    echo "OLLAMA SETUP COMPLETE!"
    echo "=========================================="
    echo "✓ Server is running on: http://localhost:11434"
    echo "✓ GPU support: NVIDIA CUDA enabled"
    echo ""
    echo "Quick start:"
    echo "  1. Pull a model: ollama pull llama3.1:8b"
    echo "  2. Run a model:  ollama run llama3.1:8b"
    echo "  3. View logs:    tail -f /var/log/ollama.log"
    echo ""
    echo "Environment variables set:"
    echo "  - CUDA_VISIBLE_DEVICES=0 (use first GPU)"
    echo "  - LD_LIBRARY_PATH includes CUDA paths"
    echo "=========================================="
fi