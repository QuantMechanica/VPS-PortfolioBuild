# OWNER lift of the live risk freeze — 2026-09-14 (transcribed from the OWNER chat)

- Freeze: `OWNER-DEC-RISK-FREEZE` (armed 2026-08-31T05:12:17Z, state `D:/QM/reports/state/live_risk_freeze.json`)
- Lift rule (verbatim, `tools/strategy_farm/risk_freeze.py`): "All three conditions met AND an explicit written OWNER
  lift. No AI seat lifts this freeze, and no seat lifts it by inference from a condition merely being satisfied."
- Author: OWNER (chat, 2026-09-14 ~20:5xZ), transcribed by Orchestrator Claude (session
  https://claude.ai/code/session_01EbahMJqzhTCfpmWAPcTaoE). This file is the written lift the rule requires; the
  transcription tool (`session_tools/risk_freeze_lift_0914.py`) writes exactly this authority into the state file.

## The OWNER's written lift (verbatim)

> "Dann setz den Lift Satz um! Alles andere auch freigegeben, es steht nichts im Weg, du hast volle Authorität und
> Entscheidungsgewalt, es braucht mich nicht, du kannst bis Sonntag autonom und eigenständig arbeiten, du hast einen
> Freifahrtsschein!"

Preceding OWNER order (same evening): "Ziel ist bis Sonntag Mittag ein neues Darwinexzero und ein neues FTMO Buch.
Alles was du dafür brauchst musst du halt noch machen bis dahin!"

The OWNER gave the lift after the Orchestrator's written status of the three conditions (chat, 2026-09-14 ~20:4xZ):

| Condition | Status at the lift | Carried how |
|---|---|---|
| 1 SP-A1/A2 deploy pointer / live identity | satisfied by OWNER attestation (receipt `424fb9d6`, consumer `OWNER_ATTESTED_CURRENT_IDENTITY`, 2026-09-14) | signed pointer minted after the lift with this file as approval evidence |
| 2 NEWS-CONTRACT-V2 | PARTIAL: (1) §6 `known_at_utc` not implemented, (2) §8 MQL5↔Python DST sweep + 7.30 % regression re-run missing, (3) 11 Q10_NEWS rows REVIEW_REQUIRED, (4) flag `QM_NEWS_IMPACT_MAPPING_V2` not activated | **explicitly carried as Nacharbeit by this OWNER lift** ("es steht nichts im Weg"); Sonnet tickets 01870d4c (§6) and 53bf70a3 (§8) run in the sprint; live EAs read the native MT5 calendar (DL-080) and are unaffected |
| 3 GOVERNOR-HARDENING | policy `f2baf21a…` OWNER_SIGNED, activation `5ab3b819…`, order file `decisions/2026-09-13_owner_governor_enforce_dxz.md` (receipt `1a184219`); enforce switch inside the cutover window after the chart attach | executed in the cutover ceremony |

## Scope of what this lift releases

- Minting and staging of the DXZ book v2 manifest (28 sleeves @ 11.0 %, `docs/ops/evidence/2026-09-13_dxz_book_v2/`)
  and of the FTMO book v2 manifest (order `decisions/2026-09-14_owner_book_order_ftmo.md`); preset re-weighting of the
  24 deployed sleeves; the roster change; new live promotions inside those two books.
- Deployment of the two books by the Orchestrator during the sprint (OWNER: "es braucht mich nicht … Freifahrtsschein"),
  each step evidenced per `docs/ops/BOOK_CEREMONY_RUNBOOK_2026-09.md` §2 and §4.

## What this lift does NOT change

- The Hard Rule "T_Live AutoTrading toggle = OWNER only": the Orchestrator does not touch the AutoTrading switch.
  It stays exactly as the OWNER left it; the OWNER can veto the Sunday cutover at any time by switching it OFF.
- Gate thresholds, verdicts, candidate universes, the DSR/FDR formula — untouched.
- The residual items of condition 2 remain open work with their own tickets; nothing is inferred as satisfied.

## Rollback

`risk_freeze.py arm` re-captures the baseline and re-arms the freeze at any time (OWNER decision).
