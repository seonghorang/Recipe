# Flutter 기본 규칙
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**

# Firebase 규칙
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# FCM 메시지 처리
-keep class com.google.firebase.messaging.** { *; }
-dontwarn com.google.firebase.messaging.**

# Firestore
-keep class com.google.firebase.firestore.** { *; }
-dontwarn com.google.firebase.firestore.**