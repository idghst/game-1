extends Node
## 배포 빌드 실기 검증(CI 러너용). 실행 인자 뒤에 붙일 때만 동작하고 평소에는 아무것도 하지 않는다.
##   HollowVigil.exe --headless --fixed-fps 60 -- --smoke
##     GodotSteam 확장 로드, Steam 없이 동작, user:// 저장 왕복, 기본 패드 배치(XInput 표준),
##     타이틀 로드 → 무적 봇으로 한 판(9층 엔딩)까지 자동 플레이
##   HollowVigil.exe -- --smoke-render
##     실제 창과 렌더러로 타이틀·전투를 그려 스크린샷을 남기고, 창·전체화면에서 정수 배율인지 확인
## 결과는 표준 출력과 user://smoke_result.txt 에 쓰고, 실패가 있으면 종료 코드 1.

const Bot = preload("res://scripts/bot.gd")
const RUN_LIMIT := 60.0 * 40.0  # 게임 시간 40분이 넘으면 멈춘 것으로 본다

var mode := ""
var fails: Array[String] = []
var lines: Array[String] = []
var main: Node2D
var victory := -1
var frames := 0
var step := 0
var t := 0.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	mode = "smoke" if "--smoke" in args else ("render" if "--smoke-render" in args else "")
	if mode == "":
		set_process(false)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	note("build: %s %s, arch %s, display %s, renderer %s, exe %s" % [OS.get_name(), OS.get_version(), Engine.get_architecture_name(),
		DisplayServer.get_name(), RenderingServer.get_current_rendering_driver_name(), OS.get_executable_path()])
	check(Engine.has_singleton("Steam"), "GodotSteam GDExtension loaded (DLL/dylib)")
	check(not SteamService.active, "runs without a Steam client")
	_check_save()
	_check_pad_defaults()


func note(s: String) -> void:
	lines.append(s)
	print("[smoke] ", s)


func check(ok: bool, what: String) -> void:
	note(("OK   " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)


func _check_save() -> void:
	var p := "user://smoke_profile.json"
	Profile.path = p  # 실제 진행 파일은 건드리지 않는다
	Profile.data = Profile.defaults()
	var earned: int = Profile.record_run({"floor": 3, "kills": 50, "elites": 1, "bosses": 1, "time": 300.0}, false, 10)
	var back: Dictionary = Profile.load_from(p)
	check(back.embers == earned and back.totals.runs == 1, "profile write/read at %s" % ProjectSettings.globalize_path(p))
	Settings.path = "user://smoke_settings.cfg"
	Settings.save()
	var cfg := ConfigFile.new()
	check(cfg.load(Settings.path) == OK and cfg.get_value("display", "scale") == Settings.scale, "settings write/read")
	DirAccess.remove_absolute(p)
	DirAccess.remove_absolute(Settings.path)


# Windows의 XInput 패드는 Godot 표준 배치(A=0, B=1, X=2, Start=6, LB=9, LT=축4, RT=축5)로 들어온다
func _check_pad_defaults() -> void:
	var has := func(action: String, cls: String, idx: int) -> bool:
		for e in InputMap.action_get_events(action):
			if e.get_class() == cls and (e.button_index if e is InputEventJoypadButton else e.axis) == idx:
				return true
		return false
	check(has.call("shoot", "InputEventJoypadMotion", JOY_AXIS_TRIGGER_RIGHT) and has.call("dash", "InputEventJoypadButton", JOY_BUTTON_LEFT_SHOULDER)
		and has.call("interact", "InputEventJoypadButton", JOY_BUTTON_X) and has.call("pause", "InputEventJoypadButton", JOY_BUTTON_START)
		and has.call("ui_accept", "InputEventJoypadButton", JOY_BUTTON_A) and has.call("ui_cancel", "InputEventJoypadButton", JOY_BUTTON_B)
		and has.call("aim_right", "InputEventJoypadMotion", JOY_AXIS_RIGHT_X), "default gamepad bindings follow the XInput standard layout")


func _start_run(floor_n: int, room_type: String) -> void:
	main = load("res://main.tscn").instantiate()
	main.use_meta = false
	main.run_finished.connect(func(v: bool) -> void: victory = int(v))
	var old := get_tree().current_scene
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	if old:
		old.queue_free()
	if floor_n > 1 or room_type != "":
		main.floor_n = floor_n
		main._new_floor()
		for c in main.cells:
			if main.types[c] == room_type:
				main._enter(c, Vector2i.LEFT)
				break


func _integer_scale(label: String) -> void:
	var win := DisplayServer.window_get_size()
	var s := get_tree().root.get_final_transform().get_scale()
	check(s.x >= 1.0 and is_equal_approx(s.x, roundf(s.x)) and is_equal_approx(s.x, s.y),
		"%s: window %s, stretch scale %s is an integer" % [label, win, s])


func _shot(file: String) -> void:
	var img := get_tree().root.get_texture().get_image()
	img.save_png("user://" + file)
	note("screenshot %s %s" % [ProjectSettings.globalize_path("user://" + file), img.get_size()])


func _process(delta: float) -> void:
	frames += 1
	t += delta
	if mode == "smoke":
		_smoke()
	else:
		_render()


func _smoke() -> void:
	match step:
		0:
			if frames > 30:
				check(get_tree().current_scene != null and get_tree().current_scene.scene_file_path == "res://title.tscn", "title scene loaded")
				_start_run(1, "")
				var bot := Bot.new()
				bot.main = main
				main.add_child(bot)
				step = 1
		1:
			if is_instance_valid(main) and main.player:
				main.player.hp = main.player.max_hp  # 무적: 한 판 전체(9층·보스 3종·엔딩)를 지나가게
			if victory != -1 or main.stats.time > RUN_LIMIT:
				check(victory == 1, "autoplay run reached the ending (floor %d, %.1f min, %d kills)" % [main.floor_n, main.stats.time / 60.0, main.stats.kills])
				_finish()


func _render() -> void:
	match step:
		0:
			if frames > 60:
				_integer_scale("windowed title")
				_shot("smoke_title.png")
				_start_run(4, "combat")
				t = 0.0
				step = 1
		1:
			if t > 2.0:
				_shot("smoke_combat.png")
				Settings.fullscreen = true
				Settings.apply()
				t = 0.0
				step = 2
		2:
			if t > 1.5:
				_integer_scale("fullscreen")
				_shot("smoke_fullscreen.png")
				Settings.fullscreen = false
				Settings.scale = 2
				Settings.apply()
				t = 0.0
				step = 3
		3:
			if t > 1.0:
				_integer_scale("windowed 2x")
				_finish()


func _finish() -> void:
	set_process(false)
	note("RESULT: %s (%d failures)" % ["PASS" if fails.is_empty() else "FAIL", fails.size()])
	var f := FileAccess.open("user://smoke_result.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(lines) + "\n")
		f.close()
	get_tree().quit(0 if fails.is_empty() else 1)
