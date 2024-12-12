import json

# Load the JSON data from the file
with open('deals.json', 'r') as file:
    deals_data = json.load(file)

# Prepare data structures for the separate files
games = {}
steams = []
metacritics = []
deals_flattened = []

# ID counters for steams and metacritics
steam_id_counter = 1
metacritic_id_counter = 1

# Sets to track unique steam and metacritic gameIDs
processed_steam_gameIDs = set()
processed_metacritic_gameIDs = set()

# Process each deal in the JSON data
for deal in deals_data:
    # Extract game details
    game = deal.pop('game')
    game_id = game['gameID']

    # Ensure games are unique by internal title
    if game['internalName'] not in games:
        games[game['internalName']] = {
            "gameID": game_id,
            "internalName": game['internalName'],
            "title": game['title']
        }

    # Extract and process Steam data
    if 'steam' in deal and game_id not in processed_steam_gameIDs:
        steam = deal.pop('steam')
        steam['gameID'] = game_id
        steam['ID'] = steam_id_counter
        steams.append(steam)
        processed_steam_gameIDs.add(game_id)
        steam_id_counter += 1

    # Extract and process Metacritic data
    if 'metacritic' in deal and game_id not in processed_metacritic_gameIDs:
        metacritic = deal.pop('metacritic')
        metacritic['gameID'] = game_id
        metacritic['ID'] = metacritic_id_counter
        metacritics.append(metacritic)
        processed_metacritic_gameIDs.add(game_id)
        metacritic_id_counter += 1

    # Flatten pricing into the deal
    pricing = deal.pop('pricing')
    deal.update(pricing)

    # Add the deal to the flattened deals list
    deal['gameID'] = game_id
    deals_flattened.append(deal)

# Write the results to separate files
with open('deals_flattened.json', 'w') as file:
    json.dump(deals_flattened, file, indent=4)

with open('games.json', 'w') as file:
    json.dump(list(games.values()), file, indent=4)

with open('steams.json', 'w') as file:
    json.dump(steams, file, indent=4)

with open('metacritics.json', 'w') as file:
    json.dump(metacritics, file, indent=4)

print("JSON files created successfully!")
