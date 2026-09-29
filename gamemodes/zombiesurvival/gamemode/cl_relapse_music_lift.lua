-- Phrase lift baked into the four played files from reference/music/source/.
-- 0.50 closes half the gap under -16.6 LUFS. Short-term loudness is an
-- EBU R128 window of 3 s centered on the moment, plus the match gain.
-- The boost is at most 6 dB, and it closes once the phrase is down at -34.6.
-- Wave fades and the music slider stay outside the file.
-- Do not multiply this strength again at playback.

GM.RelapsePhraseStrength = 0.50
