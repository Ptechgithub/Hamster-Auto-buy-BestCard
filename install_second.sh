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
        fi
    fi
}

# Install the necessary packages
install_packages

# Clear the screen
clear

# Prompt for Authorization
echo -e "${purple}=======${yellow}Hamster Combat Auto Buy best cards${purple}=======${rest}"
echo ""
echo -en "${green}Enter Authorization [${cyan}Example: ${yellow}Bearer 171852....${green}]: ${rest}"
read -r Authorization
echo -e "${purple}============================${rest}"

# Prompt for minimum balance threshold
echo -en "${green}Enter minimum balance threshold (${yellow}the script will stop purchasing if the balance is below this amount${green}):${rest} "
read -r min_balance_threshold
echo -e "${purple}============================${rest}"

# Prompt for second card threshold
echo -en "${green}Enter the Threshold that you want to buy a new card? (${yellow}number below 1 to always buy the best card and greater then 1 to buying the second best card threshold${green}):${rest}"
read -r threshold

# Variables to keep track of total spent and total profit
total_spent=0
total_profit=0

# Function to purchase upgrade
purchase_upgrade() {
    upgrade_id="$1"
    timestamp=$(date +%s%3N)
    response=$(curl -s -X POST \
      -H "Content-Type: application/json" \
      -H "Authorization: $Authorization" \
      -H "Origin: https://hamsterkombat.io" \
      -H "Referer: https://hamsterkombat.io/" \
      -d "{\"upgradeId\": \"$upgrade_id\", \"timestamp\": $timestamp}" \
      https://api.hamsterkombatgame.io/clicker/buy-upgrade)
    echo "$response"
}

# Function to get the best upgrade item
get_best_item() {
    curl -s -X POST -H "User-Agent: Mozilla/5.0 (Android 12; Mobile; rv:102.0) Gecko/102.0 Firefox/102.0" \
        -H "Accept: */*" \
        -H "Accept-Language: en-US,en;q=0.5" \
        -H "Referer: https://hamsterkombat.io/" \
        -H "Authorization: $Authorization" \
        -H "Origin: https://hamsterkombat.io" \
        -H "Connection: keep-alive" \
        -H "Sec-Fetch-Dest: empty" \
        -H "Sec-Fetch-Mode: cors" \
        -H "Sec-Fetch-Site: same-site" \
        -H "Priority: u=4" \
        https://api.hamsterkombatgame.io/clicker/upgrades-for-buy | jq -r '.upgradesForBuy | map(select(.isExpired == false and .isAvailable)) | map(select(.profitPerHourDelta != 0 and .price != 0)) | sort_by(-(.profitPerHourDelta / .price))[:1] | .[0] | {id: .id, section: .section, price: .price, profitPerHourDelta: .profitPerHourDelta, cooldownSeconds: .cooldownSeconds}'
}

get_second_best_item() {
    curl -s -X POST -H "User-Agent: Mozilla/5.0 (Android 12; Mobile; rv:102.0) Gecko/102.0 Firefox/102.0" \
        -H "Accept: */*" \
        -H "Accept-Language: en-US,en;q=0.5" \
        -H "Referer: https://hamsterkombat.io/" \
        -H "Authorization: $Authorization" \
        -H "Origin: https://hamsterkombat.io" \
        -H "Connection: keep-alive" \
        -H "Sec-Fetch-Dest: empty" \
        -H "Sec-Fetch-Mode: cors" \
        -H "Sec-Fetch-Site: same-site" \
        -H "Priority: u=4" \
        https://api.hamsterkombatgame.io/clicker/upgrades-for-buy | jq -r '.upgradesForBuy | map(select(.isExpired == false and.isAvailable)) | map(select(.profitPerHourDelta!= 0 and.price!= 0)) | sort_by(-(.profitPerHourDelta /.price))[:2] |.[1] | {id:.id, section:.section, price:.price, profitPerHourDelta:.profitPerHourDelta, cooldownSeconds:.cooldownSeconds}'
}


# Function to wait for cooldown period with countdown
wait_for_cooldown() {
    cooldown_seconds="$1"
    echo -e "${yellow}Upgrade is on cooldown. Waiting for cooldown period of ${cyan}$cooldown_seconds${yellow} seconds...${rest}"
    while [ $cooldown_seconds -gt 0 ]; do
        echo -ne "${cyan}$cooldown_seconds\033[0K\r"
        sleep 1
        ((cooldown_seconds--))
    done
}

# Verify the best item
# Function to choose between two sets of values
choose() {
    local best_item_id=$1
    local section=$2 
    local price=$3 
    local profit=$4 
    local cooldown=$5 
    local next_item_id=$6 
    local next_item_section=$7 
    local next_item_price=$8 
    local next_item_profit=$9 
    local next_item_cooldown=$10

    # Calculate the ratios
    left_side=$(echo "($threshold) * ($price/$profit)" | bc -l) # Assuming best_price and best_profit are meant to be price and profit
    right_side=$(echo "$next_item_price/$next_item_profit" | bc -l) # Assuming next_price and next_item_profit are meant to be next_item_price and next_item_profit

    if [[ -z "$cooldown" || "$cooldown" -eq 0 ]]; then
        echo "$best_item_id"
    elif [[ -v next_item_cooldown && -n "$next_item_cooldown" && "$next_item_cooldown" -ne 0 ]]; then
        echo "$best_item_id"
    elif (( $(echo "$left_side > $right_side" | bc -l) )); then
        echo "$next_item_id"
    else
        echo "$best_item_id"
    fi
}




# Main script logic
main() {
    while true; do
        # Get the best item to buy
        best_item=$(get_best_item)
        best_item_id=$(echo "$best_item" | jq -r '.id')
        section=$(echo "$best_item" | jq -r '.section')
        price=$(echo "$best_item" | jq -r '.price')
        profit=$(echo "$best_item" | jq -r '.profitPerHourDelta')
        cooldown=$(echo "$best_item" | jq -r '.cooldownSeconds')
        echo -e "${blue}The best item to buy:${yellow} $best_item_id${rest}"

        # Get the second item
        second_item=$(get_second_best_item)
        
        next_item_id=$(echo "$second_item" | jq -r '.id')
        next_item_section=$(echo "$second_item" | jq -r '.section')
        next_item_price=$(echo "$second_item" | jq -r '.price')
        next_item_profit=$(echo "$second_item" | jq -r '.profitPerHourDelta')
        next_item_cooldown=$(echo "$best_item" | jq -r '.cooldownSeconds')
        echo -e "${blue}The Second best item to buy:${yellow} $next_item_id${rest}"

        # Use the choose function to determine the best set of values
        result=$(choose $best_item_id $section $price $profit $cooldown $next_item_id $next_item_section $next_item_price $next_item_profit $next_item_cooldown)
        
        echo -e "${blue}The best product that can be bought to save time:${yellow} $result${rest}"

        if [ "$result" == "$next_item_id" ]; then
            best_item_id="$next_item_id"
            section="$next_item_section"
            price="$next_item_price"
            profit="$next_item_profit"
            cooldown="$next_item_cooldown"
        fi

        echo -e "${purple}============================${rest}"
        echo -e "${green}Best item to buy:${yellow} $best_item_id ${green}in section:${yellow} $section${rest}"
        echo -e "${blue}Price: ${cyan}$price${rest}"
        echo -e "${blue}Profit per Hour: ${cyan}$profit${rest}"
        echo ""

        # Get current balanceCoins
        current_balance=$(curl -s -X POST \
            -H "Authorization: $Authorization" \
            -H "Origin: https://hamsterkombat.io" \
            -H "Referer: https://hamsterkombat.io/" \
            https://api.hamsterkombatgame.io/clicker/sync | jq -r '.clickerUser.balanceCoins')

        # Check if current balance is above the threshold after purchase
        if (( $(echo "$current_balance - $price > $min_balance_threshold" | bc -l) )); then
            # Attempt to purchase the best upgrade item
            if [ -n "$best_item_id" ]; then
                echo -e "${green}Attempting to purchase upgrade '${yellow}$best_item_id${green}'...${rest}"
                echo ""

                purchase_status=$(purchase_upgrade "$best_item_id")

                if echo "$purchase_status" | grep -q "error_code"; then
                    wait_for_cooldown "$cooldown"
                else
                    purchase_time=$(date +"%Y-%m-%d %H:%M:%S")
                    total_spent=$(echo "$total_spent + $price" | bc)
                    total_profit=$(echo "$total_profit + $profit" | bc)
                    current_balance=$(echo "$current_balance - $price" | bc)

                    echo -e "${green}Upgrade ${yellow}'$best_item_id'${green} purchased successfully at ${cyan}$purchase_time${green}.${rest}"
                    echo -e "${green}Total spent so far: ${cyan}$total_spent${green} coins.${rest}"
                    echo -e "${green}Total profit added: ${cyan}$total_profit${green} coins per hour.${rest}"
                    echo -e "${green}Current balance: ${cyan}$current_balance${green} coins.${rest}"
                    
                    sleep_duration=$((RANDOM % 8 + 5))
                    echo -e "${green}Waiting for ${yellow}$sleep_duration${green} seconds before next purchase...${rest}"
                    while [ $sleep_duration -gt 0 ]; do
                        echo -ne "${cyan}$sleep_duration\033[0K\r${rest}"
                        sleep 1
                        ((sleep_duration--))
                    done
                fi
            else
                echo -e "${red}No valid item found to buy.${rest}"
                break
            fi
        else
            echo -e "${red}Current balance ${cyan}(${current_balance}) ${red}minus price of item ${cyan}(${price}) ${red}is below the threshold ${cyan}(${min_balance_threshold})${red}. Stopping purchases.${rest}"
            break
        fi
    done
}

# Execute the main function
main
