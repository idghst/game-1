extends Node2D
## 한 판(run)의 흐름: 층 생성 → 방 이동 → 전투/보물/상점/관문/보스 → 계단으로 다음 층.
## 9층(테마 3개 × 3층), 3층마다 보스. 9층 보스(재의 왕)를 쓰러뜨리면 엔딩.

signal run_finished(victory: bool)

const Dungeon = preload("res://scripts/dungeon.gd")
const Player = preload("res://scripts/player.gd")
const Enemy = preload("res://scripts/enemy.gd")
const Boss = preload("res://scripts/boss.gd")
const Pickup = preload("res://scripts/pickup.gd")
const Bullet = preload("res://scripts/bullet.gd")
const Upgrades = preload("res://scripts/upgrades.gd")
const Art = preload("res://scripts/art.gd")
const PauseMenu = preload("res://scripts/ui/pause_menu.gd")
const Results = preload("res://scripts/ui/results.gd")
const Meta = preload("res://scripts/meta.gd")
const Menu = preload("res://scripts/ui/menu.gd")

const W := 480.0
const H := 270.0
const WALL := 16.0
const DOOR := 40.0
const FLOORS := 9
const BOSSES := {3: "warden", 6: "matron", 9: "king"}
# 층 테마: 이름 키, 바닥·벽·문 색, 등장 적 가중치
const THEMES := [
	{"name": "THEME_CRYPT", "tile": "crypt", "floor": Color("2a2430"), "wall": Color("120f16"), "accent": Color("5a4a6a"), "ambient": Color(0.62, 0.58, 0.72),
		"enemies": {"ghoul": 4, "archer": 3, "bat": 3, "bloater": 2}},
	{"name": "THEME_CATACOMB", "tile": "catacomb", "floor": Color("1e2a2c"), "wall": Color("0c1214"), "accent": Color("2a6a6a"), "ambient": Color(0.5, 0.62, 0.66),
		"enemies": {"ghoul": 2, "archer": 3, "bat": 2, "bloater": 2, "cultist": 3, "brute": 2}},
	{"name": "THEME_SANCTUM", "tile": "sanctum", "floor": Color("2e1c1a"), "wall": Color("140a08"), "accent": Color("8a3a20"), "ambient": Color(0.66, 0.5, 0.46),
		"enemies": {"ghoul": 1, "archer": 2, "bat": 2, "bloater": 1, "cultist": 3, "brute": 3, "eye": 2}},
]
const PILLAR_LAYOUTS := [
	[],
	[Vector2(120, 80), Vector2(360, 80), Vector2(120, 190), Vector2(360, 190)],
	[Vector2(200, 100), Vector2(280, 100), Vector2(200, 170), Vector2(280, 170)],
	[Vector2(150, 70), Vector2(330, 70), Vector2(150, 200), Vector2(330, 200)],
	[Vector2(160, 135), Vector2(320, 135)],
]

var rng := RandomNumberGenerator.new()
var floor_n := 1
var cells: Array[Vector2i] = []
var types := {}
var cleared := {}
var visited := {}
var looted := {}
var shop_stock := {}  # cell -> [{item, price, bought}]
var pillars := {}  # cell -> Array[Vector2]
var current := Vector2i.ZERO
var alive := 0
var waves_left := 0
var room: Node2D
var door_body: StaticBody2D
var player: CharacterBody2D
var boss: Node2D
var camera := Camera2D.new()
var darkness := CanvasModulate.new()
var over := false
var use_meta := true  # false면 메타 강화 없이 시작하고 기록도 남기지 않는다(테스트·밸런스 측정용)
# 메타 강화가 정하는 판 규칙
var luck := 0.0
var floor_heal := false
var revives := 0
var choices := 3

# 통계(결과 화면·메타 재화·업적에 쓴다)
var stats := {"kills": 0, "elites": 0, "bosses": 0, "gold": 0, "time": 0.0, "damage_taken": 0, "rooms": 0, "floor": 1}
var gold := 0
var owned: Array = []  # 얻은 업그레이드 id
var tag_count := {}
var synergies: Array = []
var _gold_frac := 0.0
var _kills_since_heal := 0
var _hits_at_floor_start := 0

var ui: CanvasLayer
var hud: Control
var info_label: Label
var prompt_label: Label
var toast_label: Label
var _toast_t := 0.0
var _menu_open := false


func _ready() -> void:
	rng.randomize()
	camera.position = Vector2(W, H) / 2
	add_child(camera)
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	add_child(darkness)
	player = Player.new()
	add_child(player)
	var light := PointLight2D.new()  # 플레이어 랜턴
	var grad := GradientTexture2D.new()
	grad.fill = GradientTexture2D.FILL_RADIAL
	grad.fill_from = Vector2(0.5, 0.5)
	grad.fill_to = Vector2(1.0, 0.5)
	grad.width = 256
	grad.height = 256
	grad.gradient = Gradient.new()
	grad.gradient.set_color(0, Color(1, 0.85, 0.6, 1))
	grad.gradient.set_color(1, Color(1, 0.85, 0.6, 0))
	light.texture = grad
	light.texture_scale = 2.2
	light.energy = 1.25
	player.add_child(light)
	player.hp_changed.connect(_on_hp_changed)
	player.died.connect(_on_player_died)
	_build_ui()
	if use_meta:
		Meta.apply(Profile.data.meta, player, self)
		Achievements.session_new.clear()
		Achievements.unlocked.connect(_on_achievement)
	SteamService.overlay_toggled.connect(func(on: bool) -> void:
		if on:
			open_pause())
	_new_floor()
	Sfx.music("music_dungeon")


func _build_ui() -> void:
	ui = CanvasLayer.new()
	ui.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ui)
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.draw.connect(_draw_hud)
	ui.add_child(hud)
	info_label = _label(Vector2(13, 11), HORIZONTAL_ALIGNMENT_LEFT)
	prompt_label = _label(Vector2(0, H - 30), HORIZONTAL_ALIGNMENT_CENTER)
	toast_label = _label(Vector2(0, 52), HORIZONTAL_ALIGNMENT_CENTER)


func _label(pos: Vector2, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.position = pos
	l.horizontal_alignment = align
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		l.size.x = W
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 2)
	hud.add_child(l)
	return l


func theme_data() -> Dictionary:
	return THEMES[mini(floori((floor_n - 1) / 3.0), THEMES.size() - 1)]


func toast(text: String, seconds := 2.0) -> void:
	toast_label.text = text
	_toast_t = seconds


# ── 층과 방 ──────────────────────────────────────────────

func _new_floor() -> void:
	cells = Dungeon.generate(rng, 6 + floori(floor_n / 3.0))  # 6~9개: 한 판 15~25분
	types = Dungeon.assign_types(rng, cells, BOSSES.has(floor_n))
	cleared = {Vector2i.ZERO: true}
	visited = {}
	looted = {}
	shop_stock = {}
	pillars = {}
	for c in cells:
		if types[c] in ["combat", "gate"]:
			pillars[c] = PILLAR_LAYOUTS[rng.randi() % PILLAR_LAYOUTS.size()]
	stats.floor = floor_n
	if floor_heal and floor_n > 1:
		player.heal(1)
	darkness.color = theme_data().ambient
	_enter(Vector2i.ZERO, Vector2i.ZERO)
	toast("%s\n%s" % [tr("FLOOR_N") % floor_n, tr(theme_data().name)], 2.5)


# moved: 이전 방에서 이동한 방향. ZERO면 층 시작(중앙 배치).
func _enter(cell: Vector2i, moved: Vector2i) -> void:
	current = cell
	visited[cell] = true
	if room:
		room.queue_free()
	room = Node2D.new()
	add_child(room)
	move_child(room, player.get_index())  # 플레이어 아래에 그린다
	player.bullet_parent = room
	player.position = Vector2(W, H) / 2 - Vector2(moved) * Vector2(W / 2 - 30, H / 2 - 30)
	boss = null

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
	for p in pillars.get(cell, []):
		_add_rect(walls, Rect2(p - Vector2(8, 8), Vector2(16, 16)))

	alive = 0
	waves_left = 0
	var t: String = types[cell]
	if cleared.has(cell):
		door_body.queue_free()
		door_body = null
	else:
		match t:
			"combat":
				waves_left = 2 if floor_n >= 2 and rng.randf() < 0.4 + floor_n * 0.03 else 1
				_spawn_wave(false)
			"gate":
				waves_left = 2
				_spawn_wave(true)
			"boss":
				boss = Boss.new().setup(BOSSES[floor_n], player, self, 1.0)
				boss.position = Vector2(W / 2, H / 2 - 30) if moved.y >= 0 else Vector2(W / 2, H / 2 + 30)
				boss.died.connect(_on_enemy_died)
				room.add_child(boss)
				alive += 1
				Sfx.music("music_boss")
				toast(tr("BOSS_" + BOSSES[floor_n].to_upper()), 2.5)
			_:
				_clear_room(false)
	if t == "treasure" and not looted.has(cell):
		_add_pickup(Pickup.new().setup("chest", Vector2(W, H) / 2, player))
	if t == "shop":
		_fill_shop(cell)
	if t in ["gate", "boss"] and cleared.has(cell) and not (floor_n == FLOORS and t == "boss"):
		_add_pickup(Pickup.new().setup("stairs", Vector2(W, H) / 2, player))
	queue_redraw()
	hud.queue_redraw()


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


func _add_pickup(p: Area2D, into: Node = null) -> void:
	p.taken.connect(_on_pickup_taken)
	spawn(p, into if into else room)


# 물리 콜백(피격·사망) 안에서 만든 Area2D는 바로 넣을 수 없어 call_deferred로 여기를 부른다.
# 그 사이 방이 바뀌었으면 버린다(바뀐 방에 끼어들거나 고아 노드로 남지 않게).
func spawn(node: Node, into: Node) -> void:
	if into == room and is_instance_valid(into) and not into.is_queued_for_deletion():
		into.add_child(node)
	else:
		node.free()


# ── 적 ───────────────────────────────────────────────────

func hp_mult() -> float:
	return pow(1.3, floor_n - 1)  # 업그레이드가 쌓이는 속도를 따라가도록 지수로


func _spawn_wave(elite_lead: bool) -> void:
	waves_left -= 1
	var count := 2 + floori(floor_n * 0.8) + rng.randi_range(0, 2)
	var weights: Dictionary = theme_data().enemies
	for i in count:
		var elite := (elite_lead and i == 0) or rng.randf() < 0.02 + floor_n * 0.04
		spawn_enemy(_weighted(weights), _free_spot(), elite, false)


func _weighted(weights: Dictionary) -> String:
	var total := 0.0
	for k in weights:
		total += weights[k]
	var r := rng.randf() * total
	for k in weights:
		r -= weights[k]
		if r <= 0:
			return k
	return weights.keys()[0]


func _free_spot() -> Vector2:
	for i in 40:
		var p := Vector2(rng.randf_range(WALL + 20, W - WALL - 20), rng.randf_range(WALL + 20, H - WALL - 20))
		var ok := p.distance_to(player.position) > 110
		for q in pillars.get(current, []):
			ok = ok and p.distance_to(q) > 18
		if ok:
			return p
	return Vector2(W / 2, H / 2)


# summoned: 보스 소환·분열로 생긴 적
func spawn_enemy(kind: String, pos: Vector2, elite: bool, summoned: bool) -> void:
	var e: CharacterBody2D = Enemy.new().setup(kind, elite, player, self, hp_mult())
	e.position = pos.clamp(Vector2(WALL + 8, WALL + 8), Vector2(W - WALL - 8, H - WALL - 8))
	e.bullet_speed_mult = 1.0 + 0.05 * (floor_n - 1)
	e.fire_rate_mult = 1.0 + 0.07 * (floor_n - 1)
	if summoned:
		e._spawn_t = 0.35
	e.died.connect(_on_enemy_died)
	_add_enemy.call_deferred(e, room)
	alive += 1


# 보스가 죽은 그 프레임에 소환된 적처럼, 들어가기 전에 방이 클리어되거나 바뀌었으면 버린다
func _add_enemy(e: Node, into: Node) -> void:
	if cleared.has(current) or into != room or not is_instance_valid(into):
		e.free()
	else:
		into.add_child(e)


func _on_enemy_died(e: Node, rewards: bool) -> void:
	alive -= 1
	if not rewards:  # 보스와 함께 사라지는 졸개
		return
	if not over:
		stats.kills += 1
		_achieve("first_blood")
		if e.elite:
			stats.elites += 1
		for i in e.gold:
			if rng.randf() < 0.65:
				continue
			_add_pickup.call_deferred(Pickup.new().setup("coin", e.position + Vector2(rng.randf_range(-6, 6), rng.randf_range(-6, 6)), player), room)
		if rng.randf() < 0.03:
			_add_pickup.call_deferred(Pickup.new().setup("heart", e.position, player), room)
		if player.dash_reset_on_kill:
			player.reset_dash()
		if player.lifesteal_every > 0:
			_kills_since_heal += 1
			if _kills_since_heal >= player.lifesteal_every:
				_kills_since_heal = 0
				player.heal(1)
		if player.souls:
			var dir := Vector2.RIGHT.rotated(rng.randf() * TAU)
			spawn.call_deferred(Bullet.new().setup(e.position, dir * 150, player.damage, true,
				{"homing": 8.0, "color": Color("a0f0ff"), "life": 1.5}), room)
	if e == boss:
		stats.bosses += 1
		_achieve(e.kind)
		for other in get_tree().get_nodes_in_group("enemies"):
			other.die(false)
		alive = 0
		waves_left = 0
		_clear_room(true)
		return
	if over or alive > 1 or (alive == 1 and waves_left == 0):
		return
	if waves_left > 0:
		_spawn_wave(types[current] == "gate")
	elif alive == 0:
		_clear_room(true)


func _clear_room(reward: bool) -> void:
	cleared[current] = true
	if door_body and reward:
		Sfx.play("door")
	if types[current] == "boss":
		Sfx.music("music_dungeon")
	if door_body:
		door_body.queue_free()
		door_body = null
	queue_redraw()
	if not reward:
		return
	stats.rooms += 1
	var t: String = types[current]
	if t == "combat" and rng.randf() < 0.2:
		_add_pickup.call_deferred(Pickup.new().setup("heart", Vector2(W, H) / 2, player), room)
	if t == "boss" and floor_n == FLOORS:
		_finish(true)
		return
	if t in ["gate", "boss"]:
		if t == "boss":
			player.heal(2)
		_add_pickup.call_deferred(Pickup.new().setup("stairs", Vector2(W, H) / 2, player), room)
		_offer_upgrades(1.5 if t == "boss" else 0.3)


# ── 픽업·상점 ────────────────────────────────────────────

func _fill_shop(cell: Vector2i) -> void:
	if not shop_stock.has(cell):
		var stock := []
		for id in Upgrades.roll(rng, owned, 3, 0.4 + luck):
			stock.append({"item": id, "price": Upgrades.PRICE[Upgrades.ALL[id].rarity] + 5 * floor_n, "bought": false})
		stock.append({"item": "heart", "price": 10 + 2 * floor_n, "bought": false})
		shop_stock[cell] = stock
	var stock: Array = shop_stock[cell]
	for i in stock.size():
		if not stock[i].bought:
			var p := Pickup.new().setup("shop", Vector2(W / 2 + (i - 1.5) * 60, H / 2 + 10), player, stock[i].price, stock[i].item)
			p.set_meta("slot", i)
			_add_pickup(p)


func _on_pickup_taken(p: Area2D) -> void:
	match p.kind:
		"coin":
			_gold_frac += player.gold_mult
			var n := floori(_gold_frac)
			_gold_frac -= n
			gold += n
			stats.gold += n
			if gold >= 150:
				_achieve("hoarder")
			Sfx.play("coin", -6.0, randf_range(0.95, 1.1))
			Fx.burst(room, p.position, Color("f0c040"), 4, 30.0, 0.2)
		"heart":
			if player.hp >= player.max_hp:
				return  # 체력이 가득하면 남겨 둔다
			player.heal(2)
			Sfx.play("pickup")
			Fx.burst(room, p.position, Color("e03a4a"), 8, 40.0)
		"chest":
			looted[current] = true
			Fx.burst(room, p.position, Color("f0c040"), 24, 90.0, 0.5)
			_offer_upgrades(0.6)
		"shop":
			if gold < p.value:
				toast(tr("NOT_ENOUGH_GOLD"), 1.0)
				return
			if p.item == "heart" and player.hp >= player.max_hp:
				return
			gold -= p.value
			Sfx.play("upgrade")
			shop_stock[current][p.get_meta("slot")].bought = true
			if p.item == "heart":
				player.heal(2)
			else:
				_take_upgrade(p.item)
			Fx.burst(room, p.position, Color("b080e0"), 16, 70.0)
		"stairs":
			if player.hits_taken == _hits_at_floor_start:
				_achieve("untouched")
			_hits_at_floor_start = player.hits_taken
			Sfx.play("stairs")
			floor_n += 1
			_new_floor()
			return
	p.queue_free()
	hud.queue_redraw()


func _interact_target() -> Area2D:
	for p in get_tree().get_nodes_in_group("pickups"):
		if p.needs_interact() and p._t > 0.2 and p.overlaps_body(player) and not p.is_queued_for_deletion():
			return p
	return null


# ── 업그레이드 ───────────────────────────────────────────

func _offer_upgrades(bonus_luck: float) -> void:
	var picks := Upgrades.roll(rng, owned, choices, bonus_luck + luck)
	var opts := []
	for id in picks:
		var rarity: String = Upgrades.ALL[id].rarity
		opts.append({"text": "%s  [%s]\n%s" % [tr("UPG_" + id.to_upper()), tr("RARITY_" + rarity.to_upper()), tr("UPG_" + id.to_upper() + "_DESC")],
			"color": Upgrades.RARITY_COLOR[rarity]})
	_menu(tr("CHOOSE_UPGRADE"), opts, func(i: int) -> void: _take_upgrade(picks[i]))


func _take_upgrade(id: String) -> void:
	Sfx.play("upgrade")
	owned.append(id)
	Upgrades.apply(id, player)
	if Upgrades.ALL[id].rarity == "legendary":
		_achieve("legendary")
	var tag: String = Upgrades.ALL[id].tag
	tag_count[tag] = tag_count.get(tag, 0) + 1
	if tag_count[tag] >= Upgrades.SYNERGY_COUNT and not synergies.has(tag):
		synergies.append(tag)
		_achieve("synergy")
		Upgrades.apply_synergy(tag, player)
		toast("%s: %s" % [tr("SYNERGY"), tr("SYN_" + tag.to_upper())], 2.5)
		Fx.burst(room, player.position, Upgrades.RARITY_COLOR.legendary, 30, 120.0, 0.6)
	hud.queue_redraw()


# ── 진행 ─────────────────────────────────────────────────

func _process(delta: float) -> void:
	camera.offset = Fx.shake_offset(6.0)
	if not get_tree().paused and not over:
		stats.time += delta
	_toast_t -= delta
	toast_label.modulate.a = clampf(_toast_t, 0.0, 1.0)
	var target := _interact_target() if not _menu_open else null
	prompt_label.text = ""
	if target:
		var what := tr("STAIRS_DOWN") if target.kind == "stairs" else (tr("HEART") if target.item == "heart" else tr("UPG_" + target.item.to_upper()))
		prompt_label.text = "[%s] %s" % [tr("ACTION_INTERACT"), what]
		if target.kind == "shop":
			prompt_label.text += "  %dg" % target.value
			if target.item != "heart":
				prompt_label.text += "\n" + tr("UPG_" + target.item.to_upper() + "_DESC")
		if Input.is_action_just_pressed("interact"):
			_on_pickup_taken(target)
	info_label.text = "%dg   %s   %s" % [gold, tr("FLOOR_N") % floor_n, _clock(stats.time)]


func _clock(t: float) -> String:
	return "%02d:%02d" % [floori(t / 60.0), int(t) % 60]


func _physics_process(_delta: float) -> void:
	if alive > 0 or over:
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


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not over and not _menu_open:
		get_viewport().set_input_as_handled()
		open_pause()


func open_pause() -> void:
	if _menu_open or over:
		return
	_menu_open = true
	get_tree().paused = true
	var m := PauseMenu.new()
	ui.add_child(m)
	m.resumed.connect(func() -> void:
		_menu_open = false
		get_tree().paused = false)
	m.abandoned.connect(func() -> void:
		_menu_open = false
		_finish(false))


# 업적은 실제 판(use_meta)에서만 기록한다
func _achieve(id: String) -> void:
	if use_meta:
		Achievements.unlock(id)


func _on_achievement(id: String) -> void:
	toast("%s: %s" % [tr("ACHIEVEMENT_UNLOCKED"), tr("ACH_" + id.to_upper())], 2.5)


func _on_hp_changed() -> void:
	hud.queue_redraw()


func _on_player_died() -> void:
	if revives > 0:  # 재기(메타 강화): 한 번 되살아난다
		revives -= 1
		player.hp = 2
		player._invuln = 2.0
		player.hp_changed.emit()
		toast(tr("REVIVED"), 2.0)
		Fx.burst(room, player.position, Color("f8c040"), 40, 140.0, 0.7)
		for b in get_tree().get_nodes_in_group("bullets_enemy"):
			b.queue_free()
		return
	_finish(false)


func _finish(victory: bool) -> void:
	if over:
		return
	over = true
	stats.damage_taken = player.hits_taken
	Sfx.music("")
	if victory:
		Sfx.play("victory")
	var embers := Profile.record_run(stats, victory, player.dash_count) if use_meta else 0
	if use_meta:
		if victory and player.hits_taken == _hits_at_floor_start:
			_achieve("untouched")
		if victory and stats.time < 18 * 60:
			_achieve("swift_vigil")
		Achievements.check_totals()
	run_finished.emit(victory)
	# 쓰러지는 연출을 잠깐 보여 준 뒤 결과 화면
	await get_tree().create_timer(2.0 if victory else 1.2, true, false, true).timeout
	if not is_inside_tree():
		return
	get_tree().paused = true
	ui.add_child(Results.new().setup(stats, victory, embers, owned, Achievements.session_new if use_meta else []))


# 제목 + 버튼 목록을 띄우고 게임을 멈춘다. 버튼을 누르면 메뉴를 닫고 on_pick(인덱스)를 부른다.
func _menu(title: String, options: Array, on_pick: Callable) -> void:
	_menu_open = true
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.set_meta("menu", true)
	ui.add_child(root)
	var box := Menu.panel(root, title, 260)
	for i in options.size():
		var b := Button.new()
		b.text = options[i].text
		b.custom_minimum_size.x = 260
		if options[i].has("color"):
			b.add_theme_color_override("font_color", options[i].color)
			b.add_theme_color_override("font_focus_color", options[i].color.lightened(0.4))
		b.pressed.connect(func() -> void:
			root.queue_free()
			_menu_open = false
			get_tree().paused = false
			on_pick.call(i))
		box.add_child(b)
	get_tree().paused = true
	Menu.guard(root)


# ── 그리기 ───────────────────────────────────────────────

func _draw_hud() -> void:
	var heart := Art.tex("heart")
	for i in player.max_hp:
		var pos := Vector2(3 + i * 9, 2)
		if heart:
			hud.draw_texture(heart, pos, Color.WHITE if i < player.hp else Color(0.25, 0.15, 0.2))
		else:
			hud.draw_rect(Rect2(pos, Vector2(6, 6)), Color("d63c3c") if i < player.hp else Color("40202a"))
	var coin := Art.tex("coin")
	if coin:
		hud.draw_texture(coin, Vector2(3, 15))
	# 미니맵(우상단): 방문한 방과 그 이웃만 보인다
	var lo := Vector2i.ZERO
	var hi := Vector2i.ZERO
	for c in cells:
		lo = lo.min(c)
		hi = hi.max(c)
	var origin := Vector2(W - 4 - (hi.x - lo.x + 1) * 7, 3) - Vector2(lo) * 7
	var icon := {"treasure": Color("f0c040"), "shop": Color("b080e0"), "boss": Color("e03030"), "gate": Color("e08030")}
	for c in cells:
		var seen := visited.has(c)
		for d in Dungeon.DIRS:
			seen = seen or visited.has(c + d)
		if not seen:
			continue
		var col := Color("a8a0b0") if cleared.has(c) else Color("5a5068")
		if c == current:
			col = Color.WHITE
		var r := Rect2(origin + Vector2(c) * 7, Vector2(6, 5))
		hud.draw_rect(r, col)
		if icon.has(types[c]):
			hud.draw_rect(Rect2(r.position + Vector2(2, 1), Vector2(2, 3)), icon[types[c]])
	# 시너지 태그 진행
	var x := 4.0
	for tag in ["might", "swift", "arcane", "blood"]:
		var n: int = tag_count.get(tag, 0)
		for i in Upgrades.SYNERGY_COUNT:
			hud.draw_rect(Rect2(x + i * 4, H - 8, 3, 4), _tag_color(tag) if i < n else Color(_tag_color(tag), 0.25))
		x += 16
	if is_instance_valid(boss) and boss.hp > 0:
		var w := 200.0
		hud.draw_rect(Rect2((W - w) / 2, H - 10, w, 5), Color("301018"))
		hud.draw_rect(Rect2((W - w) / 2, H - 10, w * boss.hp / boss.max_hp, 5), Color("d03040"))


func _tag_color(tag: String) -> Color:
	return {"might": Color("e05040"), "swift": Color("60d0a0"), "arcane": Color("6090f0"), "blood": Color("c03060")}[tag]


func _draw() -> void:
	var th := theme_data()
	var floor_tex := Art.tex("floor_" + th.tile)
	var wall_tex := Art.tex("wall_" + th.tile)
	draw_rect(Rect2(0, 0, W, H), th.wall)
	if wall_tex:
		draw_texture_rect(wall_tex, Rect2(0, 0, W, H), true)
	if floor_tex:
		draw_texture_rect(floor_tex, Rect2(WALL, WALL, W - 2 * WALL, H - 2 * WALL), true)
		# 바닥 대비·채도를 낮춰 캐릭터와 탄이 묻히지 않게 한다
		draw_rect(Rect2(WALL, WALL, W - 2 * WALL, H - 2 * WALL), Color(th.floor, 0.55))
	else:
		draw_rect(Rect2(WALL, WALL, W - 2 * WALL, H - 2 * WALL), th.floor)
	# 벽 안쪽 그림자 띠
	draw_rect(Rect2(WALL, WALL, W - 2 * WALL, 4), Color(0, 0, 0, 0.35))
	draw_rect(Rect2(WALL, WALL, 3, H - 2 * WALL), Color(0, 0, 0, 0.25))
	for d in Dungeon.DIRS:
		if not cells.has(current + d):
			continue
		var g := _gap(d)
		if floor_tex:
			draw_texture_rect(floor_tex, g, true)
		else:
			draw_rect(g, th.floor)
		if door_body:  # 닫힌 문: 붉은 창살
			draw_rect(g, Color(0.1, 0.02, 0.03, 0.75))
			for i in range(2, int(maxf(g.size.x, g.size.y)), 6):
				var a := g.position + (Vector2(i, 0) if g.size.x > g.size.y else Vector2(0, i))
				var b := a + (Vector2(0, g.size.y) if g.size.x > g.size.y else Vector2(g.size.x, 0))
				draw_line(a, b, Color("c03a3a"), 2.0)
	for p in pillars.get(current, []):
		var r := Rect2(p - Vector2(8, 8), Vector2(16, 16))
		draw_rect(Rect2(r.position + Vector2(0, 3), r.size), Color(0, 0, 0, 0.4))
		if wall_tex:
			draw_texture_rect(wall_tex, r, true, Color(1.4, 1.4, 1.4))
		else:
			draw_rect(r, th.accent)
		draw_rect(Rect2(r.position, Vector2(16, 2)), Color(1, 1, 1, 0.15))
