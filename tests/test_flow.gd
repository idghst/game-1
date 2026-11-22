extends SceneTree
## 게임 흐름 자가검증: godot --headless --path . -s tests/test_flow.gd
## 마지막 방 클리어 → 업그레이드 선택 → 다음 층(적 증가), 그리고 사망 → 게임오버 메뉴를 확인한다.

var main: Node2D
var frame := 0
var fails := 0


func check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		printerr("FAIL: ", msg)


func enemies() -> Array:
	return main.room.get_children().filter(func(n: Node) -> bool: return n.has_signal("died"))


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 2:
		check(main.enemies_left == 0 and main.cleared.has(Vector2i.ZERO), "start room should be empty and cleared")
		main._enter(main.exit_cell, Vector2i.RIGHT)
	elif frame == 3:
		check(enemies().size() == main.enemies_left and main.enemies_left >= 4 and main.enemies_left <= 6, "exit room spawns 4~6 enemies on floor 1")
		for e in enemies():
			e.hit(999)
		check(paused and main.enemies_left == 0, "room clear should pause with upgrade menu")
		main._pick_upgrade(0)
		check(main.floor_n == 2 and main.player.damage == 2 and not paused, "upgrade + next floor")
		check(main.current == Vector2i.ZERO and main.cells.size() == 7, "floor 2 starts at origin with 7 rooms")
	elif frame == 4:
		main.player.hit(99)
		check(paused, "death should pause with game over menu")
		print("flow self-test: %d failures" % fails)
		return quit_with(fails)
	return false


func quit_with(n: int) -> bool:
	quit(1 if n else 0)
	return true
