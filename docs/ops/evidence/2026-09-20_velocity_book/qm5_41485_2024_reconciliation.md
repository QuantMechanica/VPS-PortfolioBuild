# QM5_41485 (H-V4, USDJPY C2) — 2024 harness-vs-tester reconciliation

**Author:** Fable fork, 2026-09-21. **Scope:** read-only (no factory rows, no compiles, no terminal touch; 0 factory hours).
**Data:** `docs/ops/evidence/2026-09-20_velocity_book/qm5_41485_2024_reconciliation.json` (joined per-day table, CPI clock
check) and `qm5_41485_failclosed_harness_variant.json` (harness re-run with the frozen OCO fail-closed rule).

## 1. The contradiction

| window | tester (real ticks, RISK_FIXED 1000) | harness cell USDJPY C2 |
|---|---|---|
| Q02 2018-07-02..2022-12-31 (`ffe3a8dc`) | 875 trades, +132.3R, PF 1.31, DD 18.3R, E[R] +0.151 | 998 trades, +141R, PF 1.30, DD 20.8R, E[R] +0.141 |
| Q04 F1 OOS 2023 | 174 trades, pf_net 1.004 | 206 trades, +5.2R |
| Q03 / Q04 F2 OOS 2024 (`dc30f5ce`, `bbb18054`) | **148 trades, −23.5R, PF 0.73, DD 34.6R** | **203 trades, +59.2R** |
| Q04 F3 OOS 2025 | 200 trades, pf_net 0.916 | 220 trades, +26.7R |

Q04 = walk-forward folds F1/F2/F3 with development 2017..(year−1) and one OOS year each (2023, 2024, 2025); the fold
criterion is `pf_net`; all three folds are below the bar (1.004 / 0.724 / 0.916) → `FAIL` (rows `6b8574cc`, `65ba3f5f`).

## 2. What is NOT the cause

- **Server clock.** The US CPI release minute (08:30 New York) is the maximum-volume M1 bar at **15:30 server** in 2022, 2023,
  2024 and 2025 (JSON `cpi_spike_minutes_server`); the EA placed 312 of 330 orders at 15:30 and 18 at 16:00 (news retry).
  Server = America/New_York + 7 h holds in every year.
- **Tick model.** Both Q02 and Q03 ran `generating based on real ticks` from the `.tkc` archive, which exists from 2017-10
  onwards for USDJPY.DWX (T1/T3). No synthetic-vs-real split between the periods.
- **Phase settings.** Q03 uses the identical setfile (sha `bbb55886…`), the same EA binary and the same news calendar
  (97,827 rows, self-test applicable) as Q02; only the date window differs.
- **EA logic drift.** On the 139 common same-direction days the tester and the harness fill at the same minute (median
  fill-time difference 0.2 min, p10/p90 −0.8/+0.8), same direction, same exit kind, and the median per-trade
  difference is +0.015R (harness higher). The EA implements the frozen spec; it is not defective.

## 3. Where the 82.7R gap (harness +59.2R vs tester −23.5R) comes from

| class | days | R (harness − tester) | share |
|---|---:|---:|---:|
| **A. anchor-tick order rejection + fail-closed OCO** — the tester rejects one stop side at the 15:30:00 tick (`retcode 10015 Invalid price`, 16 rejections in 2024) and the EA cancels the survivor (`NY_PREOPEN_ONE_SIDED_SEND`, frozen spec point 5); the harness's validity check uses the M1 bid open only and fills the surviving side | 11 | **+43.3** | 52 % |
| **B. direction mismatch at the anchor tick** — same day, opposite side filled first (real-tick ask/spread at a release spike vs bid-only M1 bar) | 9 | **+13.0** | 16 % |
| C. same-direction execution differences (stop slippage on gaps: e.g. 2024-10-17 tester −4.96R vs −1.04R, 2024-11-05 +2.16 vs −1.15, 2024-06-13 +0.46 vs −1.04) | 139 | +14.0 | 17 % |
| D. days the EA did not place at all (news blackout on 32 days: +5.3R; ATR / half-bar / other filter on 12 days: +7.1R) | 44 | +12.4 | 15 % |
| tester-only days | 0 | 0 | — |

Class A in detail (harness net R on the day; the tester has a cancelled pending order only): 01-31 +3.61, 03-06 +0.34,
03-29 +0.20, **04-10 +12.37 (US CPI)**, 04-15 −0.32, 06-07 −1.03 (NFP), **07-11 +24.50 (US CPI, BoJ intervention)**,
07-18 +3.97, 07-25 +1.37 (GDP), 09-06 −1.02 (NFP), 09-11 −0.70 (CPI). Eight of the eleven are 08:30-New-York release
days — the anchor tick **is** the release tick. The two CPI days alone carry +36.9R, i.e. 62 % of the harness's whole 2024.

**Mechanism.** At 15:30:00 on a release day the first tick already sits at or beyond one range edge (or inside the broker
stop level): the stop order on that side is rejected (`Invalid price`), the EA cancels the peer and stands aside (the rule
the round-1 critic asked for and revision 2 froze). The harness checks validity against the M1 *bid open* only, sees
`open < range_high`, keeps both sides, and fills the side the spike crosses at the exact level — with an 8–11-pip range
that is a 12–25R trade. It is the same optimism the critic named ("exact-level fills ignore gaps, spread, stop-level
rejection"), but on this anchor it is concentrated on the fattest days.

## 4. Why 2018–2022 agreed and 2023–2025 does not

Re-running the harness with the frozen fail-closed rule applied to the harness's *own* validity check
(`qm5_41485_failclosed_harness_variant.json`) removes only the days whose M1 open is already beyond a level: SEL n 998→967,
E[R] +0.141→+0.156, PF 1.30→1.34; VAL +0.144→+0.128; 2024 +59.2→+51.1R. That variant still cannot see the tester's
rejections, so the residual 2024 gap stays; it proves the divergence is **tick-level (ask, spread widening, stop level at
the release tick), not the rule itself**. In 2018–2022 the one-sided/rejection days net out in the harness (2019 −1.5R,
2020 −4.2R, 2021 −3.6R, 2022 −5.5R), so the harness *understated* those years slightly and the control-cell calibration
(+0.018R) looked benign. In 2024 the release-tick days were the year's best trades (+8.2R one-sided in the variant, +43.3R
in classes A) — a one-directional bias the control cell (Tokyo anchor, no releases) could never reveal.

## 5. Verdict

- **Harness modelling gap (not an EA defect, not a phase/settings defect, not a clock defect).** The bid-only M1 harness
  cannot model the anchor tick on 08:30-New-York release days; for NY-anchored cells its validation numbers are
  overstated by roughly the release-day tail. The family-F1 sweep's *ranking* (NY anchors ≈ 2× the Tokyo incumbent) rests
  on exactly these days and must be re-read: the tester says USDJPY C2 is +0.151R in 2018–2022 (better than the harness)
  and **negative to flat in 2023–2025** (Q04 pf_net 1.00 / 0.72 / 0.92).
- **Pre-registered bars of QM-RESEARCH-2026-0012 (USDJPY C2):** Q02 bars met (875 ≥ 800 trades, +0.151 ≥ +0.08R, PF 1.31 ≥
  1.15). **Holdout / build-regression bar (≥ 70 % of the selection R/bd on 2023–25) FAILED** — the tester's 2023–25 R/bd is
  negative; **Q04 FAILED** on all three folds. Per the artifact's own rules the arm does not proceed; EURUSD C3 already
  retired on its Q02 bars. Card action for `QM5_41485`: **RETIRE / no book value** (no marginal-contribution run is owed for a
  sleeve that fails its own holdout); the 13213-replacement hypothesis is refuted for this window.
- **Harness fix before any further NY-anchored sweep** (do not reuse the C-anchor VAL numbers until then): (1) validity at
  the placement tick against bid **and** ask (spread from the `.tkc` ticks or the M1 `spread` field) plus the symbol stop
  level; (2) fail-closed OCO exactly as the EA (one rejection → no trade); (3) fills through a gap at the first available
  price, not the level; (4) optional: release-day tagging so the sweep can report "release-day share of net R" per cell.
  Tokyo/London-anchored cells are affected far less (no 08:30 release at the anchor) but should be re-validated once.
- **Secondary observation (not the cause, worth a look):** the harness treats `news_calendar_2015_2025.csv` `datetime` as
  UTC; several 2024 rows are one hour early in US-summer months (e.g. 2024-07-11 Core CPI `11:30`, 2024-07-25 GDP `11:30`
  for 12:30 UTC releases) while others are correct (2024-10-03 Claims `12:30`, 2024-11-13 CPI `13:30`). The EA's framework
  self-test accepted the calendar; the harness's blackout windows are misaligned on such rows.

## 6. What this means for the Velocity programme

The 0-factory-hour harness remains the right first filter (it reproduced 2018–2022 within tolerance and ran 314 cells in
minutes), but a cell whose edge lives on the anchor tick of scheduled releases is precisely the case it cannot price. The
next hypotheses should avoid anchors that coincide with release times or must carry the tick-level validity model above
before any card.
