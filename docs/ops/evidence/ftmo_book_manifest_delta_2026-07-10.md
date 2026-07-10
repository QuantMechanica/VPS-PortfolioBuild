# FTMO book manifest delta — density refresh (2026-07-10) — FOR CODEX

**Status:** proposed, awaiting OWNER approval before live-challenge deployment. Validated on
T8–T10 (`ftmo_density_validation_2026-07-10.md`): at matched daily-breach budget this raises
P1 pass 47.5%→52.3%, lowers max-breach 31%→29%. **Risk-neutral** — Σ RISK_FIXED unchanged
(8999 ≈ 9.00% at scale 9.0); only the sleeve *set* and relative weights change.

Book location (r25p1 preset set files):
`…\Terminal\81A933A9AFC5DE3C23B15CAB19C63850\MQL5\Presets\r25p1_<SYM>_<TF>_QM5_<id>_<slug>_magic<magic>.set`

## 1. REMOVE (net-negative ballast)
- `r25p1_US100.cash_H1_QM5_10163_tv-rsi-macd-long_magic101630000.set`
  (10163/NDX is PF 0.94, −$950/yr in-book — pure drawdown; the same EA on USDJPY is fine, so
  do NOT retire the EA, only drop this NDX sleeve from the FTMO book.)

## 2. ADD (fresh-MAE recompiled + backtested; magics already in registry, no new assignment)
| new set file | ea | ftmo sym | tf | slug | magic (registry slot) |
|---|---|---|---|---|---|
| r25p1_US100.cash_H1_QM5_10118_tv-rsi-trend-cont_magic101180003.set | 10118 | US100.cash | H1 | tv-rsi-trend-cont | 101180003 (slot 3, NDX.DWX) |
| r25p1_GER40.cash_H1_QM5_10916_grimes-impulse_magic109160002.set | 10916 | GER40.cash | H1 | grimes-impulse | 109160002 (slot 2, GDAXI.DWX) |
| r25p1_XAUUSD_M30_QM5_10546_mql5-ma4060_magic105460003.set | 10546 | XAUUSD | M30 | mql5-ma4060 | 105460003 (slot 3, XAUUSD.DWX) |

Strategy params: take from each EA's validated backtest set (`framework/EAs/<label>/sets/…_<sym>_<tf>_backtest.set`).
Risk block: follow the existing book convention — `RISK_FIXED=<see table>`, `RISK_PERCENT=0`,
`qm_risk_cap_pct=2.0` where RISK_FIXED>1000 else 1.0. ENV = challenge/live per the other r25p1 sets.

## 3. REWEIGHT (risk-neutral renormalization, Σ weight = 1.0; RISK_FIXED = 1000 × scale × weight)
RF shown @ scale 9.0 for reference — **apply the current target scale** (scale reduction in flight):

| ea | ftmo sym | tf | magic | old W | new W | RF@9.0 | cap |
|---|---|---|---|---|---|---|---|
| 10847 | GBPUSD | H1 | 108470001 | 0.0432 | 0.0378 | 340 | 1.0 |
| 12990 | GBPUSD | H4 | 129900001 | 0.0400 | 0.0350 | 315 | 1.0 |
| 10911 | GER40.cash | H1 | 109110003 | 0.1396 | 0.1221 | 1099 | 2.0 |
| 10440 | US100.cash | H1 | 104400003 | 0.0510 | 0.0446 | 401 | 1.0 |
| 10692 | US100.cash | H1 | 106920005 | 0.1241 | 0.1085 | 977 | 1.0¹ |
| 12475 | US100.cash | H1 | 124750003 | 0.0361 | 0.0316 | 284 | 1.0 |
| 11476 | USDJPY | H1 | 114760002 | 0.1594 | 0.1394 | 1255 | 2.0 |
| 10286 | USOIL.cash | D1 | 102860036 | 0.0576 | 0.0504 | 453 | 1.0 |
| 12958 | XAUUSD | D1 | 129580000 | 0.1396 | 0.1221 | 1099 | 2.0 |
| 10700 | XAUUSD | H1 | 107000003 | 0.0693 | 0.0606 | 546 | 1.0 |
| 10848 | XAUUSD | H1 | 108480002 | 0.0931 | 0.0814 | 733 | 1.0 |
| **10118** | US100.cash | H1 | 101180003 | (new) | 0.0555 | 499 | 1.0 |
| **10916** | GER40.cash | H1 | 109160002 | (new) | 0.0555 | 499 | 1.0 |
| **10546** | XAUUSD | M30 | 105460003 | (new) | 0.0555 | 499 | 1.0 |

Σ RISK_FIXED @9.0 = 8999 (9.00%), 14 sleeves. ¹10692 drops below 1000 → cap may relax 2.0→1.0.

## 4. Build order (Codex, per Operating-Rules magic order-of-ops)
1. This reweight touches every set file — **fold it into the scale-reduction regen** (one pass,
   don't do it twice). 2. dirs → magic CSV tail-recheck (magics above already exist; verify no
   collision) → regen sets via `gen_setfile.ps1` → verify SHA/params → compile. 3. Recompile all
   14 with the current framework (10118/10916/10546 are already fresh-MAE from 2026-07-10 19:27).
4. Update the deploy manifest sleeve list (remove 10163, add the 3). 5. OWNER approves before the
   live challenge picks it up.

## 5. Caveats
- Live-challenge change → **OWNER sign-off required** (this doc is the spec, not the go).
- Gain is real but **modest** — the bigger lever is decorrelation (separate workstream B, in
  flight on T8–T10). If the decorrelated FX sleeves validate, a second delta may supersede this.
