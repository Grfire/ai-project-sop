# Architecture — Browser 3D + VR

Patterns distilled from Bear 71 VR (`bundle.js`, `world.json`, WebVR polyfill config) and updated for WebXR.

## Runtime model

### Canvas ownership

- One primary fullscreen WebGL canvas (`#canvas`), `position: absolute/fixed`, sized to viewport.
- Portal / splash decorative canvases may be separate 2D canvases; do not steal the GL context from the main experience.
- DOM UI sits above the GL layer until the user enters the experience; in XR, prefer in-world UI or minimal browser XR DOM overlay.

### Frame loop

```
onAnimationFrame(time, xrFrame?):
  updateControls(xrFrame)      # pose or pointer
  updateWorld(time)            # actors, paths, narrative sync
  if xrSession: renderer.render with stereo cameras
  else: renderer.render(scene, camera)
```

Today: `renderer.setAnimationLoop(fn)` with `renderer.xr.enabled = true`.

Legacy Bear 71: `VREffect` stereo path + `VRControls` pose when a `VRDisplay` / polyfill display exists.

## World data (`world.json` shape)

Bear 71’s manifest is the template. Keep content data out of code.

```jsonc
{
  "tutorials": {
    "desktop": [{ "icon": "mouse-click-drag.png", "copy": "Click and drag to look around" }],
    "mobile360": [{ "icon": "mobile360-tap-drag.png", "copy": "Tap and drag to look around" }],
    "cardboard": [{ "icon": "hmd-look.png", "copy": "Look around" }],
    "daydream": [{ "icon": "hmd-look.png", "copy": "Look around" }]
  },
  "icon-spritesheet-data": {
    "mouse-click.png": {
      "framesTotal": 2,
      "frameWidth": 16,
      "frameHeight": 32,
      "fullHeight": 64,
      "sequence": "0,6; 1"
    }
  },
  "actors": [
    {
      "name": "Entity 01",
      "mediaURL": "clip.mp4",
      "mediaWidth": "640",
      "mediaHeight": "480",
      "title": "Short documentary blurb",
      "titleShort": "VR-safe shorter blurb",
      "stats": [{ "key": "Latin", "value": "…" }],
      "baseColor": "#a35934",
      "highColor": "#c89b85"
      // plus positions / paths in your schema
    }
  ]
  // terrain refs, chapter list, waypoints…
}
```

**Design implications for engineering:**

- Every interactive entity is data: media, stats, colors, short vs long copy.
- Tutorials are **per input mode**, not one global onboarding.
- Spritesheet metadata drives lightweight animated 3D/HUD icons.

## Scene construction (economical landscape)

Bear 71 presents Banff as an **abstract data terrain**, not photogrammetry:

1. **Height / map texture** (`map.png`) drives topology or placement.
2. **Spritesheet** (`spritesheet.png`) supplies icons for wildlife, infrastructure, cameras.
3. **Points / Sprites** for dense symbol fields (cheap, readable at distance).
4. Optional path ribbons / grids for roads and tracking trails.
5. Fog + dark clear color to clip far detail.

Modern equivalents:

- `THREE.Points` + `PointsMaterial` / custom shader  
- `THREE.InstancedMesh` for repeated markers  
- Heightmap → `PlaneGeometry` displacement **only if** triangle count stays XR-safe  
- glTF for a few hero props; keep the field of instances sprite/point based  

## Narrative layer

- Long-form documentary video asset loaded alongside the world.
- Chapters (Bear 71 lists story beats) jump timeline and/or camera bookmarks.
- Actor select opens media + stats panel (DOM on 2D; textured plane / diegetic panel in VR).
- Provide `titleShort` for headset readability.

## Progressive enhancement matrix

| Capability | Detection (modern) | Behavior |
|------------|--------------------|----------|
| WebGL | renderer success | Required |
| Pointer desktop | fine pointer / mouse | Drag look, click move/select |
| Touch | coarse pointer | Touch-drag look, tap |
| WebXR VR | `navigator.xr.isSessionSupported('immersive-vr')` | Enter VR button → stereo session |
| iOS / no XR | UA + feature detect | Mobile360 + optional “add to home” cardboard-style path |
| Reduced motion | `prefers-reduced-motion` | Soften camera easing; keep teleport |

Legacy detection on Bear 71: `navigator.getVRDisplays`, `__isNativeWebVRAvailable`, polyfill `VRDisplay`.

## Polyfill config (historical)

Observed `WebVRConfig` highlights:

- `FORCE_ENABLE_VR: true` — always expose a VR display path for testing  
- `BUFFER_SCALE: 1` — start at 1.0 render scale; lower under load  
- `PREDICTION_TIME_S: 0.04` — pose prediction  
- `CARDBOARD_UI_DISABLED` / rotate instructions toggles  
- Loads Cardboard device DB: `https://storage.googleapis.com/cardboard-dpdb/dpdb.json`  

For new projects: prefer native WebXR; if you must polyfill, document why and test motion sickness carefully.

## Suggested modern package sketch

```txt
three
# optional helpers
three/examples/jsm/webxr/VRButton.js
# or custom enter-VR control matching product UI
```

Do **not** depend on removed `VREffect` / `VRControls` in new code; reimplement with `renderer.xr` + `XRTargetRaySpace` / gaze reticle.

## Asset pipeline

| Asset | Role |
|-------|------|
| `world.json` | Content + tutorials + actors |
| Height/map textures | Terrain / placement |
| Spritesheets | Icons, tutorial glyphs |
| Bitmap fonts | In-world labels |
| MP4/WebM documentary + actor clips | Narrative |
| Optional glTF | Sparse hero meshes |

Preload critically before Enter; stream actor clips on demand.
