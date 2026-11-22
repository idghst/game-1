extends Node
## 설정: 음량·화면·흔들림·언어·키/패드 배치. user://settings.cfg에 저장하고,
## 파일이 없거나 깨져 있으면 기본값으로 시작한다. 공용 UI 테마와 메뉴 효과음도 여기서 건다.

signal changed

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const PATH := "user://settings.cfg"
const REBINDABLE := ["move_up", "move_down", "move_left", "move_right", "shoot", "dash", "interact", "pause"]

var path := PATH  # 테스트용으로 바꿀 수 있다
var master := 0.8
var music := 0.7
var sfx := 0.8
var fullscreen := false
var scale := 3
var shake := true
var locale := ""  # 비어 있으면 OS 언어
var bindings := {}  # action -> {"kb": 이벤트 사전, "pad": 이벤트 사전}
var _theme: Theme
var _applied_display := []
var _defaults := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in REBINDABLE:
		_defaults[a] = {"kb": _slot_event(a, "kb"), "pad": _slot_event(a, "pad")}
	if not FileAccess.file_exists(path) and SteamService.on_deck:
		fullscreen = true  # Steam Deck 첫 실행은 전체 화면
	load_settings()
	apply()
	_theme = UiTheme.build()
	get_tree().root.theme = _theme
	get_tree().node_added.connect(_on_node_added)


# 메뉴 버튼마다 효과음을 달고, CanvasLayer 바로 아래 컨트롤에도 공용 테마를 준다
# (CanvasLayer는 창 테마 상속을 끊는다)
func _on_node_added(n: Node) -> void:
	if n is Control and n.get_parent() is CanvasLayer and n.theme == null:
		n.theme = _theme
	if n is BaseButton or n is Slider:
		n.focus_entered.connect(func() -> void: Sfx.play("ui_move", -8.0))
	if n is BaseButton:
		n.pressed.connect(func() -> void: Sfx.play("ui_select", -4.0))


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return  # 없거나 깨진 파일: 기본값 유지
	master = clampf(_num(cfg.get_value("audio", "master", master), master), 0.0, 1.0)
	music = clampf(_num(cfg.get_value("audio", "music", music), music), 0.0, 1.0)
	sfx = clampf(_num(cfg.get_value("audio", "sfx", sfx), sfx), 0.0, 1.0)
	fullscreen = cfg.get_value("display", "fullscreen", fullscreen) == true
	scale = clampi(int(_num(cfg.get_value("display", "scale", scale), scale)), 1, 4)
	shake = cfg.get_value("game", "shake", shake) != false
	var loc = cfg.get_value("game", "locale", locale)
	locale = loc if loc in ["", "en", "ko"] else ""
	var b = cfg.get_value("input", "bindings", {})
	if b is Dictionary:
		for a in b:
			if a in REBINDABLE and b[a] is Dictionary:
				for slot in ["kb", "pad"]:
					if b[a].get(slot) is Dictionary and to_event(b[a][slot]) != null:
						bindings.get_or_add(a, {})[slot] = b[a][slot]


func _num(v, fallback: float) -> float:
	return float(v) if v is float or v is int else fallback


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master)
	cfg.set_value("audio", "music", music)
	cfg.set_value("audio", "sfx", sfx)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("display", "scale", scale)
	cfg.set_value("game", "shake", shake)
	cfg.set_value("game", "locale", locale)
	cfg.set_value("input", "bindings", bindings)
	cfg.save(path)


func apply() -> void:
	for bus in [["Master", master], ["Music", music], ["SFX", sfx]]:
		var i := AudioServer.get_bus_index(bus[0])
		if i >= 0:
			AudioServer.set_bus_volume_db(i, linear_to_db(maxf(bus[1], 0.0001)))
	Fx.shake_enabled = shake
	TranslationServer.set_locale(locale if locale != "" else OS.get_locale_language())
	# 창은 화면 설정이 바뀔 때만 건드린다(음량 슬라이더를 움직일 때마다 창이 가운데로 튀지 않게)
	if DisplayServer.get_name() != "headless" and _applied_display != [fullscreen, scale]:
		_applied_display = [fullscreen, scale]
		if fullscreen:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			var size := Vector2i(480, 270) * scale
			DisplayServer.window_set_size(size)
			var screen := DisplayServer.screen_get_usable_rect()
			DisplayServer.window_set_position(screen.position + (screen.size - size) / 2)
	for a in REBINDABLE:
		for slot in ["kb", "pad"]:
			_set_slot(a, slot, to_event(bindings.get(a, {}).get(slot, _defaults[a][slot])))
	changed.emit()


func rebind(action: String, slot: String, ev: InputEvent) -> void:
	bindings.get_or_add(action, {})[slot] = from_event(ev)
	apply()
	save()


func reset_bindings() -> void:
	bindings = {}
	apply()
	save()


# 슬롯: kb = 키보드·마우스, pad = 게임패드
static func slot_of(ev: InputEvent) -> String:
	return "pad" if ev is InputEventJoypadButton or ev is InputEventJoypadMotion else "kb"


func _slot_event(action: String, slot: String) -> Dictionary:
	for ev in InputMap.action_get_events(action):
		if slot_of(ev) == slot:
			return from_event(ev)
	return {}


func _set_slot(action: String, slot: String, ev: InputEvent) -> void:
	for old in InputMap.action_get_events(action):
		if slot_of(old) == slot:
			InputMap.action_erase_event(action, old)
	if ev:
		InputMap.action_add_event(action, ev)


func event_for(action: String, slot: String) -> InputEvent:
	for ev in InputMap.action_get_events(action):
		if slot_of(ev) == slot:
			return ev
	return null


static func from_event(ev: InputEvent) -> Dictionary:
	if ev is InputEventKey:
		return {"t": "key", "code": ev.physical_keycode if ev.physical_keycode else ev.keycode}
	if ev is InputEventMouseButton:
		return {"t": "mouse", "b": ev.button_index}
	if ev is InputEventJoypadButton:
		return {"t": "joyb", "b": ev.button_index}
	if ev is InputEventJoypadMotion:
		return {"t": "joya", "a": ev.axis, "v": signf(ev.axis_value)}
	return {}


static func to_event(d: Dictionary) -> InputEvent:
	match d.get("t"):
		"key":
			var e := InputEventKey.new()
			e.physical_keycode = int(d.get("code", 0))
			return e if e.physical_keycode > 0 else null
		"mouse":
			var e := InputEventMouseButton.new()
			e.button_index = int(d.get("b", 1))
			return e
		"joyb":
			var e := InputEventJoypadButton.new()
			e.button_index = int(d.get("b", 0))
			return e
		"joya":
			var e := InputEventJoypadMotion.new()
			e.axis = int(d.get("a", 0))
			e.axis_value = 1.0 if float(d.get("v", 1.0)) >= 0 else -1.0
			return e
	return null


# 화면에 보여 줄 입력 이름
static func event_label(ev: InputEvent) -> String:
	if ev == null:
		return "-"
	if ev is InputEventKey:
		return OS.get_keycode_string(ev.physical_keycode if ev.physical_keycode else ev.keycode)
	if ev is InputEventMouseButton:
		return {1: "LMB", 2: "RMB", 3: "MMB"}.get(ev.button_index, "Mouse %d" % ev.button_index)
	if ev is InputEventJoypadButton:
		return {0: "A", 1: "B", 2: "X", 3: "Y", 4: "Back", 6: "Start", 7: "LS", 8: "RS", 9: "LB", 10: "RB",
			11: "D-Up", 12: "D-Down", 13: "D-Left", 14: "D-Right"}.get(ev.button_index, "Btn %d" % ev.button_index)
	if ev is InputEventJoypadMotion:
		var names := {0: "LS X", 1: "LS Y", 2: "RS X", 3: "RS Y", 4: "LT", 5: "RT"}
		var n: String = names.get(ev.axis, "Axis %d" % ev.axis)
		return n if ev.axis >= 4 else n + ("+" if ev.axis_value > 0 else "-")
	return "?"
