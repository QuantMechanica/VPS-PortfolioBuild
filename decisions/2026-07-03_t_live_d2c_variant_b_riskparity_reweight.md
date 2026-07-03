# T_Live decision — D2-c Variant B risk-parity reweight (capped inverse-vol)

**Status: OWNER-APPROVED — FILE-SIDE DEPLOYED; CHART APPLICATION PENDING**

- Direction ratified by OWNER in chat, 2026-07-03 ("B"), on the three-variant decision package.
- **Manifest approval (written): OWNER, 2026-07-03 — "Manifest Variante B am 03.07.2026
  freigegeben".**
- Compensating control for the still-open codex cross-review (`b482e875`/`b0b51db3`, both in
  REVIEW at deploy time): Claude independently recomputed the cap-redistribution from the
  uncapped inverse-vol weights — max deviation vs staged table 0.0001 (rounding), sum 9.7500.
- File-side deployment executed 2026-07-03 (see Deployment log below). Running EAs are NOT
  affected by preset files — the risk change takes effect only when each chart loads its new
  preset (application step, terminal UI).

## Decision

Reweight the 13 live D2-c sleeves from flat `RISK_PERCENT=0.75` to **inverse-vol risk parity
with a hard 1.0% per-sleeve cap** (capped excess redistributed pro-rata), total summed sleeve
risk unchanged at **9.75%**. Reallocation only — no risk increase, no EA/binary change, no
sleeve added or removed.

## Evidence basis

Package: `docs/ops/evidence/D2C_13SLEEVE_RISK_PARITY_SUMRISK_DECISION_2026-07-03.md`
(tasks b482e875 + b0b51db3; streams = 13 live-sleeve Q08 net-of-cost, worst-case DXZ/FTMO
commission; method = `inverse_vol_weights` + iterative 1% cap).

| policy (same 9.75% summed risk) | annual return | Sharpe | MaxDD | monthly VaR95 | worst day |
|---|---:|---:|---:|---:|---:|
| flat 0.75 (current live) | 15.76% | 2.16 | 16.89% | 2.82% | -2.64% |
| inverse-vol uncapped (rejected: 3 sleeves breach 1% cap) | 10.03% | 2.81 | 4.31% | 1.63% | -1.91% |
| **Variant B: capped inverse-vol (RATIFIED)** | **11.66%** | **2.66** | **6.22%** | **2.11%** | **-2.39%** |

Rationale: OWNER's stated objective is consistency + low drawdown; Variant B cuts 8yr MaxDD
~63% at unchanged total risk while keeping the framework 1% per-sleeve cap intact (4 sleeves
pinned at exactly 1.0000, none above). On DXZ, D-Leverage normalizes risk — the rating tracks
risk quality (Sharpe 2.16→2.66), not raw return.

## Per-sleeve RISK_PERCENT (old → new)

| slot | EA | symbol | magic | old | new |
|---:|---|---|---:|---:|---:|
| 0 | QM5_10440 | NDX.DWX | 104400003 | 0.7500 | 0.2403 |
| 1 | QM5_10513 | XAUUSD.DWX | 105130003 | 0.7500 | 0.7237 |
| 2 | QM5_10692 | NDX.DWX | 106920005 | 0.7500 | 0.3545 |
| 3 | QM5_10715 | USDJPY.DWX | 107150004 | 0.7500 | 0.7071 |
| 4 | QM5_10911 | GDAXI.DWX | 109110003 | 0.7500 | 0.3241 |
| 5 | QM5_10939 | GBPUSD.DWX | 109390001 | 0.7500 | 0.8359 |
| 6 | QM5_10940 | XAUUSD.DWX | 109400003 | 0.7500 | 0.7145 |
| 7 | QM5_11132 | SP500.DWX | 111320000 | 0.7500 | 1.0000 |
| 8 | QM5_11165 | AUDCAD.DWX | 111650002 | 0.7500 | 1.0000 |
| 9 | QM5_11421 | AUDUSD.DWX | 114210003 | 0.7500 | 0.9460 |
| 10 | QM5_11421 | EURUSD.DWX | 114210000 | 0.7500 | 1.0000 |
| 11 | QM5_12567 | XAUUSD.DWX | 125670003 | 0.7500 | 0.9039 |
| 12 | QM5_12567 | XNGUSD.DWX | 125670002 | 0.7500 | 1.0000 |

## Pre-deployment verification (done 2026-07-03, this session)

- ✅ Staged presets `...\d2c_invvol_sumrisk_2026-07-03\variant_b\staged_live_presets\`:
  **13/13 parsed BOM-aware; RISK_PERCENT matches the table exactly; RISK_FIXED=0 in all 13**
  (live ENV convention). Staged OUTSIDE the T_Live tree.
- ✅ No binary changes: `.ex5` files untouched → SHA256 identity vs framework carries over from
  the 2026-07-01 verification. Magic registry unchanged.
- ✅ Sum check: new RISK_PERCENT column sums to 9.7500.

## Deployment plan (after OWNER manifest signature)

1. Backup the 13 current live presets (`MQL5\Presets\slot*_live.set`) to a dated backup folder.
2. Copy the 13 variant_b presets into `T_Live\MT5_Base\MQL5\Presets\` under the existing
   slot naming; apply per chart (EA re-init). Sizing applies to NEW entries only — open
   positions are unaffected; prefer a quiet window, no flat requirement.
3. Confirm each chart reloaded (journal "initialized" lines), AutoTrading state unchanged.
4. Live-book pulse verifies 13/13 preset-TF + risk consistency on its next cycle.
5. Rollback = restore step-1 backup presets (single reverse operation).

## Risks (documented for the record)

- Weights derive from backtest vol; a low-vol sleeve turning loud live mis-allocates →
  mitigations: quarterly reweight cadence (standing), live-book pulse monitoring, 1% hard cap
  bounds the worst case.
- Historical return drops ~4.1pts/yr vs flat in exchange for ~10.7pts less MaxDD — accepted by
  OWNER with the ratified objective (consistency/low DD; DXZ normalizes risk).

## Deployment log (2026-07-03, Claude)

1. ✅ Backup: all 13 original presets (`slotN_..._magicNNN.set`) copied to
   `C:\QM\deploy\VariantB_reweight_2026-07-03\preset_backup\` (13 files). Note: originals
   carry NO `_live` suffix — the 2026-07-01 record's "slot..._live.set" naming was imprecise.
2. ✅ Copy: 13 `*_riskparity_capped_live.set` presets copied into
   `T_Live\MT5_Base\MQL5\Presets\` under NEW filenames — nothing overwritten; originals
   remain in place as a second rollback path.
3. ✅ SHA256: 13/13 copied files identical to staged (`C:\QM\deploy\VariantB_reweight_2026-07-03\
   staged_sha256.txt` / `live_sha256.txt`).
4. ⬜ Chart application (terminal UI, per chart 1–13): EA Properties → Load →
   `slotN_..._riskparity_capped_live.set` → OK. Sizing applies to NEW entries only; open
   positions unaffected; AutoTrading is NOT touched.
5. ⬜ Post-application: journal re-init lines confirmed per chart; live-book pulse consistency
   check on next 30-min cycle.

Rollback: reload the original `slotN_..._magicNNN.set` per chart (both the in-place originals
and the dated backup exist).

## Sign-off

- Direction (Variant B): **OWNER, 2026-07-03, chat ("B")**
- Manifest/deployment approval: **OWNER, 2026-07-03, chat — "Manifest Variante B am
  03.07.2026 freigegeben"**
- File-side deployed: **2026-07-03, Claude (backup + copy + SHA256 verified)**
- Charts applied: _pending (terminal UI step)_
