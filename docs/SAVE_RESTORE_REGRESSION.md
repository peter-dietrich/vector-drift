# Save and restore regression test — Fun City / Vector Drift

The **Save Game** button is only valid during an active flight, not at the title screen or after game over. It must now report either a saved checkpoint or a clear reason for failure.

## Data safety

Do not delete current saves while testing. The new primary save-file location is:

`~/Library/Application Support/Vector Drift/vectorDrift.savedGames.v1.json`

For 3D Flight:

`~/Library/Application Support/Vector Drift/vectorDrift.3dSaves.v1.json`

Legacy UserDefaults saves are still read if a new file does not exist. Save files are written atomically, verified by decoding after writing, and mirrored to the prior UserDefaults key. A bad/corrupt primary save file must not be silently overwritten by Save Game.

## Manual verification on macOS

1. Open Vector Drift, press **Save Game** on the title screen and verify a meaningful message explains why it cannot save.
2. Start a Classic flight, play long enough for recognizable score/wave/ammo, then click **Save Game**. Verify confirmation includes the wave and score.
3. Click **Resume**. Verify the named checkpoint with the correct score and date is listed.
4. Quit with **Command-Q**, reopen Vector Drift, select **Resume**, and check that the checkpoint is still listed.
5. Resume and verify score, remaining lives, wave, ship position and ammunition. Continue playing and check the scene does not reset when the UI updates.
6. Repeat in **Modern** mode and inspect a high score (high scores remain stored in UserDefaults).
7. Repeat in **3D Flight**, including save and resume after a full app restart.
8. Once Vector Drift is running, use Fun City's update button. Choose **Quit Game & Install Update** and verify it closes gracefully, waits for exit, resumes the selected beta release install, and retains the save slots.
9. On a cancelled quit, verify the existing running game remains untouched. Never force-terminate a game with unsaved progress.

Build CI ensures only compilation. Functional save/restore integrity and graceful quit timing still require these real Mac checks.
