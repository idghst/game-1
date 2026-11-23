## Hollow Vigil {{VERSION}}

### 받기
| 파일 | 설명 |
|---|---|
| `HollowVigil-Setup-{{VERSION}}.exe` | Windows 10/11 64비트 설치 파일. 관리자 권한 없이 사용자 계정에 설치하고, 시작 메뉴·제거 프로그램에 등록합니다 |
| `HollowVigil-{{VERSION}}-windows.zip` | Windows 무설치판. 압축을 풀고 `HollowVigil.exe` 실행 |
| `HollowVigil-{{VERSION}}-macos.zip` | macOS 11 이상(Apple Silicon·Intel). 압축을 풀고 `Hollow Vigil.app` 실행 |
| `SHA256SUMS.txt` | 위 파일들의 SHA-256 체크섬 |

### 처음 실행할 때 경고가 뜨면
- **Windows**: 코드 서명을 하지 않아 "Windows의 PC 보호(SmartScreen)" 창이 뜰 수 있습니다. **추가 정보 → 실행**을 누르세요.
{{SIGNED}}- **macOS**: Developer ID로 서명하고 Apple 공증을 마친 앱이라 경고 없이 열립니다.
{{UNSIGNED}}- **macOS**: 이번 빌드는 **서명·공증 안 됨**(ad-hoc 서명)이라 처음 열 때 막힐 수 있습니다. 한 번 열어 본 뒤 **시스템 설정 → 개인정보 보호 및 보안**에서 Hollow Vigil의 **그래도 열기**를 누르세요(macOS 14 이하는 앱을 Control+클릭 → 열기로도 됩니다).

### 변경 사항
- (여기에 이번 버전의 변경 사항을 적습니다)

저장 파일은 설치 폴더 밖(Windows `%APPDATA%\Godot\app_userdata\Hollow Vigil`)에 있어 제거하거나 다시 설치해도 남습니다.
