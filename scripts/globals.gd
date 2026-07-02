extends Node
## Global game state shared across scenes.

var hero: String = "emmy"   # "emmy" or "isla"

# currency + store upgrades (session-persistent; save file later)
var presents: int = 0
var atk_bonus: int = 0      # added to attack-card power
var heal_bonus: int = 0     # added to heal-card power
var sword_level: int = 1
