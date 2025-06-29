# Recipe Manager
  
이 프로젝트는 핸드드립 레시피와 요리 레시피를 관리하는 Flutter 기반 모바일 애플리케이션입니다. 사용자는 레시피를 추가, 편집, 삭제하고, Firestore를 통해 데이터를 저장하며, 통계 탭에서 데이터 시각화를 통해 레시피 패턴을 분석할 수 있습니다. 지속적인 유지보수와 기능 개선을 통해 개발 기술을 연마하고 있습니다.

[![Recipe Manager Demo](assets/Recording.gif)]


## 프로젝트 개요
### 목표: 
- 커피 러버와 주부를 위한 직관적이고 효율적인 레시피 관리 앱 개발

### 기술 스택:  
- Frontend: Flutter (Dart), fl_chart로 데이터 시각화  
- Backend: Firebase Firestore (실시간 데이터베이스)  
- 기타: GitHub로 버전 관리, Flutter의 릴리스 빌드 및 APK 배포  


### 주요 기능:
- 커피(원두 타입, 블루밍, 추출 단계) 및 요리(재료, 조리법) 레시피 추가/편집
- 최근 레시피 자동 로드 및 Firestore 동기화
- 통계 탭에서 월별 레시피 수와 별점 분포 시각화
- 반응형 UI 및 테마 기반 디자인 (브라운 테마)

### 상태: 
- 지속적 유지보수 중 (최근 업데이트: 2025년 6월 29일)

### 세부사항:
- Flutter 3.22 이상
- Firebase 프로젝트 설정 (Firestore 활성화)
- Android/iOS 에뮬레이터 또는 물리적 디바이스

## 주요 기능
### 1. 레시피 관리

- 레시피 추가/편집: 커피(원두, 블루밍, 추출) 및 요리(재료, 조리법) 레시피를 입력하고 Firestore에 저장
- 최근 레시피 로드: 새 레시피 추가 시 이전 레시피 데이터를 자동으로 채움
- 카드 기반 UI: 홈 화면에서 최신 10개 레시피를 카드 형태로 표시, 탭하여 상세 보기

### 2. 데이터 시각화(개선 중)

- 통계 탭: fl_chart를 사용해 월별 레시피 수(막대 차트)와 별점 분포(파이 차트) 시각화
- 실시간 업데이트: Firestore의 StreamBuilder로 데이터 동기화

### 3. 반응형 디자인

- 브라운 테마 기반 UI로 커피 애호가의 감성 반영
- SingleChildScrollView와 FloatingActionButton으로 스크롤 가능한 긴 폼 처리

## 업데이트 내역
- ### 이 프로젝트는 지속적인 개선을 통해 안정성과 사용자 경험을 향상시키고 있습니다.

- ### 통계 탭 RangeError 수정
  - 문제: 통계 탭에서 뒤로 가기 시 RangeError (length): Invalid value: not in inclusive range 0..1: 2
  - 해결: main.dart의 네비게이션 로직을 단순화하고 _selectedIndex를 _screens 리스트와 동기화
  - 추가: StatisticsScreen에 데이터 검증 추가로 빈 데이터 처리 (ratingDistribution, categoryDistribution)

- ### 레시피 추가 페이지 저장 기능 개선
  - 문제: 저장 버튼의 가시성 부족 및 입력 검증 미흡
  - 해결:
    - RecipeSetupScreen에 FloatingActionButton으로 저장 버튼 추가, 화면 오른쪽 하단 고정
    - 요리 카테고리(cooking)에 ingredients, instructions 필수 입력 검증 추가
    - Firestore 저장 시 에러 핸들링 강화 및 디버깅 로그 추가
    - 편집 모드에서 createdAt, wifeRating, wifeReview 유지

- ### APK 빌드 준비
  - 키스토어 생성 및 서명 설정 추가
  - flutter build apk --release로 배포 가능한 APK 생성

- ### 상세 페이지 버그 수정
  - 문제: RecipeDetailScreen에서 별점 입력 시 차트 표시 및 리다이렉션, 별점 미적용
  - 해결:
    - LineChart와 ratingHistory StreamBuilder 제거, 별점/리뷰 입력 UI로 단순화
    - _updateRatingAndReview에서 double 저장 및 비동기 처리 개선
    - 리다이렉션 방지 위해 네비게이션 로직 점검

- ### 하단 네비게이션 바에 UI 가려짐
  - 문제: 하단 네비게이션 바에 UI가 가려짐
  - 해결: SafeArea와 MediaQuery.padding.bottom으로 동적 패딩 추가

## 기술적 문제와 해결
- ### 네비게이션 오류:
  - 하단 네비게이션 바와 Navigator.push 간 상태 불일치 문제를 clamp과 직접 화면 렌더링으로 해결, Flutter의 상태 관리 이해를 심화.
- ### Firestore 통합:
  - 실시간 데이터 동기화와 데이터 검증을 통해 안정적인 백엔드 통합 구현.
- ### 데이터 시각화:
  - fl_chart를 활용해 소규모 데이터셋(40개 레시피)으로 효율적인 차트 렌더링, 빈 데이터 처리로 사용자 경험 개선.
- ### 영상 삽입:
  - MP4 업로드 실패 문제를 블로그 업로드 후 영상 등록으로 해결, GitHub의 렌더링 제한 우회.
- ### UI 최적화:
  - RecipeDetailScreen에서 차트 제거, SafeArea로 디바이스 UI 호환성 개선.

## 향후 계획
- 이미지 업로드: 레시피에 사진 추가 기능 (Firebase Storage 연동)
- 오프라인 지원: Firestore 오프라인 캐싱 활성화
- Google Play 배포: AAB 빌드 및 Play Console 업로드
