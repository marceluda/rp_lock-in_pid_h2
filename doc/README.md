# RP TWO Lock-in+PID Harmonic — documentation

Documentation of `lock_in+pid_harmonic2` **v2.4.4** (branch `devel2.0`, Ecosystem 2.0, FPGA built with
Vivado 2020.1): the App `lock_in+pid_harmonic` 2.3.17 with **two lock-in amplifiers** (one modulation generator,
two pairs of references with independent phases, two inputs). Back to the [project README](../README.md) ·
[CHANGELOG](../CHANGELOG.md).

| Document | Contents |
|---|---|
| [App.md](App.md) | The instruments of the App and their technical data: frequencies, the two lock-ins, filters, gains, ranges, time spans, measured lock performance; what is different from `lock_in+pid_harmonic` |
| [Usage.md](Usage.md) | The web interface panel by panel (tabs LI A / LI B, Phase A / B, "(n/a)" options), the procedures (scan, lock-ins, close and check a lock, second lock-in while locked), configs |
| [Structure.md](Structure.md) | How the web page, the server (nginx + `controllerhf.so`) and the FPGA work together; block diagrams of the FPGA, of the generator and of the demodulation lines |
| [FPGA.md](FPGA.md) | Register map of the lock module (102 registers, shifted from `_h` after 0x054) and of the oscilloscope, bit fields and selector values |
| [Remote.md](Remote.md) | Remote control over HTTP (`/lock`, `/osc`, `/data`) with Python (`control_finn.py`, `line='A'\|'B'`) examples; known issue of `POST /data`; tools and scripts on the board |
| [Devel.md](Devel.md) | Source tree, requirements, building (C, `c/` tools, FPGA), tests, installation |

Design notes kept with the sources (`lock_in+pid_harmonic2/doc/`):

- [`lock_control.md`](../lock_in+pid_harmonic2/doc/lock_control.md): the lock control (`lock_control` /
  `lock_status`, state machine in the FPGA, locking from Python).
- [`lock_capture.md`](../lock_in+pid_harmonic2/doc/lock_capture.md): *Capture Lock* and *Fire on click*.

The register table that this file had before (a copy of an old `c/lock.txt`) is now [FPGA.md](FPGA.md), checked
against the RTL.

Screenshots of the web interface are in the hidden folder `.Usage/`, and the figures of the remote control in
`.Remote/` (names starting with `h_`: taken with `lock_in+pid_harmonic`, same code for those panels).
