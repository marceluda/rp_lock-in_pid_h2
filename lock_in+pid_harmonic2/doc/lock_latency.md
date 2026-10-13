# Pipeline registers of v2.4.6 (FPGA timing) — added latencies

Port of the timing work of `lock_in+pid_harmonic` v2.3.19 (its `doc/lock_latency.md` explains the method; the user
allowed adding latency on 2026-10-12). Up to v2.4.5 the FPGA did not meet timing at 125 MHz because of long
combinational chains of the loop (generator ROM → product → LPF / bypass → gain → saturation → PID / scope / lock
control; PID sum → ctrl → out mux → DAC). v2.4.6 registers those chains. **The behaviour is the one of v2.4.5 except
for the latencies below** (checked bit by bit in simulation, `test/lock_latency_sim.sh`).

## Latency of each signal with respect to v2.4.5

| Signal | Added | ns |
|---|---|---|
| Generator outputs (`cos_ref`, `cos_A`, `sin_A`, `cos_B`, `sin_B`, `harmonic_trig`) | +1 | 8 |
| References into the two lock-ins (`demodulation_line` `ref`) | +2 (generator + 1) | 16 |
| `Xo`, `Yo`, `X2o`, `Y2o` from the product (`demodulation_line`: register after the first LPF stage + output register; `shift_sat14`) | +2 | 16 |
| `X_28`, `Y_28`, `X2_28`, `Y2_28` (bus) | +1 | 8 |
| PID outputs (`pidA_out`, `pidB_out`), from the PID input | +1 | 8 |
| `out1`, `out2` (DAC), for everything that goes out (out mux and modulation, both registered before the sum) | +1 | 8 |
| LOCK MODE loop `in1` → Y → PID A → `ctrl_A` → `out1` | +4 | 32 |

**Phase of the lock-in.** Unlike `lock_in+pid_harmonic` v2.3.19, the references reach the lock-in 1 clock later than
the outputs: the generator and the DAC outputs got 1 register each, so the modulation that goes out and comes back
(DAC → system → ADC) is 2 clocks later and the reference too: **the measured phase does not change** (in
`lock_in+pid_harmonic` 2.3.19 it changes by −360° · f · 8 ns). In the simulation this is the case "in1 delayed 2
clocks": every lock-in signal is then exactly the old one delayed 2 + its latency.

Blocks rewritten without latency (same values): gain + saturations of `demodulation_line` (`shift_sat14`), `sat14` (mask instead of barrel shifter), integrator of the PID
(ISR shift in parallel with the saturation), `sum_div` of the second LPF stage in a register (a change of `lpf_*`
reaches it 1 clock later). The PID derivative with `DSR` > 0 samples a delayed input at other points (same behaviour,
other sampling phase).

Also: the 4-bit `sg_amp1` goes to the 5-bit port `amp` of the lock-in B lines as `{1'b0, sg_amp1}` (it was connected
directly; synthesis fills with 0, xsim left the upper bit `z` and gave `X2o`/`Y2o` = x in simulation).
The recovery check of the reset (`async_default`, −1.608 ns in v2.4.4/2.4.5) now passes (+0.414 ns).

## Verification

`test/lock_latency_sim.sh` (xsim, the `lock.v` of the working tree side by side with the one of v2.4.5): all checks
bit exact; `test/lock_bus_read_sim.sh` and `test/lock_ctrl_sim.sh` pass.

## Timing (Vivado 2020.1, post-route)

| | v2.4.5 | v2.4.6 |
|---|---|---|
| WNS | -9.618 ns | -1.281 ns |
| TNS | -9949.845 ns | -509.960 ns |
| Failing endpoints | 4927 | 996 |

Worst slack per group (ns):

| Group | v2.4.5 | v2.4.6 |
|---|---|---|
| scope muxes | -9.618 | -0.369 |
| DAC registers | -8.975 | > 0 |
| adc_dat (digital loop / scope input) | -8.886 | -1.104 |
| bus copies *_rd | -8.722 | > 0 |
| PID A | -6.184 | -0.838 |
| PID B | -6.787 | -1.019 |
| lock_ctrl | -4.343 | > 0 |
| rest of the lock module | -4.866 | -0.691 |
| LPF | -3.424 | -1.281 |
| ramp | -4.094 | -0.232 |
| generator | -3.591 | > 0 |
| oscilloscope | -4.581 | -0.287 |
| bus read (sys_rdata) | -4.850 | > 0 |
| other | -3.090 | -0.227 |

What still fails is small: the recursive loops of the LPF and of the PID integrator (they cannot be pipelined
without changing the filter), the input path `in1` → PID mux → set point subtraction → multiplier, quasi-static
configuration registers, and paths of the oscilloscope outside the lock module.
