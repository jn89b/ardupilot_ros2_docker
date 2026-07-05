#!/bin/bash
cd ../ 
# Set the ArduPilot repository URL
REPO_URL="https://github.com/ArduPilot/ardupilot.git"
CLONE_DIR="ardupilot"

# Number of threads for compiling (adjust based on your system)
NUM_THREADS=$(nproc)

# Function to handle errors
error_exit() {
    echo "❌ Error: $1"
    exit 1
}

echo "🚀 Cloning ArduPilot repository..."
if [ -d "$CLONE_DIR" ]; then
    echo "📂 ArduPilot directory already exists. Pulling latest changes..."
    cd "$CLONE_DIR" || error_exit "Failed to enter ArduPilot directory"
    git pull || error_exit "Failed to update repository"
else
    git clone --recurse-submodules "$REPO_URL" || error_exit "Failed to clone ArduPilot repository"
    cd "$CLONE_DIR" || error_exit "Failed to enter ArduPilot directory"
fi

echo "⚙️ Running setup script..."
bash Tools/environment_install/install-prereqs-ubuntu.sh -y || error_exit "Failed to run setup script"

echo "🔄 Reloading environment variables..."
. ~/.profile

echo "📦 Updating submodules..."
git submodule update --init --recursive || error_exit "Failed to update submodules"

echo "🚧 Building ArduPilot..."
./waf configure --board=sitl || error_exit "Failed to configure build"

echo "✅ Build completed successfully!"