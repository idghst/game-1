extends Control
## 영구 강화 상점(타이틀 화면에서 연다). 잿불로 단계를 올린다.

signal closed

const Menu = preload("res://scripts/ui/menu.gd")
const Meta = preload("res://scripts/meta.gd")

var _box: VBoxContainer
var _embers: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.8)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box := Menu.panel(self, tr("META_TITLE"), 340)
	_embers = Label.new()
	_embers.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_embers.add_theme_color_override("font_color", Color("f08a2a"))
	box.add_child(_embers)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(340, 170)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	box.add_child(scroll)
	_box = VBoxContainer.new()
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_box)
	Menu.button(box, tr("BACK"), _close)
	_build()
	Menu.focus_first(_box)


func _build(focus_id := "") -> void:
	for c in _box.get_children():
		c.queue_free()
	_embers.text = "%s: %d" % [tr("EMBERS"), Profile.data.embers]
	for id in Meta.ALL:
		var lv := Profile.meta_level(id)
		var cost := Meta.next_cost(id, lv)
		var row := HBoxContainer.new()
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name := Label.new()
		name.text = "%s  %s" % [tr("META_" + id.to_upper()), "■".repeat(lv) + "□".repeat(Meta.max_level(id) - lv)]
		text.add_child(name)
		var desc := Label.new()
		desc.text = tr("META_" + id.to_upper() + "_DESC")
		desc.add_theme_color_override("font_color", Color("a89cae"))
		text.add_child(desc)
		row.add_child(text)
		var b := Button.new()
		b.custom_minimum_size.x = 70
		b.text = tr("META_MAXED") if cost < 0 else "%d" % cost
		b.disabled = cost < 0 or Profile.data.embers < cost
		b.focus_mode = Control.FOCUS_ALL
		b.set_meta("id", id)
		b.pressed.connect(func() -> void: _buy(id))
		row.add_child(b)
		_box.add_child(row)
	if focus_id != "":
		await get_tree().process_frame
		for b in _box.find_children("*", "Button", true, false):
			if b.get_meta("id", "") == focus_id and not b.is_queued_for_deletion():
				if b.disabled:
					Menu.focus_first(_box)
				else:
					b.grab_focus()


func _buy(id: String) -> void:
	var lv := Profile.meta_level(id)
	var cost := Meta.next_cost(id, lv)
	if cost < 0 or Profile.data.embers < cost:
		return
	Profile.data.embers -= cost
	Profile.data.meta[id] = lv + 1
	Profile.save()
	Sfx.play("upgrade")
	Achievements.check_meta()
	_build(id)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	closed.emit()
	queue_free()
