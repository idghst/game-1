extends Node
## 영구 진행(메타 재화·강화 단계·누적 통계·업적)을 user://profile.json에 저장한다.
## 쓰기는 임시 파일에 쓴 뒤 바꿔 넣고, 읽다가 깨진 파일을 만나면 .bad로 옮겨 두고 새로 시작한다.

signal saved

const PATH := "user://profile.json"
const VERSION := 1

var path := PATH  # 테스트가 실제 저장을 건드리지 않게 바꿀 수 있다
var data := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	data = load_from(path)


static func defaults() -> Dictionary:
	return {
		"version": VERSION,
		"saved_at": 0,
		"embers": 0,
		"meta": {},  # 강화 id -> 단계
		"totals": {"runs": 0, "wins": 0, "kills": 0, "elites": 0, "bosses": 0, "dashes": 0, "best_floor": 0, "best_time": 0.0, "embers_earned": 0},
		"achievements": [],
	}


# 기본값 위에 읽은 값을 타입이 맞는 것만 덮어쓴다(오래되거나 손상된 파일 대비).
static func sanitize(raw: Variant) -> Dictionary:
	var d := defaults()
	if not raw is Dictionary:
		return d
	d.saved_at = int(raw.get("saved_at", 0)) if raw.get("saved_at") is float or raw.get("saved_at") is int else 0
	d.embers = maxi(int(raw.embers), 0) if raw.get("embers") is float or raw.get("embers") is int else 0
	if raw.get("meta") is Dictionary:
		for k in raw.meta:
			if k is String and (raw.meta[k] is float or raw.meta[k] is int):
				d.meta[k] = clampi(int(raw.meta[k]), 0, 99)
	if raw.get("totals") is Dictionary:
		for k in d.totals:
			var v = raw.totals.get(k)
			if v is float or v is int:
				d.totals[k] = maxf(v, 0.0) if d.totals[k] is float else maxi(int(v), 0)
	if raw.get("achievements") is Array:
		for a in raw.achievements:
			if a is String and not d.achievements.has(a):
				d.achievements.append(a)
	return d


static func load_from(file: String) -> Dictionary:
	if not FileAccess.file_exists(file):
		return defaults()
	var text := FileAccess.get_file_as_string(file)
	var raw = JSON.parse_string(text)
	if raw == null:
		DirAccess.rename_absolute(file, file + ".bad")  # 손상된 파일은 지우지 않고 남겨 둔다
		push_warning("profile: 손상된 저장 파일을 %s.bad로 옮기고 새로 시작합니다" % file)
		return defaults()
	return sanitize(raw)


func save() -> void:
	data.saved_at = int(Time.get_unix_time_from_system())
	var text := JSON.stringify(data, "\t")
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("profile: 저장 실패 %s" % FileAccess.get_open_error())
		return
	f.store_string(text)
	f.close()
	DirAccess.remove_absolute(path)
	DirAccess.rename_absolute(tmp, path)
	saved.emit()


func total(key: String) -> Variant:
	return data.totals[key]


func meta_level(id: String) -> int:
	return data.meta.get(id, 0)


# 판이 끝나면 통계를 누적한다. 돌려주는 값은 이번 판에 얻은 잿불.
func record_run(stats: Dictionary, victory: bool, dashes: int) -> int:
	var t: Dictionary = data.totals
	t.runs += 1
	t.wins += 1 if victory else 0
	t.kills += stats.kills
	t.elites += stats.elites
	t.bosses += stats.bosses
	t.dashes += dashes
	t.best_floor = maxi(t.best_floor, stats.floor)
	if victory and (t.best_time == 0.0 or stats.time < t.best_time):
		t.best_time = stats.time
	var embers := embers_for(stats, victory)
	data.embers += embers
	t.embers_earned += embers
	save()
	return embers


static func embers_for(stats: Dictionary, victory: bool) -> int:
	return stats.floor * 4 + stats.kills / 10 + stats.elites * 2 + stats.bosses * 15 + (40 if victory else 0)
