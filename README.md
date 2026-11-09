# Vector Drift

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
| **S** | Toggle shield on/off, using a limited energy budget |
| Down arrow | Hyperspace (cooldown varies by difficulty) |
| P | Pause/resume |
| Hold Up arrow | Continuous engine-thrust rumble while accelerating |
| R or Command-R | Restart |
| Toolbar | Choose graphics, difficulty, toggle sound, see scores |

Click inside the playfield for keyboard focus.

## v0.6 features (textured asteroid rendering, renewable shields and HUD redesign)

- Two graphics modes, with distinct procedural graphics and effects
- Three difficulty settings independent of graphics mode
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
- Comet shot creates an expanding asteroid-clearing shockwave and a 750-point bonus
- Enemy UFO saucers with aimed shots, more accurate and frequent on Hard
- Original procedural arcade sounds, user-controllable sound toggle
- Title screen and persistent local top-five scores per difficulty
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
| Damaged rock fracture timer | 10 s | 10 s | 10 s first hit, at most 5 s after second nonfatal hit |

Comet and UFO spawns begin in wave 2. Classic mode only gets comet events on Hard. Switching difficulty starts a new game.

## Future improvements

Modern now composites procedural shaded asteroid sprites with vector overlays, plus drifting stars, timed damage arcs and layered particle breakups. Longer-term improvements can use Metal shaders for true dynamic surface lighting, heat distortions and volumetric nebulae. Controller support, final sound design and release packaging remain open.

## Licensing and release

Code is MIT licensed. Game name has not been cleared for trademark use. Art and generated audio are original implementations rather than copied Atari assets. Before public binary distribution, verify branding, art similarity, signing, and notarization.
