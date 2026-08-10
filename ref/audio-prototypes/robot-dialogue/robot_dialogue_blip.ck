// Original, neutral robotic dialogue blip prototype.
// Usage:
//   chuck --silent robot_dialogue_blip.ck:output.wav:a
//   chuck --silent robot_dialogue_blip.ck:output.wav:b
//   chuck --silent robot_dialogue_blip.ck:output.wav:preview

if (me.args() < 1) {
    cherr <= "Expected an output WAV path." <= IO.newline();
    me.exit();
}

me.arg(0) => string output_path;
"preview" => string mode;
if (me.args() > 1) {
    me.arg(1) => mode;
}

PulseOsc pulse => Gain voiced;
TriOsc triangle => voiced;
Noise noise => Gain noise_level => voiced;

voiced => ResonZ low_formant => Gain low_level => Gain vowel_mix;
voiced => ResonZ high_formant => Gain high_level => vowel_mix;
voiced => Gain dry_level => vowel_mix;

vowel_mix => ADSR envelope => Gain master;
master => WvOut recorder => blackhole;

output_path => recorder.wavFilename;

0.36 => pulse.width;
0.50 => pulse.gain;
0.18 => triangle.gain;
0.012 => noise_level.gain;
0.92 => low_level.gain;
0.52 => high_level.gain;
0.035 => dry_level.gain;
4.5 => low_formant.Q;
6.0 => high_formant.Q;
0.72 => master.gain;
envelope.set(8::ms, 30::ms, 0.72, 26::ms);

fun void render_blip(float base_hz, float formant_offset) {
    108 => int voiced_ms;
    envelope.keyOn();

    for (0 => int i; i < voiced_ms; i++) {
        i $ float / (voiced_ms - 1) => float phase;

        // A gentle falling contour reads more like a voice than a projectile.
        base_hz * (1.025 - 0.045 * phase) => float pitch_hz;
        pitch_hz => pulse.freq;
        pitch_hz * 2.005 => triangle.freq;

        // Spend the first part sliding from a rounded "w" into a stable "a".
        Math.min(phase / 0.32, 1.0) => float vowel_open;
        390.0 + (790.0 + formant_offset - 390.0) * vowel_open => low_formant.freq;
        820.0 + (1240.0 + formant_offset * 0.55 - 820.0) * vowel_open => high_formant.freq;
        1::ms => now;
    }

    envelope.keyOff();
    32::ms => now;
}

if (mode == "a") {
    render_blip(184.0, 0.0);
} else if (mode == "b") {
    render_blip(190.0, 24.0);
} else {
    // A short fake sentence, alternating variants like letter-by-letter speech.
    for (0 => int i; i < 15; i++) {
        if (i % 2 == 0) {
            render_blip(184.0, 0.0);
        } else {
            render_blip(190.0, 24.0);
        }

        if (i == 4 || i == 10) {
            165::ms => now;
        } else {
            58::ms => now;
        }
    }
}

recorder.closeFile();
