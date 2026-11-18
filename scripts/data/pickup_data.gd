class_name PickupData
extends Resource
## What a pickup gives (resources/pickups/*.tres). A field a pickup does not use stays 0.

## Gold added to the level's score (coin).
@export var value: int = 0
## HP restored (potion).
@export var heal_amount: int = 0  # HP
