#!/bin/bash

exit_on_error() {
    echo "Error: $1"
    exit 1
}

echo "Starting Node.js cleanup and reinstallation script..."

# Remove existing Node.js and npm installations system-wide
echo "Removing system-wide Node.js and npm installations..."
sudo rm -rf /usr/local/bin/node \
             /usr/local/bin/npm \
             /usr/local/lib/node_modules/npm \
             /usr/local/share/man/man1/node* \
             /usr/local/share/man/man1/npm*

# Search and remove Node.js and npm installations in all user home directories
echo "Removing Node.js and npm installations from all user home directories..."
for home_dir in /home/*; do
    if [ -d "$home_dir" ]; then
        echo "Cleaning in $home_dir..."
        sudo rm -rf "$home_dir/.npm" \
                     "$home_dir/.nvm" \
                     "$home_dir/.node-gyp" \
                     "$home_dir/.config/configstore/update-notifier-npm.json"
    fi
done

# Install Node.js (replace with the desired version)
NODE_VERSION="20.5.0"
echo "Installing Node.js version $NODE_VERSION..."

wget -q "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-x64.tar.xz" || exit_on_error "Failed to download Node.js"
sudo tar -C /usr/local --strip-components=1 -xJf "node-v$NODE_VERSION-linux-x64.tar.xz" || exit_on_error "Failed to extract Node.js"
rm "node-v$NODE_VERSION-linux-x64.tar.xz"

# Check installed versions using the newly installed Node.js and npm
echo "Checking installed versions..."
/usr/local/bin/node --version || exit_on_error "Node.js installation failed"
/usr/local/bin/npm --version || exit_on_error "npm installation failed"

echo "Node.js and npm have been successfully installed."
echo "Installed Node.js version: $(/usr/local/bin/node --version)"
echo "Installed npm version: $(/usr/local/bin/npm --version)"
