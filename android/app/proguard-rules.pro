# Keep generic type info
-keepattributes Signature

# Keep Gson classes
-keep class com.google.gson.** { *; }
-dontwarn com.google.gson.**

# Keep TypeToken
-keep class com.google.gson.reflect.TypeToken { *; }

# Keep flutter local notifications plugin models
-keep class com.dexterous.flutterlocalnotifications.** { *; }
