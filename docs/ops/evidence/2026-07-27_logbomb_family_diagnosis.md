# Q02 `log_bomb` family diagnosis — 139 EAs / 4,236 rows

Date: 2026-07-27
Author: Claude (board-advisor worktree)
Scope: every `work_items` row with `phase='Q02'` and payload
`failure_subclass='log_bomb'` (the tag `classify_summary_missing.py` wrote today).
Reference fix under test: commit `54efb0c66` (QM5_11072 spread-jitter modify storm).

---

## TL;DR verdict

**The `failure_subclass='log_bomb'` label on these 4,236 rows is a reclassifier
false-positive. None of the 4,236 rows was killed by the log-bomb guard, and none of
the 139 EAs carries the QM5_11072 mechanism in its current source.**

- **SAME-MECHANISM (11072 spread-jitter vs sub-pip threshold): 0 / 139.**
- **OTHER-BOMB (a genuine latent per-tick emitter): 1 / 139** — QM5_10923, an
  *unguarded* per-tick `MoveSL` (different recipe from 11072). It is latent, not the
  cause of its own rows (it holds real PASS/FAIL verdicts).
- **NO-SOURCE-BOMB / mislabel: 138 / 139.** Their Q02 rows are
  `summary_missing_retries_exhausted` — overwhelmingly the history-lock re-sync
  *transport* storm (terminal_worker.py:95–104), where the EA is innocent — that the
  reclassifier mis-stamped as `log_bomb` purely because `attempt_count>=99`.
- **NOT-ESTABLISHED: 0 / 139** — every source was scanned mechanically; every
  modify/logging hit was read; framework trail primitives were verified self-limiting.

Gate evidence: **122 / 139 hold a real PASS/FAIL-family verdict (→ must be varianted,
never edited in place); 17 / 139 are stranded (→ fixable in place)**. But since 138 of
139 have no source bomb, there is nothing to fix in place for them. The only latent
source bomb (QM5_10923) itself holds real verdicts, so even it needs a variant.

The correct remediation is a **reclassifier fix**, not 139 EA edits. See §7.

---

## 1. The family, and how it was stamped

`classify_summary_missing.py` reclassifies the `summary_missing_retries_exhausted`
graveyard (its `GRAVEYARD_TAG`). Its first cascade rule (classify_summary_missing.py:115–137):

```python
def _has_log_bomb(payload, attempt_count):
    if attempt_count >= LOG_BOMB_ATTEMPT_FLOOR:   # 99
        return True
    if str(payload.get("verdict_reason")).upper() == "LOG_BOMB":
        return True
    return any(str(x).upper() == "LOG_BOMB" for x in payload.get("reason_classes") or [])
```

Query (read-only) over `farm_state.sqlite` reproduces the family exactly: **4,236 rows,
139 distinct EAs**, top `QM5_10718 ×260, QM5_10296 ×154, QM5_1703 ×151, QM5_2003 ×149,
QM5_2004 ×149` — matching the task statement.

## 2. Row evidence: these are NOT journal floods

Aggregating the payloads of all 4,236 rows:

| Signal | Value |
|---|---|
| `verdict_reason` | `summary_missing_retries_exhausted` on 4,233 (+3 stragglers) |
| `final_failure` | `summary_missing_retries_exhausted` on **all 4,236** |
| `attempt_count` | **99 on all 4,236** |
| genuine log-bomb kill artifact (`verdict_reason=LOG_BOMB`, or `log_bomb_journal_gb`, or `final_failure='log_bomb'`, or `reason_classes` contains `LOG_BOMB`) | **0 of 4,236** |

The genuine log-bomb kill path stamps a distinctive record (terminal_worker.py:2595–2633):
`verdict_reason="LOG_BOMB"`, `reason_classes += ["LOG_BOMB"]`, `final_failure="log_bomb"`,
`log_bomb_journal_gb=<size>`, **and** `attempt_count=99`. **Not one of the 4,236 carries
any of those except the shared `attempt_count=99`.** So the stamp rests entirely on
`attempt_count>=99`, and that sentinel is **not** log-bomb-specific:

- Q02 rows with `attempt_count>=99`: **5,236**, spanning ≥8 `verdict_reason` values —
  `summary_missing_retries_exhausted` 4,254, `summary_missing` 368,
  `run_smoke_fail:ONINIT_FAILED;INCOMPLETE_RUNS` 208, `None` 157,
  `run_smoke_fail:NO_HISTORY;INCOMPLETE_RUNS` 93, `LOG_BOMB` 80, `setfile_missing` 16,
  `BARS_ZERO` 10, … The older exhaustion/poison paths stamped 99 for many causes; the
  current summary-missing path (terminal_worker.py:2093–2136) no longer does, but these
  rows were written June 2026, before that rewrite.

**Genuine log bombs are a disjoint population of 80 Q02 rows** (all carrying
`verdict_reason=LOG_BOMB` + `log_bomb_journal_gb` ≈ 0.6–0.7 GB, rate-triggered), owned by
~50 EAs. Only **4** of those EAs are in this 139-family (see §6); the other ~46 are not.
The 80 live outside the graveyard the reclassifier processes, so they were never
re-stamped — confirming the two populations do not overlap.

## 3. What `summary_missing` actually is

`summary_missing_retries_exhausted` is a **finished-but-discarded-report** signature, not a
journal flood. The dominant sub-cause is documented in the worker itself
(terminal_worker.py:95–110): T2–T10 `bases` are NTFS junctions onto one T1 store that also
holds live Darwinex history, so a finished pass whose deposit-conversion symbol is locked
at pass-end re-sync gets its report **discarded** ("history synchronization error [Not
found]" / "some error after pass finished … in 0:00:00.000") → no summary latched. The
comment records the measured storm (GDAXI 126 INFRA vs 58 PASS; NDX 68 vs 23) and states
plainly: **"The EA is innocent."**

This is corroborated by the family itself: the #1 EA, **QM5_10718 (260 rows)**, is a
28-pair cross-sectional carry **basket** — exactly the multi-symbol/index type the
re-sync storm hits — and its source is clean (§5). And EAs such as QM5_10296 hold **PASS**
verdicts at Q02 on other symbols; a deterministic source bomb like 11072 fires on *every*
symbol's every tick, so a same-EA PASS is itself evidence the failure is symbol/terminal
transport, not the EA's code.

## 4. Framework fact that bounds the whole analysis

`QM_TM_MoveSL` / `QM_TM_MoveTP` (QM_TradeManagement.mqh:368–382) do **not** dedup against
the current SL/TP — they call `QM_TM_SendSLTPModify` unconditionally, and the
modify-suppression hygiene is **live-only** (`live_hygiene = MQL_TESTER==0`, line 147). In
the tester, therefore, **every** call that clears the EA-level call-site guard sends
`TRADE_ACTION_SLTP` and logs `TM_MODIFY` (line 211). The *only* thing standing between an
EA and a per-tick modify storm is its own call-site threshold. That is precisely why 11072
bombed (jittery target + one-POINT threshold let nearly every tick through) and why the
fix was to tighten the EA-level guard. Consequently the source audit reduces to: **for
each per-tick modify, is there a monotonic guard with real hysteresis, or a constant
(closed-bar) target?**

The framework trail primitives all carry that guard internally and are self-limiting:
`QM_TM_MoveToBreakEven` (414–418), `QM_TM_TrailATR` (452–456), `QM_TM_TrailStep` (493–497)
each early-return unless `target > current_sl + point*0.5` (or the short-side mirror). Any
EA delegating to those is safe by construction.

## 5. Source classification method + result

Mechanical scan of all 139 `.mq5` for `QM_TM_Move*/Trail*`, `PositionModify/OrderModify`,
and per-tick `QM_LogEvent/Print/PrintFormat`; **every** hit was then read. Findings:

- **107** — empty-management skeleton (`Strategy_ManageOpenPosition` is a no-op or absent),
  no per-tick modify, no extra per-tick logging. Class `clean:no-mgmt`. (Representative:
  QM5_10296, read in full — manage body is a comment only.)
- **28** — has modify calls, all **guarded** (monotonic `> current_sl + point*0.5` /
  one-shot break-even flags) or delegated to the self-limiting framework primitives.
  Class `clean:guarded-trail`. All 29 modify-bearing EAs were read or primitive-verified.
- **3** — per-tick-looking `QM_LogEvent`, all gated: QM5_10718 (`BASKET_REBALANCE/REGIME`
  logged only *after* `if(!QM_IsNewBar()) return;` and only on the rebalance weekday —
  a few lines/week), QM5_1173 (`SPREAD_LEG_OPEN_FAIL` in the new-bar-gated entry path,
  returns after one log), QM5_9459 (`BOOTSTRAP_INSUFFICIENT` one-shot warmup). Class
  `clean:gated-log`.
- **1** — **QM5_10923** (`grimes-donchian`): `Strategy_ManageOpenPosition` runs every tick
  (called at OnTick:396, before the new-bar gate at :416) and, once past 2R, calls
  `QM_TM_MoveSL(ticket, new_sl, "grimes_trail_after_2r")` at line 301 **with no
  `new_sl > current_sl` guard**. `new_sl` is constant within a D1 bar (from
  `g_best_close_since_ent` ± D1-ATR shift 1), so it re-issues the *same, unchanged* SL
  every tick → per-tick `TM_MODIFY`. Class `OTHER-BOMB(latent)`. Distinct from 11072
  (constant target + missing guard, vs jittery target + too-tight guard). It nonetheless
  holds PASS verdicts, so it did not storm on the tested symbols (positions rarely dwell
  past 2R long enough to exceed the 1,500 MB/min rate cap) — a latent risk on a strongly
  trending symbol, not the cause of its `summary_missing` row.

Two mechanical flags were false positives on read: QM5_9920 (`MathAbs(tp-extended_tp)>point`
but `extended_tp` is derived from `price_open` — constant for the position's life, so it
fires once) and QM5_11019 (BE and ATR-buffer trails both monotonic-guarded).

## 6. The 4 genuine-overlap EAs

Four family EAs additionally own a **separate**, genuine, rate-killed log-bomb row (all
dated 2026-06-30, 0.6–0.7 GB, `verdict_reason=LOG_BOMB`) — these are *not* among the
4,236, they are among the disjoint 80:

| EA | genuine row | current source |
|---|---|---|
| QM5_10715 (`tv-asian-box`) | EURUSD 0.6 GB | **no per-tick modify at all** |
| QM5_11699 (`sma-m5-scalp`) | GBPUSD 0.7 GB | no per-tick modify |
| QM5_9991 (`ff-tmt-scalp-m15`) | EURUSD 0.6 GB | no per-tick modify |
| QM5_10952 (`ftmo-fvg-edge`) | EURUSD 0.6 GB | modify present, monotonic-guarded |

Since three of the four have no per-tick modify whatsoever and the fourth is guarded, the
06-30 kills are consistent with an **already-remediated framework storm** — most likely the
per-tick `QM_Magic/QM_MagicChecked` slot-warning flood, whose `warn_new` dedup landed
2026-06-21 (commit `8fe875926`, "log-bomb root cause"), reaching these EAs only if they ran
a **stale pre-fix `.ex5`**. No live source defect; recompiling against current framework
before any rerun neutralises it.

## 7. Repair recipes (precise, per class)

**Class A — SAME-MECHANISM (spread-jitter vs sub-pip threshold): 0 members.**
Recipe (documented for the fixer; this is the 11072 pattern in `54efb0c66`): in the
per-tick management function, (a) remove `spread`/`ask`/`bid` from the SL/TP *target* so it
is computed only from closed-bar values, and/or (b) replace the sub-pip `> point` threshold
with `> pip` **and** replace any bidirectional `MathAbs(target-current) > …` compare with a
monotonic one (`is_buy ? target > current + pip : target < current - pip`). Behaviour is
preserved because the closed-bar band moves at most once per bar. **No family member needs
this.**

**Class B — OTHER-BOMB, unguarded per-tick modify: 1 member (QM5_10923).**
Add the standard monotonic hysteresis guard immediately before the `MoveSL` at line 301,
matching the framework primitives:
```mql5
const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
const bool improves = (current_sl <= 0.0) ||
    (is_buy ? (new_sl > current_sl + point * 0.5)
            : (new_sl < current_sl - point * 0.5));
if(improves)
   QM_TM_MoveSL(ticket, new_sl, "grimes_trail_after_2r");
```
(`current_sl` = `PositionGetDouble(POSITION_SL)`, read once in the function.) This makes it
fire once per genuine advance instead of every tick, preserving the trail. QM5_10923 holds
real Q02/Q03/Q04 verdicts → **apply in a variant (e.g. `QM5_10923_v2`), not in place.**

**Class C — NO-SOURCE-BOMB / mislabel: 138 members.** **No EA edit.** The rows are
`summary_missing` transport failures. Two correct actions:
1. **Reclassifier fix (the real repair):** make `_has_log_bomb` require genuine kill
   evidence — `verdict_reason=='LOG_BOMB'`, or `'LOG_BOMB' in reason_classes`, or a
   `log_bomb_journal_*` key — and **drop the bare `attempt_count>=99` branch** (or gate it
   behind one of those markers). The cascade then re-buckets these 4,236 to their true
   classes (`pair_has_verdict` / history-lock transient / `never_worked`). This is a
   reversible in-place payload rewrite exactly like the run that produced the mislabel
   (`--apply` writes a snapshot; `--revert` restores).
2. The affected `(EA, symbol)` pairs already auto-heal via the history-lock
   transient-retry class in `terminal_worker` (steers off the sick terminal, does not burn
   the strategy retry budget). No per-EA work.

## 8. Gate evidence — variant vs in-place (per task step 5)

A "real verdict" = any `verdict` in the PASS/FAIL/RETIRE/ZERO_TRADES/NEED_MORE_DATA family
at any phase (INFRA_FAIL / INVALID / NULL / SUPERSEDED excluded). **122 / 139 hold one and
must be varianted; 17 / 139 are stranded and could be fixed in place.** The 17 stranded:

`QM5_10794, QM5_11174, QM5_10850, QM5_11223, QM5_11091, QM5_9992, QM5_9271, QM5_10518,
QM5_10016, QM5_9357, QM5_10782, QM5_1173, QM5_11029, QM5_9525, QM5_10882, QM5_10031,
QM5_11112`.

None of the 17 carries a source bomb (all `clean:*`), so in practice **no in-place EA edit
is warranted anywhere in the family**. The lone latent bomb (QM5_10923) is in the
varianted-122.

## 9. Recommended next steps for the fixer

1. Do **not** edit 138 EAs. Fix the reclassifier (§7 Class C) — one tool change re-buckets
   4,233 rows correctly and stops the histogram/dashboard corruption.
2. Cut a variant of **QM5_10923** with the §7-Class-B guard (it is the only EA with a real
   latent source bomb; it has verdicts, so variant not in-place).
3. For the 4 genuine-06-30 EAs (§6): recompile against current framework, then a single
   requeue; no source change.
4. Optional: verify the reclassifier fix against the disjoint 80 genuine rows to confirm
   they still classify as `log_bomb` after the `attempt_count>=99` branch is removed.

---

## Evidence appendix

- DB: `D:/QM/strategy_farm/state/farm_state.sqlite` (all queries read-only, `mode=ro`).
- Family query: `phase='Q02'` ∧ payload `failure_subclass='log_bomb'` → 4,236 rows / 139 EAs.
- Row-signal aggregate (§2): 0/4,236 genuine kill artifacts; `attempt_count=99` ∧
  `final_failure=summary_missing_retries_exhausted` on all.
- `attempt_count>=99` census (§2): 5,236 Q02 rows across ≥8 `verdict_reason` values.
- Genuine log-bomb population (§2/§6): 80 Q02 rows, `verdict_reason=LOG_BOMB` +
  `log_bomb_journal_gb`; 4 owners intersect the 139.
- Reclassifier: `tools/strategy_farm/classify_summary_missing.py:21,80,115–137`.
- Genuine-kill record: `tools/strategy_farm/terminal_worker.py:2552,2568–2633`.
- Rate/ceiling guard: `terminal_worker.py:144–148,2352–2379`.
- History-lock transport storm: `terminal_worker.py:95–110`.
- Modify primitives (no tester dedup; live-only hygiene): `QM_TradeManagement.mqh:147,
  368–382`; self-limiting trails `414–418, 452–456, 493–497`.
- Magic-slot per-tick warning + dedup fix: `QM_MagicResolver.mqh:51,58,65`; commit
  `8fe875926` (2026-06-21).
- FW8 Friday-close once-per-day guard (a since-fixed per-tick storm class):
  `QM_Common.mqh:666–692`.
- Reference EA fix: commit `54efb0c66` (QM5_11072), diagnosis
  `docs/ops/evidence/2026-07-27_fresh_infra_fail_diagnosis.md`.
- Full per-EA table: §Appendix B below.

## Appendix B — full 139-EA classification

`source-class`: `clean:no-mgmt` (empty/absent management) · `clean:guarded-trail`
(monotonic-guarded or framework-primitive trail) · `clean:gated-log` (per-tick log is
new-bar-gated/one-shot) · `OTHER-BOMB(latent)` (unguarded per-tick modify).
`gate-evidence`: phases with a real verdict, or `STRANDED(in-place)`.
`note: +genuine0630` = also owns a separate genuine 06-30 rate-kill row (§6).

| # | EA | rows | dir | source-class | gate-evidence | note |
|---|----|-----:|-----|--------------|---------------|------|
| 1 | QM5_10718 | 260 | QM5_10718_edgelab-regime-filtered-carry | clean:gated-log | verdict:Q02 |  |
| 2 | QM5_10296 | 154 | QM5_10296_cinar-cmf | clean:no-mgmt | verdict:Q02/Q03/Q04 |  |
| 3 | QM5_1703 | 151 | QM5_1703_sperandeo-multiple-top-bottom-h4 | clean:no-mgmt | verdict:Q02 |  |
| 4 | QM5_2003 | 149 | QM5_2003_nnfx-wave-sniper | clean:no-mgmt | verdict:Q02 |  |
| 5 | QM5_2004 | 149 | QM5_2004_nnfx-trix-momentum | clean:no-mgmt | verdict:Q02/Q03/Q04 |  |
| 6 | QM5_10454 | 81 | QM5_10454_mql5-supermac | clean:no-mgmt | verdict:Q02/Q04 |  |
| 7 | QM5_10795 | 71 | QM5_10795_tv-atr-rip | clean:no-mgmt | verdict:Q02 |  |
| 8 | QM5_10794 | 70 | QM5_10794_tv-atr-st | clean:guarded-trail | STRANDED(in-place) |  |
| 9 | QM5_10694 | 69 | QM5_10694_tv-ict-silver | clean:no-mgmt | verdict:Q02/Q04 |  |
| 10 | QM5_10772 | 69 | QM5_10772_tv-ny-vwap-ret | clean:no-mgmt | verdict:Q02/Q04 |  |
| 11 | QM5_12110 | 64 | QM5_12110_mtf-stochastic-confirmation | clean:no-mgmt | verdict:Q02/Q03/Q04 |  |
| 12 | QM5_1078 | 59 | QM5_1078_as-trinity-lite | clean:no-mgmt | verdict:Q02 |  |
| 13 | QM5_12382 | 52 | QM5_12382_ts-mom-12m | clean:no-mgmt | verdict:Q02/Q03 |  |
| 14 | QM5_11174 | 51 | QM5_11174_weiss-7rev | clean:no-mgmt | STRANDED(in-place) |  |
| 15 | QM5_10912 | 50 | QM5_10912_grimes-failtest | clean:no-mgmt | verdict:Q02/Q04 |  |
| 16 | QM5_10360 | 49 | QM5_10360_et-donch-decay | clean:guarded-trail | verdict:Q02 |  |
| 17 | QM5_10711 | 49 | QM5_10711_tv-mktopen-imp | clean:guarded-trail | verdict:Q02/Q04 |  |
| 18 | QM5_10850 | 49 | QM5_10850_tv-bbmr-long | clean:no-mgmt | STRANDED(in-place) |  |
| 19 | QM5_11224 | 49 | QM5_11224_ft-tdseq | clean:no-mgmt | verdict:Q02/Q04 |  |
| 20 | QM5_1145 | 49 | QM5_1145_cliff-cooper-intraday-only-idx | clean:no-mgmt | verdict:Q02/Q03/Q04 |  |
| 21 | QM5_10710 | 47 | QM5_10710_tv-asian-retbrk | clean:no-mgmt | verdict:Q02/Q03/Q04 |  |
| 22 | QM5_11223 | 46 | QM5_11223_ft-simple | clean:no-mgmt | STRANDED(in-place) |  |
| 23 | QM5_1233 | 46 | QM5_1233_ict-silver-bullet | clean:no-mgmt | verdict:Q02/Q04 |  |
| 24 | QM5_10818 | 43 | QM5_10818_tv-gemini-ema | clean:no-mgmt | verdict:Q02/Q04 |  |
| 25 | QM5_11091 | 42 | QM5_11091_stoch-mtf-state | clean:no-mgmt | STRANDED(in-place) |  |
| 26 | QM5_9992 | 42 | QM5_9992_ff-rsi-cci-4555 | clean:guarded-trail | STRANDED(in-place) |  |
| 27 | QM5_9271 | 42 | QM5_9271_mql5-ifvg-reversal | clean:no-mgmt | STRANDED(in-place) |  |
| 28 | QM5_10517 | 41 | QM5_10517_mql5-pct-chan | clean:no-mgmt | verdict:Q02 |  |
| 29 | QM5_10571 | 41 | QM5_10571_mql5-pchan-stop | clean:no-mgmt | verdict:Q02/Q04 |  |
| 30 | QM5_10784 | 41 | QM5_10784_tv-orbo-basic | clean:no-mgmt | verdict:Q02/Q04/Q05 |  |
| 31 | QM5_10792 | 41 | QM5_10792_tv-cipher-div | clean:no-mgmt | verdict:Q02 |  |
| 32 | QM5_10867 | 41 | QM5_10867_tv-xau-smc-0618 | clean:no-mgmt | verdict:Q02/Q03/Q04/Q05 |  |
| 33 | QM5_10518 | 40 | QM5_10518_mql5-sarima | clean:no-mgmt | STRANDED(in-place) |  |
| 34 | QM5_10541 | 40 | QM5_10541_mql5-20prexp | clean:no-mgmt | verdict:Q02 |  |
| 35 | QM5_10008 | 40 | QM5_10008_ff-sd-first-touch-h1 | clean:no-mgmt | verdict:Q02/Q04 |  |
| 36 | QM5_10492 | 39 | QM5_10492_mql5-daydream | clean:no-mgmt | verdict:Q02 |  |
| 37 | QM5_10577 | 39 | QM5_10577_mql5-ma-round | clean:no-mgmt | verdict:Q02/Q04 |  |
| 38 | QM5_10581 | 39 | QM5_10581_mql5-lr-slope | clean:no-mgmt | verdict:Q02/Q04 |  |
| 39 | QM5_10587 | 39 | QM5_10587_mql5-modopt | clean:no-mgmt | verdict:Q02/Q03/Q04 |  |
| 40 | QM5_9458 | 39 | QM5_9458_gk-2macd-sto | clean:no-mgmt | verdict:Q02/Q04 |  |
| 41 | QM5_10016 | 39 | QM5_10016_ff-ema100-bb-tdi-h1 | clean:no-mgmt | STRANDED(in-place) |  |
| 42 | QM5_10493 | 38 | QM5_10493_mql5-sidus | clean:no-mgmt | verdict:Q02/Q04 |  |
| 43 | QM5_10356 | 37 | QM5_10356_et-trigger-sar | clean:guarded-trail | verdict:Q02 |  |
| 44 | QM5_11012 | 36 | QM5_11012_the5ers-strength-pair | clean:no-mgmt | verdict:Q02 |  |
| 45 | QM5_12356 | 35 | QM5_12356_orev-ma-break | clean:no-mgmt | verdict:Q02 |  |
| 46 | QM5_9513 | 34 | QM5_9513_lt-breakout-stack | clean:guarded-trail | verdict:Q02 |  |
| 47 | QM5_10860 | 33 | QM5_10860_tv-htf-candle | clean:no-mgmt | verdict:Q02/Q03/Q04 |  |
| 48 | QM5_9357 | 32 | QM5_9357_mql5-orb-break | clean:no-mgmt | STRANDED(in-place) |  |
| 49 | QM5_1634 | 32 | QM5_1634_mql5-consolid-break | clean:no-mgmt | verdict:Q02 |  |
| 50 | QM5_10835 | 32 | QM5_10835_tv-st-long-filter | clean:guarded-trail | verdict:Q02 |  |
| 51 | QM5_9194 | 31 | QM5_9194_mql5-rvgi-cci | clean:guarded-trail | verdict:Q02 |  |
| 52 | QM5_9291 | 31 | QM5_9291_mql5-dem-env-break | clean:no-mgmt | verdict:Q02/Q03/Q04/Q05 |  |
| 53 | QM5_1083 | 29 | QM5_1083_chan-gld-gdx-z2 | clean:no-mgmt | verdict:Q02 |  |
| 54 | QM5_10789 | 29 | QM5_10789_tv-band-zigzag | clean:no-mgmt | verdict:Q02/Q03/Q04 |  |
| 55 | QM5_10946 | 29 | QM5_10946_zuck-weekend-cont | clean:no-mgmt | verdict:Q02 |  |
| 56 | QM5_12389 | 27 | QM5_12389_asset-rot-mom | clean:guarded-trail | verdict:Q02 |  |
| 57 | QM5_10782 | 26 | QM5_10782_tv-smc-btc-r3 | clean:no-mgmt | STRANDED(in-place) |  |
| 58 | QM5_11018 | 26 | QM5_11018_the5ers-outbar-cont | clean:guarded-trail | verdict:Q02 |  |
| 59 | QM5_1069 | 26 | QM5_1069_carver-assettrend | clean:no-mgmt | verdict:Q02/Q03/Q04/Q05/Q06 |  |
| 60 | QM5_11755 | 25 | QM5_11755_davey-big-range-momentum-h1 | clean:no-mgmt | verdict:Q02 |  |
| 61 | QM5_9920 | 25 | QM5_9920_ff-mtf-candle-color-m5 | clean:guarded-trail | verdict:Q02/Q04 |  |
| 62 | QM5_10947 | 25 | QM5_10947_zuck-24h-cont | clean:no-mgmt | verdict:Q02/Q04 |  |
| 63 | QM5_11021 | 25 | QM5_11021_the5ers-stoprun-bos | clean:guarded-trail | verdict:Q02 |  |
| 64 | QM5_11019 | 24 | QM5_11019_the5ers-ema-tunnel | clean:guarded-trail | verdict:Q02 |  |
| 65 | QM5_10836 | 23 | QM5_10836_tv-gann-phase | clean:no-mgmt | verdict:Q02/Q04 |  |
| 66 | QM5_10691 | 23 | QM5_10691_tv-smc-pro-btc | clean:no-mgmt | verdict:Q02/Q03/Q04 |  |
| 67 | QM5_10945 | 23 | QM5_10945_zuck-event-rebound | clean:no-mgmt | verdict:Q02 |  |
| 68 | QM5_11699 | 22 | QM5_11699_anon-sma10-15-50-m5-scalp | clean:no-mgmt | verdict:Q02/Q04 | +genuine0630 |
| 69 | QM5_11016 | 22 | QM5_11016_the5ers-fib-breaker | clean:no-mgmt | verdict:Q02/Q03 |  |
| 70 | QM5_11014 | 22 | QM5_11014_the5ers-mprof-va | clean:no-mgmt | verdict:Q02/Q04 |  |
| 71 | QM5_9582 | 21 | QM5_9582_ff-sdtr-h4 | clean:no-mgmt | verdict:Q02 |  |
| 72 | QM5_11458 | 21 | QM5_11458_goodwin-friday-monday-gap-d1 | clean:no-mgmt | verdict:Q02/Q04 |  |
| 73 | QM5_10941 | 21 | QM5_10941_grimes-keltner-pb | clean:no-mgmt | verdict:Q02/Q03/Q04 |  |
| 74 | QM5_10949 | 21 | QM5_10949_zuck-fri-band | clean:no-mgmt | verdict:Q02/Q03/Q04/Q05 |  |
| 75 | QM5_11015 | 21 | QM5_11015_the5ers-weekly-ny | clean:no-mgmt | verdict:Q02 |  |
| 76 | QM5_11753 | 20 | QM5_11753_5min-sma10-15-50-scalp | clean:no-mgmt | verdict:Q02/Q04 |  |
| 77 | QM5_11739 | 20 | QM5_11739_rfs-alligator-sma144-m15 | clean:no-mgmt | verdict:Q02 |  |
| 78 | QM5_9967 | 20 | QM5_9967_ff-ema2550-rsi-h1 | clean:guarded-trail | verdict:Q02/Q04 |  |
| 79 | QM5_10838 | 20 | QM5_10838_tv-m15-eurusd | clean:guarded-trail | verdict:Q02 |  |
| 80 | QM5_11010 | 20 | QM5_11010_the5ers-quasimodo-retest | clean:no-mgmt | verdict:Q02/Q04 |  |
| 81 | QM5_11020 | 20 | QM5_11020_the5ers-london-bo | clean:no-mgmt | verdict:Q02/Q04 |  |
| 82 | QM5_1173 | 20 | QM5_1173_qp-eafe-spy-sma-spread | clean:gated-log | STRANDED(in-place) |  |
| 83 | QM5_9361 | 19 | QM5_9361_mql5-ichi-kumo-bounce | clean:no-mgmt | verdict:Q02 |  |
| 84 | QM5_9637 | 19 | QM5_9637_williams-ocr-reversal-h4 | clean:no-mgmt | verdict:Q02/Q03/Q04 |  |
| 85 | QM5_11028 | 19 | QM5_11028_atc-wma-rev | clean:no-mgmt | verdict:Q02/Q03/Q04 |  |
| 86 | QM5_9927 | 18 | QM5_9927_ff-2b2b-base-m1 | clean:no-mgmt | verdict:Q02 |  |
| 87 | QM5_9412 | 18 | QM5_9412_mql5-paq-engulf | clean:no-mgmt | verdict:Q02 |  |
| 88 | QM5_9459 | 18 | QM5_9459_gk-af-aos-md | clean:gated-log | verdict:Q02/Q03/Q04 |  |
| 89 | QM5_9640 | 18 | QM5_9640_colby-disparity-index-h4 | clean:no-mgmt | verdict:Q02 |  |
| 90 | QM5_11029 | 18 | QM5_11029_atc-time-momo | clean:no-mgmt | STRANDED(in-place) |  |
| 91 | QM5_10952 | 17 | QM5_10952_ftmo-fvg-edge | clean:guarded-trail | verdict:Q02/Q04 | +genuine0630 |
| 92 | QM5_9360 | 17 | QM5_9360_mql5-ichi-kumo-cross | clean:no-mgmt | verdict:Q02 |  |
| 93 | QM5_9525 | 17 | QM5_9525_mql5-ema50-retest | clean:no-mgmt | STRANDED(in-place) |  |
| 94 | QM5_9697 | 17 | QM5_9697_ff-thv-trix-coral-m5 | clean:no-mgmt | verdict:Q02/Q04 |  |
| 95 | QM5_9903 | 17 | QM5_9903_ff-roadmap-do-fail-m5 | clean:no-mgmt | verdict:Q02/Q04 |  |
| 96 | QM5_9926 | 17 | QM5_9926_ff-riverband-sop-m5 | clean:guarded-trail | verdict:Q02/Q04 |  |
| 97 | QM5_10957 | 17 | QM5_10957_ftmo-mtf-range | clean:no-mgmt | verdict:Q02 |  |
| 98 | QM5_10557 | 17 | QM5_10557_mql5-trigger | clean:no-mgmt | verdict:Q02/Q03/Q04 |  |
| 99 | QM5_12386 | 17 | QM5_12386_comm-mom12m | clean:no-mgmt | verdict:Q02 |  |
| 100 | QM5_10955 | 16 | QM5_10955_ftmo-mr-div | clean:no-mgmt | verdict:Q02 |  |
| 101 | QM5_10956 | 16 | QM5_10956_ftmo-vwap-pb | clean:guarded-trail | verdict:Q02/Q04 |  |
| 102 | QM5_9362 | 16 | QM5_9362_mql5-ichi-chikou-span | clean:no-mgmt | verdict:Q02/Q04/Q05 |  |
| 103 | QM5_9638 | 16 | QM5_9638_demark-td-termination-active-h4 | clean:no-mgmt | verdict:Q02/Q03/Q04/Q05/Q06/Q07/Q08 |  |
| 104 | QM5_9928 | 16 | QM5_9928_ff-d1-elasticity-m15 | clean:guarded-trail | verdict:Q02 |  |
| 105 | QM5_11750 | 16 | QM5_11750_nfs-ema3-psar-h1-profit | clean:no-mgmt | verdict:Q02/Q03/Q04 |  |
| 106 | QM5_9975 | 16 | QM5_9975_ff-pipsaccumulator-d1 | clean:guarded-trail | verdict:Q02/Q03/Q04 |  |
| 107 | QM5_11023 | 16 | QM5_11023_mql5-env-rev | clean:no-mgmt | verdict:Q02/Q04 |  |
| 108 | QM5_10948 | 16 | QM5_10948_zuck-fx-period-momo | clean:no-mgmt | verdict:Q02 |  |
| 109 | QM5_9991 | 14 | QM5_9991_ff-tmt-scalp-m15 | clean:no-mgmt | verdict:Q02/Q04 | +genuine0630 |
| 110 | QM5_11332 | 13 | QM5_11332_tc-m5-18-ema20-macd-cross-trail | clean:guarded-trail | verdict:Q02 |  |
| 111 | QM5_10882 | 13 | QM5_10882_nt-bear-rsi | clean:no-mgmt | STRANDED(in-place) |  |
| 112 | QM5_10031 | 10 | QM5_10031_rw-gold-week-seas | clean:no-mgmt | STRANDED(in-place) |  |
| 113 | QM5_10024 | 10 | QM5_10024_rw-fx-comm-basket | clean:no-mgmt | verdict:Q02 |  |
| 114 | QM5_10907 | 9 | QM5_10907_carter-ema60-pb | clean:no-mgmt | verdict:Q02/Q04 |  |
| 115 | QM5_1238 | 4 | QM5_1238_tv-vwap-rsi-cont | clean:guarded-trail | verdict:Q02/Q03/Q04 |  |
| 116 | QM5_10355 | 4 | QM5_10355_et-session-orb | clean:no-mgmt | verdict:Q02 |  |
| 117 | QM5_10950 | 4 | QM5_10950_rentech-short-trend | clean:guarded-trail | verdict:Q02/Q03/Q04/Q05 |  |
| 118 | QM5_10090 | 3 | QM5_10090_mql5-harami-h1 | clean:no-mgmt | verdict:Q02/Q04 |  |
| 119 | QM5_10921 | 3 | QM5_10921_grimes-bearflag | clean:guarded-trail | verdict:Q02/Q03/Q04 |  |
| 120 | QM5_1258 | 2 | QM5_1258_hopwood-bermaui-rsi-h1 | clean:no-mgmt | verdict:Q02/Q03/Q04 |  |
| 121 | QM5_10542 | 2 | QM5_10542_mql5-bigdog | clean:no-mgmt | verdict:Q02/Q03/Q04/Q05 |  |
| 122 | QM5_10619 | 2 | QM5_10619_mql5-dcpl-rsi | clean:no-mgmt | verdict:Q02 |  |
| 123 | QM5_10497 | 2 | QM5_10497_mql5-3sma | clean:no-mgmt | verdict:Q02 |  |
| 124 | QM5_10953 | 2 | QM5_10953_ftmo-inside-brk | clean:guarded-trail | verdict:Q02/Q04/Q05 |  |
| 125 | QM5_11112 | 2 | QM5_11112_sr-lines-fade | clean:no-mgmt | STRANDED(in-place) |  |
| 126 | QM5_11027 | 2 | QM5_11027_atc-lr-slope | clean:guarded-trail | verdict:Q02 |  |
| 127 | QM5_10478 | 1 | QM5_10478_mql5-bago | clean:no-mgmt | verdict:Q02/Q04 |  |
| 128 | QM5_10715 | 1 | QM5_10715_tv-asian-box | clean:no-mgmt | verdict:Q02/Q03/Q04/Q05/Q06/Q07/Q08/Q09_PORTFOLIO | +genuine0630 |
| 129 | QM5_10140 | 1 | QM5_10140_tv-london-session-break | clean:no-mgmt | verdict:Q02 |  |
| 130 | QM5_10314 | 1 | QM5_10314_fx-open-close-momentum | clean:no-mgmt | verdict:Q02/Q04 |  |
| 131 | QM5_10780 | 1 | QM5_10780_tv-ny-orb-dyn | clean:no-mgmt | verdict:Q02 |  |
| 132 | QM5_10802 | 1 | QM5_10802_tv-wma-vwap | clean:no-mgmt | verdict:Q02/Q03/Q04 |  |
| 133 | QM5_10833 | 1 | QM5_10833_tv-autobot12 | clean:no-mgmt | verdict:Q02/Q04 |  |
| 134 | QM5_10837 | 1 | QM5_10837_tv-zscore-mr | clean:no-mgmt | verdict:Q02/Q03 |  |
| 135 | QM5_10958 | 1 | QM5_10958_ftmo-ib-brk | clean:guarded-trail | verdict:Q02/Q04 |  |
| 136 | QM5_11026 | 1 | QM5_11026_ema-wpr-m5 | clean:no-mgmt | verdict:Q02 |  |
| 137 | QM5_11022 | 1 | QM5_11022_mql5-macd-env | clean:guarded-trail | verdict:Q02/Q04 |  |
| 138 | QM5_10007 | 1 | QM5_10007_ff-prevday-breakout-edge | clean:no-mgmt | verdict:Q02/Q04 |  |
| 139 | QM5_10923 | 1 | QM5_10923_grimes-donchian | OTHER-BOMB(latent) | verdict:Q02/Q03/Q04 |  |
