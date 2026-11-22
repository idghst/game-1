extends SceneTree
## 자동 플레이 스모크: godot --headless --fixed-fps 60 --path . -s tests/test_autoplay.gd -- [판 수] [god]
## 봇으로 여러 판을 끝까지 돌려 크래시·멈춤이 없는지, 층별 소요 시간·도달 층·승률을 출력한다.
## god을 주면 플레이어가 죽지 않아 한 판 전체 길이(15~25분 목표)를 잰다.

const Bot = preload("res://scripts/bot.gd")

var runs := 3
var god := false
var main: Node2D
var results: Array = []
var floor_times := {}
var frames := 0
var run_frames := 0
var mem_start := 0.0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		runs = int(args[0])
	god = args.has("god")
	_start()


func _start() -> void:
	paused = false
	Engine.time_scale = 1.0
	main = load("res://main.tscn").instantiate()
	main.use_meta = false
	root.add_child(main)
	var bot := Bot.new()
	bot.main = main
	main.add_child(bot)
	main.run_finished.connect(_on_finished)
	run_frames = 0


func _on_finished(victory: bool) -> void:
	results.append({"hits": main.player.hits_taken, "victory": victory, "floor": main.floor_n, "time": main.stats.time, "kills": main.stats.kills, "upgrades": main.owned.size()})
	print("  objects %d, nodes %d, orphan nodes %d, static mem %.1f MB" % [Performance.get_monitor(Performance.OBJECT_COUNT), Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), OS.get_static_memory_usage() / 1048576.0])
	print("run %d: %s floor %d, %.1f min, %d kills, %d upgrades, %d hits taken, %dg spent" % [results.size(), "WIN" if victory else "LOSS", main.floor_n, main.stats.time / 60.0, main.stats.kills, main.owned.size(), main.player.hits_taken, main.stats.gold - main.gold])


var _last_floor := 1
var _floor_start := 0.0


func _process(_delta: float) -> bool:
	frames += 1
	run_frames += 1
	if frames == 600:
		mem_start = OS.get_static_memory_usage()
	if god and main.player:
		main.player.hp = main.player.max_hp
	if main.floor_n != _last_floor and not main.over:
		floor_times[_last_floor] = floor_times.get(_last_floor, []) + [main.stats.time - _floor_start]
		_floor_start = main.stats.time
		_last_floor = main.floor_n
	if main.over or run_frames > 60 * 60 * 40:  # 게임 시간 40분이 넘으면 멈춘 것으로 본다
		if not main.over:
			print("FAIL: run stuck on floor %d room %s" % [main.floor_n, main.current])
			print("  type=%s alive=%d waves=%d player=%s paused=%s enemies=%s" % [main.types[main.current], main.alive, main.waves_left, main.player.position, paused,
				get_nodes_in_group("enemies").map(func(e: Node) -> String: return "%s@%s" % [e.kind, e.position])])
			print("  cleared=%s pickups=%s pillars=%s" % [main.cleared.has(main.current), get_nodes_in_group("pickups").map(func(k: Node) -> String: return "%s@%s" % [k.kind, k.position]), main.pillars.get(main.current, [])])
			results.append({"victory": false, "floor": main.floor_n, "stuck": true})
		main.queue_free()
		_last_floor = 1
		_floor_start = 0.0
		if results.size() >= runs:
			return _report()
		_start()
	return false


func _report() -> bool:
	var stuck := results.filter(func(r: Dictionary) -> bool: return r.get("stuck", false)).size()
	var wins := results.filter(func(r: Dictionary) -> bool: return r.victory).size()
	for f in floor_times:
		var arr: Array = floor_times[f]
		print("floor %d: avg %.0fs over %d runs" % [f, arr.reduce(func(a, b): return a + b, 0.0) / arr.size(), arr.size()])
	var mem_growth := (OS.get_static_memory_usage() - mem_start) / 1048576.0
	print("autoplay: %d runs, %d wins, %d stuck, static memory growth %.1f MB" % [runs, wins, stuck, mem_growth])
	quit(1 if stuck > 0 else 0)
	return true
