extends SceneTree
## 저장·설정 자가검증: godot --headless --path . -s tests/test_save.gd
## 손상되거나 엉뚱한 타입의 저장 파일에도 죽지 않고 기본값으로 시작하는지, 키 배치 직렬화가 왕복하는지 확인한다.
## 실제 사용자 파일을 건드리지 않도록 user://test_* 경로를 쓴다.

var fails := 0


func check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		printerr("FAIL: ", msg)


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _process(_d: float) -> bool:
	var profile: Node = root.get_node("Profile")
	var settings: Node = root.get_node("Settings")
	# 1) 프로필: 깨진 JSON → 기본값 + .bad 백업
	var p := "user://test_profile.json"
	DirAccess.remove_absolute(p + ".bad")
	_write(p, "{not json at all")
	var d: Dictionary = profile.load_from(p)
	check(d.embers == 0 and d.totals.runs == 0, "corrupt profile falls back to defaults")
	check(FileAccess.file_exists(p + ".bad"), "corrupt profile is kept as .bad")
	# 2) 엉뚱한 타입·범위
	for raw in [null, "text", 42, [], {"embers": "lots"}, {"meta": "x"}, {"totals": [1, 2]}, {"achievements": {"a": 1}}]:
		var s: Dictionary = profile.sanitize(raw)
		check(s.embers == 0 and s.meta.is_empty(), "sanitize(%s) gives defaults" % str(raw))
	var s2: Dictionary = profile.sanitize({"embers": -50, "meta": {"vigor": 9999, "bad": "x"}, "totals": {"kills": 12.0, "best_time": 61.5}, "achievements": ["king", 3, "king"]})
	check(s2.embers == 0 and s2.meta.vigor == 99 and not s2.meta.has("bad"), "sanitize clamps values")
	check(s2.totals.kills == 12 and s2.totals.best_time == 61.5 and s2.achievements == ["king"], "sanitize keeps valid values")
	# 3) 저장 → 다시 읽기, 판 기록
	profile.path = p
	profile.data = profile.defaults()
	var earned: int = profile.record_run({"floor": 4, "kills": 120, "elites": 3, "bosses": 1, "time": 600.0}, false, 40)
	check(earned == 4 * 4 + 12 + 6 + 15, "embers formula (got %d)" % earned)
	var back: Dictionary = profile.load_from(p)
	check(back.embers == earned and back.totals.runs == 1 and back.totals.kills == 120 and back.totals.dashes == 40, "profile round trip")
	# 4) 설정: 깨진 cfg → 기본값, 이상한 값은 범위 안으로
	settings.path = "user://test_settings.cfg"
	_write(settings.path, "[[[ this is not a config")
	settings.master = 0.8
	settings.load_settings()
	check(settings.master == 0.8 and settings.scale == 3, "corrupt settings keep defaults")
	_write(settings.path, "[audio]\nmaster=7.5\nmusic=\"loud\"\n[display]\nscale=99\n[game]\nlocale=\"xx\"\n[input]\nbindings={\"shoot\": {\"kb\": {\"t\": \"nope\"}}, \"evil\": 1}\n")
	settings.load_settings()
	check(settings.master == 1.0 and settings.scale == 4 and settings.locale == "" and not settings.bindings.has("evil"), "settings values clamped")
	# 5) 키 배치 직렬화 왕복
	var k := InputEventKey.new()
	k.physical_keycode = KEY_F
	var m := InputEventMouseButton.new()
	m.button_index = MOUSE_BUTTON_RIGHT
	var jb := InputEventJoypadButton.new()
	jb.button_index = JOY_BUTTON_RIGHT_SHOULDER
	var ja := InputEventJoypadMotion.new()
	ja.axis = JOY_AXIS_TRIGGER_LEFT
	ja.axis_value = 1.0
	for ev in [k, m, jb, ja]:
		var again: InputEvent = settings.to_event(settings.from_event(ev))
		check(again != null and settings.from_event(again) == settings.from_event(ev), "binding round trip %s" % ev)
	settings.rebind("dash", "kb", k)
	check(settings.event_for("dash", "kb").physical_keycode == KEY_F, "rebind applies to InputMap")
	settings.reset_bindings()
	check(settings.event_for("dash", "kb").physical_keycode == KEY_SPACE, "reset restores default binding")
	# 6) 업적: 해금이 프로필에 남고, 누적 통계 업적이 조건대로 열린다
	var ach: Node = root.get_node("Achievements")
	profile.data = profile.defaults()
	ach.unlock("synergy")
	ach.unlock("synergy")
	check(profile.data.achievements == ["synergy"], "unlock is recorded once")
	profile.data.totals.kills = 1000
	profile.data.totals.runs = 10
	ach.check_totals()
	check(ach.has("first_blood") and ach.has("slayer") and ach.has("persistent") and not ach.has("elite_hunter"), "total-based achievements")
	check(profile.load_from(p).achievements.has("slayer"), "achievements saved to profile")
	check(not root.get_node("SteamService").active, "steam stays inactive in headless runs")
	for f in [p, p + ".bad", settings.path]:
		DirAccess.remove_absolute(f)
	print("save self-test: %d failures" % fails)
	quit(1 if fails else 0)
	return true
