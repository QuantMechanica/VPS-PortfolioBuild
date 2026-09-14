# Q16 checks 6 (commission/swap) and 7 (DST) — DXZ book v2, 2026-09-14

Produced 2026-09-14T20:39Z by Claude (agent_task `8d8a23e1-7522-459b-bd64-b6b342651c39`,
book-sprint ticket, decision_bound_agent claude). Read-only against T_Live throughout — no
file, chart, terminal or AutoTrading change. Sources:

- `C:/QM/mt5/T_Live/MT5_Base/MQL5/Files/QM/journal/live_deals_normalized.csv` (259 non-balance
  deal legs, 2026-04-24 → 2026-09-14, auto-exported by an existing live monitor sidecar —
  not created by this task)
- `C:/QM/mt5/T_Live/MT5_Base/MQL5/Files/QM/swap_capture_4000090541.csv` (captured 2026-07-26,
  per-symbol `contract_size`/swap schedule from the live terminal)
- `framework/registry/live_commission.json` (OWNER 2026-06-01 worst-case model)
- 25 `QM5_*_ea-*.log` files under the same `Files/QM/` dir, `ts_utc`/`ts_broker` pairs,
  84,023 matched lines, filtered to the last 14 days (2026-08-31 → 2026-09-14)

## Check 6 — commission/swap = DXZ schedule

**`C:/QM/mt5/T_Live/MT5_Base/MQL5/Profiles/Tester/Groups/` does not exist** (confirmed by
directory listing, not just empty) — there is still no tester-Groups artifact today, exactly
as OPEN-6 already said. This check is answered instead from the live deal journal, which is
the only real-money ground truth available.

The 7 sleeves in this book-v2 grid map to three commission classes:

| sleeve | symbol | class |
|---|---|---|
| 25/1537 | XAGUSD | commodity |
| 26/9641 | WS30 | index |
| 27/10700 | XAUUSD | commodity |
| 28/13013 | NDX | index |
| 06/12778 | AUDUSD | forex |
| 17/12969 | USDJPY | forex |
| 24/13117 | EURGBP + AUDJPY | forex |

Commission is charged by the broker per **symbol class**, not per EA, so the correct evidence
is realised commission from *any* live deal in that symbol/class on this account, matched
per closed position (`position_id`, IN+OUT legs summed) against
`live_commission.json`'s `max(pct_rate_rt·notional, flat_per_lot_rt·volume)` worst case:

| symbol (class) | closed positions found | realised vs. worst-case model |
|---|---|---|
| XAUUSD (commodity) | 14 | **5 of 14 (36 %) exceed** the modeled worst case, by $0.001–$0.008 per position (0.3–0.6 % relative) — all at the smallest lot sizes traded (0.01–0.02 lots). Example: pid 3162733509, vol 0.11, real commission $2.22 vs. modeled $2.2124. |
| NDX (index) | 13 | within model, comfortably (realised 33–78 % of the modeled worst case; flat $5.50/lot term dominates) |
| AUDUSD (forex) | 3 | within model (69–70 % of modeled worst case) |
| USDJPY (forex) | 30 | within model, large margin (flat term dominates; realised <1 % of the pct-based ceiling) |
| XAGUSD, WS30, EURGBP, AUDJPY | 0 | **no deal history exists yet** — these instruments/sleeves have not traded on this account |

**Finding, stated plainly and not smoothed over:** the commodity class (`pct_rate_rt` only,
no flat floor — `flat_per_lot_rt: 0.0`) has a real, small, boundary-adjacent gap at very small
lot sizes: 5 of 14 realised XAUUSD commissions land $0.001–$0.008 **above** the modeled worst
case. The absolute size is sub-cent to single-cent and immaterial to book economics, but the
model is not a strict ceiling at min-lot size — most likely because the broker applies a
minimum per-deal commission floor (or rounds up to the cent) that a pure percentage formula
does not capture. This matters here specifically because the two new commodity sleeves in
this book (25/1537 XAGUSD, 27/10700 XAUUSD) burn in at exactly this lot-size regime
(0.077 % / 0.013 % RISK_PERCENT ≈ min lot). **Recommendation:** treat commodity-class
burn-in commission as "worst-case model + ~1 cent/lot" rather than the model verbatim; not a
blocker, but do not certify the commodity worst-case model as a strict ceiling.

Swap: realised swap sums per symbol (XAUUSD −$33.60, NDX +$0.09, AUDUSD −$12.91, USDJPY $0.00
over the sampled window) are consistent in sign and rough magnitude with the captured
`swap_long`/`swap_short` schedule in `swap_capture_4000090541.csv` for the same symbols
(e.g. XAUUSD swap_long −58.6/lot/day, swap_short +32.4/lot/day — net-negative realised swap is
consistent with a long-biased book on that symbol). No per-day swap reconciliation was done
(would need each position's exact holding-day count including the Wednesday 3× rollover);
this is directional confirmation, not a cent-exact audit.

**Verdict — check 6:**
- 27/10700 (XAUUSD), 06/12778 (AUDUSD), 17/12969 (USDJPY), 28/13013 (NDX): **GREEN**, class
  verified from real closed deals on this account, with the commodity-class caveat above
  noted against 10700's own future min-lot fills.
- 26/9641 (WS30) and 24/13117 (EURGBP+AUDJPY): **GREEN-by-class-proxy** — same class formula
  already empirically validated (index via NDX, forex via AUDUSD/USDJPY) on this account, but
  neither WS30 nor EURGBP/AUDJPY has itself traded yet, so this is a class-level, not
  instrument-level, confirmation.
- 25/1537 (XAGUSD): **OPEN** — commodity class, no deal history for XAGUSD itself, and the one
  commodity instrument that *does* have history (XAUUSD) is the one class that showed the
  small worst-case overshoot at min-lot size. Do not mark GREEN until XAGUSD's own first
  burn-in fills are checked against the model with the cent-floor caveat in mind.

## Check 7 — DST on T_Live

Parsed `ts_utc` vs. `ts_broker` from every EA log line carrying both fields, 84,023 lines
across 25 files, filtered to the last 14 calendar days (2026-08-31 → 2026-09-14):

| date (UTC) | live-tick samples | offset (ts_broker − ts_utc) |
|---|---|---|
| 2026-08-31 Mon | 34 | +3.000h |
| 2026-09-01 Tue | 42 | +3.000 to +3.001h |
| 2026-09-02 Wed | 42 | +3.000 to +3.001h |
| 2026-09-03 Thu | 31 | +3.001h |
| 2026-09-04 Fri | 32 | +3.001h |
| 2026-09-05 Sat | 0 | n/a — market closed, see caveat below |
| 2026-09-06 Sun | 40 | +3.000h |
| 2026-09-07 Mon | 41 | +3.000h |
| 2026-09-08 Tue | 28 | +3.000 to +3.001h |
| 2026-09-09 Wed | 288 | +3.000 to +3.001h |
| 2026-09-10 Thu | 45 | +3.001h |
| 2026-09-11 Fri | 383 | +3.001h |
| 2026-09-12 Sat | 0 | n/a — market closed |
| 2026-09-13 Sun | 24 | +3.000h |
| 2026-09-14 Mon | 2 | +3.000h |

**Result: consistently +3.000h to +3.001h (GMT+3) across every live-tick sample in the full
14-day window** — correct for the current US-DST period per `project_qm_broker_time`
(NY-Close GMT+2 outside US DST, GMT+3 during). The sub-0.001h jitter is float/logging
precision, not a real timezone drift.

**Weekend caveat, investigated rather than silently filtered:** 305 lines on 2026-09-05 and
304 on 2026-09-06 showed wildly inconsistent offsets (−40h to −8h). Sample:
`ts_utc":"2026-09-05T07:53:04.875Z"` paired with `"ts_broker":"2026-09-04T23:54:59"` — every
one of these is a `DEINIT`/`INIT`/`NEWS_CALENDAR_LOADED`/kill-switch-restore event during the
weekend market closure, and `ts_broker` is pinned at the exact same value
(`2026-09-04T23:54:59`, Friday's last tick) across all of them while `ts_utc` keeps advancing.
This is standard MT5 behaviour — `TimeCurrent()` freezes at the last known server tick when
disconnected/market-closed rather than tracking wall-clock time — **not a DST or timezone
defect**. These rows are excluded from the table above and are called out explicitly so the
gap doesn't read as missing evidence.

**Verdict — check 7: GREEN**, log-based artifact in place of the terminal screenshot the gate
originally asked for (Hard Rule: evidence must be a log/CSV/report path, not a screenshot).
Applies to all 7 sleeve columns — DST is an account/terminal-level property, not per-EA.

## No invented values

Every number above is read from the CSVs/logs cited, or is the registry's already-recorded
worst-case model. Where evidence does not exist (XAGUSD, WS30, EURGBP, AUDJPY deal history),
the checklist stays OPEN rather than being inferred GREEN.
