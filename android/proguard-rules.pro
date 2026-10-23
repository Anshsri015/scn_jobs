# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-dontwarn io.flutter.embedding.**

# go_router / navigation — keep route argument classes from being stripped
-keepclassmembers class * {
    public <init>(...);
}

# Keep annotations used by json_serializable-generated code (added when
# freezed/json_serializable models land on Day 4).
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses

# Play Core deferred components (referenced by Flutter engine even when
# split-install isn't used) — silence known false-positive warnings.
-dontwarn com.google.android.play.core.**

# WHY THIS FILE
# R8/Proguard rules for release builds so minification (enabled in
# build.gradle) doesn't strip classes that Flutter's engine, plugins, or
# reflection-based JSON (de)serialization rely on at runtime.
# Alternative considered: disabling minifyEnabled entirely to sidestep
# proguard authoring. Rejected — that blows past the 30MB AAB target in
# Section 15 of the plan and Day 33's performance budget.
# Pitfall a junior would hit: shipping a release build that crashes only
# in release (works fine in debug) because a model's JSON factory
# constructor got stripped — always test `flutter build appbundle --release`
# manually, not just debug runs.
