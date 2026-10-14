class_name AudioMixer
extends RefCounted
## The mixing desk: a bus each for music, ambience and effects under the master, with the volumes
## the player set in Settings.

const MASTER := "Master"
const MUSIC := "Music"
const AMBIENCE := "Ambience"
const EFFECTS := "Effects"


## Makes the three buses if they are not there yet, and sets every volume.
static func setup() -> void:
	for bus_name in [MUSIC, AMBIENCE, EFFECTS]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus_name)
			AudioServer.set_bus_send(index, MASTER)
	apply()


## Sets the volume of each bus from Settings (0 to 1, in decibels, silent at 0).
static func apply() -> void:
	_apply_bus(MASTER, Settings.master_volume)
	_apply_bus(MUSIC, Settings.music_volume)
	_apply_bus(AMBIENCE, Settings.ambience_volume)
	_apply_bus(EFFECTS, Settings.effects_volume)


static func _apply_bus(bus_name: String, volume: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index == -1:
		return
	AudioServer.set_bus_mute(index, volume <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(clampf(volume, 0.001, 1.0)))
