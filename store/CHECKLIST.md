# 스팀 출시 준비물 체크리스트

## 준비됨 (이 저장소)
- [x] 게임 빌드(메인): Windows x64 / macOS universal — `forge build windows,macos`, CI 러너에서 실기 스모크
- [x] 게임 빌드(부가): Linux x64·Steam Deck — `forge build linux`, CI에서 빌드·헤드리스 스모크(필수 아님)
- [x] Windows 실행 파일 아이콘·제품명·회사·저작권·버전 메타데이터(Godot 내장 PE 수정, rcedit 불필요), 콘솔 창 없음
- [x] 캡슐 이미지 9종 — `store/capsules/`
  - header 920x430, small 462x174, main 1232x706, vertical 748x896
  - library capsule 600x900, library hero 3840x1240(로고 없음), library logo 1280x720(투명)
  - page background 1438x810, community icon 184x184
- [x] 스크린샷 8장(1920x1080, 실제 플레이) — `store/screenshots/` (Steam 최소 5장)
- [x] 짧은 설명·상세 설명·특징(한/영) — `store/STORE_PAGE.md`
- [x] 업적 14개 API 이름·조건 — `steam/README.md`
- [x] 업적 아이콘 14개 × 달성/미달성 — `store/achievements/`(64x64), `store/achievements/256/`(256x256, Steamworks 권장), 목록·조건 `store/achievements/README.md`
- [x] SteamPipe VDF 생성·업로드 스크립트 — `forge steam-vdf`, `forge steam-upload`
- [x] 크레딧·라이선스 — `CREDITS.md`, `assets/fonts/OFL.txt`

## 주인이 직접 해야 할 일 (Steamworks)
- [ ] Steamworks 파트너 가입, 앱 비용(Steam Direct) 결제, 세금·은행 정보
- [ ] App ID 발급 → `project.godot`의 `[steam] app_id` 한 줄 교체(현재 테스트용 480)
- [ ] Depot 만들고 `STEAM_DEPOT_*` 환경 변수로 업로드: Windows·macOS 필수, Linux는 출시 범위에 넣을지 결정 후
- [ ] 업적 14개 등록(API 이름은 `steam/README.md` 표 그대로), 아이콘 업로드(달성 `<id>.png`·미달성 `<id>_locked.png`, `store/achievements/256/` 권장)
- [ ] Steam Cloud 켜기(쿼터 1MB, 파일 4개 정도)
- [ ] 스토어 페이지 입력, 캡슐·스크린샷 업로드, 가격·출시일, 연령 등급 설문(IARC)
- [ ] 트레일러 영상(선택이지만 강력 권장, 아직 없음)
- [ ] (부가) Steam Deck 호환성 검토 요청 — Linux를 출시 범위에 넣을 때만
- [x] macOS Developer ID 서명·공증·스테이플 단계 — `release.yml`의 `macos-sign`(시크릿 없으면 건너뛰고 ad-hoc zip을 "서명·공증 안 됨"으로 표시)
- [ ] **macOS 서명·공증 시크릿 넣기(주인이 할 일)**: Apple Developer Program 가입 → Developer ID Application 인증서(.p12)·App Store Connect API 키(.p8) 만들기 →
  `MACOS_CERT_P12_BASE64`·`MACOS_CERT_PASSWORD`·`APPLE_TEAM_ID`·`APPLE_API_KEY_ID`·`APPLE_API_ISSUER_ID`·`APPLE_API_KEY_P8_BASE64`를 `gh secret set`으로 등록(순서·명령은 README "macOS 서명·공증").
  넣기 전까지 macOS zip은 Gatekeeper 경고가 뜸. 넣은 뒤 첫 태그 릴리스 로그에서 `source=Notarized Developer ID` 확인
- [x] Windows 설치 파일(Inno Setup, 사용자 단위 설치·시작 메뉴·제거 프로그램 등록, 한/영) — CI에서 무인 설치·실행·제거 검증, `v*` 태그로 GitHub Release
- [ ] **Authenticode 서명(주인이 할 일)**: 설치 파일·exe에 서명이 없어 SmartScreen 경고가 뜸(README에 넘어가는 법 안내). 인증서를 사면 CI의 설치 파일 단계 뒤에 signtool 서명을 붙임. Steam으로만 배포하면 필수 아님
- [ ] CI 필수 체크 지정: 비공개 저장소 + GitHub Free에서는 브랜치 보호를 쓸 수 없음. Pro로 올리거나 공개하면 `windows`·`macos` 작업을 필수 체크로 지정
- [ ] 실기 확인: 실제 Windows PC(GPU·고DPI 125~200%·오디오)와 Mac에서의 플레이, 실제 Xbox(XInput)·PS 패드, Steam 클라이언트에서 업적·Cloud·오버레이, (부가) Steam Deck
