import requests
import json

PAGES_TO_FETCH = 50
OUTPUT_FILE = "deals.json"

def fetch_deals(page_number):
    response = requests.get(f"https://www.cheapshark.com/api/1.0/deals?pageNumber={page_number}")
    if response.status_code == 200:
        return response.json()
    else:
        print(f"Fetch failure for page {page_number}: {response.status_code}")
        return []

all_deals = []

for page in range(1, PAGES_TO_FETCH + 1):
    print(f"Fetching page: {page}")
    all_deals.extend(fetch_deals(page))

with open(OUTPUT_FILE, "w") as f:
    json.dump(all_deals, f)

print(f"Merged {len(all_deals)} deals into {OUTPUT_FILE}")
