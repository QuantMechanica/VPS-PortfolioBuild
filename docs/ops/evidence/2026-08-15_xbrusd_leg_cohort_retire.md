# 2026-08-15 — XBRUSD leg-cohort: 14 venue-blocked work items retired

Found in monitoring round 1 of the OWNER-mandated 15-min factory watch.

## Trigger

QM5_21518 (wti-brent-cfm) burned six deterministic `ONINIT_FAILED` Q02
attempts on XTIUSD.DWX. Tester journal
(`D:\QM\reports\work_items\3c0d115a-…\QM5_21518\20260815_111452\raw\run_01\`):
`symbol XBRUSD.DWX does not exist` → `OnInit returns non-zero code 1`.
Source: `const string g_state_symbol = "XBRUSD.DWX";` — hardcoded, not
input-overridable. XBRUSD was retired from the DWX custom universe with the
2026-08-12 Brent re-symboling (see
`memory project_qm_magic_registry_resymbol_collision_2026-08-15`); the
canonical `framework/registry/dwx_symbol_matrix.csv` contains no Brent
symbol at all.

## Cohort sweep

`grep XBRUSD framework/EAs/**/*.mq5` → 24 EAs with LIVE code references
(one comment-only). Categories:

- **Hard leg dependency** (`g_leg_xbr` / symbol array / `_Symbol` guard):
  the 12841…20190 Brent-spread family, QM5_1189 (symbol array),
  QM5_20042 (guard `_Symbol=="XBRUSD.DWX"` — can never pass after
  re-symboling), QM5_21518 (state symbol).
- **Soft fallback input** (`strategy_oil_fallback_symbol`, qp-stress family
  1185/1192/1193/1194): runnable while the primary oil symbol exists —
  left untouched (QM5_1193 USDCAD pending row kept).

## Disposition (executed)

14 pending rows whose EA hard-requires the dead leg were set
`status=done, verdict=RETIRE` with
`verdict_reason=required_leg_xbrusd_unavailable` (row IDs in the payloads,
executed by `retire_xbr_cohort.py`, session scratchpad; precedent: the
three XBRUSD host rows RETIREd on 08-12):
QM5_1189/XTIUSD, QM5_21518/XTIUSD, and the 12 XBR_* basket rows of
QM5_12857, 12867, 12999, 13005, 13053, 13079, 13082, 13083, 13086, 13087,
13092, 13093.

Effect: prevents ~14 × 3-5 deterministic ONINIT burn cycles and removes
their contribution to the q02_stranded_exhausted_pairs backlog.

## Extraction options (OWNER decision, not executed)

- The Brent-vs-FX spread EAs (13079…13093) could be re-mechanized as
  WTI-vs-FX spreads — a strategy-identity change (new cards, new Q-runs),
  only worthwhile if the WTI-hosted siblings from the 08-12 re-symboling
  show edge.
- Importing a Brent history source into the DWX custom universe would
  unblock the whole cohort as designed — data-acquisition decision.
