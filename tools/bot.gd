extends Node
## 자동 플레이 봇: 실제 입력 액션(이동·조준·사격·대시·상호작용)을 눌러 게임을 진행한다.
## 밸런스 스모크·장시간 안정성 테스트·스크린샷에 쓴다. main에 자식으로 붙인다.

var main: Node2D
var _stuck_t := 0.0
var _jitter := Vector2.ZERO
var _last_pos := Vector2.ZERO
var _menu_t := 0.0
var _dash_pressed := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _press_vec(prefix: String, v: Vector2) -> void:
	for a in ["left", "right", "up", "down"]:
		Input.action_release(prefix + a)
	if v.x < 0: Input.action_press(prefix + "left", minf(-v.x, 1.0))
	if v.x > 0: Input.action_press(prefix + "right", minf(v.x, 1.0))
	if v.y < 0: Input.action_press(prefix + "up", minf(-v.y, 1.0))
	if v.y > 0: Input.action_press(prefix + "down", minf(v.y, 1.0))


func _physics_process(delta: float) -> void:
	if _dash_pressed:
		Input.action_release("dash")
		_dash_pressed = false
	Input.action_release("interact")
	if main.over:
		return
	if get_tree().paused:
		_press_vec("move_", Vector2.ZERO)
		_menu_t += delta
		var buttons: Array = main.ui.find_children("*", "Button", true, false)
		if _menu_t > 0.3 and not buttons.is_empty():
			_menu_t = 0.0
			buttons[randi() % buttons.size()].pressed.emit()
		return
	var p: Node2D = main.player
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	var move := Vector2.ZERO
	if not enemies.is_empty():
		var near: Node2D = enemies[0]
		for e in enemies:
			if e.position.distance_to(p.position) < near.position.distance_to(p.position):
				near = e
		var to: Vector2 = near.position - p.position
		_press_vec("aim_", to.normalized())
		Input.action_press("shoot")
		move = to.normalized() * (1.0 if to.length() > 140 else (-1.0 if to.length() < 90 else 0.0))
		move += to.normalized().orthogonal() * 0.6
		for e in enemies:
			var d: float = e.position.distance_to(p.position)
			if d < 60:
				move += (p.position - e.position).normalized() * (60 - d) / 30
		var danger := false
		for b in get_tree().get_nodes_in_group("bullets_enemy"):
			var rel: Vector2 = p.position - b.position
			if rel.length() < 50 and b.velocity.dot(rel) > 0:
				move += b.velocity.normalized().orthogonal() * signf(b.velocity.normalized().orthogonal().dot(rel)) * 1.5
				danger = danger or rel.length() < 16
		if danger and not _dash_pressed:
			Input.action_press("dash")
			_dash_pressed = true
		move += (Vector2(240, 135) - p.position) / 240.0  # 벽에서 떨어지기
		if _blocked(p.position, near.position):  # 기둥에 가려 맞지 않으면 돌아서 다가간다
			move = to.normalized() + to.normalized().orthogonal()
	else:
		Input.action_release("shoot")
		_press_vec("aim_", Vector2.ZERO)
		move = _navigate(p)
	# 앞에 기둥이 있으면 옆으로 비켜 간다
	for q in main.pillars.get(main.current, []):
		var rel: Vector2 = q - p.position
		if rel.length() < 26 and move.dot(rel) > 0:
			move += -rel.normalized() * 0.5 + move.orthogonal().normalized() * signf(move.orthogonal().dot(-rel) + 0.01) * 0.8
	# 기둥에 걸리면 잠시 옆으로 비킨다
	if p.position.distance_to(_last_pos) < 0.3 and move.length() > 0.2:
		_stuck_t += delta
		if _stuck_t > 0.3:
			_jitter = move.orthogonal().normalized() * (1 if randf() < 0.5 else -1)
			_stuck_t = -0.5
	elif _stuck_t >= 0:
		_stuck_t = 0.0
	if _stuck_t < 0:
		_stuck_t += delta
		move = _jitter
	_last_pos = p.position
	_press_vec("move_", move.normalized() if move.length() > 0.1 else Vector2.ZERO)


func _navigate(p: Node2D) -> Vector2:
	# 1) 방 안의 볼일: 동전·하트·상자 줍기, 살 수 있는 상품 사기
	for k in main.room.get_children():
		if not k.is_in_group("pickups") or k.is_queued_for_deletion():
			continue
		var want: bool = k.kind in ["coin", "chest"] or (k.kind == "heart" and p.hp < p.max_hp)
		if k.kind == "shop":
			want = main.gold >= k.value and not (k.item == "heart" and p.hp >= p.max_hp)
		if want:
			if k.kind == "shop" and k.overlaps_body(p):
				Input.action_press("interact")
			return (k.position - p.position).normalized()
	# 2) 안 가 본 방 → 마지막 방 → 계단
	var last: Vector2i = main.Dungeon.farthest(main.cells)
	var goal := last
	var dist := _bfs(main.current)
	var best := 9999
	for c in main.cells:
		if not main.visited.has(c) and c != last and dist.has(c) and dist[c] < best:
			best = dist[c]
			goal = c
	if goal == main.current:
		for k in main.room.get_children():
			if k.is_in_group("pickups") and k.kind == "stairs":
				if k.overlaps_body(p):
					Input.action_press("interact")
				return (k.position - p.position).normalized()
		return Vector2.ZERO
	var step := _first_step(main.current, goal)
	var door: Rect2 = main._gap(step)
	var target := door.get_center() + Vector2(step) * 10
	var dir := target - p.position
	# 문 앞 정렬: 문 축에 먼저 맞추고 들어간다
	if step.x != 0 and absf(dir.y) > 10:
		dir.x *= 0.2
	elif step.y != 0 and absf(dir.x) > 10:
		dir.y *= 0.2
	return dir.normalized()


func _bfs(from: Vector2i) -> Dictionary:
	var dist := {from: 0}
	var q: Array[Vector2i] = [from]
	while not q.is_empty():
		var c: Vector2i = q.pop_front()
		for d in main.Dungeon.DIRS:
			if main.cells.has(c + d) and not dist.has(c + d):
				dist[c + d] = dist[c] + 1
				q.append(c + d)
	return dist


func _first_step(from: Vector2i, to: Vector2i) -> Vector2i:
	var dist := _bfs(to)
	for d in main.Dungeon.DIRS:
		if dist.has(from + d) and dist[from + d] == dist[from] - 1:
			return d
	return Vector2i.ZERO


func _blocked(from: Vector2, to: Vector2) -> bool:
	var q := PhysicsRayQueryParameters2D.create(from, to, 1)
	return not main.get_world_2d().direct_space_state.intersect_ray(q).is_empty()
