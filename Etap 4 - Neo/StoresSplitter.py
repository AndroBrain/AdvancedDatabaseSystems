import json

# Load the JSON data from the file
with open('stores.json', 'r') as file:
    store_data = json.load(file)

# Remove the "images" key from each object in the array
for store in store_data:
    store.pop("images", None)

# Save the updated data to a new file
with open('stores_new.json', 'w') as file:
    json.dump(store_data, file, indent=4)

print("The 'images' key has been successfully removed from all objects. Updated JSON saved as 'store_updated.json'.")
