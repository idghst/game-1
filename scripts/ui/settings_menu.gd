extends Control
## 설정 화면: 음량, 전체화면/창 배율, 화면 흔들림, 언어, 키·패드 재설정. 바뀌면 바로 적용·저장한다.

signal closed

const Menu = preload("res://scripts/ui/menu.gd")
const ACTION_KEYS := {"move_up": "ACT_MOVE_UP", "move_down": "ACT_MOVE_DOWN", "move_left": "ACT_MOVE_LEFT",
	"move_right": "ACT_MOVE_RIGHT", "shoot": "ACT_SHOOT", "dash": "ACT_DASH", "interact": "ACTION_INTERACT", "pause": "ACT_PAUSE"}
const LOCALES := ["", "en", "ko"]

var _box: VBoxContainer
var _capture := {}  # {"action", "slot", "button", "t"} 입력 대기 중
var _scroll: ScrollContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.75)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var outer := VBoxContainer.new()
	panel.add_child(outer)
	var title := Label.new()
	title.text = tr("SETTINGS")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("f8c040"))
	Menu.UiTheme.big(title)
	outer.add_child(title)
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(280, 190)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	outer.add_child(_scroll)
	_box = VBoxContainer.new()
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_box)
	Menu.button(outer, tr("BACK"), _close)
	_build()


func _build() -> void:
	for c in _box.get_children():
		c.queue_free()
	_section("SET_AUDIO")
	_slider("SET_MASTER", "master")
	_slider("SET_MUSIC", "music")
	_slider("SET_SFX", "sfx")
	_section("SET_DISPLAY")
	_toggle("SET_FULLSCREEN", "fullscreen")
	_cycle("SET_SCALE", "%dx" % Settings.scale, func() -> void: Settings.scale = Settings.scale % 4 + 1)
	_section("SET_GAMEPLAY")
	_toggle("SET_SHAKE", "shake")
	var lang_names := {"": tr("LANG_AUTO"), "en": "English", "ko": "한국어"}
	_cycle("SET_LANGUAGE", lang_names[Settings.locale], func() -> void:
		Settings.locale = LOCALES[(LOCALES.find(Settings.locale) + 1) % LOCALES.size()])
	_section("SET_CONTROLS")
	var hint := Label.new()
	hint.text = tr("SET_CONTROLS_HINT")
	hint.add_theme_color_override("font_color", Color("85798e"))
	_box.add_child(hint)
	for a in Settings.REBINDABLE:
		var row := HBoxContainer.new()
		var l := Label.new()
		l.text = tr(ACTION_KEYS[a])
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		for slot in ["kb", "pad"]:
			var b := Button.new()
			b.custom_minimum_size.x = 64
			b.text = Settings.event_label(Settings.event_for(a, slot))
			b.pressed.connect(_start_capture.bind(a, slot, b))
			row.add_child(b)
		_box.add_child(row)
	Menu.button(_box, tr("SET_RESET_KEYS"), func() -> void:
		Settings.reset_bindings()
		_rebuild_keep_focus())


func _section(key: String) -> void:
	var l := Label.new()
	l.text = tr(key)
	l.add_theme_color_override("font_color", Color("a85ac8"))
	_box.add_child(l)


func _slider(key: String, prop: String) -> void:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = tr(key)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = Settings.get(prop)
	s.custom_minimum_size.x = 130
	s.focus_mode = Control.FOCUS_ALL
	s.value_changed.connect(func(v: float) -> void:
		Settings.set(prop, v)
		Settings.apply()
		Settings.save()
		if prop == "sfx":
			Sfx.play("coin"))
	row.add_child(s)
	_box.add_child(row)


func _toggle(key: String, prop: String) -> void:
	var b := CheckButton.new()
	b.text = tr(key)
	b.button_pressed = Settings.get(prop)
	b.toggled.connect(func(on: bool) -> void:
		Settings.set(prop, on)
		Settings.apply()
		Settings.save())
	_box.add_child(b)


func _cycle(key: String, value: String, step: Callable) -> void:
	var b := Button.new()
	b.text = "%s: %s" % [tr(key), value]
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(func() -> void:
		step.call()
		Settings.apply()
		Settings.save()
		_rebuild_keep_focus())
	_box.add_child(b)


# 다시 그린 뒤에도 같은 위치의 항목에 포커스를 남긴다(패드 조작 흐름이 끊기지 않게)
func _rebuild_keep_focus() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	var idx := -1
	var all := _box.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n is Control and n.focus_mode == Control.FOCUS_ALL)
	if focused:
		idx = all.find(focused)
	_build()
	await get_tree().process_frame
	all = _box.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n is Control and n.focus_mode == Control.FOCUS_ALL and not n.is_queued_for_deletion())
	if idx >= 0 and idx < all.size():
		all[idx].grab_focus()
	title_refresh()


func title_refresh() -> void:
	# 언어가 바뀌면 제목·뒤로 버튼 글자도 바뀌어야 한다
	var outer: VBoxContainer = _scroll.get_parent()
	outer.get_child(0).text = tr("SETTINGS")
	outer.get_child(2).text = tr("BACK")


func _start_capture(action: String, slot: String, b: Button) -> void:
	_capture = {"action": action, "slot": slot, "button": b, "t": 0.0}
	b.text = tr("SET_PRESS_KEY") if slot == "kb" else tr("SET_PRESS_BUTTON")


func _process(delta: float) -> void:
	if not _capture.is_empty():
		_capture.t += delta
		if _capture.t > 6.0:
			_capture.button.text = Settings.event_label(Settings.event_for(_capture.action, _capture.slot))
			_capture = {}


func _input(event: InputEvent) -> void:
	if _capture.is_empty():
		if event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			_close()
		return
	get_viewport().set_input_as_handled()
	if _capture.t < 0.2 or not event.is_pressed() or event.is_echo():
		return  # 버튼을 누른 그 입력은 무시
	var slot: String = _capture.slot
	if Settings.slot_of(event) != slot:
		return
	if event is InputEventJoypadMotion and absf(event.axis_value) < 0.6:
		return
	if not (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton or event is InputEventJoypadMotion):
		return
	if event is InputEventKey and event.physical_keycode == KEY_ESCAPE and _capture.action != "pause":
		_capture.button.text = Settings.event_label(Settings.event_for(_capture.action, slot))
	else:
		Settings.rebind(_capture.action, slot, event)
		_capture.button.text = Settings.event_label(Settings.event_for(_capture.action, slot))
	var b: Button = _capture.button
	_capture = {}
	b.grab_focus()


func open_focus() -> void:
	Menu.focus_first(_box)


func _close() -> void:
	closed.emit()
	queue_free()
