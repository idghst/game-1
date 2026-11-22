extends SceneTree
## 밸런스 스모크: godot --headless --fixed-fps 60 --path . -s tests/test_balance.gd -- [판 수]
## 실력이 다른 봇(완벽 / 보통 / 미숙)으로 여러 판을 돌려 승률과 사망 층을 잰다.
## 검사: 실력이 높을수록 더 깊이 가야 하고(난이도 곡선이 실력을 구분), 미숙한 봇이 쉽게 이기면 안 된다.
## meta를 주면 잿불 제단 강화를 모두 최대로 두고 잰다(테스트용 프로필 경로를 써서 실제 저장은 건드리지 않음).

const Bot = preload("res://scripts/bot.gd")
const SKILLS := [1.0, 0.55, 0.25]

var runs := 6
var main: Node2D
var skill_i := 0
var results := {}  # skill -> [{victory, floor, time}]
var run_frames := 0
var fails := 0
var last_victory := false
var with_meta := false


func check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		printerr("FAIL: ", msg)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		runs = int(args[0])
	with_meta = args.has("meta")
	for s in SKILLS:
		results[s] = []


func _start() -> void:
	paused = false
	Engine.time_scale = 1.0
	main = load("res://main.tscn").instantiate()
	main.use_meta = with_meta  # 기본은 메타 강화 없는 기준선
	if with_meta:
		var profile: Node = root.get_node("Profile")
		profile.path = "user://test_balance_profile.json"
		var Meta = load("res://scripts/meta.gd")
		for id in Meta.ALL:
			profile.data.meta[id] = Meta.max_level(id)
	last_victory = false
	main.run_finished.connect(func(v: bool) -> void: last_victory = v)
	root.add_child(main)
	var bot := Bot.new()
	bot.main = main
	bot.skill = SKILLS[skill_i]
	main.add_child(bot)
	run_frames = 0


func _process(_d: float) -> bool:
	if main == null:
		_start()
		return false
	run_frames += 1
	if main.over or run_frames > 60 * 60 * 40:
		var s: float = SKILLS[skill_i]
		results[s].append({"victory": last_victory, "floor": main.floor_n, "time": main.stats.time})
		main.queue_free()
		main = null
		if results[s].size() >= runs:
			skill_i += 1
			if skill_i >= SKILLS.size():
				return _report()
	return false


func _report() -> bool:
	var avg_floor := {}
	var win_rate := {}
	for s in SKILLS:
		var arr: Array = results[s]
		var wins := arr.filter(func(r: Dictionary) -> bool: return r.victory).size()
		var floors: float = arr.reduce(func(a: float, r: Dictionary) -> float: return a + r.floor, 0.0)
		avg_floor[s] = floors / arr.size()
		win_rate[s] = float(wins) / arr.size()
		var deaths := arr.filter(func(r: Dictionary) -> bool: return not r.victory).map(func(r: Dictionary) -> int: return r.floor)
		print("skill %.2f: win %d/%d, avg floor %.1f, deaths on floors %s" % [s, wins, arr.size(), avg_floor[s], deaths])
	check(avg_floor[SKILLS[0]] >= avg_floor[SKILLS[2]], "skilled bot should get deeper than unskilled bot")
	if not with_meta:
		check(win_rate[SKILLS[2]] <= 0.5, "unskilled bot should not win most runs (got %.0f%%)" % (win_rate[SKILLS[2]] * 100))
	DirAccess.remove_absolute("user://test_balance_profile.json")
	print("balance self-test: %d failures" % fails)
	quit(1 if fails else 0)
	return true
