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

## v0.3 features (thrust and shield-bounce update)

- Two graphics modes, with distinct procedural graphics and effects
- Three difficulty settings independent of graphics mode
- Finite shields available in *both* modes. Toggle with S and save remaining energy by turning them off. Energy replenishes at the start of each wave.
- Incoming asteroids bounce off an active shield, retaining their health and splitting behavior; a brief ripple and impact tone confirm contact.
- Holding thrust plays a low continuous synthesized engine roar, stopping promptly when thrust stops, the window loses input focus, the game pauses, or sound is disabled.
- Large, medium, and small asteroids move at different speeds; waves gradually accelerate
- On **Hard from wave 2**, giant slow-moving asteroids require two hits. The first reveals yellow/orange damage cracks **without shrinking the asteroid**. The second breaks it into smaller asteroids.
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
| **Shield energy per wave** | **7 s** | **5 s** | **3 s** |
| Comet interval | 15–23 s | 11–18 s | 5–9 s |
| UFO interval | 27–35 s | 19–27 s | 12–19 s |
| Giant 2-hit asteroids | No | No | Yes, from wave 2 |

Comet and UFO spawns begin in wave 2. Classic mode only gets comet events on Hard. Switching difficulty starts a new game.

## Future improvements

Modern Vector is still a procedural 2D look. Planned polish: detailed animated asteroid surfaces, parallax starfield, more varied particle fields, hit-stop/shake, heat and glow compositing, environmental hazards, controller support, full sound design, and public-release packaging.

## Licensing and release

Code is MIT licensed. Game name has not been cleared for trademark use. Art and generated audio are original implementations rather than copied Atari assets. Before public binary distribution, verify branding, art similarity, signing, and notarization.
