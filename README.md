# Vector Drift

Native macOS arcade space shooter with Classic, Modern and true XYZ 3D Flight modes.

A native macOS arcade space shooter with two independent presentation modes: **Classic** monochrome vectors and **Modern Vector** with original procedural effects. Not affiliated with Atari.

## Build

Requires macOS 13+ and Xcode 16+. Open `VectorDrift.xcodeproj`, select **My Mac**, and press **Command-R**. For an unsigned command-line build:

```bash
xcodebuild -project VectorDrift.xcodeproj -scheme VectorDrift -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

A GitHub Actions macOS build runs on pushes to `main` and pull requests. This is an early prototype; gameplay still needs local testing.

## Controls

| Input | Action |
| --- | --- |
| Return | Begin playing from title screen; restart after game over |
| Left / right arrows | Rotate |
| Up arrow | Thrust |
| Space | Fire |
| **S** | Activate or end a reusable shield; it recharges automatically |
| Down arrow | Hyperspace (cooldown varies by difficulty) |
| **N** | Launch a drifting thermonuclear area missile (default 2 per wave) |
| P | Pause/resume |
| Hold Up arrow | Continuous engine-thrust rumble while accelerating |
| R or Command-R | Restart |
| Toolbar | Switch Classic / Modern / 3D Flight, choose difficulty, Custom Game, Save Game, Resume, sound and scores |

Click inside the playfield for keyboard focus. In **3D Flight**, left/right arrows yaw, **I/K** pitch, **Q/E** roll, **W/X** rise/dive, **A/D** strafe; Up thrusts forward and Down reverses. Space fires, S shields and N launches a missile.

## v0.10.1 — Visible motion and coherent gas edges

The initial v0.10 background was visually attractive but barely moved during flight, because its parallax displacement was limited to about 38×30 points and eased back toward zero. This version integrates actual ship travel continuously and assigns different speeds to layers:

- Distant stars scroll at 0.30×; near dust at 1.60×. Both wrap indefinitely rather than stopping after a small displacement.
- Far gas, intermediate clouds, near clouds and their edge highlights respond progressively more to thrust and inertia. Gas shifts smoothly without exposing rectangular texture boundaries.
- Faint motion streaks appear on stars and dust during sustained thrust. Hyperspace still triggers a brief layer-dependent zoom.
- The 83 independent wavy line paths are removed. In their place are 23 short, branching, translucent contours generated along the same cloud-boundary ridge as the nebula itself.
- Background animation intentionally pauses when the game is paused; test motion during active play by holding Up for several seconds.
- The footer now correctly credits this as original procedural artwork, not NASA photography.

## v0.10 — Vector Nebula v2: all five graphics upgrades

Modern now uses **original procedural vector-authored art** rather than downloading telescope photographs. The scene is built once per mode activation from smooth cubic Bézier cloud contours, vector stars, galaxy ellipses, filaments, and dust, then rendered into multiple transparent textures for fast SpriteKit animation. This eliminates floating rectangular photo panels. It does not use NASA images or a network connection.

- **1. Organic Bézier contours:** low-frequency radial modulation and cubic control points produce soft, varied gas boundaries (rather than polygons or circles scattered uniformly).
- **2. Distinct gas blur depths:** broad distant cloud masses (34-point-equivalent Gaussian blur), medium gas (17), near structured clouds (5), and crisp filament highlights remain separate.
- **3. Living internal motion:** a shared GPU flow/noise shader warps the cloud content itself instead of shifting a still image. Independently phased layers breathe and shift at different rates.
- **4. Star clusters:** a broad field of small dim stars, four tighter stellar clusters (hundreds of clustered stars), a few bright six-spike diffraction stars and faint vector galaxies.
- **5. Whole-field black-hole lensing:** the same spatial deflection operates on stars, clouds, filaments, and near dust, so light bends coherently around the black hole.

The layers react to ship velocity with distinct parallax factors (near dust moves the most), and hyperspace briefly zooms the image contents. The existing asteroid-belt density influences dust opacity. Classical rendering and game rules are unchanged.

The renderer uses original vector geometry but caches rendered transparent layers in textures, rather than recomputing every path per frame. All effects are offline. Modern screenshot and GPU performance testing on a Mac are still required.

## v0.9.1 — Seamless nebula field (fix for floating photo panels)

The prior v0.9 experiment displayed three independent rectangular photograph sprites. Those overlapping panels and their edges were visible in gameplay, defeating the cinematic effect. This is now replaced by **one fixed, full-viewport canvas** with a GPU shader that samples two NASA photo textures, continuously warps the sampled coordinates, and blends the second image only inside slowly evolving, irregular cloud masks.

There are no rotated photo panels or hard rectangular overlay boundaries. Motion remains inside the shader, so the sky is stationary relative to the game viewport while nebula clouds swirl, change shape and softly drift. Thrust shifts photo sampling slightly; hyperspace adds a brief radial acceleration effect; black-hole lensing refracts both images together. The canvas resizes with the window.

The procedural fallback still appears while the first photo downloads or when offline. Astrophoto textures are cached between launches. The blend is intentionally dark enough for gameplay readability; this change still needs a visual test on your Mac, since GitHub Actions only verifies Swift compilation.

## v0.9 — Cinematic telescope-photo backgrounds

Modern (2D) now uses real, layered raster astrophotography instead of primarily drawing the backdrop from procedural dots and vector glows. The two source plates are:

- [NASA SVS 31285: Webb Cosmic Cliffs, NGC 3324](https://svs.gsfc.nasa.gov/31285/) — image credit NASA, ESA, CSA, STScI.
- [NASA SVS 12086: Hubble Orion Nebula](https://svs.gsfc.nasa.gov/12086/) — image credit NASA/ESA/STScI/AURA/The Hubble Heritage Team.

On the first launch in Modern, the game downloads these official NASA SVS JPEG plates over HTTPS into the user's macOS Caches directory under `VectorDrift/TelescopeSky`. Later launches read cached files offline. If images cannot be fetched, the prior procedural sky remains visible; it does not block gameplay. External data is limited to these two image resources, loaded only in Modern 2D. Modern displays a source-credit label in the bottom toolbar.

The photographic renderer includes a full-screen base plate, two independent soft nebula exposures, slow warp/displacement shaders, slight image breathing, motion-dependent parallax, and a short hyperspace zoom impulse. Black-hole lensing bends photographic texture samples along with the existing procedural fallback. The foreground game objects, physics and Classic mode are unchanged. Actual imagery is provided by NASA's official SVS site rather than resembling it with procedural colored circles.

The downloaded image is rendered at reduced opacity and with enlarged crops to retain legibility. This is a first image-driven pass, not a filmed or fully volumetric simulation. macOS GPU rendering and image loading should be tested locally even when macOS compilation passes.

## v0.8 features (deep-space skies and asteroid-belt passages)

- **Modern mode starfield:** a procedural star atlas with roughly a thousand dim stars, ~110 moderately bright stars, and nine prominent six-ray telescope-style stars. Lower average brightness keeps bullets and asteroids readable.
- **Distant galaxies:** seven faint rotated, varied elliptical/edge-on galaxy patches and a very subtle wide stellar dust lane, all created by code without bundling telescope images.
- **Living nebula:** three softly colored, semi-transparent cloud layers move, gently scale, and vary their opacity at different rates. An additional faint dust belt brightens as asteroid traffic becomes denser.
- **Asteroid belt density:** ordinary Modern games move through broad, slowly varying belt densities. Wave-start counts change moderately (roughly 0.78–1.31×) and rare extra smaller rocks drift in from the edge during dense stretches. A cap and a no-replenishment rule near the end of a wave prevent endlessly busy rounds. Classic retains its original counts; Custom Game presets retain their chosen exact asteroid counts, even in Modern.
- **Dark black holes:** Modern now uses dark cores with understated silver-gray rings instead of brightly colored accents. A SpriteKit shader bends the sampled starfield near the black hole, returning smoothly to normal after the hazard ends. The effect is an artistic approximation of gravitational lensing, not a physical relativity simulation.
- **Performance approach:** background stars and galaxies are baked once into a single texture; only a few nebula/dust sprites animate. No additional download assets. The existing 3D Flight background is unchanged by this Modern-specific pass.

## v0.7 features (custom rule presets, save/resume, black holes, 3D flight and nuclear missile)

- Three presentation modes: Classic wireframe 2D, Modern textured 2D, and fully spatial 3D Flight powered by SceneKit
- Built-in Easy / Medium / Hard plus **Custom Game** with named persistent rule presets. Change bullet count and lifetime, fire rate, shield duration/cooldown, rock starting count, wave growth, maximum asteroid size, hits to split, asteroid speed, lives, comets, UFOs, black holes, missiles per wave, and edge physics (wrap or bounce). Presets save locally on the Mac.
- **Unlimited reusable shields** in both modes: S activates a timed shield, and S again ends it early and starts recharge. After 7 seconds on Easy / 5 on Medium / 3 on Hard, the shield automatically expires. Recharge takes 5 / 7 / 9 seconds respectively, then the shield becomes ready to activate again. Shield timer and recharge both pause with gameplay.
- Incoming asteroids bounce off an active shield, retaining their health and splitting behavior. Larger rocks now push the ship backward harder and cause a visibly stronger, flexing shield ripple with extra Modern Vector particles.
- Holding thrust plays a low continuous synthesized engine roar, stopping promptly when thrust stops, the window loses input focus, the game pauses, or sound is disabled.
- Difficulty determines the number of asteroid sizes: **Easy three**, **Medium four**, **Hard five**. Each larger size is physically bigger and slower; fragments accelerate as they split.
- Medium introduces single-hit size-4 rocks. Hard introduces size-4 two-hit rocks and enormous size-5 three-hit rocks; initial damage cracks appear without changing the rock's size, and the second hit on the largest tier adds a second crack.
- Easy keeps its original starting count (3, +1 per wave, capped at 12). Medium begins with 4 (+1 per wave, capped at 13), while Hard begins with 7 (+2 per wave, capped at 19). These counts exclude fragments created by splitting.
- On **Hard**, level-4 rocks take two shots and level-5 rocks take three. Each non-final hit adds visible damage without changing rock size. Final hits split rocks into two of the next smaller tier.
- **Timed fractures on every difficulty:** the largest asteroid in Easy (size 3) and Medium (size 4) now takes two hits. Hard retains its existing size-4 two-hit and size-5 three-hit rocks. The first nonfatal hit starts a 10-second game-time countdown; a second nonfatal hit on a size-5 rock cuts the countdown to at most 5 seconds. A final shot splits immediately. Expired rocks split automatically without awarding points. Countdown pauses with the game and new fragments start undamaged.
- **Modern graphics now use genuine shaded bitmap surfaces:** each asteroid has its own procedurally generated mineral texture with directional shading, craters, grit, raised ridges and dark fissures. This is no longer just wireframe art in Modern mode; Classic retains white vector shapes.
- Modern's drifting stars, glowing damage flares, instability arcs and multi-layer debris remain available.
- **Interface redesign:** separate title/actions and mode-selection rows, less crowded score/status HUD, clear shield READY / ACTIVE / RECHARGING indicator, and centered overlay behind title/game-over text. Classic stays visually restrained.
- Comet special events in Modern and, on Hard, Classic; Hard comet intervals are much shorter
- Rare black holes from wave 3 attract ships, rocks, projectiles and missiles. Thrust can escape at distance, but reaching the event horizon destroys the unprotected or shielded ship. Modern 2D pulses the starfield to suggest gravitational lensing; 3D uses a spatial gravity well.
- **N-key thermonuclear missile:** forward launch, short drifting fuse, and a large explosion that clears objects in its radius. The 2D circular blast is sized to about 33% of the playfield area (before clipping). The 3D spherical blast spans approximately one third of the XYZ arena width. Default two missiles per wave, replenished every wave, custom range 0–10.
- Comet shot creates an expanding asteroid-clearing shockwave and a 750-point bonus
- Enemy UFO saucers with aimed shots, more accurate and frequent on Hard
- Original procedural arcade sounds, user-controllable sound toggle
- Title screen and persistent local top-five scores per difficulty
- **Save Game** records active 2D or 3D progress in local Mac storage; **Resume** restores lives, wave, score, position, moving rocks, bullets, damage timers, shield cooldown, missiles and black-hole state. Up to 12 recent checkpoints per engine. Saved games survive app restarts; 2D procedurally regenerated rock surface details may differ.
- Classic yellow ship-death flash and flying fragments; Modern includes brighter debris effects
- Visible difficulty and graphics buttons with an explicit selected state

## Difficulty

| Rule | Easy | Medium | Hard |
| --- | --- | --- | --- |
| Lives | 5 | 3 | 2 |
| Asteroid speed | 0.75× | 1× | 1.32× |
| Beginning large asteroids | 3 | 4 | 5 |
| Bullet lifetime | 1.5 s | 0.95 s | 0.55 s |
| Minimum time between shots | 0.13 s | 0.16 s | 0.20 s |
| Respawn protection | 3 s | 2 s | 1.25 s |
| Hyperspace cooldown | 3 s | 4.5 s | 7 s |
| Shield active duration | 7 s | 5 s | 3 s |
| Shield recharge cooldown | 5 s | 7 s | 9 s |
| Comet interval | 15–23 s | 11–18 s | 5–9 s |
| UFO interval | 27–35 s | 19–27 s | 12–19 s |
| Asteroid size tiers | 3 | 4 | 5 |
| Starting rocks, wave 1 | 3 | 4 | 7 |
| Added rocks per wave | +1 | +1 | +2 |
| Maximum starting rocks per wave | 12 | 13 | 19 |
| Giant hit points | size 3: 2 | size 4: 2 | size 4: 2; size 5: 3 |
| Default thermonuclear missiles / wave | 2 | 2 | 2 |
| Damaged rock fracture timer | 10 s | 10 s | 10 s first hit, at most 5 s after second nonfatal hit |

Comet and UFO spawns begin in wave 2. Classic mode only gets comet events on Hard. Switching difficulty starts a new game.

## Storage and limitations

Presets and saved games use macOS `UserDefaults`, stored locally in this app's preference domain. They do not sync between devices. Saved play is resumed through the **Resume** button, not through Xcode run-state restoration. Presets and save formats are prototype v1; upgrades should migrate them deliberately. The 3D camera, physics, visuals and interface are early playable prototypes and are not yet parity-complete with the 2D modes. These changes must pass macOS CI and hands-on testing before release.

## Future improvements

Modern now composites procedural shaded asteroid sprites with vector overlays, plus drifting stars, timed damage arcs and layered particle breakups. Longer-term improvements can use Metal shaders for true dynamic surface lighting, heat distortions and volumetric nebulae. Controller support, final sound design and release packaging remain open.

## Licensing and release

Code is MIT licensed. Game name has not been cleared for trademark use. Art and generated audio are original implementations rather than copied Atari assets. Before public binary distribution, verify branding, art similarity, signing, and notarization.
