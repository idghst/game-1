extends Control
## 일시정지 메뉴: 계속, 설정, 포기(결과 화면으로), 타이틀로. Esc·Start·B로 닫는다.

signal resumed
signal abandoned

const Menu = preload("res://scripts/ui/menu.gd")
const SettingsMenu = preload("res://scripts/ui/settings_menu.gd")

var _box: VBoxContainer
var _settings_open := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_box = Menu.panel(self, tr("PAUSED"), 160)
	Menu.button(_box, tr("RESUME"), _resume)
	Menu.button(_box, tr("SETTINGS"), func() -> void:
		_settings_open = true
		var s := SettingsMenu.new()
		add_child(s)
		s.open_focus()
		s.closed.connect(func() -> void:
			_settings_open = false
			Menu.focus_first(_box)))
	Menu.button(_box, tr("ABANDON"), func() -> void:
		queue_free()
		abandoned.emit())
	Menu.button(_box, tr("TO_TITLE"), func() -> void:
		get_tree().paused = false
		get_tree().change_scene_to_file("res://title.tscn"))
	Menu.focus_first(_box)


func _unhandled_input(event: InputEvent) -> void:
	if _settings_open:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_resume()


func _resume() -> void:
	queue_free()
	resumed.emit()
