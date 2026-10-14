class_name SoundBank
extends RefCounted
## The game's sounds (data/sounds.json): each says how to make it ("recipe" and its numbers), whether
## it loops, and how loud it is. render() works one out as samples (safe off the main thread), stream()
## turns it into something to play and keeps it.
##
## Recipes: noise_bed (wind, rain), crickets, chirps (birds), murmur (a crowd), crackle (a fire),
## tone (a click, a cry), bell (bells, coins, an anvil), thump (a blow).

static var _streams: Dictionary = {}


static func ids() -> Array[String]:
	var found: Array[String] = []
	for def in DataRegistry.get_list("sounds"):
		found.append(str(def["id"]))
	return found


static func is_loop(sound_id: String) -> bool:
	return bool(DataRegistry.get_def("sounds", sound_id).get("loop", false))


## How loud the sound is meant to be, 0 to 1, before any volume setting.
static func volume_of(sound_id: String) -> float:
	return float(DataRegistry.get_def("sounds", sound_id).get("volume", 1.0))


## The samples for a sound, or an empty array if there is no such sound or recipe. A sound that does
## not loop is eased in and out so that it starts and ends quietly.
static func render(sound_id: String) -> PackedFloat32Array:
	var def := DataRegistry.get_def("sounds", sound_id)
	if def.is_empty():
		return PackedFloat32Array()
	var samples := _make(sound_id, def)
	if samples.is_empty() or bool(def.get("loop", false)):
		return samples
	return Synth.fade_edges(samples, 0.3 if str(def.get("recipe", "")) == "noise_bed" else 0.004)


static func _make(sound_id: String, def: Dictionary) -> PackedFloat32Array:
	var seed_value := hash(sound_id)
	var seconds := float(def.get("seconds", 1.0))
	match str(def.get("recipe", "")):
		"noise_bed":
			return Synth.noise_bed(seconds, float(def.get("low_cut", 0.0)), float(def.get("high_cut", 0.0)), float(def.get("mod_rate", 0.0)), float(def.get("mod_depth", 0.0)), seed_value)
		"crickets":
			return Synth.crickets(seconds, float(def.get("freq", 4000.0)), float(def.get("pulse_rate", 25.0)), float(def.get("group_rate", 0.5)))
		"chirps":
			return Synth.chirps(seconds, int(def.get("count", 8)), float(def.get("low", 2000.0)), float(def.get("high", 4500.0)), seed_value)
		"murmur":
			return Synth.murmur(seconds, float(def.get("syllable_rate", 3.0)), seed_value)
		"crackle":
			return Synth.crackle(seconds, float(def.get("pops", 10)), seed_value)
		"tone":
			return Synth.tone(def.get("partials", [[440.0, 1.0]]), seconds, float(def.get("sweep_to", 0.0)), float(def.get("attack", 0.005)), float(def.get("decay", 8.0)), float(def.get("vibrato", 0.0)), float(def.get("vibrato_depth", 0.0)), float(def.get("noise", 0.0)), seed_value)
		"bell":
			return Synth.bell(float(def.get("freq", 440.0)), seconds, def.get("ratios", [1.0]), def.get("decays", [2.0]))
		"thump":
			return Synth.thump(float(def.get("freq", 120.0)), seconds, float(def.get("noise", 0.5)), seed_value)
	return PackedFloat32Array()


## A sound ready to play, made the first time it is asked for.
static func stream(sound_id: String) -> AudioStream:
	if _streams.has(sound_id):
		return _streams[sound_id]
	var samples := render(sound_id)
	if samples.is_empty():
		return null
	var made := Synth.to_stream(samples, is_loop(sound_id))
	_streams[sound_id] = made
	return made


## Hands over a sound made elsewhere (by the worker thread).
static func keep(sound_id: String, made: AudioStream) -> void:
	_streams[sound_id] = made


static func has_stream(sound_id: String) -> bool:
	return _streams.has(sound_id)
