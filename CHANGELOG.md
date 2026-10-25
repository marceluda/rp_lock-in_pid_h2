
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

v2.4.7
- Port of lock_in+pid_harmonic v2.3.21 (Reset zoom), v2.3.22 (mouse wheel) and v2.3.23 (slow scans, FPGA lock_ctrl.v);
  see its CHANGELOG for the details and the board tests. New FPGA image. "v2.3.2x" in the comments are those of
  lock_in+pid_harmonic. The two lock-ins, their register map and the lock control are not changed.
- ADDED Reset zoom: X from t = 0 to one period of the ramp (Ext Trig = Scan floor / Scan ceil: sawtooth
  (high-low+1)*(step+1), triangle 2*(high-low)*(step+1) ticks), one period of the modulation shared by both lock-ins
  (harmonic mod.: 2520*(hp+1) ticks, gen_mod_h2.v) or one whole memory at the current Dec (other Ext Trig); periods
  >= 1.5 s: 0.98 x the period (at least 50 ms before the next trigger). Y to -1..1 V (raw mode -8192..8192). During a
  lock capture it first ends it (as AUTO); the Raw Mode button rescales Y
- CHANGED the "Square mod." Ext Trig is no longer in the trigger menu (not implemented in this App: always 0 in the
  FPGA); also removed from resources/config_tool.py, labelled "0 (Square mod.)" in control_finn.py
- ADDED mouse wheel on the scope: no key zooms both axes, SHIFT only time (cursor ew-resize), ALT only the Y axes
  (cursor ns-resize, no POST); X window 20 ns .. 68.7 s; local zoom during a lock capture; xmin/xmax sent without
  rounding to 2 decimals (a fast zoom from s to ms sent 0/0)
- FIXED slow scans (windows >= 1.5 s): new long-acquisition reader in src/worker.c (rp_osc_long_rd_*: never a sample
  of an older lap of the scope memory or from before the history, adc_we_cnt register 0x2C, OK only when complete,
  ends at the window of the user); Capture Lock holds the lock request until the scope has enabled its trigger
  (lock_request_* in src/lock.c, the POST answers at once); read-only params scope_gen, scope_acq_state,
  scope_acq_gen, sig_gen (PARAMS_NUM 211 -> 215); page: capture recognised by sig_gen, partial traces drawn,
  banners, real "LOCKED but not captured"; Reset zoom clears stale traces
- FIXED (FPGA, lock_ctrl.v): the time trigger counter is valid (cnt_ok) only from a floor of a ramp that has been
  running since then (new input ramp_run = ramp_enable & ~ramp_reset) and it saturates instead of wrapping every
  34.4 s: a time (or level+time) request armed after a stop fires at the next floor + time, never mid-scan. Adapted
  to the registered trigger inputs of this App (v2.4.4): cnt_ok is set with ramp_trigger_r and delayed once for
  level+time; with the ramp running the lock fires in the same clock as before. time_eq is built from lock_trig_time-1
  and two flags in registers (the saturation inside cnt_next would lengthen the comparison path, -0.26 ns in
  lock_in+pid 2.2.9); same value every clock (lock_ctrl_tb.v checks it against cnt_next == lock_trig_time)
- example_usage.py: note about time / timeout for slow ramps
- Tests: new test/reset_zoom_sim.js (29), test/plot_wheel_sim.js (59), test/ramp_mod_period_sim.sh (ramps and
  gen_mod_h2 2520*(hp+1), 10); lock_capture_ui_sim.js section 8 (79), auto_set_c_sim sections 6-9 (44),
  lock_ctrl_tb.v cases 16-19 and the time_eq monitor (46)

v2.4.8
- Port of lock_in+pid_harmonic v2.3.24 (web page only: no FPGA, no controller change). X|Y is lock-in A (Xo, Yo); X2o/Y2o of lock-in B are not in the fixed presets (the `usr` dialog offers every signal of the selects, X2o/Y2o included).
- ADDED presets of the scope signals: six small buttons below Ext Trig (two rows of three, 42x20 px, 10 px bold):
  blue in1|in2, in1|ctrl (ctrl_A), X|Y (Xo, Yo of lock-in A); green in1|err (error), ctrl|err (ctrl_A, error) and usr.
  A click sets OscA/OscB (mux 1, 2, 3, 4, 17, 18) as the two selects do: one POST with only lock_oscA_sw / lock_oscB_sw
  (plus single_btn/xmin/xmax unchanged); zoom, trigger and Capture Lock untouched; tooltips name the two signals
- ADDED usr preset: double click (or a click while not configured, dashed border) opens a dialog with all the
  signals of the selects (default the first time: PID A out | error); Accept saves it in localStorage
  (oscUsrPreset_lock_in+pid_harmonic2) and in the configs (Config save / download json, ui.ui_osc_usr_a/b, never sent to the
  server); Config load of a config with it takes it, older configs keep the current pair
- CHANGED picking an Ext Trig other than the current one and not None sets the Trigger panel to Source = External,
  Mode = Normal in the same POST (from Single the page polls again); None changes nothing else; Config load, the end
  of a Capture Lock, Reset zoom and AUTO do not apply it; during a Capture Lock it ends it, then one POST
- Tests: new test/osc_presets_sim.js (37; the page of 2.4.7 fails 32); config_load_window_sim.js: stub of
  oscUsrConfigLoad()

v2.4.9
- Port of lock_in+pid_harmonic v2.3.26 (no FPGA change)
- CHANGED (controller, src/worker.c) Auto waits for the trigger like Normal (Ext Trig with Source External, or the level
  of a channel) and forces the acquisition only if no trigger came within max(0.25 s, 1.1 x window + 50 ms, 1.1 x period
  of the Ext Trig + 50 ms), at most 80 s; the period is known for Scan floor / ceil with the scan running (Scan enable,
  no reset, lock_status bit 4) and for harmonic mod. (2520 x (hp+1) cycles). Up to 2.4.8 Auto triggered at once (trig_imm): t = 0 at any phase of
  the scan even with Ext Trig = Scan floor (testAgent 2026-10-19, sq). Normal, Single, Capture Lock, AUTO, the Auto
  window (from the trigger) and the long acquisitions unchanged; a 30 s scan in Auto acquires every scan from its floor
- CHANGED the trigger Level field / line / slider are enabled in Auto too; the "Choose from graph" warning accepts Auto
- CHANGED "Don't turn on PIDs and Ramp on config loading" (#load_config_block_start) is unchecked by default (it was
  checked): Config load / Load file and the restore after a start / Restart set the ramp enable, Scan enable
  (lock_ramp_enable) and the PID A/B enables as saved; checked, they are set to 0 as before. Lock requests (lock_now,
  launch_lock_trig) and stream_cmd are never loaded (state_transient_zero)
- CHANGED the option is not saved anywhere: every page load starts unchecked (autocomplete="off", variable synced
  from the checkbox)
- CHANGED <title> / page title of the source index.html (said v2.4.7)
- Tests: new test/config_load_block_sim.js (10; the page of 2.4.8 fails 6); test/auto_set_c_sim/harness.c section 10
  (SIM_AUTO=1): Auto + Scan floor only floors, scan stopped forced every ~0.40 s, 3 s scan in 0..0.1 s only floors, Normal
  without trigger nothing (the src of 2.4.8 fails 10.1-10.3); 6.1 runs 9 s, section 8 waits 0.6 s

v2.4.10
- Port of lock_in+pid_harmonic 2.3.27 (web page only, no FPGA / C change). Requested by the user (2026-10-20): the App
opened with the parameters of a previous session; the user wants to choose.
- CHANGED: **Lock Control** panel moved right below **Outputs** in the left column (Oscilloscope, Outputs, Lock Control, Lock-in modules, Ramp Controller, PIDs modules, Streaming).
- CHANGED: the state that the page saves automatically (`saveState()`, every ~2 s and after each POST) is now also kept in
  **localStorage** (`lockin_last_state_lock_in+pid_harmonic2`, shared by the tabs, survives closing the browser): the **last config**.
  The tab state (`sessionStorage`, used by *Restart*) is kept as before.
- ADDED (Config dialog) checkbox **Load last config on init** (`#load_last_on_init`), **checked by default**, saved in
  localStorage (`lockin_load_last_on_init_lock_in+pid_harmonic2`). When the page starts the App (main menu, new tab, F5): checked, the
  last config is restored; unchecked, only `def_params` are sent (defaults of `src/main.c`). Ramp / PIDs of a restored
  config follow *Don't turn on PIDs and Ramp on config loading*; lock requests are never restored.
- ADDED (Config dialog) buttons **Load last config** and **Reset to defaults**: they close the dialog and restart the App
  (reload; stopped and started as when it is opened, FPGA reloaded) with the last config / with the defaults, whatever
  the checkbox says. Reset to defaults = a fresh App (no table of defaults in the page), lock open, no lock request.
- ADDED hold (`lockin_last_hold_lock_in+pid_harmonic2`): opened with the defaults, the last config is kept until the user changes a
  parameter (time window / Y axis alone do not count), so *Load last config* brings it back.
- *Restart* (took control, error dialogs) and the automatic restarts still restore the tab state; an App already running
  when the page opens keeps its state (stopped and started for Load last config / Reset to defaults).
- Tests: new `test/last_config_sim.js` (35 checks; the page of 2.4.9 fails). The other node tests unchanged and passing.

v2.4.11 - 2026-10-20 - Quick trigger buttons time / level / time+level in Lock Control; fixed lost time/level and re-lock with a POST in flight (as lock_in+pid_harmonic 2.3.28)
- Port of lock_in+pid_harmonic 2.3.28 (web page only, no FPGA / C change; same code, the lock trigger options and
the Choose from graph / Fire on click code of this App are the same as there). Requested by the user (2026-10-20).
- ADDED: **Lock Control**: three small buttons stacked between **Trigger Lock** and **Lock Now**: **time** (orange),
  **level** (blue), **time+level** (purple). A click on one of them sets the lock trigger type (Time trigger / Level
  Trigger / Level+time Trigger) and waits for a click on the graph, as *Choose from graph* (the *config* section is not
  opened): the button stays filled, the cursor over the scope is a crosshair and a short message
  (`#lock_quick_trig_msg`) is drawn over the rows below (state label, checkboxes) without moving the panel. The click
  on the graph sets the type and the time (from the scan floor) and / or the level and fires **Trigger Lock** at once
  (whatever *Fire on click* says), with **Capture Lock** if it is checked. Nothing is sent while waiting (an ARMED /
  LOCKED lock is kept until the click, then released and armed again). A 2nd click on the same button, Esc or
  *Choose from graph* cancel; another of the three buttons changes the type.
- CHANGED: layout of that row: *Trigger Lock*, the column of the three buttons and *Lock Now* are one centered flex row
  (column as tall as the big buttons, which are a bit larger: 16 px font, 60 px high); a container query makes all of
  them a bit smaller in a narrow left column (row < 235 px, e.g. 1366 px wide windows).
- FIXED: a click with *Choose from graph* + *Fire on click* while another POST was in flight lost the new time / level
  (`loadParams()`, `trigger_just_set`, wrote them as already sent; Trigger Lock fired with the old values). Now only
  the values already sent are protected; pending ones are sent after that POST.
- FIXED: with the lock LOCKED and a POST in flight at the click on the graph, neither the release nor the new request
  was sent (the send queued during a POST runs 100 ms after its answer and `lockWhenIdle()` did not wait for it). Now
  it is kept in `send_que_timer` and `lockWhenIdle()` waits for it: the release goes first, then the request.
- Tests: new `test/lock_quick_trig_sim.js` (57 checks, harness of `lock_capture_ui_sim.js`; the page of 2.4.10 fails 51).
  The other node tests unchanged and passing.

v2.4.12 - 2026-10-24 - Raw Mode: scope trigger level in ADC counts (C controller + web page, no FPGA change; as lock_in+pid_harmonic 2.3.29)

Port of lock_in+pid_harmonic 2.3.29 (same code in this App). Bug found in `rp_dummy2` (which inherited this code),
present in all earlier versions: with **Raw Mode** on, the *Level* of the scope trigger did not work.
- FIXED (C controller): in Raw Mode the page sends the level in ADC counts, but the controller passed it to
  `osc_fpga_update_params()`, which converts **volts** to counts: 100 counts were taken as 100 V and the threshold
  saturated (8191 minus the calibration offset; −3000 even wrapped to a positive threshold), so Normal / Single never
  triggered for a level other than 0. Now `rp_osc_trig_level_v()` (`src/worker.c`) turns the counts into the voltage
  that `osc_fpga_cnv_v_to_cnt()` maps back to exactly those counts (`osc_fpga_cnv_cnt_to_trig_v()`, `src/fpga.c`, with
  the calibration offset of the input selected by OscA / OscB and the user offset). A level beyond 8191 − calibration
  offset saturates there, as in volts mode.
- FIXED (C controller): AUTO in Raw Mode: the level of its search left the calibration offset out, its result (counts)
  was then applied as volts, and its Y range (counts) was scaled and clipped to ±1000 (`min_y` / `max_y` (`_norm`)
  limits, now ±20000; not scaled in Raw Mode). Volts mode unchanged.
- FIXED (web page): *Level* field, slider (and its drag) and trigger line in counts in Raw Mode (whole counts,
  −8192 … 8191; they used the volts scale and ±1), in V otherwise (± full scale); out-of-range values limited before
  sending; unit `counts` / `V` next to the field. The **Raw Mode** button converts the level (counts = V × 8192 / full
  scale at gain 1). *Config → load* of a config with the other Raw Mode sets Y to the Reset zoom range of its mode
  once (its level is not converted). The page opened in Raw Mode starts with Y ±8192 (it was ±1 count).
- Tests: new `test/raw_trigger_sim.js` (45 checks; the page of 2.4.11 fails 31) and `test/trig_level_test.c` (real
  `src/fpga.c`); `test/auto_set_c_sim` section 11 (thresholds written by the real controller in Raw Mode, AUTO in Raw
  Mode; the sources of 2.4.11 fail 6 of its 10 checks); `lock_capture_ui_sim.js`, `lock_ctrl_ui_sim.js`,
  `osc_presets_sim.js` load the new `[RAW TRIGGER]` block.

v2.4.13 - 2026-10-24 - AUTO trigger level at the middle of the signal with a calibration offset or a full scale other than 1 V; Raw Mode half counts (C controller; page: version and comments only; no FPGA change; as lock_in+pid_harmonic 2.3.30)

Port of lock_in+pid_harmonic 2.3.30 (same code in this App). Issues of the AUTO found in the review of v2.4.12 (the half
count was seen on RP2 by testAgent, 2026-10-24 21:44; the other two do not show on RP1 / RP2).

- FIXED (C controller): **AUTO in volts with a calibration offset** (`fe_chX_dc_offs` of the input, from the EEPROM;
  RP2's are 0): the AUTO measures the signal with samples corrected by the offset, but the threshold registers compare
  raw samples. The threshold of its period search added the offset a second time (one offset **above** the middle),
  and the level it left had no offset at all (threshold and page line one offset **below** the middle of the trace).
  Now both are the middle of the signal in raw counts, and the level is the normalized voltage that the acquisition
  path turns into that threshold (`osc_fpga_cnv_cnt_to_trig_v()` with the calibration and user offsets): the *Level*
  shown by the page is the middle of the trace. Its period search compares raw samples with raw limits (a signal
  smaller than the offset gave no period) and its Y range no longer mixes raw and corrected counts.
- FIXED (C controller): **AUTO in volts with a normalized full scale other than 1 V** (`fe_ch1_fs_g_hi` of the EEPROM;
  RP1 / RP2 have exactly 1 V, a typical factory calibration ~1.07 V): the level and the Y range were stored as
  counts / 8192, but a normalized value is counts × full scale / 8192 (the acquisition converts the level with that
  full scale, the page multiplies by chX full scale / that full scale): both were scaled by 1 / full scale (~7 %).
- With offsets 0 and a full scale of 1 V (RP1 / RP2) the volts AUTO gives the same result as before.
- FIXED (C controller): **Raw Mode, half counts**: the AUTO left a level of half a count (e.g. −2.5) that the page
  showed as −2 (`Math.round`) while the controller wrote −3 (`roundf`). Now the AUTO gives a whole count rounded as the
  page, and `osc_fpga_cnv_cnt_to_trig_v()` rounds a level with a fraction (e.g. from a remote client) the same way
  (`floor(x + 0.5)`): the Level field and the threshold register always agree.
- Tests: `test/auto_set_c_sim` section 11, new checks 11.10-11.16 (calibration offset 585 and normalized full scale
  0.6543 V of the harness: volts AUTO threshold of the search and of the acquisitions that follow at the middle, level
  shown by the page = middle of the trace, Y range in V, Raw AUTO with a middle of −2.5 → −2 in level and register,
  half counts from a remote client; with the sources of v2.4.12, 6 fail: 11.13 already passed);
  `test/trig_level_test.c`: levels with a fraction (±0.25, ±0.5, ±0.75) give the count the page shows (with the
  `src/fpga.c` of v2.4.12, 64004 fail); `test/raw_trigger_sim.js`: section 9 (page and controller round half counts
  the same way) and code checks 8.4, 8.6-8.9 (53 checks; with the sources of v2.4.12, 5 fail).
