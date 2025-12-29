#!/bin/bash
# Commands to run droidrun with Google Gemini in Termux

# Set up environment
export PATH=/data/data/com.termux/files/usr/bin:$PATH
export HOME=/data/data/com.termux/files/home

# Set your Google Gemini API key here
export GOOGLE_API_KEY="YOUR_API_KEY_HERE"

# Example 1: List devices
echo "=== Listing devices ==="
python3 -m droidrun devices

# Example 2: Ping device
echo "=== Pinging device ==="
python3 -m droidrun ping

# Example 3: Run a simple command
echo "=== Running command with Gemini ==="
python3 -m droidrun run "list installed apps" \
  --provider GoogleGenAI \
  --model gemini-pro

# Example 4: Run with vision enabled
echo "=== Running with vision ==="
python3 -m droidrun run "take a screenshot and describe it" \
  --provider GoogleGenAI \
  --model gemini-pro-vision \
  --vision

# Example 5: Run with streaming
echo "=== Running with streaming ==="
python3 -m droidrun run "open settings" \
  --provider GoogleGenAI \
  --model gemini-pro \
  --stream

