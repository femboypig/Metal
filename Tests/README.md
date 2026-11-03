Run the behavioral checks on a machine with Swift:

```sh
swiftc Metal/DailyMixEngine.swift Tests/DailyMixEngineChecks.swift -o /tmp/daily-mix-checks
/tmp/daily-mix-checks
swiftc Metal/ListeningHistory.swift Tests/ListeningHistoryChecks.swift -o /tmp/listening-history-checks
/tmp/listening-history-checks
```

GitHub Actions runs both programs before the unsigned iOS build. It also compiles
the embedded wave and remix shader pipelines on runners with a Metal device.
Runners without a GPU explicitly report that shader runtime validation is unavailable.

Listening history is stored locally in `Documents/telemetry.json`. Version 1 data
remains readable. New session records include source, end reason, actual listening
time, media progress, start time, manual intent, mix ID, and new favorites.
`dailyMixQuality` summarizes up to the most recent 1,000 retained session records
(with a 90-day maximum age): mix impressions, early rejection rate, fraction heard
at least 85%, and fraction newly favorited. Timer stops and failures are excluded
from the quality denominator. This is an observational baseline, not an A/B test.
No analytics service or upload is used.

Device checks for the interaction changes:

- Play a Daily Mix and skip several tracks immediately. Check that short events
  are recorded, the upcoming selection responds, and the current index matches
  the player artwork with shuffle both enabled and disabled.
- Manually switch songs, go back, seek to the end, and pause/resume. These actions
  should not create early rejection events. A seek should not inflate listening.
- Shake on the Daily Mix library page or while its player is visible. The current
  song and its position should continue. The wave ripples and a colored perimeter
  appears after a soft pulse travels from the wave to the screen edges. There is
  no text banner. Repeat
  shakes within three seconds, other library filters, and open sheets are ignored.
- Long-press the Daily Mix filter to remix without moving the device. With Reduce
  Motion enabled, remix still works without the added motion effects.
- Open Sleep Timer from the player menu. Drag the dial across both ends, select
  presets, use VoiceOver adjustments, and check light/dark appearance and large
  text. Drag the ring vertically and diagonally: the sheet and its scroll view
  must stay still. Drag outside the dial to verify normal sheet gestures. Check
  that the orange Set timer button has readable text in both themes.
  Set, update, cancel, and reopen an active timer. A deadline fades playback
  over five seconds; changing songs during the fade must restore normal volume.
  With AI DJ and repeat enabled separately, let a song end during the fade: the
  player must stop without a crossfade or automatic next/repeat.
- Verify the timer while background audio is playing, and return after its
  deadline. Its stop must be tagged `sleepTimer`, without a negative taste signal.
