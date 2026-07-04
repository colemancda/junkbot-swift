// `swift-android-native`'s AndroidLooper module only exposes `ALooper_pollOnce`/`pollAll` as
// `internal` (on `Looper.Handle`) at the version this package resolves to, so there's no public
// API to actually drive that library's installed `AndroidMainActor` executor's job queue from
// outside the module - see `ports/Android/Sources/JunkbotAndroid/AndroidMain.swift`'s poll loop,
// which needs to call the raw NDK function directly instead.
#include <android/looper.h>
