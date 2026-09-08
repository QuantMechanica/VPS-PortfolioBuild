# Native QA resize observation — 2026-09-07 23:03 UTC

Scope: no-trade QA chart 41774365623703, HWND 208868134, FTMO-Demo PID 15464.
Original trading-EA chart 40880270757609 was not resized by this test. The MDI
container can recalculate hidden chart geometry when another child is activated.
No trading permission, terminal process, symbol or timeframe was changed.

Test binary: QA2244Z, SHA256
`483ed1206c9506b2a72f0ccbe5760f8cb47b73a4b951392f46bbce0b67ac8170`.
Chart presenter SHA256
`94bea04b8d8dfcb504b8779aa16ef6364e1206d20be687a236f4f686c2494a87`.
Compare SHA256 at this test was
`4add411661ec4371b15cf5e67ced7159d171cf4a659b819e4ed0fab01f9ebf10`;
the later initial-start Retry enhancement is NOT covered by this older build.

## Observed transition

- Initial native plot 1187 x 380; full client 1243 x 403; 96 DPI.
- Only the guard-bound QA MDI child was restored and set to 940 x 405.
  Result: native plot 872 x 347, full client 928 x 370.
- Capture 611 was intentionally diagnostic and uncalibrated; it is not accepted
  as full-frame evidence. The exact chart/HWND/client calibration was then updated.
- Calibrated 612 -> 613 -> 614 (V2 -> V1 -> V2): PASS; native selftests bound to
  init token `41774365623703_1788829254_2095473406`; both V2 PNGs byte-identical.
- Original QA restored-window rectangle (78,78,1213,396) and maximized state
  were reinstated. Full client returned to 1243 x 403. Calibration restored.
- Calibrated 621 -> 622 -> 623 after restoring size: PASS and V2 PNGs byte-identical.

The actual MT5 Experts log at local 01:03:01.793 recorded:

```text
QM_CHART_V2 RESTORE_NORMALIZED chart=41774365623703
property=CHART_SHIFT_SIZE expected=original=19.1919191919191974;
width=1187 bars=149 scale=3
actual=shift=19.3585337915234845 persisted=19.3585337915234845;
width=872 bars=110 scale=3 step_px=7.92727273 error_px=1.45287931 error=0
```

This is a real execution of the changed-raster normalization branch, not an
exact-percent restoration. Its 1.453 pixel deviation is below one current bar
(7.927 pixels); integer settings and zoom remain exact. The percentage is retained
as original intent, not silently overwritten during failed restoration.

The earlier native zoom test also passed, but its before/after shift was identical;
that zoom result alone did not exercise RESTORE_NORMALIZED. Neither result implies
that MT5 guarantees a particular rounding algorithm or certifies trading behavior.

See native_resize_ab_acceptance.json, native_resize_return_ab_acceptance.json,
and the immutable native_2244Z capture/build archive. Actual native observations
cover 96 DPI; simulated high-DPI layout contracts are not native high-DPI evidence.
