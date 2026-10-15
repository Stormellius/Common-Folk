class_name Soundscape
extends RefCounted
## What there is to hear where the camera is and when: how loud each ambient layer should be, and
## which mood the music should have. Plain functions of a "context" (the hour, the season, the weather,
## where the camera is and how close), so the rules can be tested without a speaker.
##
## context keys: hour (0 to 24), season (a season id), wet (0 to 1: rain or snow falling), snowing,
## wind (about 0.4 to 1.1), in_town, crowd (0 to 1: how many people are near), fire and water (0 to 1:
## how near a fire or water is), closeness (0 to 1: how far in the camera is zoomed), paused,
## sorrow (someone is dying, or has just died), festival (a fair or market is on in the town).

const LAYERS: Array[String] = ["wind", "rain", "snow", "water", "crickets", "birds", "hubbub", "fire"]
## How much birdsong and crickets each season has.
const BIRDS := { "spring": 1.0, "summer": 0.85, "autumn": 0.45, "winter": 0.1 }
const CRICKETS := { "spring": 0.5, "summer": 1.0, "autumn": 0.4, "winter": 0.0 }


## How loud each layer of the ambience should be, 0 to 1: { layer id: level }.
static func levels(context: Dictionary) -> Dictionary:
	var hour := float(context.get("hour", 12.0))
	var season := str(context.get("season", "spring"))
	var wet := float(context.get("wet", 0.0))
	var close := float(context.get("closeness", 1.0))
	var in_town := bool(context.get("in_town", false))
	var day := _between(hour, 5.0, 8.0) * (1.0 - _between(hour, 18.0, 20.5))  # 0 at night, 1 from morning to evening
	var dusk := 1.0 - day
	var found := {}
	found["wind"] = clampf((0.22 + 0.3 * (float(context.get("wind", 0.8)) - 0.4) / 0.7 + 0.3 * wet) * (0.55 + 0.45 * close), 0.0, 1.0)
	found["rain"] = smoothstep(0.15, 0.55, wet) if not bool(context.get("snowing", false)) else 0.0
	found["snow"] = smoothstep(0.15, 0.55, wet) if bool(context.get("snowing", false)) else 0.0
	found["water"] = clampf(float(context.get("water", 0.0)), 0.0, 1.0) * close
	found["birds"] = day * float(BIRDS.get(season, 0.5)) * (1.0 - wet) * (0.45 if in_town else 1.0) * close
	found["crickets"] = dusk * float(CRICKETS.get(season, 0.0)) * (1.0 - wet) * close
	var busy := day * 1.0 + dusk * 0.2
	found["hubbub"] = (clampf(float(context.get("crowd", 0.0)), 0.0, 1.0) * busy * close) if in_town else 0.0
	found["fire"] = clampf(float(context.get("fire", 0.0)), 0.0, 1.0) * sqrt(close)
	if bool(context.get("paused", false)):
		for id in found:
			found[id] = float(found[id]) * 0.35
	return found


## The mood the music should have (an id of data/music.json).
static func mood(context: Dictionary) -> String:
	if bool(context.get("sorrow", false)):
		return "sorrow"
	if bool(context.get("festival", false)):
		return "festival"
	var hour := float(context.get("hour", 12.0))
	if hour >= 5.5 and hour < 17.5:
		return "day"
	if hour >= 17.5 and hour < 21.5:
		return "evening"
	return "night"


## 0 before `from`, 1 from `to`, a smooth slope between.
static func _between(value: float, from: float, to: float) -> float:
	return smoothstep(from, to, value)
