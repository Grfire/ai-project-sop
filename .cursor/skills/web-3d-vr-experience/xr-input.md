# XR & Input Matrix

Bear 71 teaches the critical product lesson: **the same 3D world must speak different input dialects**.

## Modes

| Mode | Look | Move | Select | Enter path |
|------|------|------|--------|------------|
| `desktop` | Click-drag / pointer lock optional | Click terrain | Click actor | “Enter experience” mono |
| `mobile360` | Touch-drag | Tap terrain | Tap actor | Same, phone landscape |
| `cardboard` | Head / gyro stereo | Tap (screen or magnet) | Tap / gaze+tap | Stereo via polyfill / XR viewer |
| `hmd` / Daydream-class | 6DoF/3DoF pose | Controller tap / trackpad | Controller ray or gaze | Native WebXR `immersive-vr` |

Ship a **mode resolver** once at bootstrap and when entering XR:

```ts
type InputMode = 'desktop' | 'mobile360' | 'cardboard' | 'hmd'

function resolveMode(xrSession: XRSession | null, ua: string): InputMode {
  if (xrSession) {
    // inspect inputSources: gaze-only vs tracked-pointer
    return hasTrackedPointer(xrSession) ? 'hmd' : 'cardboard'
  }
  if (isCoarseTouch()) return 'mobile360'
  return 'desktop'
}
```

Drive tutorials from `world.json.tutorials[mode]`.

## WebXR session (modern default)

```ts
const supported = await navigator.xr?.isSessionSupported('immersive-vr')

async function enterVR(renderer: THREE.WebGLRenderer) {
  const session = await navigator.xr!.requestSession('immersive-vr', {
    optionalFeatures: ['local-floor', 'bounded-floor', 'hand-tracking']
  })
  await renderer.xr.setSession(session)
}

renderer.xr.enabled = true
renderer.setAnimationLoop((t, frame) => {
  // update from frame.getViewerPose(refSpace)
  renderer.render(scene, camera)
})
```

Expose a clear **Enter VR / Exit VR** control. On desktop without headset, keep mono 3D; do not fake broken stereo.

## Look controls

- **Desktop:** spherical yaw/pitch from pointer delta; clamp pitch to avoid flip.  
- **Mobile360:** same math from touch; one-finger drag.  
- **XR:** camera pose from `XRFrame`; do not fight the headset with extra mouse look.

## Locomotion (comfort-first)

Bear 71 pattern: **point at land → relocate**, not fly-through WASD.

Recommended:

1. Raycast from reticle / controller / click into terrain collider.  
2. Fade or blink (short black frame) then set rig position.  
3. Keep eye height constant; never scale the player.  
4. Disable continuous artificial locomotion in VR unless the brief demands it and comfort options exist.

## Selection & gaze

- Desktop/mobile: pick with `Raycaster` from pointer NDC.  
- Cardboard / gaze: center reticle + dwell or tap.  
- HMD: `tracked-pointer` ray + squeeze/select events (`select`, `selectstart`).

Highlight actors with cheap emissive / color lerp (`baseColor` → `highColor` from data).

## Stereo & cameras

Legacy: `StereoCamera` / `VREffect` render left/right.  
Modern: `WebGLRenderer.xr` handles stereo targets.

Still your job:

- Avoid HUDs parented incorrectly to one eye.  
- Keep UI in `XRSpace` or as canvas textures on quads locked to the camera rig with care (prefer world-anchored panels).  
- Cap `renderer.setPixelRatio` and XR framebuffer scale on thermal devices.

## Device-specific UX gates

From Bear 71’s shell (keep the *behaviors*, not the copy):

- Portrait phone → “rotate your device” gate before stereo.  
- iOS path may need Add to Home Screen / separate instructions for immersive viewers.  
- Mute control always reachable; autoplay policies require a user gesture before AV.

## Testing checklist

- [ ] Desktop: look, move, select, audio  
- [ ] Phone landscape mono  
- [ ] WebXR Immersive VR on at least one headset browser (Quest Browser / Chrome + headset)  
- [ ] Fallback when `immersive-vr` unsupported (button hidden or explained)  
- [ ] Tutorial strings match the active mode  
- [ ] No stuck pointer / scroll chaining under canvas  
