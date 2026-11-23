extends SceneTree
## 트레일러 촬영 디렉터(촬영 전용, 내보내기에서 tools/*로 빠진다). `forge trailer`가 부른다.
##   godot --path . --write-movie <폴더>/f.png -s tools/trailer.gd -- <폴더> <언어> <클립>
##     클립 하나를 Movie Maker(고정 60fps)로 녹화하고, 편집 기준 시각을 <폴더>/cues.txt에 "이름 초"로 쓴다.
##   godot --path . -s tools/trailer.gd -- <폴더> <언어> captions <자막>...
##     자막을 게임 폰트(갈무리11, 12px)로 그려 2배 nearest 확대한 투명 PNG(cap0.png…)로 쓴다.
## 실제 진행 파일은 건드리지 않고, 시드를 고정해 매번 같은 장면을 찍는다.

const Bot = preload("res://scripts/bot.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const SEED := 7
const FPS := 60.0
# 축복 고르기 장면에서 사격이 눈에 띄게 달라지는 것부터 고른다
const PICK_ORDER := ["triple", "twin", "explosive", "homing", "ricochet", "inferno", "frost", "pierce", "souls", "critical", "heavy", "trigger"]

var profile: Node  # 오토로드 이름은 -s 스크립트에서 컴파일 시점에 안 보인다
var dir := ""
var clip := ""
var main: Node
var bot: Node
var title: Control
var frame := 0
var cues := {}
var length := 5.0  # 녹화 길이(초). 장면에 따라 끝을 늦춘다
var _menu_seen := -1
var _picked := -1
var _dead := -1


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	dir = args[0]
	profile = root.get_node("Profile")
	clip = args[2]
	# 사용자 설정의 볼륨과 무관하게: 배경음은 편집에서 따로 깔고, 효과음은 원래 크기로
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), true)
	for bus in ["Master", "SFX"]:
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus), 0.0)
	profile.path = "user://trailer_profile.json"
	profile.data = profile.defaults()
	seed(SEED)


# 첫 프레임에 시작해야 붙인 장면의 _ready가 돈다
func _setup() -> void:
	TranslationServer.set_locale(OS.get_cmdline_user_args()[1])  # 설정 오토로드가 시작 때 로캘을 덮어쓰므로 여기서
	if clip == "captions":
		_captions(OS.get_cmdline_user_args().slice(3))
		return
	match clip:
		"title", "logo":
			_title(clip == "title")
		"altar":
			profile.data.embers = 420
			_title(true)
			title._open_meta()
		"f1": _run(1, "combat", [])
		"f3": _run(3, "combat", ["sharp", "trigger"])
		"bless":
			_run(2, "gate", ["sharp"])
			main.luck = 1.0  # 희귀 축복이 잘 보이게(촬영 전용)
			length = 60.0
		"shop":
			_run(4, "shop", ["twin", "sharp", "boots"])
			main.gold = 140
		"elite": _run(5, "gate", ["twin", "sharp", "homing", "trigger"])
		"treasure":
			_run(6, "treasure", ["twin", "explosive", "boots"])
			length = 20.0
		"boss3": _run(3, "boss", ["twin", "sharp", "trigger"])
		"boss6": _run(6, "boss", ["triple", "explosive", "pierce", "boots"])
		"boss9": _run(9, "boss", ["souls", "inferno", "triple", "homing", "trigger"])
		"death":
			_run(5, "combat", ["twin", "sharp"], true)
			main.player.hp = 1
			main.player.hp_changed.emit()
			bot.skill = 0.3
			length = 20.0
		_:
			push_error("모르는 클립: " + clip)
			quit(1)


func _title(hide_logo: bool) -> void:
	title = load("res://title.tscn").instantiate()
	root.add_child(title)
	for c in title.get_children():
		if c is VBoxContainer or c is Label or (hide_logo and c is TextureRect and c.texture and c.texture.resource_path.ends_with("logo.svg")):
			c.hide()


func _run(floor_n: int, room_type: String, build: Array, meta := false) -> void:
	main = load("res://main.tscn").instantiate()
	main.use_meta = meta
	root.add_child(main)
	main.rng.seed = SEED * 100 + floor_n
	main.floor_n = floor_n
	main._new_floor()
	for c in main.cells:
		if main.types[c] == room_type:
			main._enter(c, Vector2i.LEFT)
			break
	for id in build:
		main._take_upgrade(id)
	bot = Bot.new()
	bot.main = main
	bot.skill = 0.85  # 조준이 살짝 흔들리고 가끔 늦게 피한다(사람처럼)
	main.add_child(bot)


func _process(_delta: float) -> bool:
	if frame == 0:
		_setup()
	if clip == "captions":
		frame = 1
		return false
	var t := frame / FPS
	frame += 1
	if main:
		_direct(t)
	elif clip == "altar":
		_altar(t)
	if t >= length:
		_finish()
	return false


func _direct(t: float) -> void:
	var p: Node2D = main.player
	p._mouse_aim = false  # 녹화 창 위의 마우스가 조준을 건드리지 않게
	if clip != "death" and p.hp < p.max_hp:
		p.heal(p.max_hp)  # 촬영 중에는 쓰러지지 않는다(맞는 연출은 그대로)
	var menu: Node = null
	for c in main.ui.get_children():
		if c.has_meta("menu"):
			menu = c
	if menu:
		bot._menu_t = -100.0  # 봇이 아무 버튼이나 누르지 않게 디렉터가 고른다
		if _menu_seen < 0:
			_menu_seen = frame
			cues.menu = t
			if clip == "treasure":
				length = t + 1.5
		if clip == "bless" and frame - _menu_seen == int(1.4 * FPS):
			_pick_button(menu).grab_focus()
		if clip == "bless" and frame - _menu_seen == int(2.2 * FPS):
			_pick_button(menu).pressed.emit()
			cues.pick = t
			_picked = frame
	if clip == "bless" and _picked > 0 and frame - _picked == int(0.6 * FPS):
		# 다음 전투 방으로 넘겨 달라진 사격을 보여 준다
		for c in main.cells:
			if main.types[c] == "combat" and not main.cleared.has(c):
				main._enter(c, Vector2i.LEFT)
				cues.fight = t
				length = t + 4.0
				break
	if clip == "death":
		if _dead < 0 and (p.hp <= 0 or t > 4.0):
			if p.hp > 0:  # 제때 안 맞으면 한 대 맞힌다
				p._invuln = 0.0
				p.hit(p.hp)
			_dead = frame
			cues.death = t
			length = t + 3.5


func _pick_button(menu: Node) -> Button:
	var buttons: Array = menu.find_children("*", "Button", true, false)
	for id in PICK_ORDER:
		for b in buttons:
			if b.text.begins_with(tr("UPG_" + id.to_upper()) + " "):
				return b
	return buttons[0]


func _altar(t: float) -> void:
	var meta: Node = title.get_child(title.get_child_count() - 1)
	for i in 3:
		if frame == int((0.8 + i * 0.9) * FPS):
			var id: String = ["might", "vigor", "might"][i]
			for b in meta.find_children("*", "Button", true, false):
				if b.get_meta("id", "") == id:
					b.grab_focus()
					b.pressed.emit()
					break
	if frame == 1:
		cues.altar = t


func _finish() -> void:
	var f := FileAccess.open(dir.path_join("cues.txt"), FileAccess.WRITE)
	f.store_string("end %.3f\n" % (frame / FPS))
	for k in cues:
		f.store_string("%s %.3f\n" % [k, cues[k]])
	f.close()
	DirAccess.remove_absolute(profile.path)
	quit()


func _captions(texts: Array) -> void:
	for i in texts.size():
		var vp := SubViewport.new()
		vp.transparent_bg = true
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		vp.size = Vector2i(240, 32)
		var band := ColorRect.new()  # 메뉴·탄막 위에서도 읽히게 옅은 띠를 깐다
		band.color = Color(0.02, 0.01, 0.04, 0.5)
		band.size = Vector2(vp.size)
		vp.add_child(band)
		var l := Label.new()
		l.text = texts[i]
		UiTheme.big(l)
		l.add_theme_color_override("font_color", Color("f0dcb0"))
		l.add_theme_color_override("font_outline_color", Color("0a0810"))
		l.add_theme_constant_override("outline_size", 3)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size = Vector2(vp.size) - Vector2(8, 0)
		l.position.x = 4
		vp.add_child(l)
		root.add_child(vp)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		# 화면 밖으로 넘치지 않는지: 두 줄 이하, 위아래 여백 안
		var ok: bool = l.get_line_count() <= 2 and l.get_line_count() * l.get_line_height() <= vp.size.y
		print("caption %d lines=%d height=%d %s: %s" % [i, l.get_line_count(), l.get_line_count() * l.get_line_height(), "OK" if ok else "OVERFLOW", texts[i]])
		var img := vp.get_texture().get_image()
		img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
		img.save_png(dir.path_join("cap%d.png" % i))
		vp.queue_free()
	quit()
