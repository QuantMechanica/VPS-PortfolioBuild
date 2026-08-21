# Q07 zero-variance investigation — what the 104 zero-variance PASSes actually measured

**Date:** 2026-08-21 · **Mode:** read-only · **Author:** Claude (board-advisor worktree)
**Question:** For 104/300 Q07 PASS rows `variance_pct = 0.00`. Is the gate measuring
nothing (defect), or measuring something that cannot move (design vacuity)? They need
opposite fixes.

**Verdict up front:** It is a **defect**, and it is **two distinct legacy defects**, both
now fixed in the current runner but both baked into 104 historical PASSes that were never
re-graded. The Q07 variance metric itself is **correct** and not degenerate. Zero-variance
here means *the seed had no effect on the trade stream* — proven directly from surviving
evidence. Explanation **1 and 2 are both confirmed**, on different subsets; explanation 3
is refuted.

---

## 1 · Measured population (reproduced from `farm_state.sqlite`)

`work_items WHERE phase='Q07'`: 491 rows — 301 `PASS`, 74 `FAIL`, 96 `INFRA_FAIL`, 1
`PENDING_RUNNER`, 19 null. Of the 301 PASS rows, parsing `variance_pct` out of
`payload_json → verdict_reason`:

| bucket | count |
|---|---:|
| `variance_pct = 0.00` | **104** |
| `variance_pct > 0` | 196 |
| unparsable | 1 |

**Every one of the 104 is dated 2026-05/06/07. Zero are from 2026-08.**

| month | zero-variance PASS | non-zero PASS |
|---|---:|---:|
| 2026-05 | 7 | 4 |
| 2026-06 | 44 | 9 |
| 2026-07 | 53 | 126 |
| 2026-08 | 0 | 57 |

Entry-path class of the 104 (from each EA's `.mq5`): **91 standard-path** (open via
`QM_TM_OpenPosition → QM_Entry`), **13 basket-path** (`QM_BasketOpenPosition`). All 13
basket rows are 2026-07.

Of the 24 zero-variance rows whose five per-seed `report.htm` still survive and are
readable, the effective-seed pattern splits cleanly by class:

| class | surviving cases | effective-seed pattern | defect |
|---|---:|---|---|
| standard | 10 | all five reports `qm_rng_seed=42` | injector collapse (expl. 2) |
| basket | 10 | five **distinct** effective seeds, identical trades | no RNG draw (expl. 1) |
| standard | 4 | mixed / partially readable | residual, per-case |

---

## 2 · How the gate is wired (source, not observation)

- The Q07 variance metric is `variance_pct = (max(pf) − min(pf)) / mean(pf) × 100`
  (`framework/scripts/q07_multiseed.py:745`). It is exactly 0.00 **iff all five per-seed
  PFs are identical**. The formula is sound and moves whenever PFs differ — proven by the
  196 non-zero rows and by the QM5_1556 rerun below (21.2%). **Explanation 3 (degenerate
  metric) is refuted.**
- The central RNG (`framework/include/QM/QM_SeedRNG.mqh`) has **exactly one consumer** in
  the framework: the Q06-HARSH stress entry-rejection, drawn via
  `QM_RandBoolTagged("entry_reject", …)` **only when `g_qm_entry_stress_reject_prob > 0.0`**
  (`QM_Entry.mqh:333-339`; basket mirror `QM_BasketOrder.mqh:252-271`). If the RNG is never
  drawn, or is drawn from the same seed, all five runs are byte-for-byte the same trade
  stream and variance is 0.00.
- The HARSH set-files do carry `qm_stress_reject_probability=0.1000`, and the input is wired
  input → `QM_FrameworkInit` (`EA_Skeleton.mq5:158`) → `QM_EntryConfigure`
  (`QM_Common.mqh:296`) → `g_qm_entry_stress_reject_prob`. So at the *set-file and standard
  init* level the stress probability arrives. Zero-variance is therefore NOT "the stress
  input never reaches the EA" — it is one of the two failures below.

---

## 3 · Decisive case — QM5_1556 / XAUUSD (the live sleeve)

`work_items` verdict: **PASS**, status done, 2026-07-05, evidence
`…\work_items\5b9d5cf2-…\QM5_1556\Q07\XAUUSD_DWX\aggregate.json` (that dir is purged; the
canonical copy survives at `D:\QM\reports\pipeline\QM5_1556\Q07\aggregate.json`).

**Original Q07 (2026-07-05):** five physically distinct run dirs (`20260705_182418`,
`_183250`, `_184137`, `_185028`, `_185920`, ~8 min apart), yet every seed:
PF **2.02**, trades **59**, drawdown **2683.23 to the cent** → spread 0.0 → variance
**0.00** → **PASS** (`min_pf=2.020`).

**Rerun (2026-07-25, `D:\QM\reports\q07_rerun_20260725\1556_XAUUSD_DWX\…\aggregate.json`):**
same EA, same symbol, same 2017-2025 window — now PF **2.01 / 2.19 / 1.99 / 1.76 / 2.19**,
trades **49 / 49 / 48 / 48 / 47**, spread 0.43 → variance **21.2 %** → **FAIL**
(`pf_variance_pct=21.20>=20.0`).

That rerun **was never ingested** (`ea_metrics` rows from `q07_rerun_20260725` = 0) and
never promoted. The standing Q07 verdict for the live sleeve is still the zero-variance
PASS; `ea_metrics` re-extracted it 2026-08-21 with `profit_factor=None`. QM5_1556 also
carries Q08 `FAIL_SOFT` (×2) and Q10 `PASS` — a full-pipeline survivor resting on a Q07
that measured nothing.

**Why the two runs differ:** QM5_1556's magic is `15560004` → slot offset **4 ≠ 0**, and
the run predates the seed-injector fix (below). Original reports are purged, so this is
inference — but a *strong* one: slot-offset ≠ 0 + pre-fix date + three sibling standard EAs
from the same week whose reports survive and read all-`42` + the rerun's real divergence.

---

## 4 · The two root causes, each proven on surviving evidence

**Defect A — seed-injector collapse (standard EAs, explanation 2).** Git: the pre-`1224d518b`
(2026-07-14) injector wrote distinct set-file labels 42/17/99/7/2026 but for EAs with
`qm_magic_slot_offset ≠ 0` the tester ran the EA's default effective seed 42 for all five.
Direct proof — three surviving cases, each **five distinct run dirs, five distinct
tester.ini seed labels, all five `report.htm` showing `qm_rng_seed=42`**:
- `D:\QM\reports\pipeline\QM5_11267\Q07\aggregate.json` (XAUUSD, 2026-07-07, 438 trades ×5)
- `D:\QM\reports\pipeline\QM5_11891\Q07\aggregate.json` (USDCHF, 318 trades ×5)
- `D:\QM\reports\pipeline\QM5_10788\Q07\aggregate.json` (XAUUSD, 219 trades ×5)

This is **not** evidence reuse / caching / dedup (the runs are physically distinct); it is
**effective-seed collapse** — five real runs all secretly seeded 42. The fix is the seed
injector, not the evidence-binding path.

**Defect B — RNG never reaches the entry path (basket EAs, explanation 1).** Git: before
WP-9 (`QM_BasketOrder.mqh`, 2026-07-25) basket legs opened via `QM_BasketOpenPosition`,
which reached `QM_TradeContextSend` with **no RNG draw** — the `QM_Entry` hook never fires
for a basket EA (the code comment at `QM_BasketOrder.mqh:194-198` states this verbatim).
Direct proof:
- `D:\QM\reports\pipeline\QM5_12712\Q07\aggregate.json` (EURGBP/EURAUD cointegration,
  2026-07-08): five **distinct** effective seeds in the reports (42/17/–/7/2026) yet
  identical 172 trades and identical drawdown → variance 0.00. The seed *loaded* correctly;
  it simply had nothing to act on.

**Control (RNG working, run diverges).** The QM5_1556 seed-42 rerun logger
`…\q07_rerun_20260725\1556_XAUUSD_DWX\QM5_1556\20260725_113043\logger_sample.jsonl`:
54 `TM_OPEN`, 49 `ENTRY_ACCEPTED`, **5 `ENTRY_REJECTED` — 4 of them
`QM_ENTRY_REJECTED_STRESS`** (~9 % ≈ the p=0.10 stress rate). When the RNG is drawn, the
stress reject fires; when seeds differ, the trade stream and PF diverge.

**Reject-line test caveat (honest):** the surviving *zero-variance* runs retain only
`report.htm` + `summary.json` — their journals/loggers were purged — so I could not grep a
zero-variance run for the *absence* of `QM_ENTRY_REJECTED_STRESS` lines directly. The
report's effective-seed cell (all-`42` for defect A; distinct-but-identical-outcome for
defect B) is the decisive substitute, and the control run above supplies the positive
reject-line evidence.

---

## 5 · `seed_auth_failure_rate = OK 0/69` — what it actually proves

`chk_seed_auth_failure_rate` (`tools/strategy_farm/health.py:3146-3184`) counts Q07 runs
**within a 14-day window** (`VACUOUSNESS_WINDOW_DAYS = 14`, line 120) whose stored reason
carries `effective_seed_mismatch` or `seed_evidence_missing` — tokens the *current*
two-axis runner emits when the report's effective seed ≠ the requested seed, or evidence is
missing.

- It proves, for the **69 in-window runs only**, that the effective seed read back from the
  report's Inputs cell **matched the requested seed** — i.e. the tester **loaded /
  authenticated** the requested seed. That is real (it reads the value the RNG was seeded
  from), and it confirms the injector regression (Defect A) is not currently firing.
- **It does NOT prove the seed had any effect on trading.** Defect B is the standing
  counter-example: the basket no-draw runs authenticate *perfectly* on both axes (correct
  distinct effective seed, correct HARSH set-file label) while producing zero variance,
  because authentication proves the seed was *loaded*, not *drawn upon*.
- It is **window-scoped** and says nothing about the 104 historical rows — all outside 14
  days. Worse, those legacy aggregates carry `invalid_reason: null` (they predate the
  authentication tokens), so even the companion `chk_q07_zero_variance`
  (`health.py:2896`) would classify them `deterministic_by_design` = benign
  (`_classify_q07_zero_variance:2859-2890`) rather than `seed_alias`. The health surface is
  **doubly blind** to the 104: by window, and by keying on tokens the legacy evidence never
  had.

**So: `OK 0/69` proves authentication (seed loaded == requested) for the recent cohort
only. It does not prove seed *effect*, and MNT-018's closure on that basis is false comfort
for the historical population** — a third of all-time Q07 passers show zero seed effect,
invisible to this check.

---

## 6 · What it means

- The **104 zero-variance PASSes are paper-stamps** — Q07 certified robustness it never
  tested. Split: ~91 standard-path (Defect A, effective-seed collapse, pre-2026-07-14) and
  13 basket-path (Defect B, no RNG draw, pre-2026-07-25), plus a residual handful needing
  per-case reads. The current runner hard-fails both defects (two-axis `effective_seed` +
  HARSH-label authentication, `q07_multiseed.py:541-576`), so the fix is **re-run the 104
  on the current binary/injector**, not a code change.
- **QM5_1556 / XAUUSD (live, probation 2026-09-06):** its Q07 PASS is a Defect-A
  paper-stamp, and the *only* honest measurement of it on record — the 2026-07-25 rerun —
  is a **FAIL at 21.2 %** that was never ingested. Before the probation review this pair
  should be re-run through the fixed Q07 and re-graded on that evidence; on the evidence
  that exists today it does not have a genuine Q07 pass.
- The 47 EAs whose *only* Q07 passes are zero-variance (per the intake question) have no
  non-zero pass to fall back on and should be prioritized in the re-run.

## 7 · Files read
- `framework/scripts/q07_multiseed.py` (variance `:745`; two-axis auth `:541-576`; injector `_write_seeded_setfile:422`)
- `framework/include/QM/QM_Entry.mqh` (`:63`, `:65-90`, `:327-339`), `QM_SeedRNG.mqh`, `QM_BasketOrder.mqh:194-271`, `QM_Common.mqh:296`, `QM_TradeManagement.mqh:301-323`, `framework/templates/EA_Skeleton.mq5:145-161`
- `docs/ops/SEED_SENSITIVITY.md` (prior art; its "Q07 not affected" claim holds only post-fix), `framework/registry/multiseed_seeds.json`
- `tools/strategy_farm/health.py` (`:120`, `:2859-2951`, `:3146-3184`)
- `D:\QM\strategy_farm\state\farm_state.sqlite` (`work_items`, `ea_metrics`)
- Aggregates: `pipeline\QM5_1556\Q07`, `q07_rerun_20260725\1556_XAUUSD_DWX\…`,
  `pipeline\QM5_11267\Q07`, `\QM5_11891\Q07`, `\QM5_10788\Q07`, `\QM5_12712\Q07`;
  logger `q07_rerun_20260725\1556_XAUUSD_DWX\QM5_1556\20260725_113043\logger_sample.jsonl`
- git: `8e597ca1e` (reject block, 2026-05-23), `1224d518b` (injector fix, 2026-07-14), WP-9 basket fix (2026-07-25)
