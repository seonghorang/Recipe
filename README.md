# Recipe Manager

핸드드립 레시피와 요리 레시피를 효율적으로 관리하고, 일본어 회화 학습을 지원하는 **Flutter 기반 모바일 애플리케이션**입니다. 사용자는 레시피 추가/편집/삭제, 데이터 시각화를 통한 패턴 분석, 그리고 새로운 기능인 **회화 학습 탭에서 음성 녹음 및 재생을 통한 상호작용**을 경험할 수 있습니다. Firebase Cloud Functions를 활용한 **푸시 알림 시스템**을 구현하여, 중요한 업데이트를 사용자에게 실시간으로 전달합니다.

<br>
<br>
<br>
<img src="assets/Recording.gif" alt="Recipe Manager Demo" width="225" height="400">
<br>

## 프로젝트 개요

### 목표:
- 사용자 친화적인 레시피 관리 및 효율적인 데이터 분석 기능 제공
- Firebase Backend as a Service (BaaS)를 활용한 서버리스 아키텍처 구현 및 운영 능력 입증
- 복잡한 비동기 처리 및 실시간 통신을 요구하는 기능(음성, 푸시 알림) 구현을 통한 기술 역량 심화

### 기술 스택:
- **Frontend**: Flutter (Dart), `fl_chart` (데이터 시각화), `just_audio` (오디오 재생), `record` (오디오 녹음)
- **Backend**: Firebase Firestore (실시간 NoSQL 데이터베이스), Firebase Storage (오디오 파일 저장), Firebase Cloud Functions (서버리스 백엔드 로직), Firebase Cloud Messaging (푸시 알림)
- **Version Control**: GitHub

### 주요 기능:
- **레시피 관리**: 커피 및 요리 레시피 CRUD 기능 및 최근 레시피 자동 로드
- **데이터 시각화**: `fl_chart`를 활용한 월별 레시피 수 및 별점 분포, 원두별 평균 별점 시각화
- **회화 학습 탭**: 일본어 문장/발음 녹음 업로드, 텍스트/음성 댓글 작성 및 재생 기능
- **실시간 푸시 알림**: 새 게시글/레시피 등록 시 백엔드 트리거를 통한 푸시 알림 발송
- **반응형 디자인**: `SafeArea`, `MediaQuery` 적용을 통한 다양한 기기 호환성 확보

### 상태:
- 지속적 유지보수 중 (최근 업데이트: 2025년 9월 16일)

## 주요 기능 상세

### 1. 레시피 관리
- 커피(원두, 블루밍, 추출 단계) 및 요리(재료, 조리법) 레시피 추가, 편집, 삭제.
- 최신 10개 레시피를 카드 형태로 표시하는 홈 화면 UI.

### 2. 데이터 시각화 및 분석
- **통계 탭**: `fl_chart`로 월별 레시피 수(막대 차트)와 별점 분포(파이 차트)를 시각화.
- **메인 화면**: 최근 업데이트된 데이터 분석 기능을 통해 원두별 평균 별점 및 사용 횟수를 직관적으로 제공.

### 3. 회화 학습 탭 (핵심 신규 기능)
- **게시글 작성**: 일본어 문장, 해석, 주의점 및 음성 녹음 (`record` 패키지) 업로드.
- **댓글 기능**: 텍스트 또는 음성 녹음 형태의 댓글 작성 지원.
- **오디오 재생**: `just_audio`를 이용한 게시글 및 댓글 오디오 재생. 단일 플레이어 인스턴스 관리로 리소스 최적화.

### 4. 실시간 푸시 알림 시스템 (핵심 신규 기능)
- **Firebase Cloud Functions**: Firestore의 `onCreate` 이벤트를 감지하여 새로운 레시피, 회화 게시글, 댓글 등록 시 사용자에게 푸시 알림 전송.
- **FCM (Firebase Cloud Messaging)**: 앱이 백그라운드/종료 상태일 때도 알림이 표시되도록 구현.

### 5. 반응형 디자인
- 브라운 테마 기반의 일관된 UI/UX.
- 긴 폼(`SingleChildScrollView`) 및 디바이스 노치/네비게이션바(`SafeArea`)에 대응하는 UI 최적화.

## 기술적 문제와 해결

본 프로젝트를 진행하며 마주쳤던 주요 기술적 난관과 이를 해결한 과정은 다음과 같습니다.

- ### **Firebase Cloud Functions 배포 및 환경 구성 문제 해결**
  - **문제**: Functions 배포 시 `firebase.json` 구조 오류, Node.js 버전 불일치 (`runtime: nodejs18` vs 로컬 `v22.x.x`), `firebase-tools` 경로 문제, 그리고 `TypeError` (잘못된 `functions.firestore.document` 사용) 등 복합적인 오류 발생. 최종적으로 `Failed to create function` 메시지 발생.
  - **해결**:
    - `firebase.json`의 `functions` 설정을 단일 객체 방식으로 정확히 재구성.
    - `nvm`을 활용하여 로컬 Node.js 버전을 `v18.x.x`로 통일하고 `npm install` 및 `firebase-tools` 재설치.
    - Firebase CLI (`firebase login --reauth`) 및 `gcloud auth` 재인증, GCP IAM 권한 (Editor, Cloud Functions Admin), 결제 계정(Blaze Plan) 활성화를 통해 서비스 계정의 배포 권한 확보.
    - Cloud Functions 코드 (`index.js`)의 문법 및 로직 점검.

- ### **오디오 재생 지연 및 런타임 오류 최적화 (`just_audio`)**
  - **문제**: 음성 파일 재생 시 `Connection aborted` 에러, `setState() called after dispose()` 경고, 그리고 `MediaCodec`의 반복적인 초기화로 인한 재생 전 버벅거림(지연 현상) 발생.
  - **해결**:
    - `_PostDetailViewState` 클래스 내에서 `StreamSubscription`을 효과적으로 관리하고, 위젯이 마운트된 상태(`mounted`)에서만 `setState()`를 호출하여 `setState after dispose` 오류 방지.
    - `dispose()` 시점에 모든 `StreamSubscription`을 `cancel()`하여 리소스 누수 방지.
    - `just_audio`의 `AudioPlayer` 인스턴스가 `ProcessingState.completed` 상태에 도달했을 때 `player.stop()` 대신 `player.pause()`와 `player.seek(Duration.zero)`를 사용하여 플레이어 리소스를 해제하지 않고 **"준비된(ready)" 상태로 유지**. 이를 통해 불필요한 `MediaCodec` 재초기화를 줄여 재생 지연을 대폭 개선.
    - `player.setUrl()` 호출 전에 `player.stop()` 및 `player.seek(Duration.zero)`를 호출하여 이전 연결의 잔상을 정리함으로써 `Connection aborted` 오류를 방지.

