extends SceneTree
## 게임패드 전용 조작 자가검증: godot --headless --path . -s tests/test_gamepad.gd
## 키보드·마우스 없이 패드 입력(D패드, A, B, Start)만으로 타이틀 → 잿불 제단 → 설정 → 새 게임 →
## 일시정지 → 계속 → 포기 → 결과 화면 → 다시 도전까지 갈 수 있는지 확인한다.

const A := JOY_BUTTON_A
const B := JOY_BUTTON_B
const START := JOY_BUTTON_START
const DOWN := JOY_BUTTON_DPAD_DOWN

var fails := 0
var steps: Array[Callable] = []
var wait := 0
var frames := 0
var _restarted := false


func check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		printerr("FAIL: ", msg)


func press(button: JoyButton) -> void:
	for pressed in [true, false]:
		var e := InputEventJoypadButton.new()
		e.button_index = button
		e.pressed = pressed
		Input.parse_input_event(e)


func focused_text() -> String:
	var f := root.gui_get_focus_owner()
	return f.text if f is Button else ""


func find(type: String) -> Node:
	var found := root.find_children("*", type, true, false)
	return found[0] if not found.is_empty() else null


func scripted(path: String) -> Node:
	for n in root.find_children("*", "Control", true, false):
		if n.get_script() and n.get_script().resource_path == path:
			return n
	return null


func _initialize() -> void:
	var profile_path := "user://test_gamepad_profile.json"
	steps = [
		func() -> void:
			root.get_node("Profile").path = profile_path  # 실제 저장을 건드리지 않게
			change_scene_to_file("res://title.tscn"),
		func() -> void:
			check(focused_text() == TranslationServer.translate("NEW_RUN"), "title focuses first button (got '%s')" % focused_text())
			press(DOWN),
		func() -> void:
			check(focused_text() == TranslationServer.translate("META_TITLE"), "d-pad down moves focus to Ember Altar")
			press(A),
		func() -> void:
			check(scripted("res://scripts/ui/meta_menu.gd") != null, "A opens Ember Altar")
			press(B),
		func() -> void:
			check(scripted("res://scripts/ui/meta_menu.gd") == null, "B closes Ember Altar")
			press(DOWN)
			press(DOWN),
		func() -> void:
			check(focused_text() == TranslationServer.translate("SETTINGS"), "focus reaches Settings")
			press(A),
		func() -> void:
			check(scripted("res://scripts/ui/settings_menu.gd") != null, "A opens Settings")
			check(root.gui_get_focus_owner() is HSlider, "settings focuses the first slider")
			press(B),
		func() -> void:
			check(scripted("res://scripts/ui/settings_menu.gd") == null, "B closes Settings")
			check(focused_text() == TranslationServer.translate("NEW_RUN"), "focus returns to the title menu")
			press(A),
		func() -> void:
			check(current_scene and current_scene.scene_file_path == "res://main.tscn", "A on Begin starts a run")
			current_scene.use_meta = false
			press(START),
		func() -> void:
			check(paused and scripted("res://scripts/ui/pause_menu.gd") != null, "Start opens pause menu")
			press(B),
		func() -> void:
			check(not paused and scripted("res://scripts/ui/pause_menu.gd") == null, "B resumes")
			press(START),
		func() -> void:
			press(DOWN)
			press(DOWN),
		func() -> void:
			check(focused_text() == TranslationServer.translate("ABANDON"), "focus reaches Abandon")
			press(A),
	]


func _process(_d: float) -> bool:
	frames += 1
	if frames > 20000:
		printerr("FAIL: timeout")
		quit(1)
		return true
	if wait > 0:
		wait -= 1
		return false
	if not steps.is_empty():
		steps.pop_front().call()
		wait = 6
		return false
	# 포기 후 결과 화면(쓰러지는 연출 1.2초 뒤)에서 A로 다시 도전
	if not _restarted:
		if paused and focused_text() == TranslationServer.translate("RESTART"):
			press(A)
			_restarted = true
			wait = 6
		return false
	check(current_scene and current_scene.scene_file_path == "res://main.tscn" and not paused, "A on results restarts a run")
	DirAccess.remove_absolute("user://test_gamepad_profile.json")
	print("gamepad self-test: %d failures" % fails)
	quit(1 if fails else 0)
	return true
