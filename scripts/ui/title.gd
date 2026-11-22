extends Control
## 타이틀 화면: 새 게임, 강화(메타 진행), 설정, 크레딧, 종료.

const Menu = preload("res://scripts/ui/menu.gd")
const SettingsMenu = preload("res://scripts/ui/settings_menu.gd")

var _box: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().paused = false
	Engine.time_scale = 1.0
	var bg := TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var tex_path := "res://assets/sprites/title.png"
	if ResourceLoader.exists(tex_path):
		bg.texture = load(tex_path)
	add_child(bg)
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.02, 0.05, 0.45)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var logo_path := "res://assets/logo/logo.svg"
	if ResourceLoader.exists(logo_path):
		var logo := TextureRect.new()
		logo.texture = load(logo_path)
		logo.position = Vector2(240 - logo.texture.get_width() / 2.0, 22)
		add_child(logo)
	else:
		var title := Label.new()
		title.text = tr("GAME_TITLE")
		title.add_theme_font_size_override("font_size", 32)
		title.add_theme_color_override("font_color", Color("f8c040"))
		title.add_theme_color_override("font_outline_color", Color("17141d"))
		title.add_theme_constant_override("outline_size", 4)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.size.x = 480
		title.position.y = 36
		add_child(title)
	_box = VBoxContainer.new()
	_box.position = Vector2(180, 120)
	_box.custom_minimum_size.x = 120
	add_child(_box)
	Menu.button(_box, tr("NEW_RUN"), func() -> void: get_tree().change_scene_to_file("res://main.tscn"))
	if ResourceLoader.exists("res://scripts/ui/meta_menu.gd"):
		Menu.button(_box, tr("META_TITLE"), _open_meta)
	Menu.button(_box, tr("SETTINGS"), _open_settings)
	Menu.button(_box, tr("CREDITS"), _open_credits)
	if OS.get_name() != "Web":
		Menu.button(_box, tr("QUIT"), func() -> void: get_tree().quit())
	var info := Label.new()
	info.text = "%s %d   v%s" % [tr("EMBERS"), Profile.data.embers, ProjectSettings.get_setting("application/config/version", "0.1.0")]
	info.add_theme_color_override("font_color", Color("85798e"))
	info.position = Vector2(4, 256)
	add_child(info)
	Menu.focus_first(_box)
	Sfx.music("music_menu")


func _open_settings() -> void:
	var s := SettingsMenu.new()
	add_child(s)
	s.open_focus()
	s.closed.connect(func() -> void: get_tree().reload_current_scene())  # 언어 변경 반영


func _open_meta() -> void:
	var m: Control = load("res://scripts/ui/meta_menu.gd").new()
	add_child(m)
	m.closed.connect(func() -> void: get_tree().reload_current_scene())


func _open_credits() -> void:
	var root := Menu.overlay(self, 0.8)
	var box := Menu.panel(root, tr("CREDITS"), 280)
	var l := Label.new()
	l.text = tr("CREDITS_TEXT")
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 280
	box.add_child(l)
	var back := Menu.button(box, tr("BACK"), func() -> void:
		root.queue_free()
		Menu.focus_first(_box))
	back.grab_focus.call_deferred()
