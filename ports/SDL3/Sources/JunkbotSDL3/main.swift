// Desktop executable entry point - all real logic lives in GameMain.swift's `junkbotMain()` so
// ports that must build these sources as a *library* (ports/Android, where SDL's Java side
// loads the game as a shared object and calls its exported `SDL_main`) can exclude this one
// file and share everything else. Library targets can't contain top-level code, which is why
// this file has to stay this small.
junkbotMain()
