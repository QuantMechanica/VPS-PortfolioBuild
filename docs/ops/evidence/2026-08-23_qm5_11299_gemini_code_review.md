# QM5_11299 Gemini build — mandatory review

Date: 2026-08-23 UTC

Router task: `04867bea-8c6b-4a17-84e3-457a513f9d6d` (`task_type=review_ea`, priority 51)

Source task: `ea624d92-20db-425b-9deb-840b11c83d40` (`gemini`/`agy`, build delivery only;
`docs/ops/evidence/ea624d92_QM5_11299_lwma144-smma5-fractal-m5-scalp_build_identity.json`)

Same defect class as the sibling reviewed alongside it in this batch
(`docs/ops/evidence/2026-08-23_review_ea_11300_9972_9979.md`, `QM5_11300` section) —
reviewed independently against that precedent's checklist for consistency.

Verdict: **REQUEST_CHANGES — no SPEC.md and an unwired strategy input; do not promote to
PIPELINE**

**Correction (post-review, same day):** findings #2 and #3 below are **wrong** — an
approved card exists, just not inside this git checkout (it lives at
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_11299_lwma144-smma5-fractal-m5-scalp.md`,
a runtime-only location I failed to check), and that card explicitly states
"News filter: off in P2" — the disabled news filter is a **documented, card-specified
choice**, not an undocumented gap. A concurrent review
(`docs/ops/evidence/2026-08-23_review_ea_11300_9972_9979.md`, `QM5_11299` section,
commit `bb0857246`) caught both errors and additionally found a real defect I missed:
`input double strategy_tp_atr_mult = 2.0` (line 42) is never read — the take-profit is
computed with a hardcoded `2.0` literal instead (lines 194/203), so the input is dead
(behavior-identical today since the literal matches the default, but a setfile/P3 override
of this input would silently do nothing). See that doc for the corrected, authoritative
version of this review. The original (partially incorrect) findings below are left
unedited for the record, per the instruction not to overwrite prior evidence.

## Findings

### 1. Blocking — SPEC.md is missing entirely

`framework/scripts/validate_spec_doc.py framework/EAs/QM5_11299_lwma144-smma5-fractal-m5-scalp`
→ **FAIL**: `SPEC.md missing`. The EA directory contains only the `.mq5`, `.ex5`, and
`sets/` — no design document.

### 2. Blocking — no approved Strategy Card, no source citation

The setfile carries `; card_defaults_status=none_found`
(`sets/..._EURUSD.DWX_M5_backtest.set:24`); there is no `cards_approved` or
`strategy-seeds` entry for `QM5_11299` anywhere on disk. `ea_id_registry.csv` shows this
`ea_id` was reserved `2026-05-23` by `Research` (source `e78a9f1f-4e6a-563c-a080-915133d6ed28`)
but never had a card written before being built three months later — the LWMA(144)/SMMA(5)
cross + fractal-SL scalp logic has no traceable source, no R1–R4 mechanisation record, and
no documented expected-trades/regime/hold-time rationale to check "card fidelity" against.
This is the identical provenance gap flagged blocking for `QM5_11300` in the same review
batch.

### 3. Blocking — news filter fully disabled, no documented exemption

Compiled-in defaults: `qm_news_temporal = QM_NEWS_TEMPORAL_OFF`,
`qm_news_compliance = QM_NEWS_COMPLIANCE_NONE`, `qm_news_mode_legacy = QM_NEWS_OFF`
(source lines 22-26). The two generated backtest setfiles (`EURUSD.DWX`, `GBPUSD.DWX`) do
not override any of these — confirmed by reading both setfiles in full (17 lines,
framework risk/magic keys only, no news keys). The Edge Lab charter requires a mandatory
news blackout; the only precedent for disabling it in this cycle (`QM5_41129`, a fresh
event-driven identity) carries an explicit OWNER-ratified event-anchored exemption with a
compensating control documented in its SPEC. This EA has neither a SPEC (finding #1) nor
any structural reason apparent from the code for why an M5 LWMA/SMMA cross scalp would be
event-flat by design — it looks like an omitted default, not a deliberate exemption.

## Checks that passed

- `validate_build_guardrails.py` → **PASS**, 3 files checked, zero findings,
  `max_news_stale_hours=336` (at the ceiling, not above).
- `build_gate_hardening.py` → zero failures.
- Registry: `ea_id_registry.csv` one active row; `magic_numbers.csv` 2 active slots
  (`EURUSD.DWX` slot 0 / `112990000`, `GBPUSD.DWX` slot 1 / `112990001`) matching the 2
  shipped setfiles 1:1, `qm_magic_slot_offset` correct per slot.
- Both setfiles: `RISK_FIXED=1000`, `RISK_PERCENT=0` — Q02-Q10 risk-mode rule satisfied.
- MQ5 SHA-256 matches the build identity artifact:
  `bc7ae0c2110fb16408bb1de58a46ca812c155d62bc47b386067b0f4ea7f94ca3`.
- EX5 SHA-256 matches the build identity artifact:
  `2489a3372177a1627619e6bcf7535fb26d1412fbb32346ba4f9101e2e378932b`.
- Compile log (`framework/build/compile/20260822_142430/...compile.log`): `0 errors,
  0 warnings`.
- One-position-per-magic enforced (`Strategy_HasOpenPosition()` guard); no pyramiding, no
  martingale, no ML entry point; `QM_FrameworkTrackOpenPositionMae()` is the first
  statement in `OnTick()` (MAE-hook contract satisfied); SL/TP are computed and normalized
  (`QM_StopRulesNormalizePrice`) with a sanity check before being handed to the framework
  (lines 206-211) — `req` fields are explicitly set field-by-field at the top of
  `Strategy_EntrySignal` rather than via `ZeroMemory`, which differs from the newer
  hardening convention seen elsewhere in this batch but is not flagged by
  `build_gate_hardening.py` and every field is in fact written before use — not a defect,
  just an older pattern.

## Non-blocking observations

- `Strategy_NoTradeFilter()` unconditionally returns `false` — no execution-timeframe
  contract guarding against a wrong chart attachment. Every indicator/price read
  (`QM_SMMA`, `QM_LWMA`, `QM_ATR`, `QM_FractalLower/Upper`, `CopyRates`) explicitly passes
  `strategy_timeframe` (M5) rather than `_Period`, so a wrong attachment would not corrupt
  the signal math — only `QM_IsNewBar()`'s default (chart-period) gating cadence. Same
  pattern judged non-blocking for `QM5_11300` in this batch; applying the same standard
  here.
- `Strategy_ExitSignal()` unconditionally returns `false` — this EA relies entirely on the
  broker-side SL/TP bracket set at entry (no discretionary exit, no time stop, no
  trailing). Plausible for a fixed-bracket M5 scalp design, but with no SPEC/card to check
  against, there is no way to confirm this is deliberate rather than an omission.
- M5 base timeframe with a fixed 2R target and ATR/fractal stop is a scalping design, not
  HFT (bar-close-gated, not tick-level) — no charter conflict on that axis alone; the open
  question is entirely the missing card/SPEC and the disabled news filter above.

## Disposition

No source, binary, registry, setfile, work item, task verdict, or trade stream was changed
by this review. `T_Live` and AutoTrading were not touched. Per hard rule ("Codex review is
mandatory before acceptance; leave Gemini code tasks in REVIEW and do not self-approve or
move them to PIPELINE"), this review task is closed with `REQUEST_CHANGES`, not `APPROVED`.
**Recommendation for Codex/OWNER:** needs (a) a SPEC.md, (b) either a real approved card or
an explicit documented rationale for building without one, (c) either the standard
`PRE30_POST30`/`DXZ` news gate turned on, or an OWNER-ratified exemption written down —
same three-part gap as `QM5_11300`, suggesting a shared build-batch process issue rather
than two independent one-off omissions.
