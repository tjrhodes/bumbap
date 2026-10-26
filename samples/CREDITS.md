# Samples

The kit is the **Roland TR-808 Rhythm Composer Sound Sample Set 1.0.0**
by Michael Fischer, Technopolis (1994), released free of charge. The sounds are not covered by the MIT licence of the code in this repo. Each sound
was sampled from a real TR-808 at 16-bit, 44.1 kHz, at five positions of each
of its knobs.

`prepare.py` copies every variant of the eight parts the machine uses, trims
their silent tails and keeps the set's file names, which spell out the 808's
knob positions (00, 25, 50, 75, 10 = fully right):

| Part | Files | 808 knobs | Starts at |
|---|---|---|---|
| Kick | BD0000 … BD1010 (25) | Tone, Decay | BD2550 |
| Snare | SD0000 … SD1010 (25) | Tone, Snappy | SD5050 |
| Clap | CP | | |
| Closed hat | CH | | |
| Open hat | OH00 … OH10 (5) | Decay | OH50 |
| Low tom | LT00 … LT10 (5) | Tuning | LT50 |
| High tom | HT00 … HT10 (5) | Tuning | HT50 |
| Rim | RS | | |
