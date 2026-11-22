# Steam 연동·업로드 안내

## 1. App ID 넣기 (한 곳)

`project.godot`의 `[steam]` 절 `app_id` 값 하나만 바꾸면 됩니다.

```ini
[steam]
app_id=480   ; 테스트용 Spacewar. 출시 전 실제 App ID로 바꾸세요. 0이면 Steam 기능을 끕니다.
```

- App ID가 0이거나, GodotSteam 애드온이 없거나, Steam 클라이언트가 꺼져 있으면 게임은 Steam 기능 없이 그대로 실행됩니다.
- 개발 중 Steam 밖에서 실행할 때는 Steam 클라이언트에 로그인해 두면 `app_id`로 초기화됩니다.

## 2. GodotSteam 애드온

저장소에는 바이너리를 넣지 않습니다. 아래 명령이 GodotSteam GDExtension 4.24(MIT)를 받아 체크섬을 확인하고
Windows x64·macOS·Linux x64 라이브러리만 `addons/godotsteam/`에 풉니다.

```sh
cargo build --release --manifest-path tools/forge/Cargo.toml
tools/forge/target/release/forge steam-addon
```

## 3. Steamworks에서 직접 할 일

1. App ID와 플랫폼별 Depot 3개(Windows, macOS, Linux)를 만듭니다.
2. **업적 14개**를 아래 API 이름으로 만듭니다(이름·설명은 `translations/strings.csv`의 `ACH_*` 참고).

   | API 이름 | 영어 이름 | 조건 |
   |---|---|---|
   | FIRST_BLOOD | First Blood | 처음으로 적 처치 |
   | WARDEN | Bone Breaker | 뼈의 파수꾼 처치 |
   | MATRON | Tide Breaker | 익사한 수녀원장 처치 |
   | KING | Vigil Kept | 재의 왕 처치(승리) |
   | UNTOUCHED | Untouched | 피해 없이 한 층 돌파 |
   | SYNERGY | Harmony | 시너지 발동 |
   | LEGENDARY | Relic Seeker | 전설 축복 획득 |
   | HOARDER | Hoarder | 금화 150개 보유 |
   | SLAYER | Slayer | 누적 1000 처치 |
   | ELITE_HUNTER | Elite Hunter | 누적 엘리트 50 처치 |
   | SWIFT_VIGIL | Swift Vigil | 18분 안에 승리 |
   | DEVOTED | Devoted | 잿불 제단 강화 5단계 |
   | DASHER | Restless | 누적 대시 500회 |
   | PERSISTENT | Persistent | 10판 시작 |

3. **Steam Cloud**: 앱 설정에서 Cloud를 켜고 바이트 쿼터(예: 1MB)와 파일 수(예: 4)를 정합니다.
   게임은 `ISteamRemoteStorage`로 `profile.json`(메타 진행·통계·업적)을 직접 올리고 받으며, 더 최근 저장을 씁니다.
   설정 파일(`settings.cfg`)은 PC마다 다르므로 올리지 않습니다.
4. 실행 옵션(Launch Options): Windows `HollowVigil.exe`, macOS `HollowVigil.app`, Linux `HollowVigil.x86_64`.
5. Steam Deck 호환성 검토 신청(게임패드 전용 조작, 기본 해상도 1280x800에서 정수 배율 2배 + 레터박스).

## 4. 빌드와 업로드

```sh
tools/forge/target/release/forge build      # build/windows, build/macos/content, build/linux
export STEAM_APP_ID=... STEAM_DEPOT_WINDOWS=... STEAM_DEPOT_MACOS=... STEAM_DEPOT_LINUX=...
export STEAM_BRANCH=beta                    # 비워 두면 기본 브랜치에 자동 공개하지 않음
export STEAM_USER=<Steamworks 빌드 계정>
tools/forge/target/release/forge steam-upload   # VDF 생성(steam/out) 후 steamcmd 실행, 비밀번호는 steamcmd가 직접 묻습니다
```

자격 증명은 저장소·스크립트에 저장하지 않습니다. `steam/out/`은 git에서 제외됩니다.
