# SP500.DWX Custom-Symbol Rollout T1 → T2..T5

**Date:** 2026-05-16T19:15Z
**Actor:** Board Advisor (T1-T5 Test-Environment Ownership)
**Trigger:** OWNER provided SP500 tick + bar data at `D:/QM/reports/setup/tick-data-timezone/`, created custom symbol `SP500.DWX` on T1, requested mirror to T2-T5.

## Source data (OWNER-supplied)

- `D:/QM/reports/setup/tick-data-timezone/SP500_GMT+2_US-DST.csv` — 9.4 GB ticks, format `YYYY.MM.DD HH:MM:SS.ms,bid,ask`, from 2018-07-02
- `D:/QM/reports/setup/tick-data-timezone/SP500_GMT+2_US-DST_M1.csv` — 138 MB M1 bars
- Timezone: filename declares `GMT+2_US-DST` = DXZ NY-Close convention (GMT+2 outside US DST, GMT+3 during US DST) → no conversion needed, 1:1 broker-time match

## Action

T2-T5 mirrored to T1 for `Bases/symbols.custom.dat` + `Bases/Custom/{history,ticks}/SP500.DWX/`. Also picks up `NDXm.DWX` symbol-definition stub (empty history/ticks dirs, present in T1 since pre-rollout) — not material.

MT5 confirmed not running on any terminal during the operation (`Get-Process terminal64` = 0 both pre and post).

## Backups created (rollback path)

Each T2-T5 has its pre-rollout `symbols.custom.dat` preserved at:

```
D:/QM/mt5/T<n>/Bases/symbols.custom.dat.bak_20260516_191500_pre-sp500
```

T2-T5 also already had `symbols.custom.dat.bak_20260516_125750` from earlier today (pre-strategy_farm refresh, untouched by this op).

## Files copied (per terminal, T2-T5)

| Path | Size | Files |
|---|---|---|
| `Bases/symbols.custom.dat` | 20480 B | 1 |
| `Bases/Custom/history/SP500.DWX/` | 162,742,505 B (155 MiB) | 9 `.hcc` + `cache/` (2018–2026 years) |
| `Bases/Custom/ticks/SP500.DWX/` | 681,968,393 B (650 MiB) | 93 `.tkc` (201807–202605 months) |

Total per terminal: ~805 MiB · across T2-T5: ~3.2 GiB · disk free after: 441 GB on `D:`.

## Integrity verification

### symbols.custom.dat — sha256 across T1-T5 (all identical)

```
b424f347af8bf27017cd2d8fd514314d67d5a6f1d3f89e253aa1cc7e6ef7c862  T1
b424f347af8bf27017cd2d8fd514314d67d5a6f1d3f89e253aa1cc7e6ef7c862  T2
b424f347af8bf27017cd2d8fd514314d67d5a6f1d3f89e253aa1cc7e6ef7c862  T3
b424f347af8bf27017cd2d8fd514314d67d5a6f1d3f89e253aa1cc7e6ef7c862  T4
b424f347af8bf27017cd2d8fd514314d67d5a6f1d3f89e253aa1cc7e6ef7c862  T5
```

### SP500.DWX directory totals (byte-exact)

History `162742505 B` on all five terminals · ticks `681968393 B` on all five terminals · entry counts identical (10 history, 95 ticks).

### Per-file sha256 spot-checks (all identical across T1-T5)

| File | sha256 |
|---|---|
| `history/SP500.DWX/2018.hcc` | `76c524b42af188ebee41a6a67027d3e664eb8c02dae1723f8c88a68546969bda` |
| `history/SP500.DWX/2026.hcc` | `e713c4a42197de231ba7da6f108e6a90ecb19fbd2c29dac767d3a70d98470cbf` |
| `ticks/SP500.DWX/201807.tkc` | `7f574cb04cb0ba5c89a361606386a7b1c6c006cb5cf83859af87ce3ef1c11208` |
| `ticks/SP500.DWX/202605.tkc` | `416d6106e6a25c2d1fe28502110025f0643f73ab37160581de3ae0183a30b6b1` |

## Symbol contract spec

The symbol definition lives inside the binary `symbols.custom.dat` written by MT5 when OWNER created `SP500.DWX` on T1 (modeled after DXZ broker's `SP500`). Contract spec was set by OWNER via the MT5 Symbols dialog; this rollout preserves it bit-for-bit. If a future change to contract spec is needed, repeat the workflow: edit on T1, re-mirror to T2-T5.

## Open follow-ups (not done here — flagged for OWNER / strategy_farm)

1. **SSRN-batch re-targeting.** Per memory `feedback_spx500_card_port_before_build.md` cards `QM5_1045..1049` were patched from SPX500 → `NDX.DWX`/`WS30.DWX` because SP500 was unavailable in the DWX feed. With `SP500.DWX` now usable as Custom Symbol:
   - `QM5_1045 zarattini-spy-intraday-momentum` (currently blocked, SPY-intraday-specific) — strong candidate for reopen on SP500.DWX
   - `QM5_1046..1049` — already built on NDX/WS30 patch; re-patch back to SP500.DWX is OWNER call (cost: re-build cycles vs. paper-spec fidelity)
2. **Backtest validation gate before any P1 run.** Custom-symbol backtest needs `news_calendar` to cover SP500-relevant events (FOMC, NFP) — already in `D:/QM/data/news_calendar`, applies symbol-agnostically. No new gate needed.
3. **DST boundary sanity-check** — has *not* been run yet (would require opening MT5 and pulling H1 bars around 2024-03-10 / 2024-11-03). Recommend deferring until first SP500.DWX backtest, where DST anomalies would surface as either OHLC gaps or duplicate-hour bars on those days.

## Rollback procedure (if needed)

MT5 must be closed on all terminals, then:

```bash
for n in 2 3 4 5; do
  rm -rf "D:/QM/mt5/T${n}/Bases/Custom/history/SP500.DWX"
  rm -rf "D:/QM/mt5/T${n}/Bases/Custom/ticks/SP500.DWX"
  mv "D:/QM/mt5/T${n}/Bases/symbols.custom.dat.bak_20260516_191500_pre-sp500" \
     "D:/QM/mt5/T${n}/Bases/symbols.custom.dat"
done
```

T1 stays as-is (OWNER's source of truth).
