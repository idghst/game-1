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
