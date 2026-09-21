# FTMO_BR_NNFX_20260921 — BR1/BR2/BR3 prescreen result (Fable, Track B family B3, 2026-09-21T20:23:25Z)

Engine: `tools/strategy_farm/session_tools/velocity_family_f3_break_retest_0921.py` on the F2 conservative closed-bar execution model
(market entry at next M5 open +/- (spread+slip)/2, stop at the worse of level and breaching-bar open, targets through by one tick, stop wins
ties, min stop 5 x round-trip spread, news blackout skips the day). PLAN.md rules verbatim; deviations: ATR(14) = simple 14-bar mean of the
M5 true range (MT5 iATR semantics), bid/ask = per-symbol cost prior. Output `velocity_family_f3_break_retest_0921.json` sha256 `cf033bd761b431e033fbc24bfea67067e63d52d7e5a9e501cf8bb5c6dcb5294b`.
SEL 2018-07-02..2022-12-31, VAL 2023-01-01..2025-12-31; family bar 0.05/16 = 0.0031. 0 factory hours.

**Result: 0 of 16 cells pass the selection bar; 0 survivors** (expected false survivors 0.0). Every cell is CLEAR_REJECT or UNKNOWN.

| Cell | State | SEL n | E[R] | PF | worst-year DD R | trades/bd | median hold min | VAL n | E[R] | PF | invalidated / expired / stop-too-tight days |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| BR2|retest_any|EURUSD.DWX | CLEAR_REJECT | 68 | -0.0948 | 0.849 | 8.42 | 0.0579 | 11.0 | 34 | 0.0115 | 1.02 | 580 / 434 / 172 |
| BR2|retest_compressed|EURUSD.DWX | UNKNOWN | 36 | -0.1007 | 0.841 | 4.78 | 0.0306 | 11.0 | 18 | 0.2052 | 1.429 | 336 / 251 / 124 |
| BR3|direct_breakout|XAGUSD.DWX | UNKNOWN | 14 | -0.1235 | 0.808 | 3.19 | 0.0119 | 10.0 | 41 | -0.0865 | 0.863 | 0 / 0 / 1346 |
| BR2|retest_compressed|USDJPY.DWX | UNKNOWN | 16 | -0.1628 | 0.76 | 3.93 | 0.0136 | 9.5 | 36 | -0.3606 | 0.529 | 249 / 187 / 96 |
| BR3|direct_breakout|XAUUSD.DWX | CLEAR_REJECT | 217 | -0.2385 | 0.66 | 39.16 | 0.1847 | 9.0 | 296 | -0.0614 | 0.901 | 0 / 0 / 833 |
| BR3|retest|XAUUSD.DWX | UNKNOWN | 31 | -0.2818 | 0.614 | 5.71 | 0.0264 | 7.0 | 55 | -0.2066 | 0.7 | 734 / 533 / 153 |
| BR2|retest_any|USDJPY.DWX | UNKNOWN | 38 | -0.3205 | 0.571 | 13.12 | 0.0323 | 8.5 | 65 | -0.199 | 0.705 | 406 / 339 / 141 |
| BR3|retest|XAGUSD.DWX | UNKNOWN | 3 | -0.335 | 0.552 | 1.13 | 0.0026 | 4.0 | 9 | -0.3237 | 0.564 | 766 / 527 / 258 |
| BR2|retest_any|GBPUSD.DWX | CLEAR_REJECT | 127 | -0.4602 | 0.435 | 22.13 | 0.1081 | 11.0 | 50 | -0.3423 | 0.544 | 554 / 464 / 168 |
| BR2|retest_compressed|GBPUSD.DWX | CLEAR_REJECT | 67 | -0.5523 | 0.361 | 15.66 | 0.057 | 10.0 | 23 | -0.3982 | 0.495 | 306 / 284 / 97 |
| BR1|retest_nopeer|NDX.DWX | CLEAR_REJECT | 210 | -0.6157 | 0.341 | 50.61 | 0.1787 | 7.0 | 140 | -0.3128 | 0.588 | 762 / 617 / 20 |
| BR1|retest_peer|NDX.DWX | CLEAR_REJECT | 159 | -0.6448 | 0.319 | 36.9 | 0.1353 | 10.0 | 103 | -0.2528 | 0.652 | 762 / 617 / 11 |
| BR1|retest_peer|SP500.DWX | CLEAR_REJECT | 128 | -1.5334 | 0.065 | 47.23 | 0.1089 | 10.0 | 115 | -1.1484 | 0.084 | 757 / 621 / 25 |
| BR1|retest_nopeer|SP500.DWX | CLEAR_REJECT | 167 | -1.5763 | 0.059 | 73.07 | 0.1421 | 10.0 | 140 | -1.2267 | 0.073 | 757 / 621 / 43 |
| BR1|retest_peer|WS30.DWX | CLEAR_REJECT | 152 | -1.9804 | 0.038 | 83.29 | 0.1294 | 8.0 | 102 | -1.3771 | 0.075 | 702 / 612 / 6 |
| BR1|retest_nopeer|WS30.DWX | CLEAR_REJECT | 195 | -2.2229 | 0.027 | 120.61 | 0.166 | 7.5 | 152 | -1.5759 | 0.057 | 702 / 612 / 11 |

Reading. (1) The retest package as specified rarely completes: on every symbol the setup is invalidated (close > 0.25 ATR through the level)
or expires (no qualifying retest within 6 bars) on 70-85 % of armed days; density never exceeds 0.18 trades/bd against the 0.40 bar.
(2) Where it fires, M5-ATR-sized stops (0.5-1.5 x ATR(14, M5) = 1-3 index points on SP500/WS30, ~1 USD on XAU) sit inside a few round-trip
spreads: a single one-minute gap doubles the loss and the cost drag alone is 30-60 % of R — the index cells lose 0.6-2.2 R per trade with
median holds of 7-11 minutes. This is the same cost-dominated class as B1 H-B3/H-B4 and the H-V4 fragility lesson, not a fill-model artefact:
the control arms (no peer, no compression, direct breakout) fail identically. (3) BR2 EURUSD `retest_compressed` shows VAL +0.21 R on 18
trades — noise at that count. (4) Peer confirmation (BR1) removes ~45 % of entries without changing the sign.

Disposition: BR1/BR2/BR3 are CLEAR_REJECT for the FTMO velocity role at these mechanics; the Codex tickets a42aa6f7/2eba7ef7/ff6826f5 stay
BACKLOG with this result attached; no mechanisation. A re-specification with ATR(D1)-scale stops and hourly retest windows would be a new
lineage (B4 candidate), to be pre-registered only if the density calibration supports >= 0.4 trades/bd.
