# 保留 Gson 反射与模型类的字段名
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.cczu.cczukit.** { *; }
-keep class com.google.gson.** { *; }

# OkHttp
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
