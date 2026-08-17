# Z7 — the retry policy was already fixed, so it frees no slots; and Z1 — the engine is right, the 20 % was mine

## Z7: the premise for prioritising it is false

Z7 was prioritised on the reasoning that deterministic classes still consume retries, and that
stopping them *"setzt genau die Slots frei, die BUILD-0 fürs Nachfahren braucht"*. I checked the
code before dispatching, and the classes are **already non-retryable**:

`framework/scripts/_phase_utils.py:46-55`, `_NON_RETRYABLE_RUN_SMOKE_REASONS`:

```
ACCOUNT_NOT_SPECIFIED · EXECUTION_IDENTITY_DRIFT · LOG_BOMB · MIN_TRADES_NOT_MET
NON_DETERMINISTIC · ONINIT_FAILED · SETUP_DATA_MISSING · TIMEOUT
```

Added by `df5215f0d` (2026-07-25, *"WP-5 + WP-6 + WP-7 — cold-cache retry, provenance-bound
streams, durable Q04 evidence"*). And it works — measured across the fix date:

| | rows | total retries | retries/row |
|---|---:|---:|---:|
| ONINIT_FAILED **before** 2026-07-25 | 1,290 | 36,942 | **28.64** |
| ONINIT_FAILED **on/after** 2026-07-25 | 632 | 28 | **0.04** |
| `run_smoke_fail` INFRA_FAIL **before** | 6,025 | 50,690 | 8.41 |
| `run_smoke_fail` INFRA_FAIL **on/after** | 859 | 124 | **0.14** |

**A 700× reduction on ONINIT_FAILED and 60× on the whole `run_smoke_fail` class.**

### My P3 number was right and its implication was wrong

P3 reported "INFRA_FAIL consumes 3,701 of ~4,970 retries" over a window starting **2026-07-15** —
which straddles the 07-25 fix. The count is correct; the *implication* that this is ongoing waste
is not. Post-fix the class has consumed **124 retries across 23 days**, which is negligible against
any queue. My "1,275–5,100 slot-hours" band described **historical** waste that was already
stopped three weeks ago, and I presented it as a live cost. That is corrected here.

**Consequence for sequencing:** Z7 does **not** free slots. The 20 hours BUILD-0's catch-up needs
must come out of the 784-row queue, not out of retry savings. The priority question stands
unchanged and undiluted — there is no free capacity to find first.

### What genuinely remains, and it is small

`BARS_ZERO` sits in `COLD_CACHE_SIGNATURES` — the **retryable** set (`_phase_utils.py:36-45`) — and
is the only live case: 1.23 retries/row historically, and 8 rows with 19 retries today.

But today's eight are **all the 410xx exponent cohort**, whose root cause was fixed this morning at
the generator, and two of them (QM5_41033, QM5_41038) have since come back **PASS**. So the
dominant producer of retryable BARS_ZERO is already gone.

The residual argument for moving `BARS_ZERO` out of the retryable set is real but modest: today
proved that a deterministic OnInit configuration rejection *presents* as BARS_ZERO, and a retry
cannot fix it. The counter-argument is equally real — a genuinely cold cache also presents as
BARS_ZERO on first touch, and that one *does* self-heal. **So this is a split, not a move**: retry
BARS_ZERO only when no OnInit rejection marker is present in the same summary. Low priority, and I
am not inflating it into a slot-recovery programme.

## Z1: the engine matches the confirmed rule state; the 20 % was my labelling slip

`tools/strategy_farm/portfolio/ftmo_rules_engine.py:135-145`, `TWO_STEP_PHASE1`:

| Field | Value | Against the confirmed spec |
|---|---|---|
| `rule_set_id` | `FTMO_2_STEP_PHASE1_2026_07_21` | self-dating, matches the docstring's retrieval date |
| `maximum_daily_loss_fraction` | **0.05** | 5 % ✓ |
| `maximum_loss_fraction` | **0.10** | 10 % ✓ |
| `maximum_loss_model` | `STATIC_INITIAL` | **static**, not trailing |
| `profit_target_fraction` | **0.10** | 10 % — *not stated in the brief* |
| `minimum_trading_days` | 4 | |

**The engine is correct and so is the evaluation. The error was in my report.** The 20 % figure is
the **DZ** mandate's total drawdown limit from the mission baseline (DZ: 5 % daily / 20 % total),
and I let it stand in a sentence about FTMO. Two books, two limit sets; mixing them was mine.

### Two things this surfaces for BUILD-6

1. **The profit target is 10 %, and the brief does not mention it.** P(pass) depends on it at least
   as strongly as on the loss limits — a 60-day window must *reach* +10 % without touching −5 %
   daily or −10 % total. Any P(pass) curve computed without it is answering a different question.
2. **`maximum_loss_model = STATIC_INITIAL`** for Phase 1, so the 10 % is measured against the
   initial balance and does **not** trail. Note the contrast: `ONE_STEP_CHALLENGE` uses
   `EOD_TRAILING` with a 3 % daily limit — a different product. BUILD-6 must bind `TWO_STEP_PHASE1`
   explicitly, or it will silently simulate the wrong contract.

Also present and dated: `minimum_trading_days = 4` and `best_day_fraction = 0.50` on the one-step
product only.

## Runbook entry

> **FTMO rule state in force:** `FTMO_2_STEP_PHASE1_2026_07_21`. Source:
> <https://ftmo.com/en/trading-objectives/>, snapshot retrieved **2026-07-21**, encoded in
> `tools/strategy_farm/portfolio/ftmo_rules_engine.py` by `2f70864be` (2026-07-21) and hardened by
> `db4de96a3` (2026-07-29). Phase 1: profit target 10 %, daily loss 5 %, maximum loss 10 %
> **static** on the initial balance, minimum 4 trading days. Daily loss is measured against the
> balance at the Prague-midnight anchor and **includes open positions**.

## Evidence

- `framework/scripts/_phase_utils.py:36-45` (retryable set), `:46-55` (non-retryable set)
- `df5215f0d` (2026-07-25) — the commit that made the classes non-retryable
- retry rates measured across the fix date over all terminal rows carrying each token
- `tools/strategy_farm/portfolio/ftmo_rules_engine.py:123-157` — the three frozen rule sets
- related: `2026-08-17_P3_verdict_class_pass_and_gate_coverage.md` (the figure corrected here)
