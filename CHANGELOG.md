
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
