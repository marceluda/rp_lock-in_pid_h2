
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

v2.4.4
- Port of the lock / web UI / controller / remote control changes of lock_in+pid_harmonic v2.3.12 to v2.3.17 (see
  its CHANGELOG for the details of each one; the "v2.3.12".."v2.3.17" in the comments of the sources are those of
  lock_in+pid_harmonic). New FPGA image. Kept from v2.4.3: everything of the TWO lock-ins (gen_mod_h2, the four
  demodulation_line, signal2_sw / signal2_i, gen_mod_phase_A / _B, X2 / Y2 with lpf_F1 and sg_amp1, the register
  map of this App, the "(n/a)" options) and the streaming offsets generated from c/lock.txt
- CHANGED the lock sequence runs entirely in the FPGA (lock_ctrl.v state machine OFF / ARMED / LOCKED): lock_control
  (0x18) is command + configuration, never rewritten by the FPGA; 0x1C is now lock_status (read only, replaces
  lock_feedback): [0] armed, [1] locked, [4:2] effective ramp / PID A / PID B enables, [15:8] lock counter. The C
  controller writes lock_control only when the user changes it and reads the status on every request; the web UI
  shows OFF / ARMED / LOCKED, Trigger Lock / Lock Now stay pressed while requested and a second click releases.
  See lock_in+pid_harmonic2/doc/lock_control.md
- CHANGED lock_ctrl.v registers its trigger inputs for timing (as lock_in+pid v2.2.6 / lock_in+pid_harmonic_hf
  v2.3.11): ramp floor trigger (counter loaded with 1 one clock later: Time trigger in the same clock as before) and
  the level / time comparisons (Level trigger 1 clock = 8 ns later). The lock-in core (demodulation, filters) is
  not changed
- CHANGED lock time trigger: 32 bits end to end (up to 2^32 - 1 ticks = 34.36 s)
- ADDED Capture Lock (each lock request captures the closing of the loop in the scope, Ext Trig = "Lock control
  trig", frozen until Auto / Single) and Fire on click. See lock_in+pid_harmonic2/doc/lock_capture.md
- FIXED "Choose from graph" with any zoom / offset / time units; a click sets only the value of the trigger type;
  the "Auto-zoom" option was removed
- ADDED Time trigger / Level trigger fields with units (16.58 ms, 20 s, 0.1 V, 120 mV...); an emptied number field
  is never sent as 0
- FIXED Config -> load applies the scope window in the right units (seen by testAgent on v2.4.3, 1 of 2 loads with
  the page in us) and does not send forcex_flag / time_units / time_range / gui_x* nor the read-only params; the full
  config is sent in chunks with the window applied from the answer of the last one
- FIXED every POST reset the scope (a Single waiting for its trigger was disarmed); AUTO after a lock capture; aborted
  auto-set; zoom-out right after a change of time units
- CHANGED PID integrator divider label "6 us" -> "65 us"; descriptions of X / Y (X, Y: cos_A / sin_A of signal_i;
  X2, Y2: cos_B / sin_B of signal2_i); pidA_sw / pidB_sw 4 bits (0..15, the width of the selector)
- ADDED HTTP remote control on Ecosystem 2.0: /osc writes TrgUnlock (0x94) and c/osc addresses registers by index;
  register ranges in config_tool.py / c/lock.txt; resources/remote_control/http_version/control_finn.py of
  lock_in+pid_harmonic v2.3.17 (scope_stop() / scope_auto(), minimal POST /data in one packet, WebScopeNotStopped,
  host resolved once) adapted to the two lock-ins: reg_labels from the selectors of this App (cos_A..sin_B, X2o,
  Y2o, signal2_i, signal2_sw), set_phase(val, line='A'|'B') (gen_mod_phase_A / _B), set_signal(sw, line),
  set_gain(line, amp) (sg_amp0 / sg_amp1), set_lpf() / get_lpf() with lines 'A' (lpf_F0) and 'B' (lpf_F1),
  get_XY(F=True) returns X, Y, X2, Y2; example_usage.py with both lock-ins and the ramp of
  test_files/lock_in+pid_harmonic2__lock_mode.json
- ADDED py/lock_from_registers.py (arm / lock now / release / status writing only FPGA registers); py/hugo.py
  lock_status and osc.acq_done(); control_hugo.py launch_lock() / lock_now() / release_lock() / lock_status()
- Tests (lock_in+pid_harmonic2/test/): xsim lock_ctrl_sim.sh and lock_bus_read_sim.sh; node lock_ctrl_ui_sim.js,
  lock_capture_ui_sim.js, trig_input_units_sim.js, config_load_window_sim.js, trig_from_graph_sim.js;
  auto_set_c_sim/run.sh (controller C on the PC)

Documentation (after v2.4.4, no change of code)
- ADDED doc/App.md, doc/Usage.md, doc/Structure.md (Mermaid diagrams), doc/FPGA.md (the 102 registers of this App,
  checked against lock.v), doc/Remote.md, doc/Devel.md, based on the documentation of lock_in+pid_harmonic 2.3.17
  and adapted to the two lock-ins; screenshots in doc/.Usage/ and doc/.Remote/
- CHANGED doc/README.md is now an index (its old register table, of an older lock.txt, is replaced by doc/FPGA.md);
  README.md rewritten (summary of 2.4.x, documentation table, installation, building, license); the detailed
  requirements moved to doc/Devel.md and the version history stays in this file

v2.4.5
- Port of the minor fixes of lock_in+pid_harmonic v2.3.18 (no FPGA change: the image is the one of v2.4.4, only
  comments of lock.v changed; the "v2.3.18" in the comments of the sources is that of lock_in+pid_harmonic)
- FIXED lock trigger registers written from Python (py/lock_from_registers.py --time/--level/--sw, control_finn.py):
  lock_trig_val / lock_trig_time / lock_trig_sw follow the rule of lock_control: the C writes each one only when its
  parameter changes and copies a value written from outside to the parameter (the page shows it and keeps it; before,
  it was not shown and the page value was written back at the next change of any lock parameter)
- FIXED Config -> load sent read-only parameters of the server (meas_*, lock_X/Y/X2/Y2, lock_lock_status,
  lock_lock_control, trig_delay, ...): skipped (server_ro_keys, the read-only list of src/main.c of this App)
- FIXED Single mode made no request at all after its acquisition (a bazaar?stop, e.g. after Prepare Streaming, or
  another client was not noticed, the lock label was not refreshed): 1 s polling in Single; an AGAIN answer starts
  the fast polling only while a Single click waits for its acquisition
- FIXED console "Capture Lock: ended by , scope settings restored" (the reason is given); mouse wheel on Ramp period /
  limits, PID, phases A/B, modulation and lock trigger fields updates the text below them; X+ of the plot range up
  to 68.72 s (it stopped at 10 s)
- FIXED py/lock_from_registers.py: --time clamped to 0..2^32-1 ticks with a message (40s gave OverflowError), ns/us
  accepted, --sw 0..15, docstring (--sw is "Signal for trigger": 0 error, 1 Xo, 2 Yo, 3 X2o, 4 Y2o, 5 F3o, 6-8 are 0)
- FIXED example_usage.py: the Lock cell restores the two lock-ins and PID A of lock_in+pid_harmonic2__lock_mode.json
  (phase A 0, phase B 630; RESTORE_LOCK_MODE = False prints a warning instead), and "save data" ends with
  rp.scope_auto() (the script left the scope of the page in Single)
- FIXED upload_app.sh: rw script of the OS as the Makefile (/opt/redpitaya/sbin/rw or /boot/sbin/rw), -w removed
  {index.html,js.css} (js,css), fpga.sh exec bit
- CHANGED c/streaming.c: its "Finishing streaming" message no longer ends with ": Success" (perror with errno 0);
  c/stream_tcp_osc_cmd runs with nice -10 and locked memory (fewer lost samples at decimation 128 with activity on
  the board, e.g. an ssh login; STREAM_NICE=<n> changes it)
- CHANGED AUTO: minimum window 1 us (was 100 ns: with noise only it gave 0...139 ns)
- CHANGED texts: "Signal for trigger" 6-8 "0 (sqXo)"..; ctrl_B = pidB_out + ramp_B (lock.v, fpga_lock.h, main.c,
  config_tool.py); 20-bit decimation in src/fpga.h and fpga/README.md; resources/README.md (read with name= or name);
  doc/lock_control.md and doc/Remote.md (trigger registers written from outside)
- Tests: test/minor_ui_sim.js (new), lock_capture_ui_sim.js part 7 (Single polling), config_load_window_sim.js
  (no read-only key sent), auto_set_c_sim parts 4 and 5

v2.4.6
- FPGA timing (port of lock_in+pid_harmonic v2.3.19, the user allowed adding latency): WNS -9.618 -> -1.281 ns,
  TNS -9950 -> -510 ns, 4927 -> 996 failing endpoints (reset recovery -1.608 -> +0.414 ns). Pipeline registers in the
  long combinational chains of the loop; same behaviour except for the latencies (bit by bit in simulation against
  v2.4.5). Details and latency of each signal: lock_in+pid_harmonic2/doc/lock_latency.md
- CHANGED (FPGA, added latency, 8 ns per clock): generator outputs +1 (gen_mod_h2 wrapper with registered outputs);
  Xo, Yo, X2o, Y2o +2 (demodulation_line: register after the first LPF stage and output register); bus X_28..Y2_28
  +1; PID outputs +1; out1/out2 +1. LOCK MODE loop +32 ns
- CHANGED (FPGA): the references reach the two lock-ins 1 clock later than the outputs, so the phase measured
  through DAC -> system -> ADC does not change (lock_in+pid_harmonic 2.3.19 does not have this compensation)
- CHANGED (FPGA, same values): shift_sat14 in demodulation_line, sat14 without barrel shifter, PID integrator with
  the ISR shift in parallel, sum_div of the second LPF stage in a register; sg_amp1 connected as {1'b0, sg_amp1}
- CHANGED page title (h2.page-title) and <title> get the version of info/info.json at build time (Makefile)
- ADDED test/lock_latency_sim.sh + test/lock_latency_tb.sv (xsim, 406 checks against v2.4.5)
