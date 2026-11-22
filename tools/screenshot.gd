extends SceneTree
## 실제 창에서 상황별 스크린샷을 저장한다.
## godot --path . -s tools/screenshot.gd -- <출력 폴더> [장면...]
## 장면: combat:<층>, boss:<층>, shop, treasure, upgrade

var main: Node2D
var out := "screenshots"
var shots: Array = []
var t := 0.0
var shot_name := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	shots = args.slice(1) if args.size() > 1 else ["combat:1", "boss:3", "shop", "upgrade"]
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
	var parts := spec.split(":")
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	if parts.size() > 1:
		main.floor_n = int(parts[1])
		main._new_floor()
	var want: String = {"combat": "combat", "boss": "boss", "shop": "shop", "treasure": "treasure", "upgrade": "treasure"}[parts[0]]
	for c in main.cells:
		if main.types[c] == want:
			main._enter(c, Vector2i.LEFT)
			break
	main.player.max_hp = 8
	main.gold = 57
	for id in ["twin", "sharp", "homing"]:
		main._take_upgrade(id)
	t = 0.0


func _process(delta: float) -> bool:
	if main == null:  # 첫 프레임에 시작해야 _ready가 돈다
		_next()
		return false
	t += delta
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
	if t > wait:
		var img := root.get_texture().get_image()
		img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
		img.save_png(out.path_join(shot_name + ".png"))
		print("saved ", out.path_join(shot_name + ".png"))
		Input.action_release("shoot")
		_next()
	return false
