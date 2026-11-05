## Autoload «Sfx»: μουσική υπόκρουσης και ηχητικά εφέ.
##
## Κάθε ήχος (music, countdown, stop, win, lose) έχει στο config: αρχείο
## ("" = ενσωματωμένος προεπιλεγμένος), ένταση 0..1 και on/off. Υπάρχει και
## γενικό mute. Οι αλλαγές στο config εφαρμόζονται αμέσως (σήμα Config.changed).
extends Node

const AssetLoader = preload("res://scripts/util/asset_loader.gd")

const DEFAULT_SOUNDS := {
	"music": "res://assets/audio/music.wav",
	"countdown": "res://assets/audio/countdown.wav",
	"stop": "res://assets/audio/stop.wav",
	"win": "res://assets/audio/win.wav",
	"lose": "res://assets/audio/lose.wav",
}
const POOL_SIZE := 6

var _music: AudioStreamPlayer
var _music_path := ""
var _pool: Array = []
var _next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music = AudioStreamPlayer.new()
	_music.finished.connect(_on_music_finished)
	add_child(_music)
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	Config.changed.connect(_apply_config)
	_apply_config()


func _cfg(key: String) -> Dictionary:
	return Config.data["audio"][key]


func _muted() -> bool:
	return bool(Config.data["audio"]["master_mute"])


## Διαδρομή αρχείου για έναν ήχο (το αρχείο του διαχειριστή ή το προεπιλεγμένο).
func path_for(key: String) -> String:
	var f := str(_cfg(key).get("file", ""))
	return f if f != "" else str(DEFAULT_SOUNDS.get(key, ""))


func _apply_config() -> void:
	if _music == null:
		return
	var c := _cfg("music")
	var path := path_for("music")
	var want := bool(c["enabled"]) and not _muted()
	_music.volume_db = linear_to_db(maxf(float(c["volume"]), 0.0001))
	if not want:
		_music.stop()
		return
	if path != _music_path or not _music.playing:
		_music_path = path
		_music.stream = _looping(AssetLoader.sound(path))
		if _music.stream != null:
			_music.play()


## Ενεργοποιεί το loop όπου το υποστηρίζει ο τύπος (OGG/MP3). Για WAV (και ως
## δίχτυ ασφαλείας) ξαναξεκινά η αναπαραγωγή στο σήμα `finished`.
func _looping(stream: AudioStream) -> AudioStream:
	if stream == null:
		return null
	if stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
		var s: AudioStream = stream.duplicate()
		s.set("loop", true)
		return s
	return stream


func _on_music_finished() -> void:
	if bool(_cfg("music")["enabled"]) and not _muted() and _music.stream != null:
		_music.play()


## Παίζει έναν από τους ρυθμιζόμενους ήχους (countdown, stop, win, lose).
func play(key: String, pitch: float = 1.0) -> void:
	var c := _cfg(key)
	if _muted() or not bool(c["enabled"]):
		return
	_play_stream(AssetLoader.sound(path_for(key)), float(c["volume"]), pitch)


## Παίζει ένα αρχείο ήχου (π.χ. ο ήχος ενός εικονιδίου στον «Τροχό»).
func play_file(path: String, volume: float = 1.0) -> void:
	if _muted() or path == "":
		return
	_play_stream(AssetLoader.sound(path), volume, 1.0)


func _play_stream(stream: AudioStream, volume: float, pitch: float) -> void:
	if stream == null:
		return
	var p: AudioStreamPlayer = _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = stream
	p.volume_db = linear_to_db(maxf(volume, 0.0001))
	p.pitch_scale = pitch
	p.play()


func stop_all_effects() -> void:
	for p in _pool:
		p.stop()


## Μετά από επαναφορά της εφαρμογής (Android) η μουσική μπορεί να έχει σταματήσει.
func resume_music() -> void:
	if _music != null and not _music.playing:
		_music_path = ""
		_apply_config()
