from requests import post
from time import time , sleep
from random import choice
from heapq import heappush, heappop

# Colors for terminal output
class Colors:
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[0;33m'
    PURPLE = '\033[0;35m'
    CYAN = '\033[0;36m'
    BLUE = '\033[0;34m'
    RESET = '\033[0m'

# Function to wait for cooldown period
def wait_for_cooldown(cooldown_seconds):
    print(f"{Colors.YELLOW}Upgrade is on cooldown. Waiting for cooldown period of {Colors.CYAN}{cooldown_seconds}{Colors.YELLOW} seconds...{Colors.RESET}")
    sleep(cooldown_seconds)

authorization = input(f"{Colors.GREEN}Enter Authorization [{Colors.CYAN}Example: {Colors.YELLOW}Bearer 171852....{Colors.GREEN}]: {Colors.RESET}")
print(f"{Colors.PURPLE}============================{Colors.RESET}")

# Prompt for minimum balance threshold
min_balance_threshold = float(input(f"{Colors.GREEN}Enter minimum balance threshold ({Colors.YELLOW}the script will stop purchasing if the balance is below this amount{Colors.GREEN}):{Colors.RESET} "))

print(f"{Colors.PURPLE}============================{Colors.RESET}")


# Function to purchase upgrade
def purchase_upgrade(authorization, upgrade_id):
    timestamp = int(time() * 1000)
    url = "https://api.hamsterkombatgame.io/clicker/buy-upgrade"
    headers = {
        "Content-Type": "application/json",
        "Authorization": authorization,
        "Origin": "https://hamsterkombat.io",
        "Referer": "https://hamsterkombat.io/"
    }
    data = {
        "upgradeId": upgrade_id,
        "timestamp": timestamp
    }
    response = post(url, headers=headers, json=data)
    return response.json()

# Headers for requests
headers = {
    'User-Agent': 'Mozilla/5.0 (Android 12; Mobile; rv:102.0) Gecko/102.0 Firefox/102.0',
    'Accept': '*/*',
    'Accept-Language': 'en-US,en;q=0.5',
    'Referer': 'https://hamsterkombat.io/',
    'Authorization': authorization,
    'Origin': 'https://hamsterkombat.io',
    'Connection': 'keep-alive',
    'Sec-Fetch-Dest': 'empty',
    'Sec-Fetch-Mode': 'cors',
    'Sec-Fetch-Site': 'same-site',
    'Priority': 'u=4',
}

# Get available upgrades
response = post('https://api.hamsterkombatgame.io/clicker/upgrades-for-buy', headers=headers).json()

class Node:
    def __init__(self, level, profit, weight, bound, selected):
        self.level = level
        self.profit = profit
        self.weight = weight
        self.bound = bound
        self.selected = selected

    def __lt__(self, other):
        return self.bound > other.bound

def calculate_bound(node, n, max_budget, upgrades):
    if node.weight >= max_budget:
        return 0

    profit_bound = node.profit
    j = node.level + 1
    total_weight = node.weight

    while j < n and total_weight + upgrades[j]["price"] <= max_budget:
        total_weight += upgrades[j]["price"]
        profit_bound += upgrades[j]["profitPerHourDelta"]
        j += 1

    if j < n and upgrades[j]["price"] != 0:
        profit_bound += (max_budget - total_weight) * upgrades[j]["profitPerHourDelta"] / upgrades[j]["price"]

    return profit_bound

def knapsack(upgrades, max_budget):
    upgrades.sort(key=lambda x: x["profitPerHourDelta"] / x["price"], reverse=True)
    n = len(upgrades)

    pq = []
    v = Node(-1, 0, 0, 0.0, [])
    max_profit = 0
    selected_upgrades = []
    heappush(pq, v)

    while pq:
        v = heappop(pq)

        if v.level == -1:
            u_level = 0
        elif v.level == n - 1:
            continue
        else:
            u_level = v.level + 1

        if u_level < n:
            u = Node(u_level, v.profit + upgrades[u_level]["profitPerHourDelta"], v.weight + upgrades[u_level]["price"], 0.0, v.selected + [upgrades[u_level]])
            u.bound = calculate_bound(u, n, max_budget, upgrades)

            if u.weight <= max_budget and u.profit > max_profit:
                max_profit = u.profit
                selected_upgrades = u.selected

            if u.bound > max_profit:
                heappush(pq, u)

        if u_level < n:
            u = Node(u_level, v.profit, v.weight, 0.0, v.selected)
            u.bound = calculate_bound(u, n, max_budget, upgrades)

            if u.bound > max_profit:
                heappush(pq, u)

    return max_profit, selected_upgrades

upgrades = [
    item for item in response["upgradesForBuy"]
    if not item["isExpired"] and item["isAvailable"] and item["price"] > 0
]

upgrades_with_ratios = []
for item in upgrades:
    max_budget = item["price"]
    max_profit, selected_upgrades = knapsack(upgrades, max_budget)
    if max_profit > item["profitPerHourDelta"] and item["profitPerHourDelta"] and max_profit > 10000:
        ratio = max_profit / max_budget * 100
        upgrades_with_ratios.append({
            'ratio': ratio,
            'max_profit': max_profit,
            'original_profit': item["profitPerHourDelta"],
            'budget': max_budget,
            'item': item,
            'selected_upgrades': selected_upgrades
        })

upgrades_with_ratios.sort(key=lambda x: x['ratio'], reverse=True)
i = 1
for upgrade in upgrades_with_ratios:
    print(f"{Colors.GREEN}{i}{Colors.RESET}) Ratio: {upgrade['ratio']:.2f}% - Max Profit: {Colors.YELLOW}{upgrade['max_profit']:,}{Colors.RESET} - Budget: {Colors.YELLOW}{upgrade['budget']:,}")
    i += 1
upgrades_num = int(input(f"{Colors.GREEN}Choice : {Colors.YELLOW}")) - 1

# Get current balance
url = "https://api.hamsterkombatgame.io/clicker/sync"
response = post(url, headers=headers)
current_balance = float(response.json()['clickerUser']['balanceCoins'])
selected_upgrades = upgrades_with_ratios[upgrades_num]['selected_upgrades']
print(f"{Colors.PURPLE}============================{Colors.RESET}")
print(f"{Colors.GREEN}Current Balance: {Colors.CYAN}{current_balance:,}{Colors.RESET}")
print(f"{Colors.GREEN}Expendable:{Colors.CYAN} {(current_balance - min_balance_threshold):,}{Colors.RESET}")
print(f"{Colors.GREEN}Number of Updates:{Colors.CYAN} {len(selected_upgrades)}{Colors.RESET}")

x = 0
for best_item in selected_upgrades:
    best_item_id = best_item['id']
    section = best_item['section']
    price = best_item['price']
    profit = best_item['profitPerHour']
    cooldown = best_item.get('cooldownSeconds',0)
    
    print(f"{Colors.PURPLE}============================{Colors.RESET}")
    print(f"{x+1}) {Colors.GREEN}Best item to buy:{Colors.YELLOW} {best_item_id} {Colors.GREEN}in section:{Colors.YELLOW} {section}{Colors.RESET}")
    print(f"{Colors.BLUE}Price: {Colors.CYAN}{price}{Colors.RESET}")
    print(f"{Colors.BLUE}Profit per Hour: {Colors.CYAN}{profit}{Colors.RESET}\n")
    x += 1

    # Check if current balance is above the threshold after purchase
    if current_balance - price > min_balance_threshold:
        print(f"{Colors.GREEN}Attempting to purchase upgrade '{Colors.YELLOW}{best_item_id}{Colors.GREEN}'...{Colors.RESET}\n")

        purchase_status = purchase_upgrade(authorization, best_item_id)

        if 'error_code' in purchase_status:
            wait_for_cooldown(cooldown)
            purchase_upgrade(authorization, best_item_id)
        else:
            print(f"{Colors.GREEN}Upgrade '{Colors.YELLOW}{best_item_id}{Colors.GREEN}' purchased successfully.{Colors.RESET}")
            print(f"{Colors.GREEN}Waiting 8 seconds before next purchase...{Colors.RESET}")
            
            sleep(8)  # Wait for 8 seconds after a successful purchase
    else:
        print(f"{Colors.RED}Current balance {Colors.CYAN}({current_balance}) {Colors.RED}minus price of item {Colors.CYAN}({price}) {Colors.RED}is below the threshold {Colors.CYAN}({min_balance_threshold}){Colors.RED}. Stopping purchases.{Colors.RESET}")
        break
else:
    if x != len(selected_upgrades):
    	print(f"{Colors.RED}No valid item found to buy.{Colors.RESET}")
    else:
    	print(f"{Colors.GREEN}Items Are Finished.{Colors.RESET}")
