extends RefCounted
## 메타 진행: 판마다 얻는 잿불로 사는 영구 강화. 이름·설명 키 META_<ID>, META_<ID>_DESC.

const ALL := {
	"vigor": {"costs": [30, 60, 100]},
	"might": {"costs": [40, 80, 130]},
	"haste": {"costs": [25, 50, 80]},
	"trigger": {"costs": [35, 70, 110]},
	"reflex": {"costs": [30, 70]},
	"purse": {"costs": [20, 40, 60]},
	"fortune": {"costs": [50, 90, 140]},
	"scavenger": {"costs": [80]},
	"second_wind": {"costs": [150]},
	"insight": {"costs": [200]},
}


static func max_level(id: String) -> int:
	return ALL[id].costs.size()


static func next_cost(id: String, level: int) -> int:
	return ALL[id].costs[level] if level < max_level(id) else -1


# 판 시작 때 플레이어·판 상태에 강화를 적용한다. lv: id -> 단계
static func apply(lv: Dictionary, player: Node, run: Node) -> void:
	player.max_hp += lv.get("vigor", 0)
	player.hp = player.max_hp
	player.damage += 2 * lv.get("might", 0)
	player.speed *= 1.0 + 0.05 * lv.get("haste", 0)
	player.fire_delay *= 1.0 - 0.05 * lv.get("trigger", 0)
	player.dash_cooldown *= 1.0 - 0.1 * lv.get("reflex", 0)
	run.gold += 15 * lv.get("purse", 0)
	run.luck = 0.2 * lv.get("fortune", 0)
	run.floor_heal = lv.get("scavenger", 0) > 0
	run.revives = lv.get("second_wind", 0)
	run.choices = 4 if lv.get("insight", 0) > 0 else 3
