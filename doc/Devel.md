# Development: building and modifying the App

How to build, modify, test and install `lock_in+pid_harmonic2` v2.4.8 (branch `master`). The internal
structure is explained in [Structure.md](Structure.md) and the registers in [FPGA.md](FPGA.md).

The build system, the C controller, the `c/` tools and the tests are those of `lock_in+pid_harmonic` 2.3.17
(project `rp_lock-in_pid_h`) with the names of this App, without the DEBUG / RELOAD flavours (removed in v2.4.3),
and with the streaming offsets generated from `c/lock.txt`.

- [Source tree](#source-tree)
- [Software requirements](#software-requirements)
- [Building everything](#building-everything)
- [Makefiles and targets](#makefiles-and-targets)
- [C controller (`controllerhf.so`)](#c-controller-controllerhfso)
- [Tools of `c/` (`lock`, `osc`, streaming)](#tools-of-c-lock-osc-streaming)
- [FPGA (Vivado 2020.1)](#fpga-vivado-20201)
- [Web interface (`index.html`)](#web-interface-indexhtml)
- [Registers and `config_tool.py`](#registers-and-config_toolpy)
- [Simulations and tests (`test/`)](#simulations-and-tests-test)
- [Installing on the board](#installing-on-the-board)
- [Versioning and packages](#versioning-and-packages)

## Source tree

```
rp_lock-in_pid_h2/
├── Makefile                 # all = App build + zip + tar into archive/
├── settings.sh              # environment for the C build (Linaro; Vivado 2015.2 only if present)
├── _build_number            # BUILD_NUMBER=N (incremented by make clean_*), not versioned
├── README.md  CHANGELOG.md  CITATION.cff  LICENSE (GPL-3.0)  TODO.md
├── doc/                     # this documentation
├── archive/                 # built packages (*.zip, *.tar.gz), not versioned
├── resources/
│   ├── config_tool.py       # register table -> code generator (see below)
│   ├── doc_tool.py
│   ├── remote_control/http_version/   # control_finn.py, example_usage.py (HTTP API client, two lock-ins)
│   ├── remote_control/shh_version/    # SSH client (deprecated)
│   ├── streaming/           # TCP receiver for the streaming (server.c, read_bin.py)
│   ├── process_web_download/, rp_cmds/, code_helpers/ (muxer generator, sin/cos tables)
│   └── README.md            # streaming and remote control notes
└── lock_in+pid_harmonic2/   # the App (this folder is what is installed on the board)
    ├── Makefile             # controller, c tools, FPGA, target/, zip, tar, upload
    ├── index.html           # web interface (HTML + JS in one file)
    ├── css/  js/            # styles, jquery.mousewheel, js.cookie
    ├── info/info.json       # name ("Harmonic TWO Lock-in+PID") and version; icon.png
    ├── nginx.conf           # extra HTTP endpoints (Lua): /lock, /osc, /streaming, ...
    ├── fpga.sh              # Ecosystem 2.0: loads fpga.bit.bin with fpgautil when the App starts
    ├── fpga.conf            # path of the .bit (Ecosystem 0.9x)
    ├── fpga.bit.bin, red_pitaya.bit, fpga.bit   # FPGA images (built, versioned)
    ├── controllerhf.so      # C controller (built, versioned)
    ├── src/                 # C controller sources
    │   ├── main.c / main.h  # parameter table (211), rp_set_params / rp_get_params / rp_get_signals
    │   ├── worker.c / .h    # scope worker thread, auto-set, measurements
    │   ├── fpga.c / fpga.h  # scope registers (0x40100000)
    │   ├── lock.c / .h, fpga_lock.c / .h   # lock registers (0x40600000, map of this App)
    │   ├── calib.c, generate.c, fpga_awg.c, pid.c, fpga_pid.c   # from the original scope App
    │   └── Makefile
    ├── c/                   # tools run on the board: lock, osc, streaming, stream_tcp_osc_cmd
    │   ├── *.c, Makefile, lock.txt, osc.txt, load_bit.sh, stream_start.sh
    │   └── lock_offsets.h   # generated from lock.txt by c/Makefile (not versioned, packaged)
    ├── py/                  # Python scripts run on the board (hugo.py, lock_from_registers.py, ...)
    ├── fpga/                # FPGA project (Vivado 2020.1, RedPitaya-FPGA structure)
    │   ├── Makefile  README.md  red_pitaya_vivado_Z10.tcl  synCheck.sh
    │   ├── rtl/rtl/         # common Red Pitaya RTL (classic/rp_scope_*.v, rp_decim.v modified by the App)
    │   ├── prj/v0.94/rtl/   # red_pitaya_top.sv, red_pitaya_ps.sv, lock.v, lock/*.v (gen_mod_h2.v, demodulation_line.v, ...)
    │   ├── prj/v0.94/{ip,sdc}, prj/barebones/ip, sdc/, brd/
    │   └── prj/v0.94/out/   # build products (not versioned)
    ├── doc/                 # design notes: lock_control.md, lock_capture.md (+ Doxygen setup)
    ├── test/                # simulations (xsim, node, native C)
    ├── upload_app.sh        # upload a package to a board through SSH
    └── target/              # staging folder for the packages (built, not versioned)
```

## Software requirements

| Tool | Version | Used for | Path on the development PC |
|---|---|---|---|
| Xilinx Vivado | **2020.1** | FPGA (synthesis, implementation, `bootgen`, xsim) | `/tools/Xilinx/Vivado/2020.1` (`VIVADO_SETTINGS`) |
| Linaro ARM toolchain | gcc-linaro-4.9-2015.02-3 (or 2014.11) `arm-linux-gnueabihf` | cross compiling the controller and the `c/` tools | `/opt/linaro/` |
| Xilinx Vivado 2015.2 | optional | sourced by `settings.sh` only if present (the 0.4.x series built the FPGA with it) | `/opt/Xilinx/Vivado/2015.2` |
| GNU make, zip, tar, sed, awk | — | build and packaging (`awk` generates `c/lock_offsets.h`) | — |
| node.js | any recent | UI simulations in `test/` | — |
| gcc (PC) | — | `test/auto_set_c_sim` | — |
| Python 3 + numpy | — | `resources/config_tool.py`, remote control | — |

Installation notes (kept from the README of the 0.x series):

```bash
# development packages
sudo apt-get install make u-boot-tools curl xz-utils nano zip
# Linaro toolchain in /opt/linaro (settings.sh looks for 2015.02-3 or 2014.11)
TOOLCHAIN="http://releases.linaro.org/15.02/components/toolchain/binaries/arm-linux-gnueabihf/gcc-linaro-4.9-2015.02-3-x86_64_arm-linux-gnueabihf.tar.xz"
curl -O $TOOLCHAIN
sudo mkdir -p /opt/linaro && sudo chown $USER:$USER /opt/linaro
tar -xpf *linaro*.tar.xz -C /opt/linaro
# Vivado needs a gmake executable
sudo ln -s /usr/bin/make /usr/bin/gmake
# 32-bit libraries needed by old toolchains on 64-bit Ubuntu
sudo apt-get install libc6-dev-i386
```

Vivado 2020.1 is installed from the Xilinx installer. The build was done on Ubuntu 24.04 x86_64.

Load the C environment:

```bash
cd rp_lock-in_pid_h2
source settings.sh          # sources Vivado 2015.2 if present, adds Linaro to PATH,
                            # exports TOOLCHAIN_PATH and CROSS_COMPILE=arm-linux-gnueabihf-
```

The FPGA Makefile loads Vivado 2020.1 by itself in a clean environment (`env -i`), so it does not matter
whether `settings.sh` was sourced.

## Building everything

```bash
cd rp_lock-in_pid_h2
source settings.sh
LANG=C make
```

This builds the controller, the `c/` tools and, if any FPGA source changed, the FPGA, then `target/` and the
packages `archive/lock_in+pid_harmonic2-<version>-<build>-devbuild.{zip,tar.gz}`. The full build of v2.4.4
(`make clean && LANG=C make`) took 29 min, exit 0, 0 gcc warnings (`devAgent.md` 2026-10-11 05:22).

A typical rebuild after changing only C or the web page (FPGA untouched, ~10 s):

```bash
source settings.sh
make -C lock_in+pid_harmonic2 clean_app && LANG=C make
```

`clean_app` and `clean_fpga` increment the build number in `_build_number`.

## Makefiles and targets

Root `Makefile`:

| Target | Action |
|---|---|
| `make` / `make all` | `make -C lock_in+pid_harmonic2 all zip tar` (packages in `archive/`) |
| `make clean` | `make -C lock_in+pid_harmonic2 clean` |
| `make upload` | `make -C lock_in+pid_harmonic2 upload` |

`lock_in+pid_harmonic2/Makefile`:

| Target | Action |
|---|---|
| `all` | `controllerhf.so` + `c_tools` + `fpga` |
| `app` | `controllerhf.so` + `c_tools` |
| `controllerhf.so` | `make -C src` (only the App itself; the DEBUG / RELOAD flavours were removed in v2.4.3) |
| `c_tools` | `make -C c all` (cross compiled `lock`, `osc`, `streaming`, `stream_tcp_osc_cmd`; generates `c/lock_offsets.h`) |
| `fpga` | `red_pitaya.bit` (from `fpga/`), `fpga.bit` (copy) and `fpga.bit.bin` (bootgen) |
| `target/lock_in+pid_harmonic2` | staging of the installable folder (also copies `upload_app.sh`, `resources/`, README, CHANGELOG; sets the version in `info.json` and `index.html`; `fpga.sh` 755; removes `__pycache__`/`*.pyc`) |
| `zip`, `tar` | packages in `../archive/` |
| `clean`, `clean_app`, `clean_fpga`, `clean_target` | clean all / C (`src`, `c`, `*.so`, target) / FPGA / target |
| `upload`, `upload_bit`, `upload_html`, `upload_py` | copy to the board by SSH (needs `RPIP`, on the command line or in `../_settings.env`; `check_rpip` stops if it is empty). They depend only on `target/`, make the file system writable with the `rw` script of the OS (`/opt/redpitaya/sbin/rw` with `PATH_REDPITAYA` exported on 2.0, `/boot/sbin/rw` on 0.9x), `upload` keeps `fpga.sh` at 755 and `upload_bit` also sends `fpga.bit.bin`. Never run by the build |

Settings file `_settings.env` (root, not versioned), read by both Makefiles:

```make
RPIP=rp-XXXXXX.local
RPOPTS=-l root -p 22
RPSCP=-P 22
```

## C controller (`controllerhf.so`)

- Sources in `lock_in+pid_harmonic2/src/`, `src/Makefile`: `$(CROSS_COMPILE)gcc`, `-Wall -Werror -g -fPIC`,
  linked with `-shared -lm -lpthread`; `VERSION` and `REVISION` come from `info/info.json` and the build
  number through `CFLAGS`.
- Build: `make -C lock_in+pid_harmonic2 controllerhf.so` (with `settings.sh` loaded).
- Compared with `_h` 2.3.17 (names substituted): `worker.c`, `fpga.c` are identical; `main.c` differs only in the
  parameters of the second lock-in (`lock_signal2_sw`, `lock_signal2_i`, `lock_gen_mod_phase_A/_B`, `lock_cos_A`…,
  `lock_X2`, `lock_Y2`) and the end of the RELOAD dock; `lock.c` / `fpga_lock.h` follow the register map of this App.
- To install a new `.so` on a running board: copy it and **stop + start the App**
  (`/bazaar?stop=` then `/bazaar?start=lock_in+pid_harmonic2`), so that nginx loads the new library.
- Debug output (`TRACE`): uncomment `// #define DEBUG 1` in `src/main.h` and rebuild; it goes to the nginx log.

## Tools of `c/` (`lock`, `osc`, streaming)

| Tool | Source | Purpose |
|---|---|---|
| `lock` | `c/lock.c` | read/write the lock registers by name (`/lock_in+pid_harmonic2/lock`) |
| `osc` | `c/osc.c` | read/write the scope registers by name (with `TrgUnlock`), `dump` of both buffers (`/lock_in+pid_harmonic2/osc`) |
| `streaming` | `c/streaming.c` | closes the file descriptors inherited from nginx, waits for `stream_cmd`, launches `stream_tcp_osc_cmd` (`/lock_in+pid_harmonic2/streaming`, through `stream_start.sh`) |
| `stream_tcp_osc_cmd` | `c/stream_tcp_osc_cmd.c` | reads the scope buffers continuously and sends them over TCP: `stream_tcp_osc_cmd <host> <port> <send_min_len>` |

**Streaming offsets (v2.4.3).** `c/Makefile` (l. 29-40) generates `c/lock_offsets.h` from `c/lock.txt`
(`LOCK_STREAM_{IP,PORT,RATE,CMD}_OFF` = 4 · index: 0x188, 0x18C, 0x190, 0x194) and fails if one of the registers is
missing; `streaming.c` and `stream_tcp_osc_cmd.c` include it. Until v2.4.3 build 11 they had the offsets of `_h`
hardcoded and the streaming read `ctrl_B` as the IP. If the register map changes, regenerate `lock.txt` with
`config_tool.py rp_c` and rebuild the tools: the offsets follow. The header is a build product (in `.gitignore`)
but it is packaged, so a native build on the board also works.

**From the development PC (cross compilation).** `c/Makefile` uses `$(CROSS_COMPILE)gcc` with its own flags
(`-g -std=gnu11 -fstack-protector-strong`, plus `-Wno-overflow` for `lock`/`osc`):

```bash
cd rp_lock-in_pid_h2
source settings.sh                        # CROSS_COMPILE=arm-linux-gnueabihf-
make -C lock_in+pid_harmonic2 c_tools     # or: make -C lock_in+pid_harmonic2/c all
make -C lock_in+pid_harmonic2/c clean
```

**On the board.** With `CROSS_COMPILE` empty the same Makefile uses the native `gcc`:

```bash
ssh root@rp-XXXXXX.local
export PATH_REDPITAYA=/opt/redpitaya; /opt/redpitaya/sbin/rw     # read-write file system (Ecosystem 2.0)
cd /opt/redpitaya/www/apps/lock_in+pid_harmonic2/c
make clean && make all
```

Whether RedPitaya_OS 2.04 ships `gcc` and `make` has **not been checked (a confirmar)**; cross compilation is the
supported way.

## FPGA (Vivado 2020.1)

`lock_in+pid_harmonic2/fpga/` follows the structure of
[RedPitaya-FPGA](https://github.com/RedPitaya/RedPitaya-FPGA) (project `v0.94`, model `Z10`). It is the `fpga/`
of `lock_in+pid_harmonic` with the `lock` module of this App: `prj/v0.94/rtl/lock.v`, `lock/gen_mod_h2.v` and
`lock/demodulation_line.v` (the tcl adds all of `lock/`; the generator reads `data_cos_ss.dat` /
`data_sin_ss.dat` with `$readmemb`). Details: `fpga/README.md`.

```bash
cd rp_lock-in_pid_h2/lock_in+pid_harmonic2/fpga
make            # prj/v0.94/out/red_pitaya.bit + prj/v0.94/out/fpga.bit.bin (bootgen)
make bit        # only the bitstream
make bin        # only fpga.bit.bin from an existing red_pitaya.bit
make project    # create prj/v0.94/build/redpitaya.xpr and open it in the Vivado GUI (no synthesis)
make clean      # remove the build products of PRJ
make help
```

Variables: `VIVADO_SETTINGS` (default `/tools/Xilinx/Vivado/2020.1/settings64.sh`), `PRJ` (`v0.94`),
`MODEL` (`Z10`), `DEFINES`. Any change in `rtl/`, `prj/v0.94/{rtl,ip,sdc}`, `sdc/`, `brd/` or the tcl
rebuilds the bitstream. After a build `synCheck.sh` writes a report (timing, critical warnings) to
`prj/v0.94/out/`; the log is `prj/v0.94/out/vivado.log` (v2.4.4: 0 ERROR, 54 CRITICAL WARNING of the same types
as `_h`).

From the App folder, `make fpga` builds through this Makefile and copies `red_pitaya.bit`, `fpga.bit` and
`fpga.bit.bin` to the App. On Ecosystem 2.0 only `fpga.bit.bin` is used (by `fpga.sh`).

Where to change things:

| What | File |
|---|---|
| Lock module (registers, muxers, outputs) | `prj/v0.94/rtl/lock.v` (bus decoder generated by `config_tool.py`) |
| Generator of the references (`cos_ref`, pairs A and B) | `prj/v0.94/rtl/lock/gen_mod_h2.v`; tables `lock/data_*_ss.dat` (`resources/code_helpers/gen_sin_cos.py`) |
| Demodulation (multiplier, filters, gain) | `prj/v0.94/rtl/lock/demodulation_line.v`, `LP_filter3.v` |
| Submodules (PID, ramp, lock control) | `prj/v0.94/rtl/lock/*.v` |
| Connections to ADC/DAC/scope/PWM/DIO | `prj/v0.94/rtl/red_pitaya_top.sv` |
| Scope (decimation, `osc_ctrl_i`, bus read) | `rtl/rtl/classic/rp_scope_com.v`, `rp_scope_cfg.v`, `rp_decim.v` |
| Constraints | `sdc/red_pitaya.xdc`, `prj/v0.94/sdc/` |

Timing since v2.4.6: almost closes (WNS −1.281 ns, TNS −510 ns, 996 endpoints; v2.4.7 −1.214 ns, `devAgent.md`):
pipeline registers in the long chains of the loop ([`lock_latency.md`](../lock_in+pid_harmonic2/doc/lock_latency.md)).
The rest of this section is the state of v2.4.4.

Timing of the image of v2.4.4 (`devAgent.md` 2026-10-11 05:22, problem 62): does not close, as in all the
designs of the family; the App works. WNS −9.618 ns (scope multiplexers), TNS −9950 ns, 4927 failing endpoints;
WHS +0.051 ns. Bus read: `sys_rdata` +3.296 ns with the 2-cycle multicycle constraint of
`prj/v0.94/sdc/red_pitaya.xdc` l. 82-83; `in1_rd` +4.521, `oscA_rd` +4.687, `lock_status_rd` +4.706 ns. Specific
paths, **a confirmar** whether they matter in practice:

- **14 paths to `signal_now_reg` of `lock_ctrl`** −4.343 ns, from `i_demodulation_line_cos_B/i_LP_filter_1` (the
  lock-in chain before the register; plus `ramp_trigger_r` −0.396). The real fix would be to register the output of
  the lock-in filters (not applied, pending a decision of the user). If the level trigger fired erratically, first
  suspect; it worked in all the tests.
- **Recovery −1.608 ns, 42 endpoints**: the asynchronous reset `adc_rstn_reg` (fanout 514) reaches late the `CLR` of
  the counter of `lock_ctrl`, the debounce of the re-lock and `sys_ack` (in `_h_hf` 2.3.11 +0.893, in `_h` +3.247:
  it depends on place and route). Only the clock in which the reset is released (FPGA load) is affected; the counter
  is reloaded at every scan floor, so no effect is expected. A synchronized / replicated reset for `lock_ctrl` would
  close it (not applied).
- `cos_A_rd`..`sin_B_rd` −0.823 ns (7 endpoints, from the ROM of `gen_mod_h2` without an output register): only a
  bus read of those references (diagnostics), not the loop.

If you add a register to the read mux of `lock.v`, keep it a register of `adc_clk` held during `sys_ren` (as the
`*_rd` copies), or the multicycle constraint is no longer valid ([FPGA.md](FPGA.md#lock-module-0x40600000)).

## Web interface (`index.html`)

- Everything (HTML, CSS overrides, JavaScript) is in `index.html`; it uses jQuery, Bootstrap and Flot from
  the Ecosystem (`../assets/`) and `js/jquery.mousewheel.js`, `js/js.cookie.min.js` of the App.
- The version shown in the title is set when packaging (`var app_version = 'VERSION'` is replaced in
  `target/`): test with the file from `target/`, not from the source folder.
- To try a change on the board without rebuilding the rest: `make -C lock_in+pid_harmonic2 upload_html
  RPIP=rp-XXXXXX.local` (or `upload_app.sh -w <host>` from a package), then reload the page; `nginx.conf` serves
  `index.html` with `Cache-Control: no-cache`.
- Syntax check: extract the scripts and run `node --check`, and run the node simulations of `test/`, which load
  the functions of `index.html`.
- Blocks marked with comments like `[LOCK CAPTURE BEGIN]` / `[TRIG FROM GRAPH BEGIN]` are used by the
  simulations; keep the markers. Functions specific of this App: `warnNaSwitches()` ("(n/a)" options; the
  simulations `lock_ctrl_ui_sim.js` and `lock_capture_ui_sim.js` stub it), `showToast()` (E3), the tolerance of
  failed `GET /data` (`MAX_CONSECUTIVE_FAILS`), the phase B conversion and the tabs LI A / LI B.

## Registers and `config_tool.py`

`resources/config_tool.py` keeps the list of the lock registers (name, width, sign, reset value,
description, UI widget) and of the scope registers, and regenerates the code between "dock" markers:

| Output | Docks |
|---|---|
| `fpga/prj/v0.94/rtl/lock.v` | `[WIREREG DOCK]`, `[FPGA MEMORY DOCK]` (read mux with the `*_rd` copies, `rd_copy` list of this App) |
| `src/fpga_lock.h`, `src/lock.c`, `src/main.c`, `src/main.h` | register struct, `[FPGAUPDATE DOCK]`, `[MAINDEFH DOCK]`, parameter table |
| `index.html` | fields and selectors (with the "(n/a)" options of `NA_SIGNALS`, l. 1635) |
| `c/lock.c`, `c/osc.c`, `c/lock.txt`, `c/osc.txt` | `[LOCKREGS DOCK]`, `[OSCREGS DOCK]`, CSV files (→ `c/lock_offsets.h` at build time) |
| `py/hugo.py` | register tables |

Usage (from inside `rp_lock-in_pid_h2/`): `python3 resources/config_tool.py` (verilog, main, html, py), or with
arguments `verilog|fpga`, `main`, `html`, `py`, `rp_c`, `all`, `clean`. Each run moves the modified files to
`name_YYYYMMDD_HHmmss.ext` backups. In v2.4.4 the docks of `lock.v`, C and py were regenerated with
`config_tool.py verilog main rp_c py`; **the docks of `index.html` were not** (they have hand edits of `_h` 2.3.12+
and of this App): do not regenerate the `html` output without reviewing the diff (`devAgent.md` 2026-10-11 05:22).

After adding or changing a register: run the tool, rebuild FPGA + controller + tools, and update
[FPGA.md](FPGA.md) (and check the names used by `control_finn.py`, `example_usage.py`, `py/`).

## Simulations and tests (`test/`)

| Test | Command | What it checks |
|---|---|---|
| `lock_ctrl_tb.v` | `test/lock_ctrl_sim.sh [work_dir]` (Vivado 2020.1 xsim) | the lock state machine `lock_ctrl.v` (registered inputs; time triggers ≥ 2³¹); prints `TB RESULT: PASS` |
| `lock_bus_read_tb.sv` | `test/lock_bus_read_sim.sh [work_dir [lock.v]]` (xsim) | bus reads of `lock.v` through `sys_bus_cdc` with asynchronous clocks, with the addresses of this App (in1 0x0E0, oscA 0xF0, in2 0xE4, pidA_kp 0x130) |
| `lock_ctrl_ui_sim.js` | `node test/lock_ctrl_ui_sim.js` | UI ↔ controller ↔ FPGA model of the lock control |
| `lock_capture_ui_sim.js` | `node test/lock_capture_ui_sim.js` | Capture Lock, Fire on click, restore, AUTO |
| `trig_from_graph_sim.js` | `node test/trig_from_graph_sim.js` | click → time conversion of *Choose from graph* |
| `trig_input_units_sim.js` | `node test/trig_input_units_sim.js [--old]` | Time / Level trigger fields with units, empty fields not sent as 0 |
| `config_load_window_sim.js` | `node test/config_load_window_sim.js [--old]` | Config → load of the time window |
| `auto_set_c_sim/` | `test/auto_set_c_sim/run.sh [src dir]` | the real C controller compiled for the PC with fake `/dev/mem`: AUTO after a capture, forceX; since v2.4.7 also a model of the circular scope buffer and of the lock pulse (slow windows, Capture Lock with history, time trigger after a stopped ramp) |
| `lock_latency_tb.sv` | `test/lock_latency_sim.sh [work_dir [old_ref]]` (xsim) | `lock.v` of the working tree side by side with the one of v2.4.5: every signal is the old one delayed by the latency of [`lock_latency.md`](../lock_in+pid_harmonic2/doc/lock_latency.md) (v2.4.6); prints `TB RESULT: PASS` |
| `minor_ui_sim.js` | `node test/minor_ui_sim.js [index.html]` | wheel → τ/f text, X+ up to 68.72 s, labels (v2.4.5) |
| `ramp_mod_period_tb.v` | `test/ramp_mod_period_sim.sh [work_dir]` (xsim) | periods of the ramp floor/ceil triggers and of the modulation trigger (2520·(hp+1), `gen_mod_h2`) on the RTL, the formulas used by Reset zoom (v2.4.7); prints `TB RESULT: PASS` |
| `reset_zoom_sim.js` | `node test/reset_zoom_sim.js [index.html] [--old]` | the real `resetZoom()` against a model of the time range code of `src/main.c` (v2.4.7) |
| `plot_wheel_sim.js` | `node test/plot_wheel_sim.js [index.html]` | mouse wheel on the plot: no key / SHIFT / ALT, limits, debounce, Capture Lock (v2.4.7) |
| `osc_presets_sim.js` | `node test/osc_presets_sim.js [index.html]` | the OscA\|OscB presets, the `usr` dialog and the Ext Trig → Trigger panel rule (v2.4.8) |

Run them from `lock_in+pid_harmonic2/`. All exit with code 1 on failure. Results of v2.4.4 (`devAgent.md`
2026-10-11 05:22, `build_logs/rp_lock-in_pid_h2_20261011_0454_v244_sim.txt` in the Apps folder): `lock_ctrl_sim`
35/35, `lock_bus_read_sim` PASS (0/4000; 2000/2000 per channel with the `lock.v` of v0.4.2), `lock_ctrl_ui_sim`
28/28, `lock_capture_ui_sim` 63/63, `trig_input_units_sim` 38/38, `config_load_window_sim` 21/21,
`trig_from_graph_sim` 0 failures, `auto_set_c_sim` 14/14. `control_finn.py` was tested by devAgent against a fake
HTTP server of the board adapted to two lock-ins (54/54 in 2.0 and 0.9x; not in the repository). The older
simulation scripts of the 0.4.x series do not apply to the `index.html` of 2.4.4. Counts reported in the CHANGELOG
for later versions: `lock_latency_sim` 406 checks (v2.4.6); `reset_zoom_sim` 29, `plot_wheel_sim` 59,
`ramp_mod_period_sim` 10, `lock_capture_ui_sim` 79, `auto_set_c_sim` 44, `lock_ctrl_sim` 46 (v2.4.7);
`osc_presets_sim` 37 (v2.4.8). Node tests run by devAgent on 2.4.8 (`build_logs/rp_lock-in_pid_h2_20261016_1635_v248_sim.txt`):
`osc_presets` 37/37, `config_load_window` 21/21, `lock_capture_ui` 79/79, `lock_ctrl_ui` 28/28, `minor_ui` 7/7,
`plot_wheel` 59/59, `reset_zoom` 29/29, `trig_input_units` 38/38, `trig_from_graph` 0 failures (2.4.8 only changed
the web page).

On the board the reference test is the LOCK MODE procedure of `test_files/lock_test.md` (Apps folder), with
`dummy_simulator` on a second board and `test_files/lock_in+pid_harmonic2__lock_mode.json`; reports in
`reportes/lock-in_pid_h2_lock_test/` and `reportes/lock-in_pid_h2.md`.

## Installing on the board

From a package (`archive/*.tar.gz` or `.zip`, or a GitHub release):

```bash
tar -xzf lock_in+pid_harmonic2-2.4.8-<build>-devbuild.tar.gz
./upload_app.sh rp-XXXXXX.local          # -p <ssh port>; -w uploads only index.html, js, css
```

`upload_app.sh` installs an SSH key if needed, makes the file system writable (`/boot/sbin/rw`), replaces
`/opt/redpitaya/www/apps/lock_in+pid_harmonic2/` and copies the App. From the sources: `make -C
lock_in+pid_harmonic2 upload RPIP=rp-XXXXXX.local`. By hand: copy the folder `lock_in+pid_harmonic2/` of the
package (not the source folder) to `/opt/redpitaya/www/apps/` with the file system in read-write mode, keeping
`fpga.sh`, `c/*.sh`, the binaries of `c/` and `py/*.py` executable (as testAgent does).

After installing: open the App page, or stop + start it (`/bazaar?stop=`, `/bazaar?start=lock_in+pid_harmonic2`,
with the `+` literal) if an older version was running. If `nginx.conf` changed, restart nginx
(`systemctl restart redpitaya_nginx`). On Ecosystem 2.0 `reload_fpga` is not supported: restarting the App reloads
the FPGA.

Notes for Ecosystem 2.0:

- In a non-interactive SSH, `rw` needs `PATH_REDPITAYA`: `export PATH_REDPITAYA=/opt/redpitaya; /opt/redpitaya/sbin/rw`.
  The `upload*` targets of the Makefile do so, and `upload_app.sh` since v2.4.5 (`/opt/redpitaya/sbin/rw` on
  Ecosystem 2.0, `/boot/sbin/rw` on 0.9x).
- Each `POST /data` leaves an open connection in the nginx of the board; after long sessions restart it
  ([Remote.md](Remote.md#known-issue-of-the-ecosystem-post-data-leaves-connections-open)).
- Close any browser tab with the main menu of the board before testing: it can relaunch the main menu and
  unload the App.

## Versioning and packages

- Version: `lock_in+pid_harmonic2/info/info.json` (`"version": "2.4.8-BUILD_NUMBER"`), `CHANGELOG.md`, `README.md`
  ("Current version"). Since v2.4.6 the build writes the version of `info.json` in `<title>` and in the page title
  of `target/…/index.html`; the title in the source `index.html` does not matter. Build number: `_build_number`
  (v2.4.8 was built as `2.4.8-20-devbuild`). Revision: `REVISION` (default `devbuild`).
- Package name: `lock_in+pid_harmonic2-<VER>-<BUILD_NUMBER>-<REVISION>.{zip,tar.gz}` in `archive/`.
- Branches: since 2026-10-15 `master` is the 2.4.x line (FPGA Vivado 2020.1, Ecosystem 2.0); the 0.4.x series
  (FPGA Vivado 2015.2, Ecosystem 0.9x/1.0 and first 2.0 support) stays in the tags `v0.4.0` .. `v0.4.2`. Tags
  `v2.4.3` .. `v2.4.8`. `devel2.0` is left as it was and is no longer used. h2 2.4.3 = `_h` 2.3.10-2.3.11 (+ bus fix
  of 2.3.17), 2.4.4 = 2.3.12-2.3.17, 2.4.5 = 2.3.18, 2.4.6 = 2.3.19 (+ the reference delay of 2.3.20),
  2.4.7 = 2.3.21-2.3.23, 2.4.8 = 2.3.24.
- The "v2.3.x" in the comments of the sources are versions of `lock_in+pid_harmonic`, whose changes were ported.
