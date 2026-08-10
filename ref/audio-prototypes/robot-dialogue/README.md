# Robot dialogue blip prototype

This folder contains an original ChucK prototype for short, non-character-specific
dialogue sounds. It does not use or reproduce audio from *Undertale*.

The sound combines a pulse oscillator, a triangle oscillator, a small amount of
noise, and two moving resonant filters. Each grain slides from a rounded onset
into a sustained "a" vowel. The two near-identical variants are meant to
alternate while visible dialogue characters appear, which makes a sentence feel
voiced without requiring recorded speech.

Generate the raw files with ChucK:

```powershell
chuck --silent robot_dialogue_blip.ck:robot_blip_a_raw.wav:a
chuck --silent robot_dialogue_blip.ck:robot_blip_b_raw.wav:b
chuck --silent robot_dialogue_blip.ck:robot_preview_raw.wav:preview
```

The processed 22.05 kHz mono files add restrained 8-bit-style quantization. Keep
the short `a` and `b` files for eventual runtime playback; the preview only
demonstrates a fake sentence rhythm.
