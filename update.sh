#!/bin/bash

# Exit immediately if any command fails
set -e

# Install necessary dependencies
pip install -r requirements.txt

# Run Python script and capture the output
python_output=$(python main.py)

# Extract desired version and sha256 from the Python output
desired_version=$(echo "$python_output" | grep -Po '"version":.*?[^\\]",' | sed 's/"version"://g' | tr -d '", ')
desired_sha256=$(echo "$python_output" | grep -Po '"sha256":.*?[^\\]",' | sed 's/"sha256"://g' | tr -d '", ')

# Define the PKGBUILD file
PKGBUILD_FILE="PKGBUILD"

# Extract the current version from the PKGBUILD file
current_version=$(grep "^pkgver=" "$PKGBUILD_FILE" | cut -d'=' -f2)

# Function to update the PKGBUILD version and sha256
update_pkgbuild() {
    echo "Updating PKGBUILD to version $desired_version with sha256 $desired_sha256"
    sed -i "s/^pkgver=.*/pkgver=$desired_version/" "$PKGBUILD_FILE"
    sed -i "s/sha256sums=('.*'/sha256sums=('$desired_sha256'/" "$PKGBUILD_FILE"
    git add "$PKGBUILD_FILE"
    git commit -m "Updated to version : $desired_version"
    git push origin main
}

# Compare current and desired versions
if [ "$(printf '%s\n' "$desired_version" "$current_version" | sort -V | head -n1)" != "$desired_version" ]; then
    echo "The current version ($current_version) is lower than $desired_version."

    # Set the tag name for GitHub environment (for actions)
    TAG_NAME=$(git show -s --format=%B HEAD | sed 's/[ \/]*//g')
    echo "TAG_NAME=$TAG_NAME" >> $GITHUB_ENV

    # Set up git configuration
    git config --global user.name "${GITHUB_ACTOR}"
    git config --global user.email "${GITHUB_ACTOR}@users.noreply.github.com"

    # Create and push a Git tag
    git tag "$TAG_NAME"

    # Update the PKGBUILD file with the new version and sha256
    update_pkgbuild

    # Run the build inside a Docker container with Arch Linux
    docker run --rm \
        -v $(pwd):/workspace -w /workspace archlinux:latest bash -c "
        echo 'Building Arch Linux package';
        pacman -Syu --noconfirm;
        pacman -S base-devel git sudo --noconfirm;

        # Create a non-root user for building the package
        useradd -m builder;
        echo 'builder ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers;

        # Ensure the builder user owns the workspace
        chown -R builder /workspace;

        # Switch to the non-root user and build the package
        sudo -u builder bash -c '
            git config --global --add safe.directory /workspace;
            makepkg -s --noconfirm;
        '
    "

else
    echo "The current version ($current_version) is up to date."
fi




