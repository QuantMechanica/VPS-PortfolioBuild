# Balke family × XAUUSD — adjudication (QM-TODO-20260823-504)

- Task: `051eb0bf-1978-42ac-9ae3-bf207529ea8c` (ops_issue, priority 64)
- Verdict: **premise correction + one actionable, ROT-blocked recommendation**

## Step 1 — is the 13213×XAUUSD RETIRE a genuine no-signal or an artifact?

**Genuine, correctly-parameterized negative — not an artifact.** The single Q02
row (`2cdf1846-1513-4863-b797-5448fb7a283a`, RETIRE, 2026-07-29) is an MNT009
legacy-disposition overlay, not a fresh Q02 numeric verdict. Its
`invalidated_reason` points to
`docs/research/BALKE_RANGE_BREAKOUT_WALKFORWARD_2026-07-14.md`, which is the
actual test that matters here:

- That walkforward used **Balke's own video-derived exact parameters**
  (03:00–06:00 broker time, GMT+2/+3 DST-aware via `Strategy_Gmt3Hour`) — the
  same correct-window logic that made USDJPY pass (1142's 22:00-raw-broker
  window was the earlier, wrong-parameter mistake; 13213 already carries the
  fix).
- XAU OOS (2021-10→2025-12, 970 trades): **PF 1.03 gross**, net +$13.3k vs
  MaxDD **−$40.6k**. Breakeven-before-costs with real drawdown risk — costed
  it goes negative.
- This reproduces Balke's own stated caveat ("gold has drawdown phases") and
  the independent master-EA finding that XAU range-breakout styles whipsaw.

So: for 13213 specifically, XAUUSD **was tested with the correct parameters**
and failed on the merits. The OWNER's 2026-08-23 premise ("we either never
tested them or used the wrong parameters") does not hold for this EA — the
right parameters were used, and they lose. This is not a candidate-pool
question, so no ROT boundary is touched by stating it.

## Step 2 — dispatch 13036 (GDAXI Q10 survivor) to XAUUSD?

**Genuinely never run** — confirmed via `work_items` (only GDAXI + one NDX
Q02 FAIL row for QM5_13036) and via the EA's `sets/` dir (GDAXI + NDX
setfiles only, no XAUUSD). 13036 (`balke-go-long-regime`) is mechanically
distinct from 13213 (`balke-gmt3-range-breakout`) — the negative walkforward
above does not cover it. This is a real, open gap, not duplicate work.

**But opening it requires actions outside my standing autonomy:**

- No `magic_numbers.csv` row exists for 13036×XAUUSD (only slots 0=NDX,
  1=GDAXI). Adding one is routine registry work, but the resolver mutation
  that must follow it (`update_magic_resolver.py` regen + **EA recompile** so
  the static `QM_MagicResolver.mqh` array picks up the new slot) is
  `recompile in active inventory` — explicitly listed **ROT** in the standing
  authorization (never autonomous), not GRÜN/GELB.
- Independently, `dwx_symbol_matrix.csv` currently flags XAUUSD.DWX custom
  history with `FAIL_tail_mid_bars` (`tail_ms got=0`, `bars_one_shot=0`,
  `bars_drift=-100,000`) — the same class of transient `NO_HISTORY` issue the
  ops runbook treats as self-healing cold-cache, but it means a same-day
  XAUUSD dispatch risks an uninformative `INFRA_FAIL` rather than a clean
  verdict.

## Recommendation (queued for OWNER, not executed)

1. Correct the premise: 13213×XAUUSD is a documented negative with Balke's
   own correct parameters, not an untested/mis-parameterized hole. Do not
   requeue 13213 on XAUUSD.
2. 13036×XAUUSD is a genuine open gap. Opening it needs a magic-registry row
   + resolver regen + recompile — OWNER sign-off requested before that
   recompile step runs (ROT boundary), after which the append-only Q02
   dispatch itself is routine GRÜN fanout.
3. Once XAUUSD.DWX's `FAIL_tail_mid_bars` custom-history state clears (or is
   confirmed self-healed), re-verify before spending a factory slot on the
   new pairing.

No registry, magic-resolver, or work-item row was mutated by this
adjudication.
