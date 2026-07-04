package org.junkbot.game

import android.app.Activity
import android.os.Bundle

// Not verified - see ../../../../../README.md's "target type" gap. Real SDL3 Android apps
// normally extend SDL's own SDLActivity (from libsdl-org/SDL's android-project template, which
// bootstraps SDL_main on a dedicated thread and wires up the GL/Vulkan surface) rather than a
// plain Activity - that template was not vendored here since doing so meaningfully requires
// testing against a real build. Whichever entry point JunkbotSDL3's JNI code ends up exposing
// (see README.md) will need to be called from here, or this should extend SDLActivity instead
// once that's vendored in.
class MainActivity : Activity() {
    companion object {
        init {
            System.loadLibrary("JunkbotSDL3")
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // TODO: call into the native library's actual entry point once ports/Android's
        // Package.swift target-type gap (executable vs. dynamic library + JNI_OnLoad) is
        // resolved - loadLibrary above only maps the .so into the process, it doesn't run
        // anything yet.
    }
}
