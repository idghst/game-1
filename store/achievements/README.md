# Steam 업적 아이콘

업적 14개의 달성·미달성 아이콘입니다. Steamworks의 업적 설정에서 업적마다 두 장을 올립니다.

- `<API 이름 소문자>.png`: 달성(색 있음), 64x64
- `<API 이름 소문자>_locked.png`: 미달성(같은 그림의 어두운 회색판), 64x64
- `256/`: 같은 이름의 256x256 확대본(nearest 4배). Steamworks 권장 크기라 이쪽을 올리면 됩니다.
- `sheet.png`: 한눈에 보기용(위 줄 달성, 아래 줄 미달성, 2배 확대)

업적 ID·조건의 기준은 `scripts/autoload/achievements.gd`(`ALL`과 해금 호출)이고, 이름은 `translations/strings.csv`의 `ACH_*`입니다.
Steam API 이름은 ID를 대문자로 바꾼 것입니다(`steam/README.md`).

| ID (API 이름) | 이름(영/한) | 달성 조건 | 그림 | 파일 |
|---|---|---|---|---|
| `first_blood` (FIRST_BLOOD) | First Blood / 첫 피 | 처음으로 적 처치(누적 처치 1) | 피 묻은 단검과 핏방울 | `first_blood.png`, `first_blood_locked.png` |
| `warden` (WARDEN) | Bone Breaker / 뼈 부수는 자 | 뼈의 파수꾼(3층 보스) 처치 | 뼈 왕관을 쓴 갈라진 해골 | `warden.png`, `warden_locked.png` |
| `matron` (MATRON) | Tide Breaker / 물결을 가르는 자 | 익사한 수녀원장(6층 보스) 처치 | 물결 위 청록 눈의 수녀 유령 | `matron.png`, `matron_locked.png` |
| `king` (KING) | Vigil Kept / 지켜진 불침번 | 재의 왕(9층 최종 보스) 처치 | 잿불이 갈라진 검은 왕관 | `king.png`, `king_locked.png` |
| `untouched` (UNTOUCHED) | Untouched / 무결 | 피해 없이 한 층 돌파 | 흠집 없는 은빛 방패 | `untouched.png`, `untouched_locked.png` |
| `synergy` (SYNERGY) | Harmony / 조화 | 시너지 발동 | 맞물린 붉은·푸른 마법 고리 | `synergy.png`, `synergy_locked.png` |
| `legendary` (LEGENDARY) | Relic Seeker / 유물 사냥꾼 | 전설 축복 획득 | 보라 보석 박힌 황금 유물 | `legendary.png`, `legendary_locked.png` |
| `hoarder` (HOARDER) | Hoarder / 수집가 | 금화 150개를 한 번에 보유 | 주머니에서 쏟아지는 금화 | `hoarder.png`, `hoarder_locked.png` |
| `slayer` (SLAYER) | Slayer / 학살자 | 누적 1000마리 처치 | 해골 더미와 검 | `slayer.png`, `slayer_locked.png` |
| `elite_hunter` (ELITE_HUNTER) | Elite Hunter / 엘리트 사냥꾼 | 누적 엘리트 50마리 처치 | 화살 박힌 뿔 달린 악마 해골 | `elite_hunter.png`, `elite_hunter_locked.png` |
| `swift_vigil` (SWIFT_VIGIL) | Swift Vigil / 재빠른 불침번 | 18분 안에 승리 | 불꽃 얹힌 모래시계 | `swift_vigil.png`, `swift_vigil_locked.png` |
| `devoted` (DEVOTED) | Devoted / 헌신 | 잿불 제단 강화 합계 5단계 | 잿불이 타는 돌 제단 | `devoted.png`, `devoted_locked.png` |
| `dasher` (DASHER) | Restless / 쉴 새 없이 | 누적 대시 500회 | 속도선을 남기는 날개 장화 | `dasher.png`, `dasher_locked.png` |
| `persistent` (PERSISTENT) | Persistent / 끈기 | 10판 시작 | 불 켜진 놋쇠 등불 | `persistent.png`, `persistent_locked.png` |

## 다시 만들기

원본은 `assets/src/manifest.txt`의 `ach_*` 줄(종류 `badge`)에서 맥미니 이미지 생성기로 만들고, 공용 팔레트 픽셀아트로 바꿉니다.

```sh
tools/forge/target/release/forge gen ach_king   # 원본 하나 생성(이름 생략 시 없는 것만). 다시 만들 땐 기존 ach_king.* 원본을 먼저 지움
tools/forge/target/release/forge pixel          # 이 폴더의 64·256·sheet를 모두 다시 씀
```

미달성 아이콘은 달성본의 밝기만 남겨 0.45배로 누르고 바탕이 묻히지 않게 조금 띄운 뒤 팔레트의 회색 단계로 맞춘 결정적 변환입니다(`tools/forge/src/pixel.rs`의 `locked`).
`forge test`의 `tests/test_achievement_icons.gd`가 파일 이름·개수·크기를 업적 정의와 맞춰 봅니다.
