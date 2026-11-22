extends SceneTree
## 프레임 속도 측정(실제 창 필요): godot --path . -s tests/test_perf.gd
## 봇이 무적으로 9층 보스방과 8층 전투방에서 싸우는 동안 프레임 시간을 재서,
## 평균 60fps 이상이고 16.7ms(60fps)를 크게 넘는 프레임이 거의 없는지 확인한다.

const Bot = preload("res://tools/bot.gd")
const SCENES := [["boss", 9], ["combat", 8], ["boss", 6]]
const SECONDS := 15.0

var main: Node2D
var idx := 0
var t := 0.0
var samples: Array[float] = []
var max_bullets := 0
var fails := 0


func _start() -> void:
	if main:
		main.queue_free()
	paused = false
	main = load("res://main.tscn").instantiate()
	main.use_meta = false
	root.add_child(main)
	main.floor_n = SCENES[idx][1]
	main._new_floor()
	for c in main.cells:
		if main.types[c] == SCENES[idx][0]:
			main._enter(c, Vector2i.LEFT)
			break
	for id in ["triple", "explosive", "homing", "pierce"]:  # 화면에 탄이 많은 무거운 빌드
		main._take_upgrade(id)
	var bot := Bot.new()
	bot.main = main
	main.add_child(bot)
	t = 0.0


func _process(delta: float) -> bool:
	if main == null:
		_start()
		return false
	main.player.hp = main.player.max_hp  # 측정 중 사망 방지
	t += delta
	if t > 1.0:  # 첫 1초(로딩)는 제외
		samples.append(delta)
		max_bullets = maxi(max_bullets, get_nodes_in_group("bullets_enemy").size() + get_nodes_in_group("bullets_player").size())
	if paused:
		paused = false  # 축복 선택 메뉴가 떠도 계속 측정
		for m in main.ui.get_children():
			if m.has_meta("menu"):
				m.queue_free()
		main._menu_open = false
	if t > SECONDS:
		idx += 1
		if idx >= SCENES.size():
			return _report()
		_start()
	return false


func _report() -> bool:
	samples.sort()
	var avg: float = samples.reduce(func(a: float, b: float) -> float: return a + b, 0.0) / samples.size()
	var p99: float = samples[int(samples.size() * 0.99)]
	var slow := samples.filter(func(d: float) -> bool: return d > 1.0 / 50.0).size()
	print("perf: %d frames, avg %.1f fps, 99th pct %.1f ms, frames slower than 50fps: %d (%.2f%%), peak bullets %d, refresh %.0f Hz" % [
		samples.size(), 1.0 / avg, p99 * 1000.0, slow, 100.0 * slow / samples.size(), max_bullets, DisplayServer.screen_get_refresh_rate()])
	if 1.0 / avg < 58.0:
		fails += 1
		printerr("FAIL: average below 60fps")
	if float(slow) / samples.size() > 0.01:
		fails += 1
		printerr("FAIL: more than 1% of frames below 50fps")
	print("perf self-test: %d failures" % fails)
	quit(1 if fails else 0)
	return true
