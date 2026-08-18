# Optimization — Stereo WebGL Budgets

From the [Bear 71 WebVR case study](https://web.dev/case-studies/bear71): VR renders the scene **twice per frame**. Comfort fails when FPS drops. Optimize for the weakest target that must run stereo.

## Non-negotiables

1. **Reduce draw calls** — merge geometries that share materials; atlas; instancing.  
2. **Keep shaders simple** — strip unused lighting features; hand-write when stock materials are heavy.  
3. **Close draw distance + fog** — cheaper than LOD systems you never finish.  
4. **Texture-based text** — bitmap/MSDF over TextGeometry.  
5. **Economical art direction as eng constraint** — Super Mario 64 @ 60fps beats Galaxy @ 6fps.  
6. **Solipsistic sim** — only animate / simulate near the player.  
7. **Cache in typed arrays** — height samples, path samples, precomputed colors.

## Quality tiers

| Tier | When | Actions |
|------|------|---------|
| High | Desktop mono | Full sprite density, DPR ≤ 2 |
| Medium | Desktop VR / strong mobile | Cut DPR, thin far sprites |
| Low | Cardboard / thermal throttle | `BUFFER_SCALE`/`framebufferScaleFactor` 0.7–0.8, disable soft particles, lower fog far |

Hook `XRSession` / `renderer.info` + rolling FPS; degrade before the user nauseates.

## Three.js practicals

```ts
renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2))
renderer.xr.enabled = true
// under load:
baseLayer && (/* XRWebGLLayer framebufferScaleFactor */)

material.fog = true
camera.far = /* tight */
scene.fog = new THREE.Fog(0x000000, near, far)

// prefer
new THREE.Points(geo, pointsMat)
new THREE.InstancedMesh(geo, mat, count)
// avoid per-entity Mesh with unique materials
```

## Asset budgets (starting points — tune with profiling)

| Item | Guidance |
|------|----------|
| Materials in flight | Dozens, not hundreds of unique programs |
| Triangle count (stereo mobile) | Prefer < ~100k shaded tris unless proven |
| Texture memory | Atlases; power-of-two; compress (ETC2/ASTC where available) |
| Video | One primary narrative stream; actor clips on demand; pause off-screen |
| Lights | 0–1 lights; unlit/sprite workflows win |

## Motion sickness levers (engineering)

- Maintain frame time stability (no huge GC spikes — pool objects).  
- Prefer teleport over smooth locomotion.  
- Keep acceleration of the camera rig near zero except player-initiated blinks.  
- Pose prediction / WebXR reprojection help, but **your** JS hitch still breaks comfort.  
- Never scale or shear the XR camera independently of the reference space.

## Perf verification

Code-level:

- [ ] `renderer.info.render.calls` inspected in mono vs XR  
- [ ] No per-frame `new` in hot path  
- [ ] Textures not uploading every frame  

Product-level (required for readiness):

- [ ] Desktop 60fps feel while documentary plays  
- [ ] Phone landscape usable without thermal death in 5 minutes  
- [ ] Headset session: stable stereo, readable in-world type, teleport works  

## Legacy vs modern API map

| Bear 71 (WebVR era) | Prefer now |
|---------------------|------------|
| `webvr-polyfill` + `VRDisplay` | `navigator.xr` |
| `THREE.VREffect` | `renderer.xr` |
| `THREE.VRControls` | XR frame pose / `XRReferenceSpace` |
| `WebVRConfig.BUFFER_SCALE` | `XRWebGLLayer` framebuffer scale |
| `getVRDisplays()` | `isSessionSupported` / `requestSession` |

Keep the **architecture** (polyfill→native progressive path, dual-eye budget, input modes). Replace the **deprecated APIs**.
