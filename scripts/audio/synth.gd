class_name Synth
extends RefCounted
## Makes sound out of arithmetic: the game has no recorded audio, so everything it plays (wind,
## rain, an axe on a log, a bell, the lute) is worked out here, sample by sample, the way the
## pictures are drawn in code. Samples are floats from -1 to 1, mono, at RATE a second.
##
## Nothing here touches the scene tree, so it is safe to call from a worker thread. The random
## numbers come from a seed, so a sound is the same each time it is made.

const RATE := 22050


static func rng_for(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


static func silence(seconds: float, rate: int = RATE) -> PackedFloat32Array:
	var buffer := PackedFloat32Array()
	buffer.resize(maxi(1, roundi(seconds * rate)))
	return buffer


## White noise, `count` samples.
static func noise(rng: RandomNumberGenerator, count: int) -> PackedFloat32Array:
	var buffer := PackedFloat32Array()
	buffer.resize(count)
	for i in count:
		buffer[i] = rng.randf() * 2.0 - 1.0
	return buffer


## One-pole low pass: takes the highs off. Cutoff in Hz.
static func lowpass(source: PackedFloat32Array, cutoff: float, rate: int = RATE) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(source.size())
	var factor := 1.0 - exp(-TAU * cutoff / float(rate))
	var held := 0.0
	for i in source.size():
		held += factor * (source[i] - held)
		out[i] = held
	return out


## Takes the lows off.
static func highpass(source: PackedFloat32Array, cutoff: float, rate: int = RATE) -> PackedFloat32Array:
	var low := lowpass(source, cutoff, rate)
	var out := PackedFloat32Array()
	out.resize(source.size())
	for i in source.size():
		out[i] = source[i] - low[i]
	return out


## Adds `source` (times `gain`) into `target` from sample `offset`, as far as it fits.
static func mix_into(target: PackedFloat32Array, source: PackedFloat32Array, offset: int, gain: float = 1.0) -> void:
	var count := mini(source.size(), target.size() - offset)
	for i in count:
		target[offset + i] += source[i] * gain


static func peak(buffer: PackedFloat32Array) -> float:
	var top := 0.0
	for value in buffer:
		top = maxf(top, absf(value))
	return top


static func rms(buffer: PackedFloat32Array) -> float:
	if buffer.is_empty():
		return 0.0
	var total := 0.0
	for value in buffer:
		total += value * value
	return sqrt(total / float(buffer.size()))


## Scales the sound so its loudest sample is `target`.
static func normalize(buffer: PackedFloat32Array, target: float = 0.9) -> PackedFloat32Array:
	var top := peak(buffer)
	if top <= 0.0001:
		return buffer
	var scale := target / top
	var out := PackedFloat32Array()
	out.resize(buffer.size())
	for i in buffer.size():
		out[i] = buffer[i] * scale
	return out


## Fades the ends so that nothing clicks.
static func fade_edges(buffer: PackedFloat32Array, seconds: float, rate: int = RATE) -> PackedFloat32Array:
	var fade := mini(roundi(seconds * rate), buffer.size() / 2)
	var out := buffer.duplicate()
	for i in fade:
		var gain := float(i) / float(fade)
		out[i] *= gain
		out[out.size() - 1 - i] *= gain
	return out


## Turns a sound made `fade` samples too long into one that loops without a seam: the extra tail is
## blended into the start, so the end runs straight on into the beginning.
static func make_loop(buffer: PackedFloat32Array, fade: int) -> PackedFloat32Array:
	var length := buffer.size() - fade
	var out := PackedFloat32Array()
	out.resize(length)
	for i in length:
		out[i] = buffer[i]
	for i in mini(fade, length):
		var blend := float(i) / float(fade)
		out[i] = buffer[i] * blend + buffer[length + i] * (1.0 - blend)
	return out


# --- sounds with a shape ----------------------------------------------------------------------

## Wind, rain, a stream: noise with the highs and lows taken off, swelling and fading slowly.
## `mod_rate` swells a second, `mod_depth` (0 to 1) how much.
static func noise_bed(seconds: float, low_cut: float, high_cut: float, mod_rate: float, mod_depth: float, seed_value: int, rate: int = RATE) -> PackedFloat32Array:
	var rng := rng_for(seed_value)
	var fade := roundi(0.5 * rate)
	var raw := noise(rng, roundi(seconds * rate) + fade)
	if high_cut > 0.0:
		raw = lowpass(raw, high_cut, rate)
	if low_cut > 0.0:
		raw = highpass(raw, low_cut, rate)
	var phase := rng.randf() * TAU
	for i in raw.size():
		var swell := 1.0 - mod_depth * (0.5 + 0.5 * sin(phase + TAU * mod_rate * float(i) / float(rate)))
		raw[i] *= swell
	return make_loop(normalize(raw, 0.8), fade)


## A tone, or several (`partials`: [[hz, amplitude], ...]), that can slide to `sweep_to` Hz, with an
## attack, a decay (higher is quicker), a wobble (`vibrato` Hz and `vibrato_depth`, a share of the pitch)
## and some `noise` mixed in.
static func tone(partials: Array, seconds: float, sweep_to: float, attack: float, decay: float, vibrato: float, vibrato_depth: float, noise_amount: float, seed_value: int, rate: int = RATE) -> PackedFloat32Array:
	var rng := rng_for(seed_value)
	var count := roundi(seconds * rate)
	var out := PackedFloat32Array()
	out.resize(count)
	var phases: Array[float] = []
	for entry in partials:
		phases.append(0.0)
	for i in count:
		var t := float(i) / float(rate)
		var progress := float(i) / float(maxi(1, count - 1))
		var envelope := exp(-decay * t) * minf(1.0, t / maxf(attack, 0.0005))
		var wobble := 1.0 + vibrato_depth * sin(TAU * vibrato * t)
		var value := 0.0
		for index in partials.size():
			var hz := float(partials[index][0])
			if sweep_to > 0.0:
				hz = lerpf(hz, hz * sweep_to / float(partials[0][0]), progress)
			phases[index] += TAU * hz * wobble / float(rate)
			value += sin(phases[index]) * float(partials[index][1])
		if noise_amount > 0.0:
			value += (rng.randf() * 2.0 - 1.0) * noise_amount
		out[i] = value * envelope
	return normalize(fade_edges(out, 0.004, rate), 0.9)


## A bell: partials at the given ratios of the pitch, each dying away at its own rate.
static func bell(freq: float, seconds: float, ratios: Array, decays: Array, rate: int = RATE) -> PackedFloat32Array:
	var count := roundi(seconds * rate)
	var out := PackedFloat32Array()
	out.resize(count)
	for index in ratios.size():
		var hz := freq * float(ratios[index])
		var decay := float(decays[mini(index, decays.size() - 1)])
		var amplitude := 1.0 / (1.0 + 0.6 * index)
		for i in count:
			var t := float(i) / float(rate)
			out[i] += sin(TAU * hz * t) * amplitude * exp(-decay * t)
	return normalize(fade_edges(out, 0.002, rate), 0.9)


## A knock: a pitch that falls quickly, with a burst of noise on the front (an axe in a log, a drum).
static func thump(freq: float, seconds: float, noise_amount: float, seed_value: int, rate: int = RATE) -> PackedFloat32Array:
	var rng := rng_for(seed_value)
	var count := roundi(seconds * rate)
	var out := PackedFloat32Array()
	out.resize(count)
	var phase := 0.0
	for i in count:
		var t := float(i) / float(rate)
		var hz := freq * (1.0 + 2.5 * exp(-t * 40.0))
		phase += TAU * hz / float(rate)
		out[i] = sin(phase) * exp(-t * 18.0) + (rng.randf() * 2.0 - 1.0) * noise_amount * exp(-t * 60.0)
	return normalize(fade_edges(out, 0.002, rate), 0.9)


## Short bright chirps at random places in a loop: birdsong.
static func chirps(seconds: float, count: int, low: float, high: float, seed_value: int, rate: int = RATE) -> PackedFloat32Array:
	var rng := rng_for(seed_value)
	var out := silence(seconds, rate)
	for i in count:
		var start := rng.randf() * (seconds - 0.6)
		var base := rng.randf_range(low, high)
		var notes := rng.randi_range(1, 4)
		var at := start
		for note in notes:
			var length := rng.randf_range(0.06, 0.14)
			var rise := rng.randf_range(0.8, 1.5)
			var chirp := tone([[base, 1.0]], length, base * rise, 0.01, 12.0, 0.0, 0.0, 0.0, seed_value + i * 7 + note, rate)
			mix_into(out, chirp, roundi(at * rate), rng.randf_range(0.4, 0.8))
			at += length + rng.randf_range(0.04, 0.1)
	return normalize(out, 0.8)  # the ends are quiet, so it loops as it is


## Crickets: a high tone pulsed fast, in bursts.
static func crickets(seconds: float, freq: float, pulse_rate: float, group_rate: float, rate: int = RATE) -> PackedFloat32Array:
	var count := roundi(seconds * rate)
	var out := PackedFloat32Array()
	out.resize(count)
	for i in count:
		var t := float(i) / float(rate)
		var group := maxf(0.0, sin(TAU * group_rate * t)) # bursts
		var pulse := maxf(0.0, sin(TAU * pulse_rate * t))
		out[i] = sin(TAU * freq * t) * pulse * pulse * group
	return normalize(out, 0.7)


## A fire: a low rumble and now and then a pop.
static func crackle(seconds: float, pops_per_second: float, seed_value: int, rate: int = RATE) -> PackedFloat32Array:
	var rng := rng_for(seed_value)
	var fade := roundi(0.4 * rate)
	var count := roundi(seconds * rate) + fade
	var out := lowpass(noise(rng, count), 260.0, rate)
	for i in out.size():
		out[i] *= 2.5
	var pops := roundi(pops_per_second * seconds)
	for p in pops:
		var at := rng.randi_range(0, count - 800)
		var length := rng.randi_range(80, 600)
		var loudness := rng.randf_range(0.3, 1.0)
		var tick := lowpass(noise(rng, length), rng.randf_range(2000.0, 6000.0), rate)
		for i in length:
			out[at + i] += tick[i] * loudness * 3.0 * exp(-float(i) / float(length) * 5.0)
	return make_loop(normalize(out, 0.8), fade)


## The murmur of a crowd: low noise rising and falling in a hundred syllables.
static func murmur(seconds: float, syllable_rate: float, seed_value: int, rate: int = RATE) -> PackedFloat32Array:
	var rng := rng_for(seed_value)
	var fade := roundi(0.5 * rate)
	var count := roundi(seconds * rate) + fade
	var base := highpass(lowpass(noise(rng, count), 950.0, rate), 130.0, rate)
	var shaper := lowpass(noise(rng, count), syllable_rate * 1.2, rate)
	var top := maxf(0.001, peak(shaper))
	for i in count:
		base[i] *= 0.25 + 0.75 * absf(shaper[i]) / top
	return make_loop(normalize(base, 0.8), fade)


# --- instruments -------------------------------------------------------------------------------

## A plucked string by the Karplus-Strong method: a burst of noise goes round a short delay that
## softens it a little each time, and rings like a lute or harp. `damping` just under 1 rings
## longer; `smooth` (0 to 1) takes the sharpness off the start.
static func pluck(freq: float, seconds: float, damping: float, smooth: float, seed_value: int, rate: int = RATE) -> PackedFloat32Array:
	var rng := rng_for(seed_value)
	var period := maxi(2, roundi(float(rate) / freq))
	var ring := PackedFloat32Array()
	ring.resize(period)
	var held := 0.0
	for i in period:
		var fresh := rng.randf() * 2.0 - 1.0
		held = held * smooth + fresh * (1.0 - smooth)
		ring[i] = held
	var count := roundi(seconds * rate)
	var out := PackedFloat32Array()
	out.resize(count)
	var index := 0
	for i in count:
		var current := ring[index]
		var next := ring[(index + 1) % period]
		out[i] = current
		ring[index] = damping * 0.5 * (current + next)
		index = (index + 1) % period
	return normalize(fade_edges(out, 0.003, rate), 0.9)


## A pipe: a soft tone with a little breath and vibrato that swells in.
static func flute(freq: float, seconds: float, seed_value: int, rate: int = RATE) -> PackedFloat32Array:
	var out := tone([[freq, 1.0], [freq * 2.0, 0.25], [freq * 3.0, 0.08]], seconds, 0.0, 0.07, 0.8, 5.0, 0.006, 0.05, seed_value, rate)
	return out


## A soft pad: a few slightly detuned tones, rising and falling slowly.
static func pad(freq: float, seconds: float, rate: int = RATE) -> PackedFloat32Array:
	var count := roundi(seconds * rate)
	var out := PackedFloat32Array()
	out.resize(count)
	for i in count:
		var t := float(i) / float(rate)
		var envelope := minf(1.0, t / 0.8) * minf(1.0, (seconds - t) / 0.8)
		out[i] = (sin(TAU * freq * t) + 0.6 * sin(TAU * freq * 1.004 * t) + 0.35 * sin(TAU * freq * 2.0 * t)) * envelope
	return normalize(out, 0.9)


## An instrument's note: `midi` is the note number (60 is middle C).
static func note(instrument: String, midi: int, seconds: float, seed_value: int = 1, rate: int = RATE) -> PackedFloat32Array:
	var freq := 440.0 * pow(2.0, float(midi - 69) / 12.0)
	match instrument:
		"harp":
			return pluck(freq, seconds, 0.9985, 0.55, seed_value + midi, rate)
		"flute":
			return flute(freq, seconds, seed_value + midi, rate)
		"pad":
			return pad(freq, seconds, rate)
		"drum":
			return thump(freq, seconds, 0.7, seed_value + midi, rate)
		_:
			return pluck(freq, seconds, 0.9965, 0.3, seed_value + midi, rate)


# --- turning it into something the engine can play -------------------------------------------

## 16-bit little-endian samples.
static func to_bytes(buffer: PackedFloat32Array) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(buffer.size() * 2)
	for i in buffer.size():
		bytes.encode_s16(i * 2, clampi(roundi(buffer[i] * 32767.0), -32768, 32767))
	return bytes


static func to_stream(buffer: PackedFloat32Array, loop: bool = false, rate: int = RATE) -> AudioStreamWAV:
	return stream_from_bytes(to_bytes(buffer), buffer.size(), loop, rate)


static func stream_from_bytes(bytes: PackedByteArray, samples: int, loop: bool = false, rate: int = RATE) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = bytes
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = samples
	return stream
