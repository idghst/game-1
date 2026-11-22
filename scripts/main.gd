extends Node2D
## 게임 흐름: 층 생성 → 방 이동 → 방 클리어 시 문 열림 + 업그레이드 선택 → 마지막 방 클리어 시 다음 층.

const Dungeon = preload("res://scripts/dungeon.gd")
const Player = preload("res://scripts/player.gd")
const Enemy = preload("res://scripts/enemy.gd")

const W := 480.0
const H := 270.0
const WALL := 16.0
const DOOR := 40.0
const UPGRADES := ["Damage +1", "Fire rate +25%", "Move speed +15%"]

var rng := RandomNumberGenerator.new()
var floor_n := 1
var cells: Array[Vector2i] = []
var exit_cell := Vector2i.ZERO
var cleared := {}
var current := Vector2i.ZERO
var enemies_left := 0
var room: Node2D
var door_body: StaticBody2D
var player: CharacterBody2D
var ui: CanvasLayer
var hud: Control
var hud_label: Label
var theme_small := Theme.new()
var camera := Camera2D.new()


func _ready() -> void:
	rng.randomize()
	camera.position = Vector2(W, H) / 2
	add_child(camera)
	theme_small.default_font_size = 10
	player = Player.new()
	add_child(player)
	player.hp_changed.connect(_update_hud)
	player.died.connect(_game_over)
	ui = CanvasLayer.new()
	ui.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ui)
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.theme = theme_small
	hud.draw.connect(_draw_hud)
	ui.add_child(hud)
	hud_label = Label.new()
	hud_label.position = Vector2(4, 10)
	hud.add_child(hud_label)
	_new_floor()


func _new_floor() -> void:
	cells = Dungeon.generate(rng, 5 + floor_n)
	exit_cell = Dungeon.farthest(cells)
	cleared = {Vector2i.ZERO: true}
	_enter(Vector2i.ZERO, Vector2i.ZERO)


# moved: 이전 방에서 이동한 방향. ZERO면 층 시작(중앙 배치).
func _enter(cell: Vector2i, moved: Vector2i) -> void:
	current = cell
	if room:
		room.queue_free()
	room = Node2D.new()
	add_child(room)
	player.bullet_parent = room
	player.position = Vector2(W, H) / 2 - Vector2(moved) * Vector2(W / 2 - 30, H / 2 - 30)

	var walls := StaticBody2D.new()
	door_body = StaticBody2D.new()
	room.add_child(walls)
	room.add_child(door_body)
	for d in Dungeon.DIRS:
		var s := _side(d)
		if not cells.has(cell + d):
			_add_rect(walls, s)
			continue
		var g := _gap(d)
		if d.x != 0:
			_add_rect(walls, Rect2(s.position, Vector2(WALL, g.position.y)))
			_add_rect(walls, Rect2(s.position.x, g.end.y, WALL, H - g.end.y))
		else:
			_add_rect(walls, Rect2(s.position, Vector2(g.position.x, WALL)))
			_add_rect(walls, Rect2(g.end.x, s.position.y, W - g.end.x, WALL))
		_add_rect(door_body, g)

	enemies_left = 0
	if cleared.has(cell):
		door_body.queue_free()
	else:
		var count := 1 + floor_n + rng.randi_range(0, 2) + (2 if cell == exit_cell else 0)
		for i in count:
			var pos := player.position
			while pos.distance_to(player.position) < 100:
				pos = Vector2(rng.randf_range(WALL + 16, W - WALL - 16), rng.randf_range(WALL + 16, H - WALL - 16))
			var e: CharacterBody2D = Enemy.new().setup(rng.randf() < 0.4, player, floor_n)
			e.position = pos
			e.died.connect(_on_enemy_died)
			room.add_child(e)
			enemies_left += 1
	queue_redraw()
	_update_hud()


func _side(d: Vector2i) -> Rect2:
	match d:
		Vector2i.LEFT: return Rect2(0, 0, WALL, H)
		Vector2i.RIGHT: return Rect2(W - WALL, 0, WALL, H)
		Vector2i.UP: return Rect2(0, 0, W, WALL)
		_: return Rect2(0, H - WALL, W, WALL)


func _gap(d: Vector2i) -> Rect2:
	var s := _side(d)
	if d.x != 0:
		return Rect2(s.position.x, (H - DOOR) / 2, WALL, DOOR)
	return Rect2((W - DOOR) / 2, s.position.y, DOOR, WALL)


func _add_rect(body: StaticBody2D, r: Rect2) -> void:
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = r.size
	shape.position = r.get_center()
	body.add_child(shape)


func _process(_delta: float) -> void:
	camera.offset = Fx.shake_offset(6.0)


func _physics_process(_delta: float) -> void:
	if enemies_left > 0:
		return
	# 문이 열린 상태에서 벽 두께 절반을 넘어가면 이웃 방으로 이동
	var p := player.position
	var d := Vector2i.ZERO
	if p.x < WALL / 2:
		d = Vector2i.LEFT
	elif p.x > W - WALL / 2:
		d = Vector2i.RIGHT
	elif p.y < WALL / 2:
		d = Vector2i.UP
	elif p.y > H - WALL / 2:
		d = Vector2i.DOWN
	if d != Vector2i.ZERO and cells.has(current + d):
		_enter(current + d, d)


func _on_enemy_died() -> void:
	enemies_left -= 1
	if enemies_left > 0 or player.hp == 0:  # 같은 프레임에 사망했으면 게임오버 메뉴만 띄운다
		return
	cleared[current] = true
	door_body.queue_free()
	queue_redraw()
	_update_hud()
	_menu("ROOM CLEAR - choose an upgrade", UPGRADES, _pick_upgrade)


func _pick_upgrade(i: int) -> void:
	match i:
		0: player.damage += 1
		1: player.fire_delay *= 0.8
		2: player.speed *= 1.15
	get_tree().paused = false
	if current == exit_cell:
		floor_n += 1
		_new_floor()
	_update_hud()


func _game_over() -> void:
	_menu("GAME OVER - reached floor %d" % floor_n, ["Restart"], func(_i: int) -> void:
		get_tree().paused = false
		get_tree().reload_current_scene())


# 제목 + 버튼 목록을 띄우고 게임을 멈춘다. 버튼을 누르면 메뉴를 닫고 on_pick(인덱스)를 부른다.
func _menu(title: String, labels: Array, on_pick: Callable) -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.theme = theme_small
	var panel := PanelContainer.new()
	var box := VBoxContainer.new()
	center.add_child(panel)
	panel.add_child(box)
	var t := Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	for i in labels.size():
		var b := Button.new()
		b.text = labels[i]
		b.pressed.connect(func() -> void:
			center.queue_free()
			on_pick.call(i))
		box.add_child(b)
	ui.add_child(center)
	box.get_child(1).grab_focus()
	get_tree().paused = true


func _update_hud() -> void:
	hud_label.text = "FLOOR %d   DMG %d   RATE %.1f/s   SPD %d" % [floor_n, player.damage, 1.0 / player.fire_delay, player.speed]
	hud.queue_redraw()


func _draw_hud() -> void:
	for i in player.max_hp:
		hud.draw_rect(Rect2(4 + i * 8, 3, 6, 6), Color("d63c3c") if i < player.hp else Color("40202a"))
	# 미니맵(우상단): 흰색 = 현재 방, 회색 = 클리어, 붉은색 = 마지막 방
	var lo := Vector2i.ZERO
	var hi := Vector2i.ZERO
	for c in cells:
		lo = lo.min(c)
		hi = hi.max(c)
	var origin := Vector2(W - 4 - (hi.x - lo.x + 1) * 7, 3) - Vector2(lo) * 7
	for c in cells:
		var col := Color("5a5068")
		if c == exit_cell:
			col = Color("a03040")
		if cleared.has(c):
			col = Color("a8a0b0")
		if c == current:
			col = Color.WHITE
		hud.draw_rect(Rect2(origin + Vector2(c) * 7, Vector2(6, 5)), col)


func _draw() -> void:
	var floor_col := Color("3a2228") if current == exit_cell else Color("2a2430")
	draw_rect(Rect2(0, 0, W, H), Color("120f16"))
	draw_rect(Rect2(WALL, WALL, W - 2 * WALL, H - 2 * WALL), floor_col)
	for d in Dungeon.DIRS:
		if cells.has(current + d):
			draw_rect(_gap(d), Color("8a2a2a") if enemies_left > 0 else floor_col)
