#!/bin/bash

# Breakout Game Launcher
# Handles macOS-specific GLFW requirements

cd "$(dirname "$0")"

echo "Building Breakout..."
java -jar bin/flix.jar build

if [ $? -ne 0 ]; then
    echo "Build failed!"
    exit 1
fi

echo ""
echo "Starting Breakout..."
echo "Press ESC or close the window to exit."
echo ""

# Build classpath
CP="build/class"
CP="$CP:lib/external/SpriteRenderer.jar"
CP="$CP:lib/cache/https/repo1.maven.org/maven2/org/lwjgl/lwjgl/3.3.4/lwjgl-3.3.4.jar"
CP="$CP:lib/cache/https/repo1.maven.org/maven2/org/lwjgl/lwjgl-glfw/3.3.4/lwjgl-glfw-3.3.4.jar"
CP="$CP:lib/cache/https/repo1.maven.org/maven2/org/lwjgl/lwjgl-opengl/3.3.4/lwjgl-opengl-3.3.4.jar"
CP="$CP:lib/cache/https/repo1.maven.org/maven2/org/lwjgl/lwjgl-stb/3.3.4/lwjgl-stb-3.3.4.jar"

# Native library path
NATIVES="lib"

# Check if running on macOS
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS requires -XstartOnFirstThread for GLFW
    java -XstartOnFirstThread -Djava.library.path="$NATIVES" -cp "$CP" Main
else
    # Linux/Windows
    java -Djava.library.path="$NATIVES" -cp "$CP" Main
fi
