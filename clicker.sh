#!/bin/bash

# Colors
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
purple='\033[0;35m'
cyan='\033[0;36m'
blue='\033[0;34m'
rest='\033[0m'

# If running in Termux, update and upgrade
if [ -d "$HOME/.termux" ] && [ -z "$(command -v jq)" ]; then
    echo "Running update & upgrade ..."
    pkg update -y
    pkg upgrade -y
fi

# Function to install necessary packages
install_packages() {
    local packages=(curl jq bc)
    local missing_packages=()

    # Check for missing packages
    for pkg in "${packages[@]}"; do
        if ! command -v "$pkg" &> /dev/null; then
            missing_packages+=("$pkg")
        fi
    done

    # If any package is missing, install missing packages
    if [ ${#missing_packages[@]} -gt 0 ]; then
        if [ -n "$(command -v pkg)" ]; then
            pkg install "${missing_packages[@]}" -y
        elif [ -n "$(command -v apt)" ]; then
            sudo apt update -y
            sudo apt install "${missing_packages[@]}" -y
        elif [ -n "$(command -v yum)" ]; then
            sudo yum update -y
            sudo yum install "${missing_packages[@]}" -y
        elif [ -n "$(command -v dnf)" ]; then
            sudo dnf update -y
            sudo dnf install "${missing_packages[@]}" -y
        else
            echo -e "${yellow}Unsupported package manager. Please install required packages manually.${rest}"
            exit 1
        fi
    fi
}

# Install the necessary packages
install_packages

# Clear the screen
clear
echo -e "${purple}=======${yellow} Hamster Combat Auto Clicker${purple}=======${rest}"
# Prompt for Authorization
echo ""
echo -en "${green}Enter Authorization [${cyan}Example: ${yellow}Bearer 171852....${green}]: ${rest}"
read -r Authorization
echo -e "${purple}============================${rest}"

# Prompt for coin capacity threshold
echo -en "${green}Enter Coin Capacity [${yellow}default:5000${green}]:${rest} "
read -r capacity
capacity=${capacity:-5000}


while true; do
    Taps=$(curl -s -X POST \
        https://api.hamsterkombatgame.io/clicker/sync \
        -H "Content-Type: application/json" \
        -H "Authorization: $Authorization" \
        -d '{}' | jq -r '.clickerUser.availableTaps')

    if [ "$Taps" -lt 30 ]; then
        echo "Taps are less than 30. Waiting to reach $capacity again..."
        while [ "$Taps" -lt $capacity ]; do
            Taps=$(curl -s -X POST \
                https://api.hamsterkombatgame.io/clicker/sync \
                -H "Content-Type: application/json" \
                -H "Authorization: $Authorization" \
                -d '{}' | jq -r '.clickerUser.availableTaps')
            sleep 5
        done
        continue
    fi

    random_sleep=$(shuf -i 20-60 -n 1)
    sleep $(echo "scale=3; $random_sleep / 1000" | bc)

    curl -s -X POST https://api.hamsterkombatgame.io/clicker/tap \
        -H "Content-Type: application/json" \
        -H "Authorization: $Authorization" \
        -d '{
            "availableTaps": '"$Taps"',
            "count": 3,
            "timestamp": '"$(date +%s)"'
        }' > /dev/null

    echo "Taps left: $Taps"
done
