#!/bin/bash
# usage: render_page.sh <path-or-url e.g. /pipeline> <out.png> [width] [height]   (uses the local pretty-URL server on 8770)
U="$1"; case "$U" in http*) URL="$U";; *) URL="http://127.0.0.1:8770$U";; esac
"C:/Program Files/Google/Chrome/Application/chrome.exe" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 --window-size=${3:-1400},${4:-2400} --timeout=20000 --virtual-time-budget=8000 --screenshot="$2" "$URL" 2>&1 | grep -iE 'written|error' | head -2
