# Hollow Vigil (할로우 비질)

다크 판타지 던전을 내려가는 2D 탑다운 트윈스틱 로그라이트. Godot 4.7 + GDScript, 480x270 픽셀아트(정수 배율, nearest).

- 9층(테마 3개 × 3층), 3·6·9층 보스, 9층 보스 처치가 엔딩. 한 판 15~25분.
- 적 7계열 + 엘리트, 보스 3종, 축복 22개(희귀도 4단계, 태그 3개 시너지), 방 5종(전투·보물·상점·관문·보스)
- 잿불 제단 영구 강화 10종, 업적 14개, Steam Cloud, 한국어·영어, 키·패드 재설정

## 지원 플랫폼

| 구분 | 플랫폼 | 검증 |
|---|---|---|
| 메인 | Windows 10/11 x64 | CI `windows-latest`에서 배포 exe 실행: 헤드리스 자동 플레이 한 판, 실제 창(ANGLE/Direct3D) 렌더·정수 배율·전체 화면, 저장, GodotSteam DLL, 메타데이터·아이콘·GUI 서브시스템, `forge test --quick` |
| 메인 | macOS 11+ (Apple Silicon·Intel 유니버설) | CI `macos-latest`(Apple Silicon)에서 배포 앱 실행: 같은 스모크, 유니버설 바이너리·ad-hoc 서명 확인 |
| 부가 | Linux x64 / SteamOS(Steam Deck) | 빌드와 헤드리스 스모크는 돌지만 실패해도 CI를 막지 않음 |

배포 빌드 스모크는 누구나 돌릴 수 있습니다: `HollowVigil.exe --headless --fixed-fps 60 -- --smoke`, 실제 창은 `-- --smoke-render`(결과: 사용자 데이터 폴더의 `smoke_result.txt`).

## 실행

```sh
brew install --cask godot                    # Godot 4.7.x
cargo build --release --manifest-path tools/forge/Cargo.toml
tools/forge/target/release/forge steam-addon # GodotSteam(선택, 없으면 Steam 없이 실행)
godot --headless --path . --import           # 첫 실행 전 한 번
godot --path .                               # 게임 실행
```

조작: WASD 이동, 마우스 조준·좌클릭 사격, Space/Shift 대시, E 상호작용, Esc 일시정지.
게임패드: 왼스틱 이동, 오른스틱 조준, RT 사격, LB/LT 대시, X 상호작용, Start 일시정지, 메뉴는 D패드/스틱 + A/B.

## 도구 (`tools/forge`, Rust)

| 명령 | 하는 일 |
|---|---|
| `forge test [--long\|--quick]` | 헤드리스 자가검증 전체(던전 연결성, 번역, 저장 손상, 9층 흐름, 패드 전용 메뉴, 자동 플레이, 실력별 밸런스) |
| `forge build [windows,macos,linux]` | 내보내기 → `build/`(생략하면 세 플랫폼) |
| `forge steam-addon` | GodotSteam GDExtension 받기(체크섬 확인) |
| `forge steam-vdf` / `forge steam-upload` | SteamPipe VDF 생성 / steamcmd 업로드 (`steam/README.md`) |
| `forge gen` → `forge pixel` | 맥미니 이미지 생성기로 원본 생성 → 공용 팔레트 픽셀아트 변환 |
| `forge sfx` | 효과음·배경음 합성 |
| `forge capsules` | 스토어 캡슐 이미지 |
| `forge graph` | GDScript(.gd·.tscn·project.godot)를 직접 읽어 graphify 그래프에 합치고 Obsidian·HTML로 내보내기(주석은 읽지 않음) |

창이 필요한 확인: `godot --path . -s tests/test_perf.gd`(프레임 속도), `godot --path . -s tools/screenshot.gd -- <폴더> [장면...]`(스크린샷).

## 문서

- 밸런스 측정과 봇의 한계: `docs/BALANCE.md`
- Steam 연동·업로드: `steam/README.md`
- 스토어 페이지·출시 체크리스트: `store/`
- 크레딧·라이선스: `CREDITS.md`
