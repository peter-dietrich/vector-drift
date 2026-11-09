# Vector Drift

An original, native macOS arcade space shooter inspired by classic vector games. This is not affiliated with Atari.

## Build

Requires Xcode 16+ and macOS 13+. Open `VectorDrift.xcodeproj`, select **My Mac**, and press **Command-R**. No third-party dependencies or external assets.

## Controls

- Left / right arrows: rotate
- Up arrow: thrust (momentum continues when released)
- Space: fire
- Down arrow: hyperspace (cooldown)
- P: pause or resume
- R or Command-R: restart

Click the playfield to focus keyboard input.

## Included in v0.2

- Native SwiftUI window and SpriteKit playfield
- Switchable Classic monochrome and enhanced Modern Vector rendering
- Modern mode: procedural stars, subtle nebulae, faceted asteroids with craters, engine flame and glowing particles
- Modern mode: occasional high-speed comet (from wave 2), glowing particle tail and expanding area-damage shockwave
- Comet hits give 750 points plus bonuses for rocks destroyed by the shockwave
- Classic ship collision: short yellow flash and flying ship-outline fragments; Modern gets enhanced debris
- Procedural, original rock outlines; three sizes; splitting
- Momentum, projectile firing, screen wrapping, wave progression
- Bullet range, firing rate, respawn protection and hyperspace cooldown scale with selected difficulty
- Three lives, collision protection, hyperspace, scoring, persisted high score
- Local graphics and difficulty preferences (changing difficulty starts a new game)
- Three difficulties: Easy (5 lives, 0.75× asteroid speed), Medium (3 lives, 1×), Hard (2 lives, 1.32×)
- Size-based asteroid velocity: large slow, medium faster, small fastest; waves gradually accelerate

## Difficulty tuning

| Setting | Easy | Medium | Hard |
| --- | --- | --- | --- |
| Starting lives | 5 | 3 | 2 |
| Asteroid speed multiplier | 0.75× | 1.0× | 1.32× |
| Starting large asteroids | 3 | 4 | 5 |
| Bullet lifetime (range) | 1.50 s | 0.95 s | 0.55 s |
| Time between shots | 0.13 s | 0.16 s | 0.20 s |
| Respawn protection | 3 s | 2 s | 1.25 s |
| Hyperspace cooldown | 3 s | 4.5 s | 7 s |

Difficulty is independent of the graphics mode. Switching difficulty starts a new game.

## Roadmap

UFO opponents, custom synthesized sounds, gamepad input, animation polish, settings, separate difficulty leaderboards, tests, original branding, code signing and notarization.

## Rights and distribution

The source code is licensed under the repository's MIT License. The name Vector Drift has not been cleared for trademark use. All graphics are drawn procedurally without copying original Atari game code, audio, or assets. Review branding and creative similarity before public game distribution.

## Build status

v0.2 source changes pushed. The macOS SpriteKit build and gameplay have not been validated in this environment; please build locally in Xcode and report any compiler/runtime problems before public releases.
