---
name: web-3d-vr-experience
description: >-
  Implements browser-based 3D + VR experiences in the Bear 71 VR / NFB × Jam3
  technical pattern: Three.js WebGL scene, stereo VR via WebXR (WebVR legacy),
  polyfill fallbacks, multi-input (desktop / mobile360 / Cardboard / HMD),
  data-driven world JSON, sprite/point landscapes, and synced documentary AV.
  Use when building WebXR/WebVR immersive docs, 3D grid worlds in the browser,
  Cardboard/Daydream-style web VR, or projects like Bear 71 VR.
  Only load when sop-orchestrator instructs.
disable-model-invocation: true
---

# Web 3D + VR Experience

## SOP adapter

Loaded only by `sop-orchestrator` when the UI stage needs WebXR/Three.js runtime (not ordinary product UI).

Technical playbook for immersive browser experiences modeled on [Bear 71 VR](https://bear71vr.nfb.ca/) (NFB × Jam3): **one URL → desktop 3D, mobile 360, and headset VR**, without native app install.

This skill is about **architecture and runtime**, not visual branding. Do not spend tokens recreating the Bear 71 look unless the user also asks for design.

## Reference stack (observed)

| Layer | Bear 71 (2017-era) | Build today |
|-------|--------------------|-------------|
| 3D engine | Three.js **r81** + `WebGLRenderer` | Three.js current + `WebGLRenderer` (or WebGPURenderer if targeting modern only) |
| VR I/O | **WebVR** + `webvr-polyfill`, `THREE.VRControls` / `THREE.VREffect` / `StereoCamera` | **WebXR Device API** (`navigator.xr`) via `THREE.WebXRManager` / `renderer.xr` |
| Fallback | Polyfill stereo + gyro when native VR absent (`FORCE_ENABLE_VR`, Cardboard DPDB) | `@immersive-web/webxr-polyfill` only if needed; else desktop/mobile look-drag |
| World data | `assets/data/world.json` (actors, tutorials, scene data) | Same idea: JSON/glTF + media manifests |
| Terrain language | Height/map textures (`map.png`), **Points/Sprites**, spritesheets | Instanced meshes / Points / batched sprites |
| Narrative AV | Long-form `b71-documentary.mp4` + spatial UI | HTMLVideoElement / Audio synced to chapter timeline |
| UI shell | DOM splash over full-bleed `#canvas` | DOM chrome + WebGL canvas underneath |
| Text in 3D | Bitmap font atlases (PNG + metric TXT), not TextGeometry | MSDF / bitmap / canvas textures |

Primary sources: live site `bundle.js` + [web.dev case study](https://web.dev/case-studies/bear71).

## Architecture

```
┌─────────────────────────────────────────────┐
│ DOM shell (splash, about, enter-VR, mute)   │
├─────────────────────────────────────────────┤
│ Input adapter                               │
│  desktop | mobile360 | cardboard | hmd/xr   │
├─────────────────────────────────────────────┤
│ Experience runtime                          │
│  · load world.json + media                  │
│  · build abstract 3D landscape              │
│  · actors / POIs / gaze-or-click select     │
│  · documentary timeline + chapters          │
├─────────────────────────────────────────────┤
│ Three.js scene graph                        │
│  camera ← controls (orbit / XR pose)        │
│  render path: mono | stereo XR              │
└─────────────────────────────────────────────┘
```

**Hard product rule:** one codebase, progressive enhancement:

1. Desktop mouse look + click-to-move  
2. Mobile touch drag look + tap  
3. Inline stereo / headset via WebXR session (`immersive-vr`) when available  

## Build workflow

```
Web 3D+VR Progress:
- [ ] 1. Choose progressive targets (desktop / mobile360 / XR headset)
- [ ] 2. Scaffold Three.js + full-bleed canvas + DOM enter controls
- [ ] 3. Define world.json schema (actors, tutorials per device, POIs)
- [ ] 4. Implement mono camera + device-specific look/move input
- [ ] 5. Add WebXR session (stereo, reference space, frame loop)
- [ ] 6. Optimize for dual-eye cost (draw calls, fog, LOD, sprites)
- [ ] 7. Sync narrative AV + chapter UI
- [ ] 8. Device tutorials + comfort (FPS, locomotion, reduced motion)
- [ ] 9. Verify desktop, phone landscape, and at least one XR path
```

## Implementation rules

1. **Stereo doubles GPU cost** — budget the scene for worst case (mobile XR), not desktop mono.
2. **Prefer economical art** — sprite/point/grid worlds over dense PBR meshes (Bear 71 pattern).
3. **Merge draw calls** — shared materials; instancing; atlas textures.
4. **Short draw distance + fog** — hide world edges cheaply.
5. **Texture text in-world** — avoid TextGeometry for labels/stats.
6. **Solipsistic simulation** — update/detail only what is near the viewer.
7. **Cache heavy CPU work** in typed arrays.
8. **Locomotion comfort** — teleport / click-to-move on land; avoid continuous artificial acceleration in VR.
9. **Input matrix** — never assume one control scheme; branch tutorials + hit-testing per mode.
10. **WebXR first today** — treat classic WebVR (`getVRDisplays`, `VREffect`) as legacy reference only.

## Core modules to ship

| Module | Responsibility |
|--------|----------------|
| `renderer` | WebGL canvas, pixel ratio caps, XR enabled, resize |
| `xr-session` | `requestSession('immersive-vr')`, end session, optional AR later |
| `controls` | Look (pointer/touch/pose), move (raycast to terrain), select actors |
| `world-loader` | Parse JSON, spawn sprites/points/paths, bind media |
| `narrative` | Video/audio clock, chapter markers, mute |
| `hud` | DOM overlays that hide/minimize in XR; in-world prompts when needed |
| `perf` | FPS guardrails, buffer scale, quality tiers |

Details: [architecture.md](architecture.md) · Input matrix & XR: [xr-input.md](xr-input.md) · Perf checklist: [optimization.md](optimization.md)

## Anti-patterns

- Shipping headset-only builds with no desktop/mobile path  
- Desktop-quality mesh counts in stereo on phones  
- Continuous joystick locomotion without comfort options  
- Relying on deprecated WebVR without a WebXR path  
- Putting critical copy only in DOM that vanishes in XR with no in-world fallback  
- Treating VR as a CSS “3D transform” gimmick instead of a WebGL frame loop  

## When the user invokes this skill

1. Restate the **runtime targets** (which devices).  
2. Propose the **module split** above before coding visuals.  
3. Default stack: **Three.js + WebXR + JSON world + sprite/point landscape**.  
4. Cite Bear 71 only as an architecture reference, not as IP to copy (assets, story, branding).  
