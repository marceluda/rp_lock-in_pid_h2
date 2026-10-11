
# Devbuild  changes


v0.3.9
- ADDED support for ecosystem 2.0 of RedPitaya

v0.4.0
- Flavour change. 
  - Removed F1, F2, F3 signals
  - Added second demodulation channel (X2, Y2)

v0.4.1
- Ecosystem 2.0 fixes, ported from rp_lock-in_pid_h v0.3.10
  - FIXED E3: parameters are sent in chunks of at most 600 B (only changed and finite values, with retries)
  - App status is probed with POST; the App is started robustly (stop + 1.5 s + start + verification)
  - ADDED "took control" detection when another client claims the board
  - ADDED save and restore of the App state in the browser
  - FIXED Config -> load; own localStorage key for this App
  - reload_fpga is disabled in Ecosystem 2.0 (nginx returns 501)
  - Cache-Control (no-cache) for index.html in nginx.conf
  - main.c (GUI_XMIN/XMAX from rp_main_params) and Makefile updated for Ecosystem 2.0 (fpga.bit.bin with bootgen, -lm -lpthread)
- Signals that are 0 in this flavour (sin_ref, cos_1f, cos_2f, cos_3f, F3o) are shown as disabled "(n/a)" options
- Restart after "took control" restores the saved values when the intruder is the same App
- ADDED cautious mode: if /get_client_id is slow or fails, /data is not requested until the board answers fast again
- First bitstream that includes X2/Y2 filtered with lpf_F1

v0.4.2
- Web interface fixes, ported from rp_lock-in_pid_h_hf v0.3.8
  - FIXED second of two quick consecutive changes being lost while a POST was in flight
  - FIXED indicators (R, X, Y, phase of both channels, scope) frozen by the edit timer after leaving a field; Escape cancels an edit
  - FIXED Enter with an out-of-range value sending two POSTs (Enter is prevented, forms use novalidate)
  - FIXED mouse wheel: no longer sends single_btn, and SHIFT + wheel uses the right sign
  - FIXED duplicated POST when using the mouse wheel on a focused field
- FIXED cautious mode entered without reason during active use: a single slow/failed /get_client_id is retried at once (cautious only if the retry is slow/fails too), a slow answer overlapping our own POST /data is not measured, and the checks to leave it are 1 s apart (was 3 s)
- FIXED endless POST loop (~15 POST/s, it crashed the nginx worker) after Config -> load of a config without some keys (e.g. of another App): missing keys keep their current value, a select without selection never gives NaN, NaN is never a pending change, and sendParams() has an anti-loop guard (no POST without changes < 200 ms after the previous one, at most 10 POST/s)

v2.4.3
- First version of the 2.x series (branch devel2.0): the same changes as lock_in+pid_harmonic v2.3.10 +
  v2.3.11 (see its CHANGELOG for the details of each one), plus the bus read fix of its v2.3.17. Everything
  that makes this App "TWO" is kept: gen_mod_h2 (cos_ref, cos_A/sin_A with gen_mod_phase_A, cos_B/sin_B with
  gen_mod_phase_B), four demodulation_line (X, Y of signal_i; X2, Y2 of signal2_i), signal2_sw, lpf_F1 for
  X2/Y2, the register map of v0.4.2 and the "(n/a)" options of the signals that are 0 in this App. The
  "v2.3.x" in the comments of the code are versions of lock_in+pid_harmonic
- CHANGED the FPGA design is built with Vivado 2020.1 (RedPitaya-FPGA project structure, project v0.94,
  model Z10 = STEMlab 125-14): lock_in+pid_harmonic2/fpga is the fpga/ of lock_in+pid_harmonic with the lock
  module of this App (lock.v, lock/gen_mod_h2.v, lock/demodulation_line.v); the Vivado 2015.2 design is kept
  untracked in lock_in+pid_harmonic2/fpga_old_2015.2
- CHANGED the oscilloscope is the RedPitaya 2.0 one: the controller unlocks the trigger (0x94) before
  every acquisition and detects its end with conf bit 4; 20-bit decimation (time range up to ~68 s);
  samples keep the 14 ADC bits (controller, c/osc, c/stream_tcp_osc_cmd, py/hugo.py)
- FIXED corrupt bus reads of live signals (in1, oscA, out1, PID...: a mix of bits of two values, 2-4 % of the
  reads in lock_in+pid_harmonic): lock.v loads sys_rdata only while sys_ren and holds it, the read-only wires
  are read from registered copies (*_rd: in1, in2, out1, out2, oscA, oscB, pidA/B in/out, ramp_A/B, cos_ref,
  cos_A, sin_A, cos_B, sin_B, error_mean, error_std, lock_feedback) and the frozen copies (*_reg) are held
  during a read; multicycle constraint on sys_rdata. config_tool.py generates the new read mux. xsim
  test/lock_bus_read_sim.sh: PASS (v0.4.2: 2000/2000 reads with sys_rdata changing < 8 ns before the PS
  sampling edge)
- FIXED streaming (c/stream_tcp_osc_cmd segfault, repeated data, first Start without data, E3, leaving the
  App while streaming, corrupt end, check_streaming), c/lock unsigned registers, /lock and /osc `?name`
  without `=`, c/ tools cross compiled by the App Makefile (`make c_tools`, c/stream_start.sh), time scale
  after Restart, a Single click made during a POST no longer lost
- FIXED streaming (testAgent 2026-10-11 00:28, also in v0.4.2): c/streaming and c/stream_tcp_osc_cmd used the
  register offsets of lock_in+pid_harmonic (stream_ip/port/rate/cmd at 0x17C..0x188); in this App they are at
  0x188..0x194 (signal2_sw, signal2_i and gen_mod_phase_B shift the map), so ctrl_B was read as the IP, the
  streaming started by itself and Stop did not stop it. The offsets are now generated by c/Makefile from c/lock.txt
  (register map of config_tool.py) into c/lock_offsets.h
- FIXED c/streaming closes the file descriptors inherited from the nginx worker (it is started from nginx with
  os.execute; the sockets stayed open in CLOSE-WAIT in c/streaming and c/stream_tcp_osc_cmd while streaming)
- REMOVED the DEBUG and RELOAD flavours (controllerhf_dbg.so, controllerhf_rld.so, src/main_*.so_.c, the
  RELOAD_DOCK marks of src/main.c, fpga.bif); only the App itself is built and packaged
- CHANGED Makefile upload targets (as lock_in+pid_harmonic v2.3.15): `make upload RPIP=...`, rw of the OS
  (2.0 and 0.9x), check_rpip, fpga.sh keeps its exec bit; settings.sh loads Vivado 2015.2 only if present
