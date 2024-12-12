import json


def nest_deals(deals):
    nested_deals = []

    for deal in deals:
        nested_deal = {
            "steam": {
                "steamRatingText": deal.get("steamRatingText"),
                "steamRatingPercent": deal.get("steamRatingPercent"),
                "steamRatingCount": deal.get("steamRatingCount"),
                "steamAppID": deal.get("steamAppID"),
            },
            "metacritic": {
                "metacriticLink": deal.get("metacriticLink"),
                "metacriticScore": deal.get("metacriticScore"),
            },
            "pricing": {
                "salePrice": deal.get("salePrice"),
                "normalPrice": deal.get("normalPrice"),
                "isOnSale": deal.get("isOnSale"),
                "savings": deal.get("savings"),
            },
            "game": {
                "internalName": deal.get("internalName"),
                "title": deal.get("title"),
                "gameID": deal.get("gameID"),
            },
            # Retain any other fields not explicitly nested
            **{k: v for k, v in deal.items() if k not in {
                "steamRatingText", "steamRatingPercent", "steamRatingCount", "steamAppID",
                "metacriticLink", "metacriticScore",
                "salePrice", "normalPrice", "isOnSale", "savings",
                "internalName", "title", "gameID"
            }}
        }

        nested_deals.append(nested_deal)

    return nested_deals

with open("deals.json", "r") as infile:
    deals = json.load(infile)

nested_deals = nest_deals(deals)

with open("nested_deals.json", "w") as outfile:
    json.dump(nested_deals, outfile, indent=4)