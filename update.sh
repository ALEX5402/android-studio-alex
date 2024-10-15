#!/bin/bash

# Exit immediately if any command fails
set -e

# Install necessary dependencies
pip install -r requirements.txt

# Run Python script and capture the output
python_output=$(python main.py)

# Extract desired version and sha256 from the Python output
desired_version=$(echo "$python_output" | jq -r '.version')
desired_sha256=$(echo "$python_output" | jq -r '.sha256')

echo "$desired_sha256"
# Define template and output files
PKGBUILD_TEMPLATE="PKGBUILD.template"
NEW_PKGBUILD="PKGBUILD"
CURRENT_VERSION_FILE="currentversion.txt"

# Extract the current version from the currentversion.txt file
if [ -f "$CURRENT_VERSION_FILE" ]; then
    current_version=$(cat "$CURRENT_VERSION_FILE" | tr -d '[:space:]')
else
    echo "currentversion.txt not found. Assuming no current version."
    current_version=""
fi

# Function to generate a new PKGBUILD file with updated version and sha256
generate_pkgbuild() {
    echo "Generating a new PKGBUILD with version $desired_version and sha256 $desired_sha256"
    sed "s/{VERSION}/$desired_version/g; s/{SHA256}/$desired_sha256/g" "$PKGBUILD_TEMPLATE" > "$NEW_PKGBUILD"
    echo "$desired_version" > currentversion.txt
}

# Compare current and desired versions
if [ "$current_version" != "$desired_version" ]; then
    echo "The current version ($current_version) is lower than $desired_version."

    TAG_NAME=$(git show -s --format=%B HEAD | sed 's/[ \/]*//g')
    echo "TAG_NAME=$TAG_NAME" >> $GITHUB_ENV

    # Set up git configuration
    git config --global user.name "${GITHUB_ACTOR}"
    git config --global user.email "${GITHUB_ACTOR}@users.noreply.github.com"

    generate_pkgbuild
    # Create and push a Git tag
    # git tag "$TAG_NAME"
    git add currentversion.txt
    git add PKGBUILD
    git commit -m "update to : $desired_version"
    git push origin main

    # Generate a new PKGBUILD file with the new version and sha256

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
