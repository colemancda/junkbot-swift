/**
 * JavaScript harness for Junkbot Swift Embedded WASM
 *
 * Responsibilities:
 *  - Load and instantiate the WASM binary
 *  - Parse level text files and feed entity data to Swift via exported functions
 *  - Provide the JS drawing/audio functions that Swift imports via @_extern(c)
 *  - Run the game loop at 18fps (matching original Junkbot)
 */

const TARGET_FPS = 18;
const CELL_W = 15;
const CELL_H = 18;

// ─────────────────────────────────────────────────────────────────────────────
// Asset loading
// ─────────────────────────────────────────────────────────────────────────────

const resources = {};

async function loadImage(src) {
    return new Promise((resolve, reject) => {
        const img = new Image();
        img.onload = () => resolve(img);
        img.onerror = () => reject(new Error(`Failed to load image: ${src}`));
        img.src = src;
    });
}

async function loadJSON(src) {
    const res = await fetch(src);
    return res.json();
}

async function loadText(src) {
    const res = await fetch(src);
    return res.text();
}

async function loadResources() {
    [
        resources.sprites,
        resources.spritesAtlas,
        resources.spritesUndercover,
        resources.spritesUndercoverAtlas,
        resources.backgrounds,
        resources.backgroundsAtlas,
    ] = await Promise.all([
        loadImage("../images/spritesheets/sprites.png"),
        loadJSON("../images/spritesheets/sprites.json"),
        loadImage("../images/spritesheets/Undercover Exclusive/sprites.png"),
        loadJSON("../images/spritesheets/Undercover Exclusive/sprites.json"),
        loadImage("../images/spritesheets/backgrounds.png"),
        loadJSON("../images/spritesheets/backgrounds.json"),
    ]);

    // Build name→bounds lookup from atlas JSON
    // The JSON format is: { frames: [[x,y,w,h], ...], frames_by_name: {"name": index, ...} }
    // or the gamefroot format: { images: [...], frames: [[x,y,w,h],...], ...}
    // We'll handle both formats.
    resources.spritesAtlas._lookup = buildAtlasLookup(resources.spritesAtlas);
    resources.spritesUndercoverAtlas._lookup = buildAtlasLookup(resources.spritesUndercoverAtlas);
    resources.backgroundsAtlas._lookup = buildAtlasLookup(resources.backgroundsAtlas);
}

function buildAtlasLookup(atlas) {
    const lookup = {};
    if (atlas.frames_by_name) {
        for (const [name, idx] of Object.entries(atlas.frames_by_name)) {
            lookup[name] = atlas.frames[idx];
        }
    } else if (Array.isArray(atlas.frames)) {
        // Gamefroot format: frames is array of [x,y,w,h], names come from elsewhere
        // In this project the atlas JSON from gamefroot has a separate names array
        const names = atlas.names || [];
        for (let i = 0; i < names.length; i++) {
            lookup[names[i].toLowerCase()] = atlas.frames[i];
        }
    }
    return lookup;
}

function getFrame(atlasKey, name) {
    const atlas = resources[atlasKey + 'Atlas'];
    if (!atlas) return null;
    return atlas._lookup[name] || atlas._lookup[name.toLowerCase()] || null;
}

// ─────────────────────────────────────────────────────────────────────────────
// Canvas setup
// ─────────────────────────────────────────────────────────────────────────────

const canvas = document.getElementById("game-canvas");
const ctx = canvas.getContext("2d");
ctx.imageSmoothingEnabled = false;

function resizeCanvas() {
    canvas.width  = canvas.clientWidth  * devicePixelRatio;
    canvas.height = canvas.clientHeight * devicePixelRatio;
}
window.addEventListener("resize", resizeCanvas);
resizeCanvas();

// Viewport state (updated by js_set_viewport called from Swift)
let vp = { cx: 0, cy: 0, scale: 1 };

function worldToScreen(wx, wy) {
    return [
        Math.floor(canvas.width  / 2 + (wx - vp.cx) * vp.scale),
        Math.floor(canvas.height / 2 + (wy - vp.cy) * vp.scale),
    ];
}

function screenToWorld(sx, sy) {
    return [
        Math.round((sx - canvas.width  / 2) / vp.scale + vp.cx),
        Math.round((sy - canvas.height / 2) / vp.scale + vp.cy),
    ];
}

// ─────────────────────────────────────────────────────────────────────────────
// Drawing helpers
// ─────────────────────────────────────────────────────────────────────────────

const BRICK_COLOR_NAMES = ["white", "red", "green", "blue", "yellow", "gray"];

function drawSprite(image, atlasKey, frameName, wx, wy, flipX = false, alpha = 1) {
    const frame = getFrame(atlasKey, frameName);
    if (!frame) { return; }
    const [sx, sy, sw, sh] = frame;
    const [dx, dy] = worldToScreen(wx, wy);
    const dw = sw * vp.scale;
    const dh = sh * vp.scale;
    ctx.save();
    ctx.globalAlpha = alpha;
    if (flipX) {
        ctx.scale(-1, 1);
        ctx.drawImage(image, sx, sy, sw, sh, -(dx + dw), dy, dw, dh);
    } else {
        ctx.drawImage(image, sx, sy, sw, sh, dx, dy, dw, dh);
    }
    ctx.restore();
}

// ─────────────────────────────────────────────────────────────────────────────
// Audio
// ─────────────────────────────────────────────────────────────────────────────

const SOUND_PATHS = [
    /* 0  turn        */ "../audio/sound-effects/turn1.ogg",
    /* 1  blockPickUp */ "../audio/sound-effects/blockpickup.ogg",
    /* 2  blockDrop   */ "../audio/sound-effects/blockdrop.ogg",
    /* 3  blockClick  */ "../audio/sound-effects/blockclick.ogg",
    /* 4  fall        */ "../audio/sound-effects/fall.ogg",
    /* 5  headBonk    */ "../audio/sound-effects/headbonk1.ogg",
    /* 6  collectBin  */ "../audio/sound-effects/eat1.ogg",
    /* 7  collectBin2 */ "../audio/sound-effects/garbage1.ogg",
    /* 8  switchClick */ "../audio/sound-effects/switch_click.ogg",
    /* 9  switchOn    */ "../audio/sound-effects/switch_on.ogg",
    /* 10 switchOff   */ "../audio/sound-effects/switch_off.ogg",
    /* 11 deathByFire */ "../audio/sound-effects/fire.ogg",
    /* 12 deathByWater*/ "../audio/sound-effects/electricity1.ogg",
    /* 13 deathByLaser*/ "../audio/sound-effects/undercover/laser_hit.wav",
    /* 14 deathByBot  */ "../audio/sound-effects/robottouch4.ogg",
    /* 15 getShield   */ "../audio/sound-effects/shieldon2.ogg",
    /* 16 getPowerup  */ "../audio/sound-effects/h_powerup1.ogg",
    /* 17 losePowerup */ "../audio/sound-effects/h_powerdown3.ogg",
    /* 18 teleport    */ "../audio/sound-effects/undercover/teleport.wav",
    /* 19 ohYeah      */ "../audio/sound-effects/voice_ohyeah.ogg",
    /* 20 ouch        */ "../audio/sound-effects/voice_ouch.ogg",
    /* 21 uhoh        */ "../audio/sound-effects/voice_uhoh.ogg",
    /* 22 jump        */ "../audio/sound-effects/jump3.ogg",
    /* 23 fan         */ "../audio/sound-effects/fan.ogg",
    /* 24 drip0       */ "../audio/sound-effects/drip1.ogg",
    /* 25 drip1       */ "../audio/sound-effects/drip2.ogg",
    /* 26 drip2       */ "../audio/sound-effects/drip3.ogg",
    /* 27 undo        */ "../audio/sound-effects/lego-creator/undo-I0512.wav",
];

const audioBuffers = [];
let audioCtx = null;

async function initAudio() {
    audioCtx = new (window.AudioContext || window.webkitAudioContext)();
    const loads = SOUND_PATHS.map(async (path, i) => {
        try {
            const res = await fetch(path);
            const buf = await res.arrayBuffer();
            audioBuffers[i] = await audioCtx.decodeAudioData(buf);
        } catch (_) {
            audioBuffers[i] = null;
        }
    });
    await Promise.all(loads);
}

function playSound(index) {
    if (!audioCtx || !audioBuffers[index]) return;
    const src = audioCtx.createBufferSource();
    src.buffer = audioBuffers[index];
    src.connect(audioCtx.destination);
    src.start();
}

// ─────────────────────────────────────────────────────────────────────────────
// Level parsing (mirrors JS loadLevelFromText)
// ─────────────────────────────────────────────────────────────────────────────

const BRICK_COLOR_INDEX = { white: 0, red: 1, green: 2, blue: 3, yellow: 4, gray: 5 };
let teleportIDCounter = 1;
const teleportIDMap = {}; // string key → numeric ID

function parseTeleportID(str) {
    if (!str) return -1;
    if (!teleportIDMap[str]) teleportIDMap[str] = teleportIDCounter++;
    return teleportIDMap[str];
}

function parseSwitchID(str) {
    if (!str) return -1;
    if (!teleportIDMap[str]) teleportIDMap[str] = teleportIDCounter++;
    return teleportIDMap[str];
}

function loadLevelIntoWasm(wasm, levelText) {
    const sections = {};
    let section = "";
    for (const line of levelText.split(/\r?\n/)) {
        if (/^\s*(#.*)?$/.test(line)) continue;
        const m = line.match(/^\[(.*)\]$/);
        if (m) { section = m[1]; continue; }
        sections[section] = sections[section] || [];
        const eqIdx = line.indexOf("=");
        sections[section].push([line.slice(0, eqIdx), line.slice(eqIdx + 1)]);
    }

    let spacing = [15, 18];
    let boundsW = 0, boundsH = 0;
    if (sections.playfield) {
        for (const [k, v] of sections.playfield) {
            if (/^spacing$/i.test(k)) spacing = v.split(",").map(Number);
        }
        for (const [k, v] of sections.playfield) {
            if (/^size$/i.test(k)) {
                const [cols, rows] = v.split(",").map(Number);
                boundsW = cols * spacing[0];
                boundsH = rows * spacing[1];
            }
        }
    }

    wasm.begin_load_level(0, 0, boundsW, boundsH);

    if (!sections.partslist) return;
    let types = [], colors = [];
    for (const [k, v] of sections.partslist) {
        if (k === "types") types = types.concat(v.toLowerCase().split(","));
        else if (k === "colors") colors = colors.concat(v.toLowerCase().split(","));
    }

    for (const [k, v] of sections.partslist) {
        if (k !== "parts") continue;
        for (const def of v.split(",")) {
            const e = def.split(";");
            const gx = parseInt(e[0]) - 1;
            const gy = parseInt(e[1]) - 1;
            const x = gx * spacing[0];
            const y = gy * spacing[1];
            const typeName = (types[parseInt(e[2]) - 1] || "").toLowerCase();
            const colorName = (colors[parseInt(e[3]) - 1] || "red").toLowerCase();
            const animName = (e[4] || "").toLowerCase();
            const colorIdx = BRICK_COLOR_INDEX[colorName] ?? 1;
            const facing = /(_l$|^l$)/.test(animName) ? -1 : 1;
            let facingY = 0;
            if (/_u/.test(animName)) facingY = -1;
            else if (/_d/.test(animName)) facingY = 1;
            const on = animName === "on" || animName === "none" || animName === "";
            const relID = e[6] || "";

            const brickMatch = typeName.match(/^brick_(\d+)$/);
            if (brickMatch) {
                const w = parseInt(brickMatch[1]);
                const isFixed = colorName === "gray";
                wasm.add_brick(x, y, w, colorIdx, isFixed ? 1 : 0);
            } else if (typeName === "minifig") {
                wasm.add_junkbot(x, y - CELL_H * 3, facing, 0);
            } else if (typeName === "haz_walker") {
                wasm.add_gearbot(x, y - CELL_H, facing);
            } else if (typeName === "haz_climber") {
                wasm.add_climbbot(x, y - CELL_H, facing, facingY);
            } else if (typeName === "haz_dumbfloat") {
                wasm.add_flybot(x, y - CELL_H, facing);
            } else if (typeName === "haz_float") {
                wasm.add_eyebot(x, y - CELL_H, facing, facingY);
            } else if (typeName === "flag") {
                wasm.add_bin(x, y - CELL_H * 2, 0, 0);
            } else if (typeName === "scaredy") {
                wasm.add_bin(x, y - CELL_H * 2, facing, 1);
            } else if (typeName === "haz_slickcrate") {
                wasm.add_crate(x, y - CELL_H);
            } else if (typeName === "haz_slickfire") {
                wasm.add_fire(x, y, on ? 1 : 0, parseSwitchID(relID));
            } else if (typeName === "haz_slickfan") {
                wasm.add_fan(x, y, on ? 1 : 0, parseSwitchID(relID));
            } else if (typeName === "haz_slicklaser_l") {
                // haz_slicklaser_l points RIGHT
                wasm.add_laser(x, y, 1, on ? 1 : 0, parseSwitchID(relID));
            } else if (typeName === "haz_slicklaser_r") {
                // haz_slicklaser_r points LEFT
                wasm.add_laser(x, y, -1, on ? 1 : 0, parseSwitchID(relID));
            } else if (typeName === "haz_slickswitch") {
                wasm.add_switch(x, y, on ? 1 : 0, parseSwitchID(relID));
            } else if (typeName === "haz_slickteleport") {
                wasm.add_teleport(x, y, parseTeleportID(relID));
            } else if (typeName === "haz_slickjump") {
                wasm.add_jump(x, y, 1);
            } else if (typeName === "brick_slickjump") {
                wasm.add_jump(x, y, 0);
            } else if (typeName === "haz_slickshield") {
                wasm.add_shield(x, y, animName === "off" ? 1 : 0, 1);
            } else if (typeName === "brick_slickshield") {
                wasm.add_shield(x, y, animName === "off" ? 1 : 0, 0);
            } else if (typeName === "haz_slickpipe") {
                wasm.add_pipe(x, y);
            }
        }
    }

    wasm.finish_load_level();
}

// ─────────────────────────────────────────────────────────────────────────────
// WASM import object — Swift @_extern(c) calls map to these
// ─────────────────────────────────────────────────────────────────────────────

// Shared linear memory — Swift Embedded WASM imports this from env.memory
const wasmMemory = new WebAssembly.Memory({ initial: 256, maximum: 1024 });

function makeImports() {
    return {
        env: {
            memory: wasmMemory,
            __stack_chk_fail() { throw new Error("Swift: stack overflow"); },

            // Simple bump allocator for Swift runtime alloc needs
            posix_memalign(ptrOut, alignment, size) {
                const mem = new Uint8Array(wasmMemory.buffer);
                // Keep a heap pointer after the 64 KB stack region
                if (!wasmMemory._heapPtr) wasmMemory._heapPtr = 65536;
                const align = Math.max(alignment, 8);
                wasmMemory._heapPtr = (wasmMemory._heapPtr + align - 1) & ~(align - 1);
                const ptr = wasmMemory._heapPtr;
                wasmMemory._heapPtr += size;
                // Write the pointer into *ptrOut (little-endian i32)
                new DataView(wasmMemory.buffer).setUint32(ptrOut, ptr, true);
                return 0; // success
            },
            free(_ptr) { /* bump allocator — no-op free */ },
            arc4random_buf(ptr, len) {
                const buf = new Uint8Array(wasmMemory.buffer, ptr, len);
                crypto.getRandomValues(buf);
            },
            // Rendering
            js_begin_frame() {
                ctx.save();
                ctx.translate(Math.floor(canvas.width / 2), Math.floor(canvas.height / 2));
                ctx.scale(vp.scale, vp.scale);
                ctx.translate(-Math.floor(vp.cx), -Math.floor(vp.cy));
                ctx.imageSmoothingEnabled = false;
            },
            js_end_frame() {
                ctx.restore();
            },
            js_clear_background() {
                ctx.save();
                ctx.setTransform(1, 0, 0, 1, 0, 0);
                ctx.fillStyle = "#bbb";
                ctx.fillRect(0, 0, canvas.width, canvas.height);
                ctx.restore();
            },
            js_set_viewport(cx, cy, scale) {
                vp.cx = cx; vp.cy = cy; vp.scale = scale;
            },

            js_draw_brick(wx, wy, colorIdx, widthInStuds, fixed) {
                const colorName = fixed ? "immobile" : (BRICK_COLOR_NAMES[colorIdx] || "gray");
                if (colorName === "gray") {
                    // fixed gray bricks use "immobile" sprite name
                }
                const key = `brick_${fixed ? "immobile" : (BRICK_COLOR_NAMES[colorIdx] || "red")}_${widthInStuds}`;
                drawSpriteWorld("sprites", key, wx, wy);
            },

            js_draw_junkbot(wx, wy, facing, animFrame, flags) {
                const armored      = !!(flags & 1);
                const dying        = !!(flags & 2);
                const dyingFromWater = !!(flags & 4);
                const collectingBin = !!(flags & 8);
                const floating     = !!(flags & 16);
                const losingShield = !!(flags & 32);
                const gettingShield = !!(flags & 64);

                let animName;
                if (dying) {
                    const t = Math.floor(animFrame % 10);
                    animName = dyingFromWater ? `minifig_dead_water_${1 + t}` : `minifig_dead_${1 + t}`;
                } else if (collectingBin) {
                    const t = Math.floor(animFrame % 17);
                    animName = `minifig_bin_${1 + t}`;
                } else if (floating) {
                    animName = `minifig_float_${1 + (animFrame % 4)}`;
                } else if (gettingShield) {
                    animName = `minifig_shield_${1 + (animFrame % 11)}`;
                } else {
                    const t = (Math.floor(animFrame / 5)) % 4;
                    animName = facing > 0
                        ? `minifig_walk_r_${1 + t}`
                        : `minifig_walk_l_${1 + t}`;
                }
                drawSpriteWorld("sprites", animName, wx, wy);
                if (armored || losingShield) {
                    // Draw shield overlay — flash when losing
                    const alpha = losingShield ? (Math.floor(animFrame / 2) % 2 === 0 ? 0.5 : 0) : 1;
                    const shieldFrame = `minifig_shield_overlay`;
                    drawSpriteWorldAlpha("sprites", shieldFrame, wx, wy, alpha);
                }
            },

            js_draw_gearbot(wx, wy, facing, animFrame) {
                const t = Math.floor(animFrame % 3);
                const dir = facing > 0 ? "r" : "l";
                drawSpriteWorld("sprites", `haz_walker_walk_${dir}_${1 + t}`, wx, wy);
            },

            js_draw_climbbot(wx, wy, facing, facingY, animFrame) {
                const t = Math.floor(animFrame % 7);
                const dir = facing > 0 ? "r" : "l";
                drawSpriteWorld("sprites", `haz_climber_walk_${dir}_${1 + t}`, wx, wy);
            },

            js_draw_flybot(wx, wy, facing, animFrame) {
                const t = Math.floor(animFrame % 4);
                const dir = facing > 0 ? "r" : "l";
                drawSpriteWorld("spritesUndercover", `haz_dumbfloat_${dir}_${1 + t}`, wx, wy);
            },

            js_draw_eyebot(wx, wy, facing, facingY, animFrame, laserOn) {
                const t = Math.floor(animFrame % 4);
                const active = Math.abs(facing) > 0 || facingY !== 0;
                const prefix = active ? "eyebot_active" : "eyebot_inactive";
                drawSpriteWorld("sprites", `${prefix}_${1 + t}`, wx, wy);
            },

            js_draw_bin(wx, wy, facing, scaredy, animFrame) {
                if (scaredy && facing !== 0) {
                    const t = Math.floor(animFrame % 2);
                    const dir = facing > 0 ? "r" : "l";
                    drawSpriteWorld("spritesUndercover",
                        `scaredy_walk_${dir}_${1 + t}`, wx, wy);
                } else {
                    drawSpriteWorld("sprites", "bin", wx, wy);
                }
            },

            js_draw_crate(wx, wy) {
                drawSpriteWorld("spritesUndercover", "haz_slickcrate_norm", wx, wy);
            },

            js_draw_fire(wx, wy, on, animFrame) {
                const state = on ? "on" : "off";
                const t = on ? (Math.floor(animFrame % 8 < 4 ? animFrame % 4 : 4 - animFrame % 4)) : 0;
                drawSpriteWorld("sprites", `haz_slickfire_${state}_${1 + t}`, wx, wy);
            },

            js_draw_fan(wx, wy, on, animFrame) {
                const state = on ? "on" : "off";
                const t = on ? Math.floor(animFrame % 4) : 0;
                drawSpriteWorld("sprites", `haz_slickfan_${state}_${1 + t}`, wx, wy);
            },

            js_draw_switch(wx, wy, on, animFrame) {
                const state = on ? "on" : "off";
                drawSpriteWorld("sprites", `haz_slickswitch_${state}_1`, wx, wy);
            },

            js_draw_pipe(wx, wy, animFrame) {
                drawSpriteWorld("sprites", "haz_slickpipe_dry_1", wx, wy);
            },

            js_draw_shield(wx, wy, used, fixed) {
                const prefix = fixed ? "haz" : "brick";
                const state = used ? "off" : "on";
                drawSpriteWorld("sprites", `${prefix}_slickshield_${state}_1`, wx, wy);
            },

            js_draw_jump(wx, wy, active, animFrame, fixed) {
                const prefix = fixed ? "haz" : "brick";
                const animName = active
                    ? `${prefix}_slickjump_active_${1 + Math.floor(animFrame % 5)}`
                    : `${prefix}_slickjump_dormant_1`;
                drawSpriteWorld("sprites", animName, wx, wy);
            },

            js_draw_teleport(wx, wy, animFrame, blocked) {
                const t = Math.floor(animFrame % 4);
                drawSpriteWorld("spritesUndercover", `haz_slickteleport_on_${1 + t}`, wx, wy);
                if (blocked) {
                    ctx.save();
                    const [sx, sy] = worldPos(wx, wy);
                    ctx.fillStyle = "rgba(255,0,0,0.3)";
                    ctx.fillRect(sx, sy, CELL_W * 4 * vp.scale, CELL_H * 2 * vp.scale);
                    ctx.restore();
                }
            },

            js_draw_laser(wx, wy, facing, on) {
                const dir = facing > 0 ? "l" : "r"; // sprite naming is reversed vs direction
                const state = on ? "on" : "off";
                drawSpriteWorld("spritesUndercover", `haz_slicklaser_${dir}_${state}_1`, wx, wy);
            },

            js_draw_droplet(wx, wy, splashing, animFrame) {
                if (splashing) {
                    const t = Math.floor(animFrame % 5);
                    drawSpriteWorld("sprites", `droplet_splash_${1 + t}`, wx, wy);
                } else {
                    drawSpriteWorld("sprites", "droplet_1", wx, wy);
                }
            },

            js_draw_wind_column(wx, wy, extent, fanAnimFrame) {
                for (let row = 0; row < extent; row++) {
                    const t = Math.floor(fanAnimFrame % 7);
                    drawSpriteWorld("sprites", `fanair_1_${1 + t}`, wx, wy - row * CELL_H);
                }
            },

            js_draw_laser_beam(wx, wy, facing, extent, hitWall, animFrame) {
                for (let i = 0; i < extent; i++) {
                    const bx = wx + (facing > 0 ? CELL_W * 2 : -CELL_W) + CELL_W * i * facing;
                    const t = Math.floor(animFrame % 3);
                    drawSpriteWorld("spritesUndercover", `laserbeam_1_${1 + t}`, bx, wy);
                }
            },

            js_draw_teleport_effect(wx, wy, frameIndex) {
                drawSpriteWorldAlpha("spritesUndercover", `transefx_${1 + frameIndex}`, wx, wy, 0.5);
            },

            js_draw_debug_rect(wx, wy, ww, wh) {
                const [sx, sy] = worldPos(wx, wy);
                ctx.strokeStyle = "rgba(255,0,0,0.7)";
                ctx.strokeRect(sx, sy, ww * vp.scale, wh * vp.scale);
            },

            // Audio
            js_play_sound(index) {
                playSound(index);
            },

            // Win / Lose
            js_on_win() {
                document.getElementById("overlay-message").textContent = "🎉 You Win!";
                document.getElementById("overlay").style.display = "flex";
            },
            js_on_lose() {
                document.getElementById("overlay-message").textContent = "💀 Junkbot Died";
                document.getElementById("overlay").style.display = "flex";
            },
        },
    };
}

// ─────────────────────────────────────────────────────────────────────────────
// Low-level draw helpers that work in world space (inside the viewport transform)
// ─────────────────────────────────────────────────────────────────────────────

function worldPos(wx, wy) {
    // The ctx already has the world transform applied (from js_begin_frame),
    // so we can draw directly at world coordinates.
    return [wx, wy];
}

function drawSpriteWorld(sheetKey, frameName, wx, wy) {
    drawSpriteWorldAlpha(sheetKey, frameName, wx, wy, 1);
}

function drawSpriteWorldAlpha(sheetKey, frameName, wx, wy, alpha) {
    const atlas = sheetKey + "Atlas";
    const frame = getFrame(sheetKey, frameName);
    if (!frame) {
        // Draw placeholder rectangle
        ctx.save();
        ctx.globalAlpha = alpha * 0.5;
        ctx.fillStyle = "magenta";
        ctx.fillRect(wx, wy, CELL_W * 2, CELL_H * 2);
        ctx.restore();
        return;
    }
    const [sx, sy, sw, sh] = frame;
    const sheet = resources[sheetKey];
    if (!sheet) return;
    ctx.save();
    ctx.globalAlpha = alpha;
    ctx.drawImage(sheet, sx, sy, sw, sh, wx, wy, sw, sh);
    ctx.restore();
}

// ─────────────────────────────────────────────────────────────────────────────
// Input
// ─────────────────────────────────────────────────────────────────────────────

function canvasEventToWorld(event) {
    const rect = canvas.getBoundingClientRect();
    const px = (event.clientX - rect.left) * devicePixelRatio;
    const py = (event.clientY - rect.top)  * devicePixelRatio;
    const wx = Math.round((px - canvas.width  / 2) / vp.scale + vp.cx);
    const wy = Math.round((py - canvas.height / 2) / vp.scale + vp.cy);
    return [wx, wy];
}

function setupInput(wasmExports) {
    canvas.addEventListener("pointerdown", (e) => {
        e.preventDefault();
        if (audioCtx && audioCtx.state === "suspended") audioCtx.resume();
        const [wx, wy] = canvasEventToWorld(e);
        wasmExports.mouse_down(wx, wy);
    });
    canvas.addEventListener("pointermove", (e) => {
        const [wx, wy] = canvasEventToWorld(e);
        wasmExports.mouse_move(wx, wy);
    });
    canvas.addEventListener("pointerup", (e) => {
        const [wx, wy] = canvasEventToWorld(e);
        wasmExports.mouse_up(wx, wy);
    });
    canvas.addEventListener("pointercancel", () => {
        wasmExports.mouse_up(0, 0);
    });
}

// ─────────────────────────────────────────────────────────────────────────────
// Main entry point
// ─────────────────────────────────────────────────────────────────────────────

async function main() {
    document.getElementById("status").textContent = "Loading assets…";
    await loadResources();
    await initAudio();

    document.getElementById("status").textContent = "Loading WASM…";
    let wasmInstance;
    try {
        const result = await WebAssembly.instantiateStreaming(
            fetch("junkbot.wasm"),
            makeImports()
        );
        wasmInstance = result.instance;
    } catch (err) {
        document.getElementById("status").textContent = "Failed to load WASM: " + err;
        return;
    }

    const wasm = wasmInstance.exports;
    wasm.game_init();

    // Seed RNG with current time
    wasm.set_rng_seed(Date.now() & 0xFFFFFFFF);

    setupInput(wasm);

    // Populate level list
    const levelListEl = document.getElementById("level-list");
    const levelFiles = window.LEVEL_FILES || [];
    for (const file of levelFiles) {
        const li = document.createElement("li");
        const btn = document.createElement("button");
        btn.textContent = file.name;
        btn.onclick = async () => {
            document.getElementById("overlay").style.display = "none";
            document.getElementById("status").textContent = "Loading level…";
            const text = await loadText(file.path);
            loadLevelIntoWasm(wasm, text);
            document.getElementById("status").textContent = "";
        };
        li.append(btn);
        levelListEl.append(li);
    }

    // Start with the first level if available
    if (levelFiles.length > 0) {
        const text = await loadText(levelFiles[0].path);
        loadLevelIntoWasm(wasm, text);
    }

    document.getElementById("status").textContent = "";

    // Game loop at TARGET_FPS
    const frameDuration = 1000 / TARGET_FPS;
    let lastTime = 0;
    function loop(timestamp) {
        if (timestamp - lastTime >= frameDuration) {
            lastTime = timestamp;
            wasm.game_tick();
        }
        requestAnimationFrame(loop);
    }
    requestAnimationFrame(loop);
}

main().catch(console.error);
