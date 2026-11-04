## Φόρτωση εικόνων και ήχων κατά το runtime.
##
## - `res://...`: αρχεία του project (demo θέμα, προεπιλογές) → ResourceLoader.
## - `user://...` ή απόλυτη διαδρομή: αρχεία που εισήγαγε ο διαχειριστής →
##   φορτώνονται «ωμά» (Image / AudioStream*) χωρίς import του editor.
##
## Κρατά cache ώστε κάθε αρχείο να φορτώνεται μία φορά.
extends RefCounted

static var _textures := {}
static var _sounds := {}


static func clear_cache() -> void:
	_textures.clear()
	_sounds.clear()


static func texture(path: String) -> Texture2D:
	if path == "":
		return null
	if _textures.has(path):
		return _textures[path]
	var tex: Texture2D = null
	if path.begins_with("res://"):
		if ResourceLoader.exists(path):
			tex = load(path) as Texture2D
			# Mipmaps για καθαρή σμίκρυνση (τα εικονίδια 512px εμφανίζονται μικρότερα).
			var src: Image = null
			if tex != null:
				src = tex.get_image()
			if src != null and not src.is_compressed() and not src.has_mipmaps():
				src.generate_mipmaps()
				tex = ImageTexture.create_from_image(src)
	elif FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img != null and not img.is_empty():
			img.generate_mipmaps()
			tex = ImageTexture.create_from_image(img)
	if tex == null:
		push_warning("Δεν φορτώθηκε η εικόνα: " + path)
	_textures[path] = tex
	return tex


static func sound(path: String) -> AudioStream:
	if path == "":
		return null
	if _sounds.has(path):
		return _sounds[path]
	var stream: AudioStream = null
	if path.begins_with("res://"):
		if ResourceLoader.exists(path):
			stream = load(path) as AudioStream
	elif FileAccess.file_exists(path):
		match path.get_extension().to_lower():
			"ogg":
				stream = AudioStreamOggVorbis.load_from_file(path)
			"wav":
				stream = AudioStreamWAV.load_from_file(path)
			"mp3":
				var f := FileAccess.open(path, FileAccess.READ)
				if f != null:
					var mp3 := AudioStreamMP3.new()
					mp3.data = f.get_buffer(f.get_length())
					stream = mp3
	if stream == null:
		push_warning("Δεν φορτώθηκε ο ήχος: " + path)
	_sounds[path] = stream
	return stream
