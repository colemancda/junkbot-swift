# Junkbot for iOS 9

Junkbot on 32-bit iPhones running iOS 9 (armv7, such as the iPhone 4S), built
with Embedded Swift.

The game is `JunkbotCore` plus the Darwin port's SpriteKit renderer, scene,
menus and game shell, compiled unchanged from
`../Darwin/JunkbotMobile.swiftpm/Sources/JunkbotMobile`. Embedded Swift
targets bare metal (`armv7-apple-none-macho`) and can't import Apple's
frameworks, so this port provides just the API those files use:

- `Sources/Foundation`, `Sources/UIKit` and `Sources/SpriteKit`: Swift modules
  named after the frameworks they stand in for, so the shared files'
  `import SpriteKit` and `#if canImport(UIKit)` work as they do on iOS.
  `UIKit` also has a `MainActor` stand-in, which `GameActor` resolves to.
- `Backend`: Objective-C that does the real work with UIKit, SpriteKit,
  AVFoundation and GameController, through a C interface Embedded Swift can
  call. Only pointers and longs cross it (floats go as bit patterns), since
  bare-metal and iOS armv7 pass other values differently.
- `Sources/Junkbot`: what's specific to this port - the app entry point, audio
  over `AVAudioPlayer`, MFi controller input, and save data in a line-based
  file (Embedded Swift has no `Codable`).

The game has no async code, so it doesn't link the concurrency runtime.

## Controls

Touch, as on the iOS app. With an MFi controller: A grabs and drops bricks or
presses the focused button, the pause button backs out a screen, the d-pad
moves menu focus or nudges a grabbed brick, and the left stick (extended
controllers) moves the cursor.

Controller input hasn't been confirmed on hardware yet: on an iPhone 4S with
iOS 9.3.6, a paired SteelSeries Nimbus never shows up in `GCController` - the
kernel drops its HID reports (`handleReport failed : device is NULL`) before
GameController sees them, so this is between iOS 9 and that controller, not
the game.

## Building

Needs a swift.org toolchain with the `armv7-apple-none-macho` Embedded
standard library (6.4.2 or later) and the iOS 9.3 SDK, since current SDKs no
longer link armv7:

```sh
make sdk SDK_ARCHIVE=/path/to/iPhoneOS9.3.sdk.tar.xz
make
```

The app is signed with a development identity (`SIGN_IDENTITY`, `TEAM_ID`);
AppSync on a jailbroken device accepts it without a provisioning profile.
`make install SSH_HOST=<device>` copies it to `/Applications` over SSH, and
`make ipa` packages `build/Junkbot.ipa`.
