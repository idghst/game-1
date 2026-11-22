extends SceneTree
## 절차 생성 자가검증: godot --headless --path . -s tests/test_dungeon.gd
## 여러 시드에서 던전이 항상 연결되고, 마지막 방이 시작 방에서 가장 먼 방인지 확인한다.

const Dungeon = preload("res://scripts/dungeon.gd")

var fails := 0


func check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		printerr("FAIL: ", msg)


func _initialize() -> void:
	var rng := RandomNumberGenerator.new()
	for s in 2000:
		rng.seed = s
		var count := 1 + s % 20
		var cells := Dungeon.generate(rng, count)
		var dist := Dungeon.distances(cells)
		var exit := Dungeon.farthest(cells)
		var unique := {}
		for c in cells:
			unique[c] = true
		check(cells.size() == count, "seed %d: room count %d != %d" % [s, cells.size(), count])
		check(unique.size() == cells.size(), "seed %d: duplicate rooms" % s)
		check(dist.size() == cells.size(), "seed %d: disconnected (%d/%d reachable)" % [s, dist.size(), cells.size()])
		check(cells.has(exit) and dist[exit] == dist.values().max(), "seed %d: exit is not the farthest room" % s)
		check(count == 1 or exit != Vector2i.ZERO, "seed %d: exit is the start room" % s)
	print("dungeon self-test: 2000 seeds, %d failures" % fails)
	quit(1 if fails else 0)
