extends Node

var default_settings := {
	"dir_history": {}
}

var settings := {}
var settings_dirty := false

var directory := ""
var files := {}
var filtered_files := []
var selected_files := []
var selected_file_index := 0

onready var dirbutton := $"%dirbutton"
onready var dirdialog := $"%dirdialog"
onready var preview := $"%preview"
onready var btn_new_cap := $"%btn_new_cap"
onready var edit_cap := $"%edit_cap"
onready var file_filter := $"%file_filter"
onready var file_list := $"%file_list"
onready var file_info := $"%file_info"
onready var btn_zip: MenuButton = $"%btn_zip"
onready var btn_recent: MenuButton = $"%btn_recent"
onready var btn_sorton: MenuButton = $"%btn_sorton"
onready var caption_token_count := $"%caption_token_count"

var sort_mode := 0
var sort_modes := {
	"name": { "text": "Name" },
	"size_l": { "text": "Size (Large to small)" },
	"size_s": { "text": "Size (Small to large)" },
	"mod_new": { "text": "Modified (Newest to oldest)" },
	"mod_old": { "text": "Modified (Oldest to newest)" },
	"created_new": { "text": "Created (Newest to oldest)" },
	"created_old": { "text": "Created (Oldest to newest)" },
	"tokens_most": { "text": "Tokens (Most to least)" },
	"tokens_least": { "text": "Tokens (Least to most)" },
}

func _load_settings(to, from):
	for k in from:
		match typeof(from[k]):
			TYPE_DICTIONARY:
				if not k in to:
					settings_dirty = true
					to[k] = {}
				_load_settings(to[k], from[k])
			_:
				if not k in to or to[k] != from[k]:
					settings_dirty = true
					to[k] = from[k]
		
func load_settings():
	settings = default_settings.duplicate(true)
	var loaded: Dictionary = JSON.parse(read("user://settings.json", "{}")).result
	_load_settings(settings, loaded)

func _ready():
	load_settings()
	
	var _e
	_e = dirbutton.connect("pressed", self, "_show_dirdialog")
	_e = dirdialog.connect("dir_selected", self, "set_dir")
	
	var popup: PopupMenu = btn_sorton.get_popup()
	_e = popup.connect("index_pressed", self, "_sorton_pressed")
	var index := 0
	for k in sort_modes:
		var v = sort_modes[k]
		popup.add_item(v["text"], index)
		popup.set_item_metadata(index, k)
		index += 1
	
	popup = btn_zip.get_popup()
	_e = popup.connect("index_pressed", self, "_zip_pressed")
	popup.add_item("Captions & Images", 0)
	popup.add_item("Captions", 1)
	popup.add_item("Images", 2)
	
	popup = btn_recent.get_popup()
	_e = popup.connect("index_pressed", self, "_recent_pressed")
	var dirs: Dictionary = get_setting("dir_history")
	if dirs:
		dirs = sorted(dirs)
		for dir in dirs:
			popup.add_item(dir)
	
	_e = btn_new_cap.connect("pressed", self, "_new_caption")
	_e = edit_cap.connect("text_changed", self, "_caption_changed")
	_e = file_list.connect("meta_clicked", self, "_select_file")
	_e = file_filter.connect("text_changed", self, "_file_filter_changed")
	
	# Get last dir.
	if dirs:
		dirs = sorted(dirs)
		set_dir(dirs.keys()[0])
	else:
		set_dir(ProjectSettings.globalize_path("res://dummyfolder"))

func all_files():
	return files.values()

func file_count():
	return len(files)

func _file_filter_changed(_filter := ""):
	update_filtered_list()
	update_file_list()
	
func update_filtered_list():
	var new_filter: String = file_filter.text
	if new_filter != "":
		filtered_files.clear()
		for file in all_files():
			if new_filter.to_lower() in file.caption.to_lower():
				filtered_files.append(file)
	else:
		filtered_files = all_files()
	
func sorted(d: Dictionary, method := "keys", reverse := false) -> Dictionary:
	var dsort := []
	for k in d:
		dsort.append([k, d[k]])
	dsort.sort_custom(self, "_sorton_%s" % [method])
	var newdict := {}
	if reverse:
		for i in range(len(dsort)-1, -1, -1):
			var item = dsort[i]
			newdict[item[0]] = item[1]
	else:
		for item in dsort:
			newdict[item[0]] = item[1]
	return newdict
	
func _sorton_keys(a, b): return a[1] < b[1]
func _sorton_keys_reverse(a, b): return a[1] > b[1]

func _caption_changed(_caption := ""):
	var file := file()
	file.caption = edit_cap.text
	file.unsaved = true
	file.mtime = OS.get_unix_time()
	update_token_count()

func _zip_pressed(index: int):
	match index:
		0: execute([ProjectSettings.globalize_path("res://zipper.py"), directory, "--captions", "--images"])
		1: execute([ProjectSettings.globalize_path("res://zipper.py"), directory, "--captions"])
		2: execute([ProjectSettings.globalize_path("res://zipper.py"), directory, "--images"])

func execute(args: Array):
	var output := []
	var err := OS.execute("python3", args, true, output, true)
	for line in output:
		print("[python] ", line)
	return err == OK

func _recent_pressed(index: int):
	var dir_path := btn_recent.get_popup().get_item_text(index)
	set_dir(dir_path)

func save_files():
	var unsaved := []
	for file in files.values():
		if file.unsaved:
			unsaved.append(file)
	
	unsaved.sort_custom(self, "_sorton_mtime")
	
	var saved := []
	for file in unsaved:
		var cappath := with_suffix(file.path, ".caption")
		var caption: String = file.caption
		write(cappath, caption)
		file.unsaved = false
		saved.append([cappath.rsplit("/", true, 1)[-1].rsplit(".", true, 1)[0], caption.substr(0, 64) + "..."])
	
	if saved:
		print("Saved %s caption(s)." % [len(saved)])
		for s in saved:
			print("\t%s: \"%s\"" % s)
		update_file_list()
	
func _new_caption():
	var file := file()
	write(with_suffix(file.path, ".caption"))
	select_file_at()
	
func _new_txt():
	var file := file()
	write(with_suffix(file.path, ".txt"))
	select_file_at()
	
func _select_file(file: Dictionary):
	# Select many files.
	if Input.is_key_pressed(KEY_CONTROL):
		if not file in selected_files:
			selected_files.append(file)
		update_file_list()
	# Select one file.
	else:
		selected_files.clear()
		selected_files.append(file)
		select_file_at(files.values().find(file))

func _sorton_pressed(index):
	sort_mode = index
	var info: Dictionary = sort_modes.values()[index]
	btn_sorton.text = "Sort: %s" % info.text
	sort_files()
	
func sort_files():
	var images_sorted := []
	for k in files:
		images_sorted.append([k, files[k]])
	
	images_sorted.sort_custom(self, "_sorton_%s" % [sort_modes.keys()[sort_mode]])
	
	files.clear()
	for item in images_sorted:
		files[item[0]] = item[1]
	
	update_filtered_list()
	update_file_list()

func _sorton_name(a, b): return a[1].path < b[1].path
func _sorton_size_l(a, b): return a[1].bytes > b[1].bytes
func _sorton_size_s(a, b): return a[1].bytes < b[1].bytes
func _sorton_mod_new(a, b): return a[1].mtime > b[1].mtime
func _sorton_mod_old(a, b): return a[1].mtime < b[1].mtime
func _sorton_created_new(a, b): return a[1].ctime > b[1].ctime
func _sorton_created_old(a, b): return a[1].ctime < b[1].ctime
func _sorton_mtime(a, b): return a.mtime < b.mtime

func _show_dirdialog():
#	OS.shell_open(str("file://", directory))
	dirdialog.show()

func exists(path: String) -> bool:
	return File.new().file_exists(path)

func read(path: String, default := "") -> String:
	var f := File.new()
	if f.file_exists(path):
		var _e := f.open(path, File.READ)
		var text := f.get_as_text()
		f.close()
		return text
	else:
		return default

func write(path: String, content = ""):
	if not typeof(content) == TYPE_STRING:
		content = JSON.print(content)
		
	var f := File.new()
	var _e := f.open(path, File.WRITE)
	f.store_string(content)
	f.close()

func set_setting(path: String, value):
	var s := settings
	var path_parts := path.split(";")
	for i in len(path_parts)-1:
		if not path_parts[i] in s:
			s[path_parts[i]] = {}
		s = s[path_parts[i]]
	
	var prop := path_parts[-1]
	if not prop in s or s[prop] != value:
		s[prop] = value
		settings_dirty = true

func get_setting(path: String, default := null):
	var s = settings
	for part in path.split(";"):
		if part in s:
			s = s[part]
		else:
			push_error("No %s in settings." % [path])
			return default
	return s

func set_dir(dir: String):
	print("Selected dir ", dir)
	
	if dir != "":
		set_setting("dir_history;%s"%dir, OS.get_unix_time())
	
	directory = dir
	dirbutton.text = dir
	selected_file_index = 0
	load_files()
	sort_files()
	update_label()
	update_image()

func file(index := selected_file_index) -> Dictionary:
	if index >= 0 and index < len(filtered_files):
		return filtered_files[index]
	return {}

func get_tokens(s: String) -> int:
	var tokens := 0
	for part in s.split(","):
		for word in part.strip_edges().split(" "):
			if word.strip_edges():
				tokens += 1
	return tokens
	
func update_label():
	var file: Dictionary = file(selected_file_index)
	if file:
		var path: String = file.path.trim_prefix(directory).trim_prefix("/")
		var tokens = get_tokens(file.caption)
		var size := "".humanize_size(file.get("bytes", 0))
		file_info.set_bbcode("[%s/%s]\nsize: %s\ntokens: %s\n%s" % [selected_file_index+1, file_count(), size, tokens, path])
	else:
		file_info.set_bbcode("???")

func update_image():
	preview.texture = null
	
	var file := file()
	if not file:
		return
	
	var image := Image.new()
	var err = image.load(file.path)
	if err != OK:
		print("Couldn't load ", file.path)
	else:
		var texture := ImageTexture.new()
		texture.create_from_image(image, 0)
		preview.texture = texture

func with_suffix(path: String, suffix: String) -> String:
	return path.rsplit(".", true, 1)[0] + suffix
	
func select_file_at(index: int = selected_file_index):
	selected_file_index = wrapi(index, 0, len(filtered_files))
	var file := file()
	var cap_path := with_suffix(file.path, ".caption")
	
	if exists(cap_path):
		btn_new_cap.visible = false
		edit_cap.visible = true
		edit_cap.text = file.caption
	else:
		btn_new_cap.visible = true
		edit_cap.visible = false
		edit_cap.text = ""
	
	update_token_count()
	
	edit_cap.cursor_set_column(len(edit_cap.text), true)
	edit_cap.grab_focus()
	edit_cap.grab_click_focus()
	
	update_label()
	update_image()
	update_file_list()

func update_token_count():
	caption_token_count.text = "%s/255" % get_tokens(edit_cap.text)

func load_files():
	files.clear()
	
	var output = []
	if execute([ProjectSettings.globalize_path("res://get_image_info.py"), directory]):
		var parsed := JSON.parse(read("tempdata.json"))
		if parsed.error == OK:
			files = parsed.result
	
	update_file_list()
	
func update_file_list():
	file_list.clear()
	var index := 0
	for file in filtered_files:
		if selected_file_index == index:
			file_list.push_color(Color.white)
		elif file in selected_files:
			file_list.push_color(Color.greenyellow)
		else:
			file_list.push_color(Color.webgray)
		var check := "[*]" if file.get("unsaved", false) else "[ ]"
		file_list.push_meta(file)
		file_list.append_bbcode("[color=black]%s[%s][/color] %s" % [check, index, file.path.rsplit("/", 1)[-1]])
		file_list.pop()
		file_list.pop()
		file_list.newline()
		index += 1

func get_tags(caption: String) -> Array:
	var tags := Array(caption.split(","))
	for i in tags:
		tags[i] = tags[i].strip_edges()
	return tags

func join_tags(tags: Array) -> String:
	return ", ".join(tags)

# Add tags to the front or back.
func bulk_tag(tags: String, append := false):
	var new_tags := get_tags(tags)
	for file in selected_files:
		var file_tags := get_tags(file)
		var changed := false
		for tag in new_tags:
			if not tag in file_tags:
				if append:
					file_tags.push_back(tag)
				else:
					file_tags.push_front(tag)
				changed = true
		if changed:
			file.caption = join_tags(file_tags)

func _image_pressed(img: Dictionary):
	select_file_at(files.values().find(img))
	
func _process(_delta):
	if Input.is_action_just_pressed("save_file"):
		save_files()
	
	if Input.is_action_just_pressed("prev_file"):
		select_file_at(filtered_files.find(file())-1)
	
	if Input.is_action_just_pressed("next_file"):
		select_file_at(filtered_files.find(file())+1)
	
	if Input.is_action_just_pressed("select_all_files"):
		selected_files.clear()
		selected_files.append_array(filtered_files)
	
	if settings_dirty:
		settings_dirty = false
		write("user://settings.json", settings)
		print("Saved user://settings.json")
