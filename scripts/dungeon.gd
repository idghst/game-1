extends RefCounted
## 방 그리드 절차 생성. 좌표는 Vector2i, 시작 방은 (0, 0).

const DIRS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]


# 이미 있는 방의 이웃 칸에만 새 방을 붙이므로 결과는 항상 연결되어 있다.
static func generate(rng: RandomNumberGenerator, count: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = [Vector2i.ZERO]
	while cells.size() < count:
		var c: Vector2i = cells[rng.randi() % cells.size()] + DIRS[rng.randi() % DIRS.size()]
		if not cells.has(c):
			cells.append(c)
	return cells


# 시작 방에서 각 방까지의 BFS 거리. 도달 못 한 방은 결과에 없다.
static func distances(cells: Array[Vector2i]) -> Dictionary:
	var dist := {Vector2i.ZERO: 0}
	var queue: Array[Vector2i] = [Vector2i.ZERO]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for d in DIRS:
			var n := c + d
			if cells.has(n) and not dist.has(n):
				dist[n] = dist[c] + 1
				queue.append(n)
	return dist


# 마지막 방 = 시작 방에서 가장 먼 방.
static func farthest(cells: Array[Vector2i]) -> Vector2i:
	var dist := distances(cells)
	var best := Vector2i.ZERO
	for c in dist:
		if dist[c] > dist[best]:
			best = c
	return best


# 방 종류: start, combat, treasure, shop, 그리고 마지막 방은 boss(보스 층) 또는 gate.
# 보물·상점은 막다른 방을 우선 쓴다.
static func assign_types(rng: RandomNumberGenerator, cells: Array[Vector2i], boss_floor: bool) -> Dictionary:
	var types := {}
	for c in cells:
		types[c] = "combat"
	types[Vector2i.ZERO] = "start"
	var last := farthest(cells)
	types[last] = "boss" if boss_floor else "gate"
	var free: Array[Vector2i] = []
	for c in cells:
		if types[c] == "combat":
			free.append(c)
	free.shuffle()
	free.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return _neighbors(cells, a) < _neighbors(cells, b))
	for special in ["treasure", "shop"]:
		if free.size() > 2:  # 전투 방은 최소 2개 남긴다
			types[free.pop_front()] = special
	return types


static func _neighbors(cells: Array[Vector2i], c: Vector2i) -> int:
	var n := 0
	for d in DIRS:
		if cells.has(c + d):
			n += 1
	return n
