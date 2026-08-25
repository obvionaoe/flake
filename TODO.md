# TODO

- openlogi: chase a faster upstream fix for the cold-start HID++ node-probe
  cadence (`openlogi_hid::inventory`'s "node probe keeps failing — retiring
  its channel before reopen" retry loop). Not a bug — it already self-heals
  — but after a full reboot it took ~52s (5 retries, ~8s apart) for
  gestures/DPI to come back, vs ~21s after a plain sleep/wake, because a
  cold BLE reconnect is slower than resuming an already-negotiated link.
  See modules/shared/openlogi/default.nix and mx-master-4-gesture-fixes.patch
  for the two related, already-patched bugs in the same area.
