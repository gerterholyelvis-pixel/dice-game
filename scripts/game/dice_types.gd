class_name DiceTypes
extends RefCounted
## Catalogue of die kinds. Each die has six faces holding pip counts (1..6).
## A face showing exactly one pip is a "burn" (see RunState).

const TYPES: Dictionary = {
	"bone": {
		"name": "Bone Die",
		"blurb": "Plain and honest. One face in six burns.",
		"faces": [1, 2, 3, 4, 5, 6],
		"body": Color(1.0, 0.97, 0.88),
		"pip": Color(1.0, 0.42, 0.08),
	},
	"obsidian": {
		"name": "Obsidian Die",
		"blurb": "Never burns. Steady and strong.",
		"faces": [2, 3, 4, 4, 5, 6],
		"body": Color(0.16, 0.12, 0.2),
		"pip": Color(0.75, 0.45, 1.0),
	},
	"gilded": {
		"name": "Gilded Die",
		"blurb": "Greedy: two sixes, but still one burn.",
		"faces": [1, 3, 4, 5, 6, 6],
		"body": Color(0.95, 0.72, 0.25),
		"pip": Color(0.45, 0.08, 0.02),
	},
	"cinder": {
		"name": "Cinder Die",
		"blurb": "Reckless: three sixes, two burns.",
		"faces": [1, 1, 4, 6, 6, 6],
		"body": Color(0.55, 0.12, 0.08),
		"pip": Color(1.0, 0.85, 0.3),
	},
}

const ORDER: Array[String] = ["bone", "obsidian", "gilded", "cinder"]


static func faces_of(type_id: String) -> Array[int]:
	var out: Array[int] = []
	for f: int in TYPES[type_id]["faces"]:
		out.append(f)
	return out


static func display_name(type_id: String) -> String:
	return TYPES[type_id]["name"]


static func average(type_id: String) -> float:
	var total: float = 0.0
	for f: int in TYPES[type_id]["faces"]:
		total += f
	return total / 6.0
