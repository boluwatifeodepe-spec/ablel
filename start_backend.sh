#!/bin/bash
# Start Able Media Extraction Backend & Tunnel

echo "Starting Able Media Extraction Backend..."
cd "$(dirname "$0")/backend" || exit
npm start
