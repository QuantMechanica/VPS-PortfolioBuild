# FTMO Demo Validation Contract

**Authority:** OWNER-DEC-CBE-20260915 (master directive 2026-09-15 section 12 and
follow-up sections 13-14). **Status:** active. **Owner surface:**
`tools/strategy_farm/ftmo/demo_cycle.py`, `docs/ops/FTMO_CHALLENGE_READINESS.md`.

This contract defines, deterministically:

1. which portfolio is under Demo validation,
2. when the representative two-week window began,
3. when a change makes existing Demo evidence no longer representative,
4. the Demo-cycle state machine and its outcomes.

It exists so the questions in follow-up directive section 13 can be answered from
data, not opinion. The paid decision remains OWNER-only and cannot be executed by
automation.

---

## 1. Which portfolio is under validation

The roster is **observed** read-only from the FTMO demo terminal's actual chart /
EA set (chart profile `.chr` files; fallback `ftmo_demo_attach_map.json`). Each
trading sleeve is `(ea_id, symbol, magic, risk_pct, ex5_sha)`. The governor and
telemetry EAs and empty charts are not sleeves.

**`roster_hash`** = SHA-256 of the sorted `(magic, ea_id, symbol)` tuples. It is
the **composition identity**. Risk and ex5 hash are deliberately excluded from
the identity hash so that risk changes and mechanics changes are classified
separately (below) rather than silently folded into a new identity.

## 2. When the two-week window began

`cycle_start_utc` = the first observation of the current `roster_hash`. The ledger
`ftmo_demo_cycle.json` records `roster_history` (each hash and its first-seen UTC),
so the start is stable and reproducible across runs. If no prior evidence exists,
the start bootstraps from the earliest available observation; if none is
available it is recorded as `UNKNOWN` with the evidence gap named - never guessed.

`validation_days` = now - `cycle_start_utc`. The minimum representative window is
**14 days** (`VALIDATION_MIN_DAYS`). Fourteen days is a **minimum evidence
period, not an auto-buy trigger** (directive section 12).

## 3. Material-change semantics (section 14)

The goal is to avoid both extremes: resetting the two-week clock for every tiny
change, and pretending an entirely different portfolio was already validated. A
change is classified deterministically by `classify_material_change`.

| Change | Material? | Representative-breaking? (resets cycle) |
|---|---|---|
| **Sleeve added** | yes | yes |
| **Sleeve removed** | yes | yes |
| **Risk changed** on surviving sleeves | yes iff aggregate risk delta > **X** of prior book risk | yes iff material |
| **Mechanics changed** (ex5 hash) on surviving sleeves | yes (for those sleeves) | yes iff affected risk share >= **Y** of book risk |
| **Compliance / news rule changed** | yes | yes |
| **Product changed** (size, Standard/Swing, step count) | yes | yes (new cycle) |
| Small parameter/preset change below the X/Y thresholds | logged, not material | no |

### Thresholds and their reasoning

- **X = 0.20** (`RISK_MATERIAL_BOOK_SHARE_X`). Book risk today is ~2.5%
  (8 sleeves x 0.3125%); a single sleeve is ~12.5% of book. X = 20% means a risk
  edit touching more than a fifth of deployed book risk resets/extends the
  validation, while a small tweak to one sleeve is logged only. An absolute floor
  `RISK_MATERIAL_ABS_PCT_FLOOR = 0.10` book-risk-percent points prevents a
  near-zero-risk book from making every change look "material".
- **Y = 0.10** (`MECHANICS_REPRESENTATIVE_BOOK_SHARE_Y`). A binary (ex5 hash)
  change is always material **for the affected sleeve**, but it only breaks
  portfolio-level representativeness when the affected sleeves carry **>= 10% of
  book risk**. Changing the mechanics of <10% of book risk does not invalidate the
  ~90% of evidence unaffected by the change.

X and Y are OWNER policy constants in `tools/strategy_farm/ftmo/policy_config.py`.
Changing them is an OWNER-only decision. They are a recommendation under directive
section 14; if the OWNER prefers different thresholds, edit the constants and cite
the decision.

## 4. State machine

```
NEW  ->  RUNNING  ->  REPRESENTATIVE  ->  DECISION_PACKAGE
 ^                                    |
 |  representative-breaking change    |
 +------------------------------------+
```

- **NEW** - a cycle just (re)started: first observation of the roster hash, or a
  representative-breaking change reset the clock.
- **RUNNING** - cycle observed, `validation_days < 14`, no representative-breaking
  change since start.
- **REPRESENTATIVE** - `validation_days >= 14` **and** no representative-breaking
  material change since `cycle_start_utc`.
- **DECISION_PACKAGE** - the readiness layer produced an OWNER decision package on
  a representative cycle; preserved while the cycle stays representative.

A representative-breaking change at any point sends the cycle back to **NEW** and
restarts the clock. Non-breaking material changes are appended to
`material_changes` and logged, but do not reset.

## 5. Outcomes (decision package, section 12)

The readiness layer maps the cycle + fitness + rule-freshness into exactly one of:

| Outcome (readiness enum) | Directive wording | Meaning |
|---|---|---|
| `NOT_READY` | NOT READY | Hard blocker, no fit candidate exists, or a realized breach. |
| `RECOMPOSE` | RECOMPOSE AND RESTART VALIDATION | Current book not FTMO-fit; build a different demo book (restarts cycle). |
| `CONTINUE_DEMO` | EXTEND DEMO | Representative window not complete, or fit but pass-probability not yet evidenced. |
| `READY_FOR_OWNER_REVIEW` | (pre-BUY) | Representative + fit + rules fresh + first-passage in the OWNER-review band. |
| `BUY_100K_2STEP_RECOMMENDED` | BUY RECOMMENDED | All go-criteria met; recommend the OWNER buy one 100k 2-Step Challenge. |

The recommendation is advisory. The paid decision is executed by the OWNER by
hand; no code path in `tools/strategy_farm/ftmo/` acts on a paid Challenge
(enforced by `tests/test_ftmo_no_purchase_guard.py`).

## 6. Current honest state (2026-09-15)

The running demo book is 8 DXZ-derived swing sleeves - an explorative "M13"
capture, **not a frozen intended-challenge portfolio**. Cycle-1 realized -9.95%
with a -10.26% max drawdown (breaching the 10% total-loss limit); no candidate
clears the FUND_SCORE floor and Q10 admits 0/42. The two-week clock has therefore
not begun on any intended roster. See `docs/ops/FTMO_CHALLENGE_READINESS.md`.
