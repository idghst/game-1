extends SceneTree
## 실제 창에서 메인 씬을 띄워 스크린샷 2장(전투, 업그레이드 선택)을 저장한다.
## godot --path . -s tools/screenshot.gd -- <출력 폴더>

var main: Node2D
var t := 0.0
var step := 0
var out := "screenshots"


func _initialize() -> void:
	if OS.get_cmdline_user_args().size() > 0:
		out = OS.get_cmdline_user_args()[0]
	main = load("res://main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	if step == 0 and t > 0.5:
		# 시작 방 옆의 전투 방으로 이동하고, 가장 가까운 적을 향해 자동 사격
		for d in main.Dungeon.DIRS:
			if main.cells.has(d):
				main._enter(d, d)
				break
		main.player._mouse_aim = false
		Input.action_press("shoot")
		step = 1
	elif step == 1:
		var best: Node2D
		for e in main.room.get_children():
			if e.has_signal("died") and (best == null or e.position.distance_to(main.player.position) < best.position.distance_to(main.player.position)):
				best = e
		main.player._mouse_aim = false  # 실제 마우스가 창 위에 있으면 조준을 덮어쓴다
		if best:
			main.player.aim = (best.position - main.player.position).normalized()
		if t > 2.5:
			_save("gameplay.png")
			Input.action_release("shoot")
			for e in main.room.get_children():
				if e.has_signal("died"):
					e.hit(999)
			step = 2
	elif step == 2 and t > 3.0:
		_save("upgrade.png")
		return true
	return false


func _save(file: String) -> void:
	var img := root.get_texture().get_image()
	img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
	img.save_png(out.path_join(file))
	print("saved ", out.path_join(file), " ", img.get_size())
