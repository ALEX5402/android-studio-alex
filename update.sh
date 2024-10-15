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

TELEGRAM_BOT_TOKEN=$1

# Check if the token is provided
if [ -z "$TELEGRAM_BOT_TOKEN" ]; then
    echo "Error: Telegram bot token not provided. Pass the token as the first argument."
    exit 1
fi

# Telegram chat ID
TELEGRAM_CHAT_ID="1859836370"

# Function to send Telegram notification
send_telegram_notification() {
    message=$1
    curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
    -d chat_id="$TELEGRAM_CHAT_ID" \
    -d text="$message"
}


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
    generate_pkgbuild

    TAG_NAME=$(echo "v$desired_version" | sed 's/[ \/]*//g')
    echo "TAG_NAME=$TAG_NAME" >> $GITHUB_ENV

    # Set up git configuration
    git config --global user.name "${GITHUB_ACTOR}"
    git config --global user.email "${GITHUB_ACTOR}@users.noreply.github.com"

    # Generate a new PKGBUILD file with the new version and sha256
    mkdir temp
    cp PKGBUILD temp
    cp android-studio-alex.desktop temp
    cp license.html temp

    cd temp
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
    pwd
     if ls *.pkg.tar.zst 1> /dev/null 2>&1; then
        echo "Package generated successfully. Copying it to parent directory."
        sudo cp *.pkg.tar.zst ../../
        # Ensure builder user owns the workspace
        send_telegram_notification "New Android Studio Version: $desired_version https://github.com/ALEX5402/android-studio-alex/releases/download/$TAG_NAME/android-studio-alex-$desired_version-x86_64.pkg.tar.zst"
    else
        echo "Error: Package not generated."
        send_telegram_notification "Error: Package generation failed for version $desired_version."
        exit 1
    fi
    cd ..
    # Add and commit the changes
    git add currentversion.txt PKGBUILD
    git commit -m "update to: $desired_version"
    git push origin main
else
    echo "The current version ($current_version) is up to date."
fi
