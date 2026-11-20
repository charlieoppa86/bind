# release 빌드 R8(코드 축소·난독화) 규칙. build.gradle.kts의 release.proguardFiles에서 읽는다.
# Firebase·Google 로그인 라이브러리는 자체 consumer 규칙을 함께 배포하므로 여기에 따로 적지 않는다.

# Flutter 엔진·플러그인 등록
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }

# Flutter 엔진이 참조하지만 앱에 넣지 않는 Play Core(지연 컴포넌트) 클래스
-dontwarn com.google.android.play.core.**

# flutter_local_notifications: 알림 정보를 Gson으로 저장·복원한다
-keep class com.dexterous.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken
