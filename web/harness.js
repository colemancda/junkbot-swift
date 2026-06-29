/**
 * JavaScript harness for Junkbot Swift Embedded WASM
 *
 * Responsibilities:
 *  - Load and instantiate the WASM binary
 *  - Parse level text files and feed entity data to Swift via exported functions
 *  - Provide the JS drawing/audio functions that Swift imports via @_extern(c)
 *  - Run the game loop at 18fps (matching original Junkbot)
 */

import { init } from './Package/index.js';

const TARGET_FPS = 15; // original game ran at ~15fps in practice on 60Hz displays
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
        resources.junkbotAnimations,
    ] = await Promise.all([
        loadImage("../images/spritesheets/sprites.png"),
        loadJSON("../images/spritesheets/sprites.json"),
        loadImage("../images/spritesheets/Undercover Exclusive/sprites.png"),
        loadJSON("../images/spritesheets/Undercover Exclusive/sprites.json"),
        loadImage("../images/spritesheets/backgrounds.png"),
        loadJSON("../images/spritesheets/backgrounds.json"),
        loadJSON("../junkbot-animations.json"),
    ]);

    // Build name→frame lookup. Gamefroot format: { frames: [[x,y,w,h],...], animations: { name: [idx] } }
    resources.spritesAtlas._lookup = buildAtlasLookup(resources.spritesAtlas);
    resources.spritesUndercoverAtlas._lookup = buildAtlasLookup(resources.spritesUndercoverAtlas);
    resources.backgroundsAtlas._lookup = buildAtlasLookup(resources.backgroundsAtlas);
}

function buildAtlasLookup(atlas) {
    const lookup = {};
    // Gamefroot format: { frames: [[x,y,w,h],...], animations: { name: [frameIdx,...] } }
    if (atlas.animations && Array.isArray(atlas.frames)) {
        for (const [name, indices] of Object.entries(atlas.animations)) {
            const frameIdx = indices[0];
            if (frameIdx != null && atlas.frames[frameIdx]) {
                lookup[name.toLowerCase()] = atlas.frames[frameIdx];
            }
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
let vp = { cx: 0, cy: 0, scale: devicePixelRatio };

// Current level backdrop + decals (parsed from level text, drawn in JS)
let currentBackdrop = "bkg1";
let currentDecals = [];

// Draw a decal/backdrop from the backgrounds atlas at world (x, y), top-left aligned
function drawDecal(x, y, name) {
    const frame = getFrame("backgrounds", name);
    if (!frame) return;
    const [sx, sy, sw, sh] = frame;
    ctx.drawImage(resources.backgrounds, sx, sy, sw, sh, x, y, sw, sh);
}

// Draw the level backdrop and decals (world space; viewport transform already active)
function drawBackdrop() {
    drawDecal(-6, -25, currentBackdrop);
    for (const d of currentDecals) {
        drawDecal(d.x - 30, d.y - 64, d.name);
    }
}

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
// ─────────────────────────────────────────────────────────────────────────────
// Level loading — text parsed in JS, entity data fed to Swift via wasm.add_*
// ─────────────────────────────────────────────────────────────────────────────

const BRICK_COLOR_INDEX = { white: 0, red: 1, green: 2, blue: 3, yellow: 4, gray: 5 };

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

    // [info] → Swift for score/display
    let title = "", hint = "", par = Infinity;
    for (const [k, v] of sections.info || []) {
        if (/^title$/i.test(k)) title = v;
        else if (/^hint$/i.test(k)) hint = v;
        else if (/^par$/i.test(k)) par = Number(v);
    }
    wasm.set_level_info(title, hint, isFinite(par) ? par : -1);

    // [background]
    window.JunkbotRenderer.js_clear_decals();
    window.JunkbotRenderer.js_set_backdrop("bkg1");
    for (const [k, v] of sections.background || []) {
        if (/^backdrop$/i.test(k)) {
            window.JunkbotRenderer.js_set_backdrop(v.trim());
        } else if (/^decals$/i.test(k)) {
            for (const d of v.split(",")) {
                const p = d.split(";");
                if (p.length >= 3)
                    window.JunkbotRenderer.js_add_decal(parseInt(p[0]), parseInt(p[1]), p[2].trim());
            }
        }
    }

    // [playfield]
    let spacing = [15, 18], boundsW = 0, boundsH = 0;
    for (const [k, v] of sections.playfield || []) {
        if (/^spacing$/i.test(k)) spacing = v.split(",").map(Number);
    }
    for (const [k, v] of sections.playfield || []) {
        if (/^size$/i.test(k)) {
            const [cols, rows] = v.split(",").map(Number);
            boundsW = cols * spacing[0]; boundsH = rows * spacing[1];
        }
    }
    wasm.begin_load_level(0, 0, boundsW, boundsH);

    // [partslist]
    if (!sections.partslist) { wasm.finish_load_level(); return; }
    let types = [], colors = [];
    for (const [k, v] of sections.partslist) {
        if (k === "types")  types  = types.concat(v.toLowerCase().split(","));
        else if (k === "colors") colors = colors.concat(v.toLowerCase().split(","));
    }

    const idMap = {};
    let idCounter = 1;
    const resolveID = s => { if (!s) return -1; if (!idMap[s]) idMap[s] = idCounter++; return idMap[s]; };

    for (const [k, v] of sections.partslist) {
        if (k !== "parts") continue;
        for (const def of v.split(",")) {
            const e = def.split(";");
            const x = (parseInt(e[0]) - 1) * spacing[0];
            const y = (parseInt(e[1]) - 1) * spacing[1];
            const typeName  = (types[parseInt(e[2]) - 1]  || "").toLowerCase();
            const colorName = (colors[parseInt(e[3]) - 1] || "red").toLowerCase();
            const animName  = (e[4] || "").toLowerCase();
            const colorIdx  = BRICK_COLOR_INDEX[colorName] ?? 1;
            const facing    = /(_l$|^l$)/.test(animName) ? -1 : 1;
            const facingY   = /_u/.test(animName) ? -1 : /_d/.test(animName) ? 1 : 0;
            const on        = animName === "on" || animName === "none" || animName === "";
            const relID     = e[6] || "";
            const brickMatch = typeName.match(/^brick_(\d+)$/);
            if (brickMatch) {
                wasm.add_brick(x, y, parseInt(brickMatch[1]), colorIdx, colorName === "gray" ? 1 : 0);
            } else if (typeName === "minifig")        { wasm.add_junkbot(x, y - CELL_H * 3, facing, 0);
            } else if (typeName === "haz_walker")     { wasm.add_gearbot(x, y - CELL_H, facing);
            } else if (typeName === "haz_climber")    { wasm.add_climbbot(x, y - CELL_H, facing, facingY);
            } else if (typeName === "haz_dumbfloat")  { wasm.add_flybot(x, y - CELL_H, facing);
            } else if (typeName === "haz_float")      { wasm.add_eyebot(x, y - CELL_H, facing, facingY);
            } else if (typeName === "flag")           { wasm.add_bin(x, y - CELL_H * 2, 0, 0);
            } else if (typeName === "scaredy")        { wasm.add_bin(x, y - CELL_H * 2, facing, 1);
            } else if (typeName === "haz_slickcrate") { wasm.add_crate(x, y - CELL_H);
            } else if (typeName === "haz_slickfire")  { wasm.add_fire(x, y, on ? 1 : 0, resolveID(relID));
            } else if (typeName === "haz_slickfan")   { wasm.add_fan(x, y, on ? 1 : 0, resolveID(relID));
            } else if (typeName === "haz_slicklaser_l") { wasm.add_laser(x, y, 1, on ? 1 : 0, resolveID(relID));
            } else if (typeName === "haz_slicklaser_r") { wasm.add_laser(x, y, -1, on ? 1 : 0, resolveID(relID));
            } else if (typeName === "haz_slickswitch")  { wasm.add_switch(x, y, on ? 1 : 0, resolveID(relID));
            } else if (typeName === "haz_slickteleport"){ wasm.add_teleport(x, y, resolveID(relID));
            } else if (typeName === "haz_slickjump")    { wasm.add_jump(x, y, 1);
            } else if (typeName === "brick_slickjump")  { wasm.add_jump(x, y, 0);
            } else if (typeName === "haz_slickshield")  { wasm.add_shield(x, y, animName === "off" ? 1 : 0, 1);
            } else if (typeName === "brick_slickshield"){ wasm.add_shield(x, y, animName === "off" ? 1 : 0, 0);
            } else if (typeName === "haz_slickpipe")    { wasm.add_pipe(x, y);
            }
        }
    }

    wasm.finish_load_level();
    vp.cx = boundsW / 2;
    vp.cy = boundsH / 2;
}

async function loadLevelText(wasm, path) {
    const text = await loadText(path);
    loadLevelIntoWasm(wasm, text);
}

window.JunkbotRenderer = {
    // Backdrop + decals (set by Swift level loader)
    js_set_backdrop(name) {
        currentBackdrop = name;
    },
    js_clear_decals() {
        currentDecals = [];
    },
    js_add_decal(x, y, name) {
        currentDecals.push({ x, y, name });
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
        // Fill gray in screen space, then restore world transform
        ctx.save();
        ctx.setTransform(1, 0, 0, 1, 0, 0);
        ctx.fillStyle = "#bbb";
        ctx.fillRect(0, 0, canvas.width, canvas.height);
        ctx.restore();
        // Draw level backdrop + decals in world space
        drawBackdrop();
    },
    js_set_viewport(cx, cy, scale) {
        // Canvas backing store is devicePixelRatio-scaled, so fold dpr into the
        // world scale to render sprites at full, crisp size on retina displays.
        vp.cx = cx; vp.cy = cy; vp.scale = scale * devicePixelRatio;
    },

    // All entity sprites are bottom-aligned: the sprite's bottom edge sits at
    // (wy + entityHeight - 1) and the 3D stud overhang extends upward, exactly
    // like the original game's drawImage(... entity.y + entity.height - h - 1 ...).
    js_draw_brick(wx, wy, colorIdx, widthInStuds, fixed) {
        const key = `brick_${fixed ? "immobile" : (BRICK_COLOR_NAMES[colorIdx] || "red")}_${widthInStuds}`;
        const h = spriteH("sprites", key);
        blit("sprites", key, wx, wy + 18 - h - 1);
    },

    js_draw_junkbot(wx, wy, facing, animFrame, flags) {
        const ENTITY_H = 4 * 18; // junkbot logical height
        const armored      = !!(flags & 1);
        const dying        = !!(flags & 2);
        const dyingFromWater = !!(flags & 4);
        const collectingBin = !!(flags & 8);
        const losingShield = !!(flags & 32);
        const gettingShield = !!(flags & 64);

        // Determine animName exactly like the original drawJunkbot
        let animName, animLength = 10;
        if (dyingFromWater) { animName = "water_die"; }
        else if (dying)      { animName = "die"; }
        else if (collectingBin) { animName = "eat_start"; animLength = 17; }
        else if (gettingShield) { animName = `shield_on_${facing > 0 ? "r" : "l"}`; animLength = 11; }
        else { animName = `walk_${facing > 0 ? "r" : "l"}`; }

        if (armored && (!losingShield || (animFrame % 4 < 2))) {
            if (animName === "eat_start") animName = "shield_eat";
            else if (!animName.includes("shield")) animName = `shield_${animName}`;
        }

        // Look up keyframe (with offset) from junkbot-animations.json when available
        const animation = resources.junkbotAnimations[animName];
        let frameName, ox = 0, oy = 0;
        if (animation) {
            animLength = animation.length;
            const kf = animation[animFrame % animLength];
            frameName = kf.sprite;
            ox = kf.offset.x; oy = kf.offset.y;
        } else {
            const t = animFrame % animLength;
            frameName = `minifig_${animName}_${1 + t}`;
        }

        const h = spriteH("sprites", frameName);
        blit("sprites", frameName, wx - ox, wy + ENTITY_H - 1 - h - oy);
    },

    js_draw_gearbot(wx, wy, facing, animFrame) {
        const name = `gearbot_walk_${facing > 0 ? "r" : "l"}_${1 + (animFrame % 2)}`;
        const h = spriteH("sprites", name);
        blit("sprites", name, wx, wy + 2 * 18 - h - 1);
    },

    js_draw_climbbot(wx, wy, facing, facingY, animFrame) {
        let dir = facing > 0 ? "r" : "l";
        if (facingY === -1) dir = "u";
        else if (facingY === 1) dir = "d";
        const name = `climbbot_walk_${dir}_${1 + (animFrame % 6)}`;
        blit("sprites", name, wx, wy - 6); // original: entity.y - 6
    },

    js_draw_flybot(wx, wy, facing, animFrame) {
        const name = `flybot_${1 + (animFrame % 2)}`;
        const h = spriteH("sprites", name);
        blit("sprites", name, wx, wy + 2 * 18 - h - 1);
    },

    js_draw_eyebot(wx, wy, facing, facingY, animFrame, laserOn) {
        const active = facing !== 0 || facingY !== 0;
        const name = `eyebot_${active ? "active_" : ""}${1 + (animFrame % 2)}`;
        const h = spriteH("sprites", name);
        blit("sprites", name, wx, wy + 2 * 18 - h - 1);
    },

    js_draw_bin(wx, wy, facing, scaredy, animFrame) {
        const ENTITY_H = 3 * 18;
        if (scaredy && facing !== 0) {
            const name = `scaredy_walk_${facing > 0 ? "r" : "l"}_${1 + (animFrame % 2)}_s3`;
            const h = spriteH("spritesUndercover", name);
            blit("spritesUndercover", name, wx + 4, wy + ENTITY_H - h - 5);
        } else {
            const h = spriteH("sprites", "bin");
            blit("sprites", "bin", wx + 4, wy + ENTITY_H - h - 5);
        }
    },

    js_draw_crate(wx, wy) {
        const h = spriteH("spritesUndercover", "haz_slickcrate");
        blit("spritesUndercover", "haz_slickcrate", wx, wy + 2 * 18 - h - 1);
    },

    js_draw_fire(wx, wy, on, animFrame) {
        const fi = on ? ((animFrame % 8 < 4) ? animFrame % 4 : 4 - (animFrame % 4)) : 0;
        const name = `haz_slickfire_${on ? "on" : "off"}_${1 + fi}`;
        const h = spriteH("sprites", name);
        blit("sprites", name, wx + 1, wy + 18 - h - 4);
    },

    js_draw_fan(wx, wy, on, animFrame) {
        const name = `haz_slickfan_${on ? "on" : "off"}_${1 + (on ? animFrame % 4 : 0)}`;
        const h = spriteH("sprites", name);
        blit("sprites", name, wx + 1, wy + 18 - h - 4);
    },

    js_draw_switch(wx, wy, on, _animFrame) {
        const name = on ? "haz_slickswitch_on_1" : "haz_slickswitch_off_1";
        const h = spriteH("sprites", name);
        blit("sprites", name, wx, wy + 18 - h - 1);
    },

    js_draw_pipe(wx, wy, _animFrame) {
        // original: entity.x + 11, entity.y - 12
        blit("sprites", "haz_slickpipe_dry_1", wx + 11, wy - 12);
    },

    js_draw_shield(wx, wy, used, fixed) {
        const state = used ? "off" : "on";
        const sheet = fixed ? "sprites" : "spritesUndercover";
        const name = fixed ? `haz_slickshield_${state}` : `brick_slickshield_${state}`;
        const h = spriteH(sheet, name);
        blit(sheet, name, wx, wy + 18 - h - 1);
    },

    js_draw_jump(wx, wy, active, animFrame, fixed) {
        const prefix = fixed ? "haz_slickjump" : "brick_slickjump";
        const name = active ? `${prefix}_active_${1 + (animFrame % 5)}` : `${prefix}_dormant_1`;
        const h = spriteH("sprites", name);
        blit("sprites", name, wx, wy + 18 - h - 1);
    },

    js_draw_teleport(wx, wy, animFrame, blocked) {
        const on = !blocked;
        let name = `haz_slickteleport_${on ? "on" : "off"}_1`;
        // active animation while warping
        if (animFrame % 60 > 30) name = `haz_slickteleport_active_${1 + (animFrame % 2)}`;
        const h = spriteH("spritesUndercover", name);
        blit("spritesUndercover", name, wx, wy + 18 - h - 1);
    },

    js_draw_laser(wx, wy, facing, on) {
        // entity name vs sprite direction is swapped: facing 1 -> "L" sprite
        const name = `haz_slicklaser_${facing > 0 ? "l" : "r"}_on_1`;
        const w = spriteW("spritesUndercover", name);
        const h = spriteH("spritesUndercover", name);
        const ENTITY_W = 2 * 15, ENTITY_H = 18;
        const alpha = on ? 1 : 0.5;
        if (facing < 0) {
            blit("spritesUndercover", name, wx + ENTITY_W - w + 11, wy + ENTITY_H - 1 - h, alpha);
        } else {
            blit("spritesUndercover", name, wx, wy + ENTITY_H - 1 - h, alpha);
        }
    },

    js_draw_droplet(wx, wy, splashing, animFrame) {
        const name = `drip_${splashing ? "splashing" : "falling"}_${1 + (splashing ? animFrame % 5 : 0)}`;
        const ox = splashing ? (-3 - animFrame) : 0;
        const oy = splashing ? -15 : 0;
        blit("sprites", name, wx + 15 + ox, wy + oy);
    },

    js_draw_wind_column(wx, wy, extent, fanAnimFrame) {
        const fi = fanAnimFrame % 7;
        const name = `fanair_1_${1 + fi}`;
        // original: x + 4, y - frameIndex*2 + 8, marching upward by 18 per row
        for (let row = 0; row < extent; row++) {
            blit("sprites", name, wx + 4, (wy - row * 18) - fi * 2 + 8);
        }
    },

    js_draw_laser_beam(wx, wy, facing, extent, _hitWall, animFrame) {
        const ENTITY_W = 2 * 15;
        const name = `laserbeam_1_${1 + (animFrame % 3)}`;
        for (let i = 0; i < extent; i++) {
            const x = wx + (facing === 1 ? ENTITY_W : -15) + 15 * i * facing;
            blit("spritesUndercover", name, x + 4, wy);
        }
    },

    js_draw_teleport_effect(wx, wy, frameIndex) {
        const name = `transefx_${1 + (frameIndex % 3)}`;
        const h = spriteH("spritesUndercover", name);
        blit("spritesUndercover", name, wx + 5, wy - h + 2, 0.5);
    },

    js_set_alpha(alpha) {
        ctx.globalAlpha = alpha;
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
};

// ─────────────────────────────────────────────────────────────────────────────
// Low-level draw helpers that work in world space (inside the viewport transform)
// ─────────────────────────────────────────────────────────────────────────────

function worldPos(wx, wy) {
    // The ctx already has the world transform applied (from js_begin_frame),
    // so we can draw directly at world coordinates.
    return [wx, wy];
}

// Sprite frame dimensions (0 if missing)
function spriteW(sheetKey, name) { const f = getFrame(sheetKey, name); return f ? f[2] : 0; }
function spriteH(sheetKey, name) { const f = getFrame(sheetKey, name); return f ? f[3] : 0; }

// Low-level blit: draw a named sprite at exact destination (dx, dy) in world space.
// (The viewport transform is already applied to ctx during a frame.)
function blit(sheetKey, name, dx, dy, alpha = 1) {
    const frame = getFrame(sheetKey, name);
    if (!frame) {
        ctx.save();
        ctx.globalAlpha = 0.4;
        ctx.fillStyle = "magenta";
        ctx.fillRect(dx, dy, CELL_W * 2, CELL_H);
        ctx.restore();
        return;
    }
    const [sx, sy, sw, sh] = frame;
    const sheet = resources[sheetKey];
    if (!sheet) return;
    if (alpha !== 1) {
        ctx.save();
        ctx.globalAlpha = alpha;
        ctx.drawImage(sheet, sx, sy, sw, sh, dx, dy, sw, sh);
        ctx.restore();
    } else {
        ctx.drawImage(sheet, sx, sy, sw, sh, dx, dy, sw, sh);
    }
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
    await loadResources();
    await initAudio();

    window.onWasmReady = () => {
        const wasm = window.JunkbotWasm;
        setupInput(wasm);

        // Expose level loader to index.html's menu system
        const levelFiles = window.LEVEL_FILES || [];
        const levelByName = Object.fromEntries(levelFiles.map(f => [f.name, f.path]));

        let prevWinLose = 0;
        window._currentMoves = 0;

        window._loadLevelByName = async (name) => {
            const path = levelByName[name];
            if (!path) { console.warn("Level not found:", name); return; }
            prevWinLose = 0;
            window._currentMoves = 0;
            await loadLevelText(wasm, path);
        };

        // Load any level the user clicked before WASM was ready
        if (window._pendingLevel) {
            const pending = window._pendingLevel;
            window._pendingLevel = null;
            window._loadLevelByName(pending);
        }

        // Game loop
        const minInterval = 1000 / TARGET_FPS;
        let lastTime = 0;
        function loop(now) {
            if (now - lastTime >= minInterval) {
                lastTime = now;
                window.JunkbotRenderer.js_begin_frame();
                window.JunkbotRenderer.js_clear_background();
                wasm.game_tick();
                window.JunkbotRenderer.js_end_frame();

                const moves = wasm.get_moves?.() ?? 0;
                if (moves !== window._currentMoves) {
                    window._currentMoves = moves;
                    window.onMovesUpdate?.(moves);
                }
                const winLose = wasm.get_win_lose_state();
                if (winLose !== prevWinLose && winLose !== 0) {
                    prevWinLose = winLose;
                    window.onWinLoseChange?.(winLose, moves);
                }
            }
            requestAnimationFrame(loop);
        }
        requestAnimationFrame(loop);
    };

    try {
        await init();
    } catch (err) {
        console.error("Failed to load WASM:", err);
    }
}

main().catch(console.error);
