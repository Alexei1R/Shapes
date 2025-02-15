#!/bin/bash

# Function to print separator
print_separator() {
    echo -e "\n===================================" | pbcopy
    echo "$1" | pbcopy
    echo "===================================" | pbcopy
}

# Function to copy file contents with path to clipboard
copy_file_contents() {
    if [ -f "$1" ]; then
        {
            echo -e "\n==================================="
            echo "FILE: $1"
            echo "==================================="
            cat "$1"
            echo -e "\n"
        } | pbcopy
        echo "✅ Copied contents of $1 to clipboard"
    else
        echo "❌ File not found: $1"
    fi
}

# Create temporary file for accumulated content
temp_file=$(mktemp)

# Start collecting content
{
    echo "Directory Structure as of $(date '+%Y-%m-%d %H:%M:%S')"
    echo "==================================="
    tree -L 3
    echo -e "\n"
} > "$temp_file"

# Array of target files
files=(
    "Engine/Drawable.swift"
    "Engine/Renderer/Model.swift"
    # "Engine/Renderer/Animation.swift"
    "Engine/Renderer/CustomAnimation.swift"

    "Views/ARUIView.swift"
    "Service/AnimationRecorder.swift"
    # "Engine/Utils/Time.swift"
    "Shaders/ModelShaders.metal"
    "Shaders/Circle.metal"
    "Engine/Primitives/Circle.swift"
    # "ContentView.swift"
    # "ScanView.swift"
    #
    # "Engine/Renderer/Camera.swift"
    # "Math/Math.swift"
)

# Append contents of each file to temp file
for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        {
            echo -e "\n==================================="
            echo "FILE: $file"
            echo "==================================="
            cat "$file"
            echo -e "\n"
        } >> "$temp_file"
        echo "✅ Added $file"
    else
        echo "❌ File not found: $file"
    fi
done

# Copy entire content to clipboard
cat "$temp_file" | pbcopy
echo "✨ All contents have been copied to clipboard!"

# Clean up
rm "$temp_file"
