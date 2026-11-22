extends Control
## 결과 화면: 승패, 통계, 얻은 업그레이드, 이번 판에 얻은 잿불(메타 재화). 승리하면 엔딩 문구를 먼저 보여 준다.

const Menu = preload("res://scripts/ui/menu.gd")
const Art = preload("res://scripts/art.gd")
const Upgrades = preload("res://scripts/upgrades.gd")


func setup(stats: Dictionary, victory: bool, embers: int, owned: Array, new_achievements: Array) -> Control:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.01, 0.03, 0.85)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	if victory:
		_ending(func() -> void: _stats(stats, victory, embers, owned, new_achievements))
	else:
		_stats(stats, victory, embers, owned, new_achievements)
	return self


# 엔딩: 짧은 글 한 장 후 결과 화면
func _ending(next: Callable) -> void:
	var page := Control.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(page)
	var box := Menu.panel(page, tr("VICTORY"), 320)
	var ending := Label.new()
	ending.text = tr("ENDING_TEXT")
	ending.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ending.custom_minimum_size.x = 320
	ending.add_theme_color_override("font_color", Color("dcb88c"))
	box.add_child(ending)
	Menu.button(box, tr("CONTINUE"), func() -> void:
		page.queue_free()
		next.call())
	Menu.guard.call_deferred(page)  # setup은 트리에 붙기 전에 불린다


func _stats(stats: Dictionary, victory: bool, embers: int, owned: Array, new_achievements: Array) -> void:
	var box := Menu.panel(self, tr("VICTORY") if victory else tr("GAME_OVER"), 300)
	var grid := GridContainer.new()
	grid.columns = 4  # 통계 두 쌍씩 한 줄
	grid.add_theme_constant_override("h_separation", 10)
	box.add_child(grid)
	var rows := [
		["RES_FLOOR", str(stats.floor)],
		["RES_TIME", "%02d:%02d" % [floori(stats.time / 60.0), int(stats.time) % 60]],
		["RES_KILLS", str(stats.kills)],
		["RES_ELITES", str(stats.elites)],
		["RES_BOSSES", str(stats.bosses)],
		["RES_GOLD", str(stats.gold)],
		["RES_HITS", str(stats.damage_taken)],
		["RES_EMBERS", "+%d" % embers],
	]
	for r in rows:
		var k := Label.new()
		k.text = tr(r[0])
		k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := Label.new()
		v.text = r[1]
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if r[0] == "RES_EMBERS":
			v.add_theme_color_override("font_color", Color("f08a2a"))
		grid.add_child(k)
		grid.add_child(v)
	if not owned.is_empty():
		var icons := HFlowContainer.new()
		icons.custom_minimum_size.x = 300
		for id in owned:
			var t := TextureRect.new()
			t.texture = Art.tex("icon_" + Upgrades.ALL[id].tag)
			t.modulate = Upgrades.RARITY_COLOR[Upgrades.ALL[id].rarity].lightened(0.2)
			t.tooltip_text = tr("UPG_" + id.to_upper())
			icons.add_child(t)
		box.add_child(icons)
	for a in new_achievements:
		var l := Label.new()
		l.text = "★ " + tr("ACH_" + a.to_upper())
		l.add_theme_color_override("font_color", Color("f8c040"))
		box.add_child(l)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	var again := Menu.button(row, tr("RESTART"), func() -> void:
		get_tree().paused = false
		get_tree().change_scene_to_file("res://main.tscn"))
	Menu.button(row, tr("TO_TITLE"), func() -> void:
		get_tree().paused = false
		get_tree().change_scene_to_file("res://title.tscn"))
	Menu.guard.call_deferred(self)
