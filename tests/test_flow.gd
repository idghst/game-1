extends SceneTree
## 게임 흐름 자가검증: godot --headless --path . -s tests/test_flow.gd
## 1층부터 9층까지 관문/보스 방을 강제로 클리어 → 업그레이드 선택 → 계단으로 내려가 최종 보스 처치(승리)까지,
## 보물·상점 방 내용물, 그리고 새 판에서 사망 → 게임오버를 확인한다.

var MainScene: PackedScene
var frames := 0

var main: Node2D
var fails := 0
var step := "start"
var wait := 0
var victory := -1


func check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		printerr("FAIL: ", msg)


func _initialize() -> void:
	MainScene = load("res://main.tscn")  # 오토로드 등록 뒤에 컴파일되도록 런타임에 불러온다
	_new_main()


func _new_main() -> void:
	if main:
		main.queue_free()
	paused = false
	main = MainScene.instantiate()
	main.run_finished.connect(func(v: bool) -> void: victory = int(v))
	root.add_child(main)


func _cell_of(type: String) -> Vector2i:
	for c in main.cells:
		if main.types[c] == type:
			return c
	return Vector2i(999, 999)


func _pick_menu() -> bool:
	for b in main.ui.find_children("*", "Button", true, false):
		b.pressed.emit()
		return true
	return false


func _pickups(kind: String) -> Array:
	return main.room.get_children().filter(func(n: Node) -> bool: return n.is_in_group("pickups") and n.kind == kind)


func _process(_delta: float) -> bool:
	frames += 1
	if frames > 20000:
		printerr("FAIL: timeout in step ", step)
		quit(1)
		return true
	if wait > 0:
		wait -= 1
		return false
	match step:
		"start":
			check(main.alive == 0 and main.cleared.has(Vector2i.ZERO), "start room should be empty and cleared")
			var tr_cell := _cell_of("treasure")
			check(tr_cell != Vector2i(999, 999), "floor has a treasure room")
			check(_cell_of("shop") != Vector2i(999, 999), "floor has a shop")
			main._enter(tr_cell, Vector2i.RIGHT)
			step = "treasure"
			wait = 2
		"treasure":
			var chests := _pickups("chest")
			check(chests.size() == 1, "treasure room has a chest")
			main._on_pickup_taken(chests[0])
			check(paused, "chest opens upgrade menu")
			check(_pick_menu() and main.owned.size() == 1, "picking an upgrade adds it")
			main._enter(_cell_of("shop"), Vector2i.RIGHT)
			step = "shop"
			wait = 2
		"shop":
			check(_pickups("shop").size() == 4, "shop has 3 upgrades + heart")
			main.gold = 999
			main._on_pickup_taken(_pickups("shop")[0])
			check(main.owned.size() == 2 and main.gold < 999, "buying from shop")
			step = "goto_last"
		"goto_last":
			var t := "boss" if main.BOSSES.has(main.floor_n) else "gate"
			var c := _cell_of(t)
			check(c == main.Dungeon.farthest(main.cells), "floor %d: %s room is the farthest" % [main.floor_n, t])
			main._enter(c, Vector2i.RIGHT)
			check(main.alive > 0, "floor %d: last room has enemies" % main.floor_n)
			step = "fight"
			wait = 2
		"fight":
			for e in main.get_tree().get_nodes_in_group("enemies"):
				e._spawn_t = 0.0
				e.hit(999999)
			wait = 2
			if main.over:
				check(victory == 1 and main.floor_n == 9, "final boss kill = victory on floor 9")
				check(main.stats.bosses == 3, "3 bosses killed (got %d)" % main.stats.bosses)
				_new_main()
				step = "death"
			elif main.cleared.has(main.current):
				check(paused, "floor %d: clearing last room offers upgrade" % main.floor_n)
				_pick_menu()
				step = "stairs"
		"stairs":
			var stairs := _pickups("stairs")
			check(stairs.size() == 1, "floor %d: stairs appear" % main.floor_n)
			var before: int = main.floor_n
			main._on_pickup_taken(stairs[0])
			check(main.floor_n == before + 1 and main.current == Vector2i.ZERO, "descend to floor %d" % (before + 1))
			step = "goto_last"
			wait = 2
		"death":
			main.player.hit(99)
			check(main.over and victory == 0 and paused, "death ends run with game over menu")
			print("flow self-test: %d failures" % fails)
			quit(1 if fails else 0)
			return true
	return false
