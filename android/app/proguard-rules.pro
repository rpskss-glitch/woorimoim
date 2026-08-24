# 앱 크기를 줄이려고 안 쓰는 코드를 지우는데, 아래 것들은 지우면 안 된다.
# (지워지면 앱이 켜지자마자 또는 알림이 올 때 조용히 죽는다)

# Flutter 엔진
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase — 이름으로 찾아 쓰는 부분이 있어 이름이 바뀌면 못 찾는다
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**

# Firestore가 주고받는 값을 담는 그릇들
-keepclassmembers class * {
  @com.google.firebase.firestore.PropertyName <fields>;
}

# 알림 패키지가 예약 알림을 되살릴 때 이름으로 찾는다
-keep class com.dexterous.** { *; }
-dontwarn com.dexterous.**

# 옛 안드로이드 지원용 라이브러리 (경고만 나오고 실제로는 안 쓰임)
-dontwarn java.lang.invoke.**
-dontwarn javax.annotation.**

# 앱을 쪼개서 나중에 내려받는 기능(Play Feature Delivery)은 쓰지 않는다.
# Flutter 엔진 안에 그 기능을 부르는 코드가 남아 있어 R8이 "클래스가 없다"며 멈추므로 무시시킨다.
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**
