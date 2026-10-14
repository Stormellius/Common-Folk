class_name AudioDirector
extends Node
## Plays everything you hear. The sounds are made by arithmetic (Synth, SoundBank, Composer) on a worker
## thread when the game starts, so the first few seconds are quiet while it works.
##
## * Ambience: layers of looping sound (wind, rain, birds, crickets, a crowd, a fire, water) whose
##   levels come from where the camera is and when (see Soundscape).
## * Music: a piece for the mood of the moment (day, evening, night, a festival, a death), crossfaded
##   as the mood changes.
## * Work and instruments: people at a chopping block, a quarry, a forge, a bench or a building site make their
##   sounds when they are near the camera; a person at a lute, harp or drum plays a tune, better with skill.
## * One-shots: bells, a cry, a coin, a chime when your folk's wishes come true, a click on every button.
##
## It only listens: it reads the simulation and never changes it, and does nothing without sound output.

const TILE := 48.0                 # pixels to a tile (MapView.TILE_SIZE)
const HEAR_TILES := 34.0           # work and music is played this far from the camera
const THINK_EVERY := 0.25          # seconds between looking at the world
const FOLLOW := 1.6                # how fast a level follows its goal, per second
const CROSSFADE := 3.0             # seconds to change the music
const POOL := 16                   # sounds that can play at once at places
const GLOBAL_POOL := 4             # and sounds that play wherever the camera is
const NOTE_RINGS := { "lute": 1.6, "harp": 2.2, "drum": 0.4 }
const FIRST_NOTE := 55
const LAST_NOTE := 82
const MUSIC_SEED := 1

var enabled := true

var _sim: Simulation
var _world: WorldState
var _camera: Camera2D
var _layers: Dictionary = {}        # layer id -> AudioStreamPlayer
var _levels: Dictionary = {}        # layer id -> where it is now, 0 to 1
var _goals: Dictionary = {}         # layer id -> where it is heading
var _music: Array[AudioStreamPlayer] = []
var _music_gain: Array[float] = [0.0, 0.0]
var _music_mood := ""
var _music_side := 0
var _music_streams: Dictionary = {}   # mood id -> AudioStreamWAV
var _pool: Array[AudioStreamPlayer2D] = []
var _global_pool: Array[AudioStreamPlayer] = []
var _notes: Dictionary = {}           # "instrument:midi" -> AudioStreamWAV
var _sources: Array[Dictionary] = []  # { "tile", "sound", "radius" } of fires and water
var _sources_for := -1                # how many objects there were when _sources was made
var _since_think := 0.0
var _sorrow_until := 0
var _work_wait: Dictionary = {}       # pawn id -> seconds to its next sound of work
var _players: Dictionary = {}         # pawn id -> { "instrument", "tile", "tune", "index", "wait" }
var _thunder_wait := 60.0
var _context_now: Dictionary = {}
var _thread: Thread
var _mutex := Mutex.new()
var _ready_sounds: Array[Dictionary] = []  # made by the thread, waiting to be turned into streams
var _quit := false


func _ready() -> void:
	AudioMixer.setup()
	for layer_id in Soundscape.LAYERS:
		var player := AudioStreamPlayer.new()
		player.bus = AudioMixer.AMBIENCE
		player.volume_db = -80.0
		add_child(player)
		_layers[layer_id] = player
		_levels[layer_id] = 0.0
		_goals[layer_id] = 0.0
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.bus = AudioMixer.MUSIC
		player.volume_db = -80.0
		add_child(player)
		_music.append(player)
	for i in POOL:
		var player := AudioStreamPlayer2D.new()
		player.bus = AudioMixer.EFFECTS
		player.max_distance = HEAR_TILES * TILE
		player.attenuation = 1.4
		player.panning_strength = 0.9
		add_child(player)
		_pool.append(player)
	for i in GLOBAL_POOL:
		var player := AudioStreamPlayer.new()
		player.bus = AudioMixer.EFFECTS
		add_child(player)
		_global_pool.append(player)
	get_tree().node_added.connect(_on_node_added)
	if DisplayServer.get_name() != "headless":  # nothing could be heard
		start_building()


func _exit_tree() -> void:
	_quit = true
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()


## Points the director at the game it should listen to (call again for a new game).
func bind(sim: Simulation, camera: Camera2D) -> void:
	if _sim != null and is_instance_valid(_sim):
		_sim.sound_made.disconnect(play_effect_at)
		_sim.event_started.disconnect(_on_event_started)
		_sim.pawn_died.disconnect(_on_pawn_died)
	_sim = sim
	_world = sim.world
	_camera = camera
	_sources_for = -1
	_work_wait.clear()
	_players.clear()
	sim.sound_made.connect(play_effect_at)
	sim.event_started.connect(_on_event_started)
	sim.pawn_died.connect(_on_pawn_died)


# --- making the sounds ------------------------------------------------------------------------

## Starts making every sound and piece of music on a worker thread; they begin to play as they are ready.
func start_building() -> void:
	if _thread != null:
		return
	_thread = Thread.new()
	_thread.start(_build_all)


## Makes everything now, on this thread (a test, or a tool with no window).
func build_now() -> void:
	_build_all()
	_collect_ready()


func _build_all() -> void:
	for sound_id in SoundBank.ids():
		if _quit:
			return
		_deliver({ "kind": "sound", "id": sound_id, "samples": SoundBank.render(sound_id), "loop": SoundBank.is_loop(sound_id) })
	for instrument in ["lute", "harp"]:
		for midi in range(FIRST_NOTE, LAST_NOTE + 1):
			if _quit:
				return
			_deliver({ "kind": "note", "id": "%s:%d" % [instrument, midi], "samples": Synth.note(instrument, midi, float(NOTE_RINGS[instrument]), 3), "loop": false })
	for def in DataRegistry.get_list("music"):
		if _quit:
			return
		var mood_id := str(def["id"])
		_deliver({ "kind": "music", "id": mood_id, "samples": Composer.render(Composer.compose(mood_id, MUSIC_SEED)), "loop": true })


func _deliver(sound: Dictionary) -> void:
	sound["bytes"] = Synth.to_bytes(sound["samples"])
	sound["count"] = (sound["samples"] as PackedFloat32Array).size()
	sound.erase("samples")
	_mutex.lock()
	_ready_sounds.append(sound)
	_mutex.unlock()


func _collect_ready() -> void:
	_mutex.lock()
	var arrived := _ready_sounds.duplicate()
	_ready_sounds.clear()
	_mutex.unlock()
	for sound: Dictionary in arrived:
		var made := Synth.stream_from_bytes(sound["bytes"], int(sound["count"]), bool(sound["loop"]))
		match str(sound["kind"]):
			"sound":
				SoundBank.keep(str(sound["id"]), made)
			"note":
				_notes[str(sound["id"])] = made
			"music":
				_music_streams[str(sound["id"])] = made


## Whether everything has been made.
func is_ready() -> bool:
	return _music_streams.size() >= DataRegistry.count("music") and SoundBank.has_stream("hubbub")


# --- every frame ------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_collect_ready()
	_since_think += delta
	if _since_think >= THINK_EVERY and _sim != null:
		_think(_since_think)
		_since_think = 0.0
	_follow_levels(delta)
	_follow_music(delta)
	_play_instruments(delta)


func _follow_levels(delta: float) -> void:
	for layer_id in _layers:
		var level: float = _levels[layer_id]
		level = move_toward(level, float(_goals[layer_id]), FOLLOW * delta)
		_levels[layer_id] = level
		var player: AudioStreamPlayer = _layers[layer_id]
		if level < 0.004:
			if player.playing:
				player.stop()
			continue
		if player.stream == null:
			player.stream = SoundBank.stream(str(layer_id)) if SoundBank.has_stream(str(layer_id)) or not _building() else null
		if player.stream != null and not player.playing:
			player.play()
		player.volume_db = linear_to_db(level * SoundBank.volume_of(str(layer_id)))


## Whether the worker thread is still at work (a sound that is not there yet is not made on the main thread).
func _building() -> bool:
	return _thread != null and _thread.is_alive()


func _follow_music(delta: float) -> void:
	for side in 2:
		var player := _music[side]
		var goal := 1.0 if side == _music_side and _music_mood != "" else 0.0
		_music_gain[side] = move_toward(_music_gain[side], goal, delta / CROSSFADE)
		if _music_gain[side] <= 0.003:
			if player.playing and side != _music_side:
				player.stop()
			if side != _music_side:
				continue
		if side == _music_side and player.stream != null and not player.playing and _music_gain[side] > 0.0:
			player.play()
		var def := DataRegistry.get_def("music", _music_mood if side == _music_side else str(player.get_meta("mood", "")))
		var base := float(def.get("volume", 0.6)) * (0.6 if GameClock.speed_level == 0 else 1.0)
		player.volume_db = linear_to_db(maxf(0.0001, _music_gain[side] * base))


# --- looking at the world ---------------------------------------------------------------------

func _think(dt: float) -> void:
	_context_now = context()
	_goals = Soundscape.levels(_context_now)
	var mood := Soundscape.mood(_context_now)
	if mood != _music_mood or (_music_mood != "" and not _music[_music_side].playing and _music_streams.has(_music_mood)):
		_change_music(mood)
	_work_sounds(dt)
	_refresh_players()
	_thunder(dt)


## What there is to hear now (see Soundscape).
func context() -> Dictionary:
	var tile := _camera_tile()
	var zoom := _camera.zoom.x if _camera != null else 1.0
	var town := _world.town_at(tile, 4)
	var date := GameClock.get_date()
	_refresh_sources()
	var fire := 0.0
	var water := 0.0
	for source in _sources:
		var near := 1.0 - Vector2(source["tile"] - tile).length() / float(source["radius"])
		if near > 0.0:
			if source["sound"] == "fire":
				fire = maxf(fire, near)
			elif source["sound"] == "water":
				water = maxf(water, near)
	for burning in _world.fires:  # what is alight now
		fire = maxf(fire, 1.0 - Vector2(burning - tile).length() / 7.0)
	var crowd := 0
	for pawn in _sim.household.pawns:
		crowd += 1 if absi(pawn.tile.x - tile.x) + absi(pawn.tile.y - tile.y) <= 16 else 0
	for pawn in _sim.town.pawns:
		crowd += 1 if absi(pawn.tile.x - tile.x) + absi(pawn.tile.y - tile.y) <= 16 else 0
	var festival := false
	for def in _sim.events.active_defs():
		festival = festival or (def.has("gather") and not town.is_empty())
	var sorrow := _sorrow_until > GameClock.tick
	for pawn in _sim.household.pawns:
		sorrow = sorrow or pawn.is_dying()
	return {
		"hour": float(GameClock.get_minute_of_day()) / 60.0,
		"season": str(date.get("season_id", "spring")),
		"wet": Weather.wet,
		"snowing": Weather.snowing,
		"wind": Weather.wind.length(),
		"in_town": not town.is_empty(),
		"crowd": clampf(float(crowd) / 12.0, 0.0, 1.0),
		"fire": fire,
		"water": water,
		"closeness": clampf((zoom - 0.35) / 0.9, 0.0, 1.0),
		"paused": GameClock.speed_level == 0,
		"sorrow": sorrow,
		"festival": festival,
	}


func _camera_tile() -> Vector2i:
	if _camera == null:
		return _world.home_center()
	return Vector2i(floori(_camera.global_position.x / TILE), floori(_camera.global_position.y / TILE))


## The hearths, forges and water of the world that can be heard, listed again when objects come or go.
func _refresh_sources() -> void:
	if _world.objects.size() != _sources_for:
		_sources.clear()
		for placed in _world.objects:
			var ambient: Dictionary = placed.def().get("ambient", {})
			if not ambient.is_empty():
				_sources.append({ "tile": placed.tile, "sound": str(ambient["id"]), "radius": float(ambient.get("radius", 6.0)) })
		_sources_for = _world.objects.size()


func _change_music(mood: String) -> void:
	if not _music_streams.has(mood):
		return  # not made yet: the music will start when it is
	var side := 1 - _music_side if _music_mood != "" else _music_side
	_music[side].stream = _music_streams[mood]
	_music[side].set_meta("mood", mood)
	_music[side].stop()
	_music[side].play()
	_music_side = side
	_music_mood = mood


func _on_pawn_died(_person: String, _cause: String, _successor: String) -> void:
	_sorrow_until = GameClock.tick + 4 * 60


func _on_event_started(event_name: String, _text: String) -> void:
	if event_name.to_lower().contains("service"):
		var spot := _chapel_tile()
		for strike in 3:
			get_tree().create_timer(1.9 * strike).timeout.connect(func() -> void: play_effect("bell", spot, 1.0))


func _chapel_tile() -> Vector2i:
	var home := _world.home_town()
	for lot in _world.lots:
		if str(lot["kind"]) == "chapel" and str(lot.get("town", "")) == str(home.get("id", "")):
			return (lot["rect"] as Rect2i).get_center()
	return Vector2i(-1, -1)


# --- one-shots --------------------------------------------------------------------------------

func play_effect_at(sound_id: String, tile: Vector2i) -> void:
	play_effect(sound_id, tile, 1.0)


## Plays a sound once, at a tile (heard less the farther the camera is) or, at (-1, -1), everywhere.
func play_effect(sound_id: String, tile: Vector2i, volume: float = 1.0, pitch: float = 1.0) -> void:
	if not enabled:
		return
	var stream := _stream_for(sound_id)
	if stream == null:
		return
	var db := linear_to_db(maxf(0.0001, volume * SoundBank.volume_of(sound_id)))
	if tile == Vector2i(-1, -1):
		var player := _free(_global_pool)
		player.stream = stream
		player.volume_db = db
		player.pitch_scale = pitch
		player.play()
		return
	var spot := _free_2d()
	spot.stream = stream
	spot.volume_db = db
	spot.pitch_scale = pitch
	spot.global_position = (Vector2(tile) + Vector2(0.5, 0.5)) * TILE
	spot.play()


## A sound that is ready; a short one is made now if the thread has not got to it.
func _stream_for(sound_id: String) -> AudioStream:
	if SoundBank.has_stream(sound_id):
		return SoundBank.stream(sound_id)
	if _building() and not SoundBank.is_loop(sound_id) and sound_id not in ["bell", "toll"]:
		return SoundBank.stream(sound_id)
	return null if _building() else SoundBank.stream(sound_id)


func _free(pool: Array[AudioStreamPlayer]) -> AudioStreamPlayer:
	for player in pool:
		if not player.playing:
			return player
	return pool[0]


func _free_2d() -> AudioStreamPlayer2D:
	for player in _pool:
		if not player.playing:
			return player
	return _pool[0]


func _on_node_added(node: Node) -> void:
	if node is BaseButton and not (node as BaseButton).pressed.is_connected(_click):
		(node as BaseButton).pressed.connect(_click)


func _click() -> void:
	play_effect("click", Vector2i(-1, -1), 1.0, randf_range(0.95, 1.05))


# --- people at work and at their instruments --------------------------------------------------

## Folk at a chopping block, a quarry, a forge, a bench or a building site make their noise, now and then,
## when they are near enough to hear (and when the game is not running fast).
func _work_sounds(dt: float) -> void:
	var tile := _camera_tile()
	var live := {}
	if GameClock.speed_level == 0 or GameClock.speed_level >= 3:
		_work_wait.clear()
		return
	for group in [_sim.household.pawns, _sim.town.pawns]:
		for pawn: Pawn in group:
			var sound := _work_sound_of(pawn)
			if sound.is_empty() or absi(pawn.tile.x - tile.x) + absi(pawn.tile.y - tile.y) > int(HEAR_TILES):
				continue
			live[pawn.id] = true
			var wait: float = float(_work_wait.get(pawn.id, randf() * float(sound["every"]))) - dt
			if wait <= 0.0:
				play_effect(str(sound["id"]), pawn.tile, 0.8, randf_range(0.92, 1.08))
				wait = float(sound["every"]) * randf_range(0.85, 1.25)
			_work_wait[pawn.id] = wait
	for pawn_id in _work_wait.keys():
		if not live.has(pawn_id):
			_work_wait.erase(pawn_id)


## { "id", "every" } for what this person's work sounds like right now, or empty.
func _work_sound_of(pawn: Pawn) -> Dictionary:
	if pawn.job_kind == "build" and pawn.job_stage == "working":
		return { "id": "hammer", "every": 0.9 }
	if pawn.job_kind != "use" or pawn.job_stage != "using":
		return {}
	var placed := _world.get_object(pawn.job_object)
	if placed == null:
		return {}
	return placed.def().get("work_sound", {})


## Who is playing an instrument within hearing: they start and stop a tune as they sit down and get up.
func _refresh_players() -> void:
	var tile := _camera_tile()
	var live := {}
	for group in [_sim.household.pawns, _sim.town.pawns]:
		for pawn: Pawn in group:
			if pawn.job_kind != "use" or pawn.job_stage != "using" or absi(pawn.tile.x - tile.x) + absi(pawn.tile.y - tile.y) > int(HEAR_TILES):
				continue
			var placed := _world.get_object(pawn.job_object)
			if placed == null or not placed.def().has("instrument"):
				continue
			live[pawn.id] = true
			if not _players.has(pawn.id):
				var skill := Skills.level(pawn, "music")
				_players[pawn.id] = { "instrument": str(placed.def()["instrument"]), "tile": placed.tile, "tune": Composer.improvise(skill, pawn.id * 7919 + GameClock.tick, 48), "index": 0, "wait": 0.2 }
	for pawn_id in _players.keys():
		if not live.has(pawn_id):
			_players.erase(pawn_id)


func _play_instruments(delta: float) -> void:
	if _players.is_empty() or GameClock.speed_level == 0 or GameClock.speed_level >= 3:
		return
	for pawn_id in _players:
		var entry: Dictionary = _players[pawn_id]
		entry["wait"] = float(entry["wait"]) - delta
		if float(entry["wait"]) > 0.0:
			continue
		var tune: Array = entry["tune"]
		var step: Dictionary = tune[int(entry["index"]) % tune.size()]
		entry["index"] = int(entry["index"]) + 1
		entry["wait"] = float(step["delay"])
		_play_note(str(entry["instrument"]), int(step["midi"]), entry["tile"])


func _play_note(instrument: String, midi: int, tile: Vector2i) -> void:
	if instrument == "drum":
		midi = 36 + (midi % 3) * 7
	else:
		midi = clampi(midi, FIRST_NOTE, LAST_NOTE)
	var key := "%s:%d" % [instrument, midi]
	if not _notes.has(key):
		if _building():
			return
		_notes[key] = Synth.to_stream(Synth.note(instrument, midi, float(NOTE_RINGS.get(instrument, 1.6)), 3))
	var spot := _free_2d()
	spot.stream = _notes[key]
	spot.volume_db = linear_to_db(0.7)
	spot.pitch_scale = 1.0
	spot.global_position = (Vector2(tile) + Vector2(0.5, 0.5)) * TILE
	spot.play()


## Now and then in a heavy rain, thunder far off.
func _thunder(dt: float) -> void:
	if Weather.wet < 0.6 or Weather.snowing:
		_thunder_wait = maxf(_thunder_wait, 30.0)
		return
	_thunder_wait -= dt
	if _thunder_wait <= 0.0:
		play_effect("thunder", Vector2i(-1, -1), randf_range(0.4, 0.9))
		_thunder_wait = randf_range(40.0, 110.0)
