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

## Included in v0.1

- Native SwiftUI window and SpriteKit playfield
- Classic monochrome vector graphics and switchable Modern Vector rendering
- Procedural, original rock outlines; three sizes; splitting
- Momentum, projectile firing, screen wrapping, wave progression
- Three lives, collision protection, hyperspace, scoring, persisted high score
- Local graphics and difficulty preferences (changing difficulty starts a new game)
- Three difficulties: Easy (5 lives, 0.75× asteroid speed), Medium (3 lives, 1×), Hard (2 lives, 1.32×)
- Size-based asteroid velocity: large slow, medium faster, small fastest; waves gradually accelerate

## Roadmap

UFO opponents, custom synthesized sounds, gamepad input, improved animations, settings, high-score leaderboard, tests, original branding, code signing and notarization.

## Rights and distribution

The source code is licensed under the repository's MIT License. The name Vector Drift has not been cleared for trademark use. All graphics are drawn procedurally without copying original Atari game code, audio, or assets. Review branding and creative similarity before public game distribution.

## Build status

Initial prototype: not yet built or run on a Mac. Report any Xcode compilation issues before public releases.
