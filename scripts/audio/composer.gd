class_name Composer
extends RefCounted
## Writes and plays the game's music, from rules (data/music.json), with no recorded tunes.
##
## compose() writes a piece for a mood: a mode (a scale with a feel: bright ionian, wistful dorian,
## dark phrygian), a root note, a tempo and a chord progression. The tune is built from short
## phrases that walk up and down the scale, landing on the notes of the chord on the strong beats and
## on the home note at the end; the lute (or flute, or harp) carries it over a bass and a soft pad,
## and the festival has a drum. render() plays the piece with the instruments of Synth into one long
## sound whose tail runs round into its start, so that it loops without a break. improvise() makes
## up the phrases a person plays at an instrument: slower and less sure at low skill.
##
## The same mood and seed always give the same piece.

const MODES := {
	"ionian": [0, 2, 4, 5, 7, 9, 11],
	"dorian": [0, 2, 3, 5, 7, 9, 10],
	"phrygian": [0, 1, 3, 5, 7, 8, 10],
	"mixolydian": [0, 2, 4, 5, 7, 9, 10],
	"aeolian": [0, 2, 3, 5, 7, 8, 10],
}
const BEATS_PER_BAR := 4
## How a bar of four beats is cut into notes: a few rhythms, plainer first.
const BAR_RHYTHMS := [
	[1.0, 1.0, 1.0, 1.0],
	[2.0, 1.0, 1.0],
	[1.5, 0.5, 1.0, 1.0],
	[1.0, 0.5, 0.5, 1.0, 1.0],
	[0.5, 0.5, 0.5, 0.5, 1.0, 1.0],
	[0.5, 0.5, 1.0, 0.5, 0.5, 1.0],
	[0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5],
	[3.0, 1.0],
	[4.0],
]
const RINGS := { "lute": 1.7, "harp": 2.4 }  # how long a plucked note is allowed to ring, seconds


## The midi note of a scale degree (0 is the root, 7 the root an octave up; negative goes below).
static func degree_note(mode: String, root: int, degree: int) -> int:
	var steps: Array = MODES.get(mode, MODES["ionian"])
	return root + 12 * floori(float(degree) / 7.0) + int(steps[posmod(degree, 7)])


## Writes a piece: { "mood", "bpm", "bars", "beats", "seconds", "notes": [{ "beat", "length", "midi",
## "instrument", "gain" }] }, notes in order of beat.
static func compose(mood_id: String, seed_value: int) -> Dictionary:
	var def := DataRegistry.get_def("music", mood_id)
	if def.is_empty():
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 31 + hash(mood_id)
	var mode := str(def.get("mode", "ionian"))
	var root := int(def.get("root", 50))
	var bars := int(def.get("bars", 16))
	var bpm := float(def.get("bpm", 90))
	var progression: Array = def.get("progression", [0, 3, 4, 0])
	var density := float(def.get("density", 0.7))
	var rests := float(def.get("rest_chance", 0.1))
	var melody := str(def.get("melody", "lute"))
	var notes: Array[Dictionary] = []

	# The tune: two four-bar phrases, played A B A B, the last landing home.
	var phrase_a := _phrase(rng, progression, density, rests, false)
	var phrase_b := _phrase(rng, progression, density, rests, true)
	for bar in bars:
		var phrase: Array = phrase_a if (bar / 4) % 2 == 0 else phrase_b
		var entries: Array = phrase[bar % 4]
		for index in entries.size():
			var entry: Dictionary = entries[index]
			var last := bar == bars - 1 and index == entries.size() - 1
			var length := maxf(float(entry["length"]), 2.0) if last else float(entry["length"])  # the last note is held
			var degree := 0 if last else int(entry["degree"])  # and it is home
			notes.append({ "beat": float(bar * BEATS_PER_BAR) + float(entry["beat"]), "length": length, "midi": degree_note(mode, root + 12, degree), "instrument": melody, "gain": 1.0 })
	# The bass and the pad follow the chords.
	for bar in bars:
		var chord := int(progression[bar % progression.size()])
		var start := float(bar * BEATS_PER_BAR)
		var bass := str(def.get("bass", "lute"))
		if bass == "pad":
			notes.append({ "beat": start, "length": float(BEATS_PER_BAR), "midi": degree_note(mode, root - 12, chord), "instrument": "pad", "gain": 0.5 })
		else:
			notes.append({ "beat": start, "length": 2.0, "midi": degree_note(mode, root - 12, chord), "instrument": bass, "gain": 0.7 })
			notes.append({ "beat": start + 2.0, "length": 2.0, "midi": degree_note(mode, root - 12, chord + 4), "instrument": bass, "gain": 0.5 })
		if bool(def.get("pad", false)) and bar % 2 == 0:
			for tone in [0, 2, 4]:
				notes.append({ "beat": start, "length": float(BEATS_PER_BAR * 2), "midi": degree_note(mode, root, chord + tone), "instrument": "pad", "gain": 0.16 })
		if bool(def.get("drum", false)):
			for beat in BEATS_PER_BAR:
				var strong := beat % 2 == 0
				notes.append({ "beat": start + float(beat), "length": 0.3, "midi": 36 if strong else 52, "instrument": "drum", "gain": 0.7 if strong else 0.3 })
	notes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["beat"]) < float(b["beat"]))
	var beats := bars * BEATS_PER_BAR
	return { "mood": mood_id, "bpm": bpm, "bars": bars, "beats": beats, "seconds": float(beats) * 60.0 / bpm, "notes": notes }


## A phrase of four bars: for each bar, a list of { "beat", "length", "degree" }.
static func _phrase(rng: RandomNumberGenerator, progression: Array, density: float, rests: float, answer: bool) -> Array:
	var bars: Array = []
	var degree := 4 if not answer else 2
	for bar in 4:
		var chord := int(progression[bar % progression.size()])
		var rhythm_index := 0
		var roll := rng.randf()
		if roll < density * 0.55:
			rhythm_index = rng.randi_range(3, BAR_RHYTHMS.size() - 3)
		elif roll < density:
			rhythm_index = rng.randi_range(1, 5)
		else:
			rhythm_index = rng.randi_range(0, 2) if rng.randf() < 0.6 else BAR_RHYTHMS.size() - 1 - rng.randi_range(0, 1)
		var rhythm: Array = BAR_RHYTHMS[rhythm_index]
		var entries: Array = []
		var beat := 0.0
		for length in rhythm:
			var strong := is_equal_approx(beat, 0.0) or is_equal_approx(beat, 2.0)
			if strong:
				degree = _nearest_chord_tone(degree, chord)
			else:
				var move := rng.randf()
				var step := 1 if move < 0.35 else (-1 if move < 0.7 else (2 if move < 0.8 else (-2 if move < 0.9 else rng.randi_range(-3, 3))))
				degree = clampi(degree + step, -2, 9)
			if not (rng.randf() < rests and not strong):
				entries.append({ "beat": beat, "length": float(length), "degree": degree })
			beat += float(length)
		if entries.is_empty():
			entries.append({ "beat": 0.0, "length": 4.0, "degree": _nearest_chord_tone(degree, chord) })
		bars.append(entries)
	return bars


## The note of the chord (built on scale degree `chord`) closest to `degree`.
static func _nearest_chord_tone(degree: int, chord: int) -> int:
	var best := degree
	var best_gap := 99
	for octave in range(-1, 2):
		for tone: int in [0, 2, 4]:
			var candidate: int = chord + tone + 7 * octave
			if absi(candidate - degree) < best_gap:
				best_gap = absi(candidate - degree)
				best = candidate
	return best


## The piece played into one sound at `rate`, peak 0.85. Notes that run past the end carry on from the start.
static func render(piece: Dictionary, rate: int = Synth.RATE) -> PackedFloat32Array:
	if piece.is_empty():
		return PackedFloat32Array()
	var seconds_per_beat := 60.0 / float(piece["bpm"])
	var total := roundi(float(piece["seconds"]) * rate)
	var track := PackedFloat32Array()
	track.resize(total)
	var voices := {}  # "instrument:midi:length" -> the note played, made once
	for entry: Dictionary in piece["notes"]:
		var instrument := str(entry["instrument"])
		var length := float(entry["length"]) * seconds_per_beat
		var ring := float(RINGS.get(instrument, length))
		var key := "%s:%d:%.2f" % [instrument, int(entry["midi"]), ring if RINGS.has(instrument) else snappedf(length, 0.05)]
		if not voices.has(key):
			voices[key] = Synth.note(instrument, int(entry["midi"]), ring if RINGS.has(instrument) else maxf(0.2, length), 7, rate)
		var voice: PackedFloat32Array = voices[key]
		var offset := roundi(float(entry["beat"]) * seconds_per_beat * rate)
		var gain := float(entry["gain"]) * (0.5 if instrument == "pad" else 1.0)
		var size := voice.size()
		for i in size:
			var at := offset + i
			if at >= total:
				at -= total  # the tail wraps round
				if at >= total:
					break
			track[at] += voice[i] * gain
	return Synth.normalize(track, 0.85)


## Up to `count` notes of a tune made up on the spot by someone at an instrument: [{ "delay", "midi" }],
## `delay` being the seconds since the last. Better players (skill 0 to 10) go faster and play fewer sour notes.
static func improvise(skill: int, seed_value: int, count: int = 12) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var mode := "dorian" if rng.randf() < 0.5 else "mixolydian"
	var tune: Array[Dictionary] = []
	var degree := rng.randi_range(2, 6)
	var pace := 0.62 - 0.035 * float(skill)
	var sour := maxf(0.0, 0.22 - 0.022 * float(skill))
	for i in count:
		var step := rng.randi_range(-2, 2)
		degree = clampi(degree + step, 0, 9)
		var midi := degree_note(mode, 57, degree)
		if rng.randf() < sour:
			midi += 1 if rng.randf() < 0.5 else -1
		var long := rng.randf() < 0.25
		tune.append({ "delay": pace * (1.8 if long else 1.0) * rng.randf_range(0.85, 1.15), "midi": midi })
	return tune
