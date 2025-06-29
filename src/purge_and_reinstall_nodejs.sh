#!/bin/bash

exit_on_error() {
    echo "Error: $1"
    exit 1
}

echo "Starting Node.js cleanup and reinstallation script..."

# Remove existing Node.js and npm installations system-wide
echo "Removing system-wide Node.js, npm, and global node_modules..."
node_bin_path=$(which node)
npm_bin_path=$(which npm)
sudo rm -rf "$node_bin_path" \
    "$npm_bin_path" \
    /usr/local/lib/node_modules \
    /usr/local/share/man/man1/node* \
    /usr/local/share/man/man1/npm*

# Fetch the latest Node.js version
echo "Fetching the latest Node.js version..."
NODE_VERSION=$(curl -s https://nodejs.org/dist/latest/ | grep -oP 'node-v\K[\d.]+(?=-linux-x64.tar.xz)' | head -1)
if [ -z "$NODE_VERSION" ]; then
    exit_on_error "Failed to fetch the latest Node.js version"
fi
echo "Latest Node.js version: $NODE_VERSION"

# Install the latest Node.js version
echo "Installing Node.js version $NODE_VERSION..."
wget -q "https://nodejs.org/dist/latest/node-v$NODE_VERSION-linux-x64.tar.xz" || exit_on_error "Failed to download Node.js"
sudo tar -C /usr/local --strip-components=1 -xJf "node-v$NODE_VERSION-linux-x64.tar.xz" || exit_on_error "Failed to extract Node.js"
rm "node-v$NODE_VERSION-linux-x64.tar.xz"

# Check installed versions using the newly installed Node.js and npm
echo "Checking installed versions..."
/usr/local/bin/node --version || exit_on_error "Node.js installation failed"
/usr/local/bin/npm --version || exit_on_error "npm installation failed"

echo "Node.js and npm have been successfully installed."

# Adjust user-specific Node.js and npm files
for home_dir in /home/*; do
    if [ -d "$home_dir" ]; then
        username=$(basename "$home_dir")
        echo "Starting adjustment for $home_dir of user $username..."

        # Check for directory existence before deletion
        for dir in .npm .nvm .node-gyp .config/node_modules .config/configstore/update-notifier-npm.json package.json package-lock.json; do
            if [ -d "$home_dir/$dir" ] || [ -f "$home_dir/$dir" ]; then
                echo "Removing $dir in $home_dir"
                rm -rf "${home_dir:?}/$dir"
            fi
        done

        # Using find to change ownership and permissions
        find "$home_dir" \( -name '.npm' -o -name '.nvm' -o -name '.node-gyp' -o -name '.config' \) -exec chown -R "$username":"$username" {} + -exec chmod -R u+rwX,go+rX,go-w {} +

        echo "Adjustments completed for $username."
    fi
done

echo "Permissions adjusted for user-specific directories."
