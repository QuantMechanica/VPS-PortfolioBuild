# Framework-input pin repair — uncompiled EAs (2026-09-13)

Source-repair of the `EA_FRAMEWORK_INPUT_PINNED` template defect in EAs that have
**not been compiled yet**, so the compile queue can move. Compiled EAs are out of
scope: a rebuilt `.ex5` is a new identity (OWNER 2026-09-13), so only uncompiled
sources may be touched.

Author: Claude (source-repair engineer). Branch: `agents/board-advisor`.
Read-only DB used for compile-status: `D:/QM/strategy_farm/state/farm_state.sqlite`.

## The rule

`build_check.ps1` predicate **`EA_FRAMEWORK_INPUT_PINNED` (OWNER 2026-09-06)**,
`framework/scripts/build_check.ps1` lines ~962-993 (QM-MARK
`FRAMEWORK_INPUT_PIN_PATTERNS` / `FRAMEWORK_INPUT_PIN_SCAN`).

Framework-owned knobs must remain phase inputs. Inside `Strategy_InputsValid` /
`Strategy_NoTradeFilter` an EA may validate the finite inclusive `0.0..1.0` range of
`qm_stress_reject_probability`, but must **not lock** `qm_rng_seed`, the stress value,
`qm_news_*` (mode/temporal/compliance/legacy/stale_max_hours/min_impact) or
`qm_friday_close_*` with `==` / `!=` comparisons (or `!qm_friday_close_enabled`).
Pinning these makes the EA's `InputsValid` reject the very phase set-files the pipeline
feeds it (e.g. `q06_stress_harsh_seed17` carries `qm_rng_seed=17`,
`qm_stress_reject_probability=0.1`) — a false `COMPILE_FAIL`/`ONINIT_FAILED` even when
MetaEditor reports `errors=0`. This is the known INPUTSVALID-PIN defect class.

## Template origin — nothing to patch in the generator

- The canonical template `framework/templates/EA_Skeleton.mq5` is **already correct**:
  it audits clean (0 hits) and carries an explicit contract comment (lines 89-92):
  *"Locked-configuration guards may pin strategy inputs, qm_ea_id, qm_magic_slot_offset
  and risk mode only. Never pin qm_rng_seed, qm_news_*, qm_friday_close_*, or a default
  qm_stress_reject_probability. Stress may be validated only as finite and within the
  inclusive 0.0..1.0 range."* — exactly what this repair implements.
- A grep across `tools/`, `framework/`, `scripts/` (excluding `framework/EAs/`, tests
  and docs) for the emitted pin strings (`qm_rng_seed == 42`, `qm_news_temporal ==`,
  `qm_friday_close_hour_broker ==`, `reject_probability) <= 1`) returns **nothing** —
  there is no deterministic generator/template file that emits the pin.
- The defect exists only in already-generated **"winsweep" batch** EA artifacts, which
  deviated from the skeleton's documented contract. The governed successor-repair tool
  `tools/strategy_farm/session_tools/repair_successor_stale_compile_rows_0913.py` (which
  handles the compiled-EA identity-restart side) already references this evidence doc.
- Prevention is already in place: the skeleton comment + the `EA_FRAMEWORK_INPUT_PINNED`
  build_check gate, which now catches any regeneration. No generator change was required.

## Scope selection (read-only DB)

Flagged sources total: **174**. Touchable criterion: **no `COMPILE_EA/COMPILE_OK` row
AND no row in any post-compile phase** (Q00+). An EA that reached Q02+ was compiled and
has a live identity even where its `COMPILE_EA` row was pruned, so it is out of scope.

- **11 touchable** (patched) — carried 76 pin hits.
- **163 skipped** — carried 903 pin hits; 48 have a `COMPILE_OK` row, 115 reached Q02+
  (compile row pruned but identity live). Listed below.

Note on the task's "known pending" hint list: `QM5_41113`, `QM5_41123`, `QM5_41142`
already have `COMPILE_OK` rows (skipped); `QM5_1538`, `QM5_41374`, `QM5_41389`,
`QM5_41397`, `QM5_41399` are uncompiled but carry **no** pin hit (their `COMPILE_FAIL`
is for another reason) — nothing to patch.

## Patched EAs (11) — before / after

The patch, confined to `Strategy_InputsValid` / `Strategy_NoTradeFilter`, drops the
`qm_rng_seed` / `qm_news_*` / `qm_friday_close_*` equality/inequality pins and converts
the `MathAbs(qm_stress_reject_probability) <= 1.0e-12` lock-to-zero into the sanctioned
range check `(qm_stress_reject_probability >= 0.0 && qm_stress_reject_probability <= 1.0)`.
All `strategy_*` ranges, symbol checks and RISK/PORTFOLIO locks are preserved.

| EA | diff (+/-) | pin hits before→after | symbol-lint viol before→after |
|----|-----------|-----------------------|-------------------------------|
| QM5_20042_brent-dom17 | +0 / -3 | 2 → 0 | 1 → 1 |
| QM5_20053_xcu-weekend-prem | +3 / -4 | 2 → 0 | 1 → 1 |
| QM5_41135_xauxag-mdaily-iqrmean-rv | +3 / -9 | 8 → 0 | 3 → 3 |
| QM5_41138_xauxag-mdaily-hl-rv | +3 / -9 | 8 → 0 | 3 → 3 |
| QM5_41157_xauxag-mtheilsen-rv | +3 / -9 | 8 → 0 | 3 → 3 |
| QM5_41160_xauxag-mlad-rv | +3 / -9 | 8 → 0 | 3 → 3 |
| QM5_41179_xtixng-mcoxstuart-rv | +3 / -9 | 8 → 0 | 0 → 0 |
| QM5_41181_xauxag-mkendall-rv | +3 / -9 | 8 → 0 | 3 → 3 |
| QM5_41187_xauxag-mks-rv | +3 / -9 | 8 → 0 | 3 → 3 |
| QM5_41188_xtixng-mrepmedian-rv | +3 / -9 | 8 → 0 | 3 → 3 |
| QM5_41189_xtixng-mlad-rv | +3 / -9 | 8 → 0 | 0 → 0 |

Totals: 11 files, +30 / -88 lines; 76 → 0 pin hits.

## Verification

- Full-tree pin audit (`audit_framework_input_pins.py`): flagged sources **174 → 163**;
  exactly the 11 patched EAs removed; **0 newly flagged** (the added range check does not
  trip the scan).
- Per-EA `--check-source`: pin hits **0** on all 11.
- `lint_ea_symbol_literals.py`: violation count **unchanged** on every EA — the pin repair
  introduces **no** new symbol literals.
- Delimiter balance (parens/braces) verified **0/0** on every patched file; line endings
  are pure LF (matches the LF-blob pin-SHA canonical form).
- `build_gate_hardening.py`: 9/11 report **0 failures** (3 pre-existing card-undecidable
  warnings each). `QM5_20042`/`QM5_20053` report 1 pre-existing failure each
  (`EA_SYMBOL_NOT_IN_DWX_MATRIX`, see below) — registry/matrix-based, cannot be caused by
  a guard-only source edit.

## Remaining independent blockers (pre-existing, out of scope, NOT caused by this repair)

The pin repair is necessary but not always sufficient to compile these EAs:

- **Fully unblocked now (pin + symbol-lint + hardening all clean):** `QM5_41179`,
  `QM5_41189` — both on the known-pending list; they can compile once re-dispatched.
- **`EA_SYMBOL_LITERAL_REBUILD_REQUIRES_FIX`** (build_check symbol-literal gate,
  `ea_symbol_literal_debt_baseline.txt`; "repaired at the natural rebuild", OWNER
  2026-09-13; rollback `QM_SYMBOL_LITERAL_REBUILD_GATE=0`): still blocks the other 9
  (`20042`, `20053`, `41135`, `41138`, `41157`, `41160`, `41181`, `41187`, `41188`).
- **`EA_SYMBOL_NOT_IN_DWX_MATRIX`**: `QM5_20042` (`XBRUSD.DWX`) and `QM5_20053`
  (`XCUUSD.DWX`) — symbols absent from `framework/registry/dwx_symbol_matrix.csv`
  (candidate-universe/registry gap).

## Compiled / Q02+ EAs still carrying the pattern (163) — cannot be touched

These need OWNER-decided rebuilds at their natural rebuild (governed successor path
`repair_successor_stale_compile_rows_0913.py`), because recompiling mints a new identity.
Split: 48 with a `COMPILE_OK` row, 115 reached Q02+ (compile row pruned). Per-EA phase
detail in the audit JSON (`broad_predicate_sweep` / `exact_seed_neq_cohort`).

QM5_1224_white-okunev-fx-xmom, QM5_20016_xti-xng-mon-rv, QM5_20017_xng-dom15-long,
QM5_20018_xng-wed-short, QM5_20019_xauxag-wkend, QM5_20020_wti-dom17-short,
QM5_20021_wti-h2m-short, QM5_20022_wti-wed-long, QM5_20023_idx-macro-announce-day,
QM5_20025_wti-feboct-daily, QM5_20027_wti-dom26-short, QM5_20028_wti-dom1-long,
QM5_20029_wti-monfri-daily, QM5_20035_xng-dom27-short, QM5_20036_wti-dom8-long,
QM5_20094_xng-fri-short, QM5_20095_auag-mon-diff, QM5_20099_wti-samecal,
QM5_20100_xng-samecal, QM5_20110_xti-xng-fri-rv, QM5_20117_wti-fri-lagrev,
QM5_20124_xng-stor-m30, QM5_20128_xng-stor-fade, QM5_20132_xng-stor-orb,
QM5_20133_wti-wpsr-pb, QM5_20134_wti-wpsr-fail, QM5_20135_wti-winter-trend,
QM5_20136_wti-caltrend, QM5_20137_wti-seas-pb, QM5_20141_wti-sumtrend,
QM5_20145_wti-fri-trend, QM5_20149_wti-montrend, QM5_20153_wti-thu-trend,
QM5_20154_wti-wed-trend, QM5_20155_wti-tue-trend, QM5_20156_xng-wed-trend,
QM5_20158_xng-tue-trend, QM5_20159_xng-mon-trend, QM5_20160_xng-fri-trend,
QM5_20162_xng-winter-dualtrend, QM5_20163_xng-thu-trend, QM5_20169_wti-thu-bear,
QM5_20170_wti-wed-bear, QM5_20171_brent-tsmom3m, QM5_20172_wti-fri-bear,
QM5_20173_wti-mon-bullfade, QM5_20174_wti-tue-bullfade, QM5_20182_wti-sum-bull,
QM5_20185_wti-win-bearfade, QM5_20186_xauxag-samecal, QM5_20187_wti-tsmom1m,
QM5_20189_xauxag-calmom1, QM5_20190_oilbench-cal, QM5_20192_xauxag-ivol,
QM5_20194_xauxag-momrev, QM5_20198_xng-tue-bear, QM5_20204_xng-tsmom1m,
QM5_20205_wti-calmom1, QM5_20206_xauxag-momivol, QM5_20209_wti-winter-mom1,
QM5_20213_wti-summer-mom1, QM5_20214_wti-sum-rev1, QM5_20215_wti-dom-trend,
QM5_20217_wti-wkend-mom, QM5_20218_wti-winter-rev1, QM5_20221_wti-win-signmom,
QM5_20222_wti-seas-sign, QM5_20227_wti-seas-mom1, QM5_20229_wti-seas-rev1,
QM5_20230_wti-seas-gap, QM5_20231_wti-seas-mom12, QM5_20239_wti-pulltrend,
QM5_20244_wti-trend-sign, QM5_20245_wti-vr-rsm, QM5_20247_wti-vr-calreg,
QM5_20251_wti-cal-rsm, QM5_20253_wti-vr3-mom, QM5_20260_xauxag-mom-vote,
QM5_20292_fx-carry-unwind_card, QM5_21503_xti-weekly-tsmom-lowvol,
QM5_21517_xauxag-seas-rv, QM5_32008_euro-triplet-statistical-arbitrage-eurostable,
QM5_41013_wti-mopen-mom, QM5_41014_xtixng-thu-rv, QM5_41015_xtixng-tue-rv,
QM5_41017_wti-dom-ctrreg, QM5_41018_xtixng-wed-rv, QM5_41019_wti-wopen-mom,
QM5_41020_wti-wclose-mom, QM5_41022_wti-wdual-mom, QM5_41029_wti-flow-agree,
QM5_41030_xauxag-flowdiv, QM5_41031_xauxag-goldlead, QM5_41039_xauxag-mflow-div,
QM5_41040_xauxag-wflow-fade, QM5_41042_wti-wed-flow-agree, QM5_41043_xng-thu-flow-agree,
QM5_41044_xng-thu-flow-fade, QM5_41045_wti-wed-trend-agree, QM5_41046_wti-wed-trend-pb,
QM5_41047_xng-thu-trend-pb, QM5_41048_xng-thu-trend-agree, QM5_41057_xauxag-wflow-agree-fade,
QM5_41058_xng-wflow-agree, QM5_41060_xauxag-week-nr7-brk, QM5_41062_xauxag-wgap-fade,
QM5_41066_xauxag-wdecay-rv, QM5_41075_xauxag-wovershoot-rv, QM5_41076_xauxag-waccel-rv,
QM5_41077_xauxag-wretr-rv, QM5_41078_xauxag-wstreak3-rv, QM5_41079_xauxag-wclose-extreme-rv,
QM5_41083_xauxag-wlegdiv-rv, QM5_41085_xauxag-wdaybreadth-rv, QM5_41086_xauxag-commonshock-rv,
QM5_41088_xauxag-wclv-div-rv, QM5_41103_xauxag-mrange-migrate-rv, QM5_41104_xauxag-mmedian-shift-rv,
QM5_41109_xauxag-mmean-median-rv, QM5_41110_xauxag-moutside-res-rv, QM5_41112_xauxag-mdaybreadth-rv,
QM5_41113_xauxag-mhalfagree-rv, QM5_41116_xauxag-mthirdvote-rv, QM5_41118_xauxag-mlatehalf-dom-rv,
QM5_41119_xauxag-mclose-quartile-rv, QM5_41120_xauxag-mopen-residence-rv, QM5_41121_xauxag-mseqdom-rv,
QM5_41123_xauxag-mpath-eff-rv, QM5_41125_xauxag-mrms-coherence-rv, QM5_41128_xauxag-mdaily-persist-rv,
QM5_41164_xauxag-mrepmedian-rv, QM5_41166_xauxag-mrobust3-agree-rv, QM5_41174_xauxag-mspearman-rv,
QM5_41175_xtixng-mpettitt-rv, QM5_41177_xauxag-mwilcoxon-shift-rv, QM5_41185_xauxag-fracd-rv,
QM5_41192_xtixng-mdaily-hl-rv, QM5_41193_xtixng-fracd-rv, QM5_41207_xauxag-corrbreak-rv,
QM5_41242_wti-eia-negdrift-m1, QM5_41243_wti-eia-lag2-fade-m5, QM5_41244_xng-tail-mtsm-s2,
QM5_41246_xauxag-mturnpoint-rv, QM5_41247_xauxag-mcusum-rv, QM5_41248_xauxag-mpettitt-rv,
QM5_41260_xauxag-mad2-rv, QM5_41263_xauxag-mkuiper-rv, QM5_41265_xauxag-mbf-scale-rv,
QM5_41269_xauxag-mklotz-scale-rv, QM5_41278_xauxag-mcucconi-rv, QM5_41279_xauxag-msavage-rv,
QM5_41281_xauxag-mconover-scale-rv, QM5_41282_xauxag-mvdw-rv, QM5_41285_xauxag-mjt-rv,
QM5_41286_xauxag-msiegel-tukey-rv, QM5_41318_xauxag-msndisp-rv, QM5_41341_xauxag-mbisquare-rv,
QM5_41348_xauxag-mhampel-rv, QM5_41355_xauxag-mtrim2-rv, QM5_41357_xtixng-mwinsor2-rv,
QM5_41363_xtixng-flowdiv, QM5_41364_xtixng-wclv-div-rv, QM5_41365_xtixng-decouple-rv
