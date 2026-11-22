extends SceneTree
## 번역 자가검증: godot --headless --path . -s tests/test_i18n.gd
## 코드에서 쓰는 모든 번역 키(문자열 리터럴 tr("...") + 데이터에서 만드는 키)가 영어·한국어 모두에 있는지,
## 그리고 형식 문자열(%d)의 개수가 언어끼리 같은지 확인한다.

const Upgrades = preload("res://scripts/upgrades.gd")
const Meta = preload("res://scripts/meta.gd")

var fails := 0


func check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		printerr("FAIL: ", msg)


func _scan(dir: String, keys: Dictionary) -> void:
	var re := RegEx.create_from_string("tr\\(\"([A-Z0-9_]+)\"\\)")
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			for m in re.search_all(FileAccess.get_file_as_string(dir.path_join(f))):
				keys[m.get_string(1)] = true
	for d in DirAccess.get_directories_at(dir):
		_scan(dir.path_join(d), keys)


func _initialize() -> void:
	var keys := {}
	_scan("res://scripts", keys)
	for id in Upgrades.ALL:
		keys["UPG_" + id.to_upper()] = true
		keys["UPG_" + id.to_upper() + "_DESC"] = true
	for r in Upgrades.RARITY_WEIGHT:
		keys["RARITY_" + r.to_upper()] = true
	for tag in ["might", "swift", "arcane", "blood"]:
		keys["SYN_" + tag.to_upper()] = true
	for id in Meta.ALL:
		keys["META_" + id.to_upper()] = true
		keys["META_" + id.to_upper() + "_DESC"] = true
	for b in ["warden", "matron", "king"]:
		keys["BOSS_" + b.to_upper()] = true
	for t in ["CRYPT", "CATACOMB", "SANCTUM"]:
		keys["THEME_" + t] = true
	for a in ["MOVE_UP", "MOVE_DOWN", "MOVE_LEFT", "MOVE_RIGHT", "SHOOT", "DASH", "PAUSE"]:
		keys["ACT_" + a] = true
	var ach := load("res://scripts/autoload/achievements.gd")
	if ach:
		for a in ach.ALL:
			keys["ACH_" + a.to_upper()] = true
			keys["ACH_" + a.to_upper() + "_DESC"] = true
	var en := TranslationServer.get_translation_object("en")
	var ko := TranslationServer.get_translation_object("ko")
	check(en != null and ko != null, "en/ko translations loaded")
	for k in keys:
		var e := String(en.get_message(k))
		var o := String(ko.get_message(k))
		check(e != "" and o != "", "missing translation for %s (en=%s ko=%s)" % [k, e != "", o != ""])
		check(e.count("%d") == o.count("%d") and e.count("%s") == o.count("%s"), "format mismatch in %s" % k)
	check(String(en.get_message("GAME_TITLE")) == ProjectSettings.get_setting("application/config/name"), "GAME_TITLE matches project name")
	print("i18n self-test: %d keys, %d failures" % [keys.size(), fails])
	quit(1 if fails else 0)
