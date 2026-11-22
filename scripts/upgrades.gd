extends RefCounted
## 업그레이드 데이터, 희귀도별 추첨, 효과 적용, 태그 시너지.
## 이름·설명은 번역 키 UPG_<ID>, UPG_<ID>_DESC.

const RARITY_WEIGHT := {"common": 60.0, "rare": 28.0, "epic": 10.0, "legendary": 2.5}
const RARITY_COLOR := {"common": Color("c8c0b0"), "rare": Color("5fa8e8"), "epic": Color("b46ae0"), "legendary": Color("f0b040")}
const PRICE := {"common": 20, "rare": 35, "epic": 55, "legendary": 85}

# unique: 한 번만 얻을 수 있음
const ALL := {
	"sharp": {"rarity": "common", "tag": "might"},
	"heavy": {"rarity": "common", "tag": "might"},
	"trigger": {"rarity": "common", "tag": "swift"},
	"boots": {"rarity": "common", "tag": "swift"},
	"lightstep": {"rarity": "common", "tag": "swift"},
	"vitality": {"rarity": "common", "tag": "blood"},
	"barrel": {"rarity": "common", "tag": "arcane"},
	"greed": {"rarity": "common", "tag": "blood"},
	"twin": {"rarity": "rare", "tag": "might"},
	"pierce": {"rarity": "rare", "tag": "arcane"},
	"ricochet": {"rarity": "rare", "tag": "arcane"},
	"bloodpact": {"rarity": "rare", "tag": "blood", "unique": true},
	"critical": {"rarity": "rare", "tag": "might"},
	"frost": {"rarity": "rare", "tag": "arcane", "unique": true},
	"homing": {"rarity": "epic", "tag": "arcane", "unique": true},
	"explosive": {"rarity": "epic", "tag": "might", "unique": true},
	"phantom": {"rarity": "epic", "tag": "swift", "unique": true},
	"inferno": {"rarity": "epic", "tag": "blood", "unique": true},
	"glass": {"rarity": "legendary", "tag": "might", "unique": true},
	"triple": {"rarity": "legendary", "tag": "might", "unique": true},
	"souls": {"rarity": "legendary", "tag": "blood", "unique": true},
	"timewarp": {"rarity": "legendary", "tag": "swift", "unique": true},
}

# 같은 태그 3개를 모으면 발동. 이름 키 SYN_<TAG>.
const SYNERGY_COUNT := 3


# 서로 다른 업그레이드 n개를 희귀도 가중치로 뽑는다. luck > 0이면 높은 희귀도 확률이 오른다.
static func roll(rng: RandomNumberGenerator, owned: Array, n: int, luck := 0.0) -> Array[String]:
	var pool: Array[String] = []
	for id in ALL:
		if not (ALL[id].get("unique", false) and owned.has(id)):
			pool.append(id)
	var picks: Array[String] = []
	while picks.size() < n and not pool.is_empty():
		var total := 0.0
		for id in pool:
			total += _weight(id, luck)
		var r := rng.randf() * total
		for id in pool:
			r -= _weight(id, luck)
			if r <= 0:
				picks.append(id)
				pool.erase(id)
				break
	return picks


static func _weight(id: String, luck: float) -> float:
	var rarity: String = ALL[id].rarity
	var w: float = RARITY_WEIGHT[rarity]
	return w * (1.0 + luck) if rarity != "common" else w


# 플레이어 능력치에 효과를 적용한다.
static func apply(id: String, p: Node) -> void:
	match id:
		"sharp": p.damage += 3
		"heavy":
			p.damage += 6
			p.fire_delay *= 1.12
			p.knockback *= 1.5
		"trigger": p.fire_delay *= 0.85
		"boots": p.speed *= 1.12
		"lightstep": p.dash_cooldown *= 0.75
		"vitality":
			p.max_hp += 2
			p.heal(2)
		"barrel":
			p.shot_speed *= 1.2
			p.shot_life *= 1.25
		"greed": p.gold_mult += 0.5
		"twin": p.projectiles += 1
		"pierce": p.pierce += 1
		"ricochet": p.bounce += 1
		"bloodpact": p.lifesteal_every = mini(p.lifesteal_every, 20) if p.lifesteal_every > 0 else 20
		"critical": p.crit += 0.15
		"frost": p.slow = true
		"homing": p.homing += 3.0
		"explosive": p.explode += 20.0
		"phantom": p.phantom = true
		"inferno": p.burn = true
		"glass":
			p.damage = int(p.damage * 1.6)
			p.max_hp = maxi(p.max_hp - 2, 2)
			p.hp = mini(p.hp, p.max_hp)
		"triple": p.projectiles += 2
		"souls": p.souls = true
		"timewarp":
			p.fire_delay *= 0.7
			p.speed *= 1.15
	p.hp_changed.emit()


static func apply_synergy(tag: String, p: Node) -> void:
	match tag:
		"might": p.damage = int(p.damage * 1.25)
		"swift":
			p.dash_reset_on_kill = true
			p.speed *= 1.1
		"arcane":
			p.homing += 1.5
			p.pierce += 1
		"blood":
			p.max_hp += 2
			p.heal(2)
			p.lifesteal_every = 12
	p.hp_changed.emit()
