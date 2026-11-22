extends SceneTree
## 실제 창에서 상황별 스크린샷을 저장한다.
## godot --path . -s tools/screenshot.gd -- <출력 폴더> [장면...]
## 장면: combat:<층>, boss:<층>, shop, treasure, upgrade, title, settings, meta, pause, results, victory

var main: Node
var out := "screenshots"
var shots: Array = []
var t := 0.0
var shot_name := ""
var scale := 3  # scale=4를 주면 1920x1080(스토어 규격)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	shots = args.slice(1) if args.size() > 1 else ["combat:1", "boss:3", "shop", "upgrade"]
	for a in shots.duplicate():
		if a.begins_with("scale="):
			scale = int(a.get_slice("=", 1))
			shots.erase(a)
	DirAccess.make_dir_recursive_absolute(out)



func _next() -> void:
	if main:
		main.queue_free()
	paused = false
	if shots.is_empty():
		quit()
		return
	var spec: String = shots.pop_front()
	shot_name = spec.replace(":", "_")
	# "en/title"처럼 앞에 언어를 붙이면 그 언어로 찍는다
	TranslationServer.set_locale(spec.get_slice("/", 0) if "/" in spec else OS.get_locale_language())
	spec = spec.get_slice("/", 1) if "/" in spec else spec
	shot_name = shot_name.replace("/", "_")
	var parts := spec.split(":")
	t = 0.0
	if parts[0] in ["title", "settings", "meta"]:
		main = load("res://title.tscn").instantiate()
		root.add_child(main)
		if parts[0] == "settings":
			main._open_settings()
		elif parts[0] == "meta":
			main._open_meta()
		return
	main = load("res://main.tscn").instantiate()
	main.use_meta = false  # 촬영이 실제 진행 기록을 남기지 않게
	root.add_child(main)
	if parts.size() > 1:
		main.floor_n = int(parts[1])
		main._new_floor()
	var want: String = {"combat": "combat", "boss": "boss", "shop": "shop", "treasure": "treasure", "upgrade": "treasure",
		"pause": "combat", "results": "combat", "victory": "combat"}[parts[0]]
	for c in main.cells:
		if main.types[c] == want:
			main._enter(c, Vector2i.LEFT)
			break
	main.player.max_hp = 8
	main.gold = 57 + int(parts[1]) * 11 if parts.size() > 1 else 57
	var builds := [["twin", "sharp", "homing"], ["triple", "explosive", "pierce", "frost"], ["souls", "inferno", "trigger", "boots"]]
	for id in builds[(int(parts[1]) if parts.size() > 1 else 0) % 3]:
		main._take_upgrade(id)
	if parts[0] == "pause":
		main.open_pause.call_deferred()
	elif parts[0] in ["results", "victory"]:
		main.stats.kills = 214
		main.stats.time = 1104.0
		main.floor_n = 9 if parts[0] == "victory" else 5
		main.stats.floor = main.floor_n
		main._finish.call_deferred(parts[0] == "victory")


func _process(delta: float) -> bool:
	if main == null:  # 첫 프레임에 시작해야 _ready가 돈다
		_next()
		return false
	t += delta
	if not "player" in main:  # 타이틀 계열 화면
		if t > 1.0:
			_save(shot_name)
			_next()
		return false
	var p: Node2D = main.player
	p._mouse_aim = false
	p._invuln = 1.0  # 촬영 중 사망 방지
	var best: Node2D = null
	for e in main.get_tree().get_nodes_in_group("enemies"):
		if best == null or e.position.distance_to(p.position) < best.position.distance_to(p.position):
			best = e
	if best:
		p.aim = (best.position - p.position).normalized()
		Input.action_press("shoot")
	else:
		Input.action_release("shoot")
	var wait := 4.0 if shot_name.begins_with("boss") else 2.2
	if shot_name == "upgrade" and t > 0.5 and not paused:
		p.position = Vector2(240, 135)
	if shot_name in ["results", "victory"]:
		wait = 3.0
	if t > wait:
		_save(shot_name)
		Input.action_release("shoot")
		_next()
	return false


func _save(file: String) -> void:
	var img := root.get_texture().get_image()
	img.resize(img.get_width() * scale, img.get_height() * scale, Image.INTERPOLATE_NEAREST)
	img.save_png(out.path_join(file + ".png"))
	print("saved ", out.path_join(file + ".png"))
