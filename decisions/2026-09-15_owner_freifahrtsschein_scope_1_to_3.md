# OWNER confirmation 2026-09-15: the Freifahrtsschein covers the three cutover items the critic flagged

- Author: OWNER (chat, 2026-09-15 ~07:4xZ), transcribed by Orchestrator Claude
  (session https://claude.ai/code/session_01EbahMJqzhTCfpmWAPcTaoE).
- Context: the sprint daily check of 2026-09-15 was produced by the new Creator → Critic → Formatter
  chain (`docs/ops/evidence/2026-09-15_agent_chain/sprint_daily_check_2026-09-15_final.md`). The Opus
  critic flagged three cutover items as OWNER acts not yet covered by a written OWNER decision, and one
  Market Watch pre-step. The orchestrator put them to the OWNER as one line each.

## The OWNER's words (verbatim)

> "Freifahrtsschein deckt 1 bis 3, Market Watch mache ich Sonntag
> AGY CLI habe ich eingeloggt, sollte also funktionieren!"

Preceding orchestrator message (2026-09-15 ~07:3xZ), item 3 of "Deine Akte": "Vom Kritiker aufgedeckt:
das Deploy-Manifest v2 ist unsigniert, die 11,0 %-Buchrisiko-Stufe hat keine Decision-Datei mit deinen
Worten, der Monitor-Chart-Attach auf T_Live ist per Order vom 13.09. dein Akt, und XAGUSD/WS30 fehlen
im T_Live Market Watch. Sag „Freifahrtsschein deckt 1 bis 3, Market Watch mache ich Sonntag" oder
korrigiere einzeln."

## What "1 bis 3" binds

| # | Item (critic finding) | OWNER decision now | Effect |
|---|---|---|---|
| 1 | Deploy manifest v2 (rev 3, 28 sleeves @ 11.0 % / cap 1.5 %, `docs/ops/evidence/2026-09-13_dxz_book_v2/deploy_manifest_v2_DRAFT.yaml`) carried `owner_signature: PENDING` (Q16 check 3, finding B2) | **approved in writing by this confirmation** under the 2026-09-14 Freifahrtsschein (`decisions/2026-09-14_owner_risk_freeze_lift.md`) | `owner_signature` in the manifest references this file + its sha256. A material change of the roster or the risk step after this date needs a fresh reference; `claude_verification_signature` stays PENDING until the orchestrator's ceremony verification (CLAUDE.md T_Live workflow step 3). |
| 2 | 11.0 % book-risk step (`OWNER-DEC-BOOK-RISK-11-20260913`) existed only as an orchestrator interpretation of the OWNER's 2026-09-13 words ("Die Konzentrationscaps kannst Du fuenfzehn Prozent erhoehen beziehungsweise wie fuer Darwinex Zero am besten geeignet") inside `tools/strategy_farm/config/concentration_tail_limits.v1.json` (finding B10) | **confirmed as the OWNER's decision**: total book risk 9.7499 % → 11.0 % with the not-worse gate against the deployed 24 (breaks at 12.0), concentration cap 1.5 % | this file is the missing `decisions/` record for OWNER-DEC-BOOK-RISK-11-20260913 |
| 3 | Monitor-v2 chart attach on T_Live inside the D6 ceremony: the 2026-09-13 governor order (`decisions/2026-09-13_owner_governor_enforce_dxz.md` §"OWNER-only") reserved the attach to the OWNER, while the 2026-09-14 Freifahrtsschein says "es braucht mich nicht" (finding B3) | **the Freifahrtsschein covers the attach**: the orchestrator loads profile V3 (28 charts + monitor) during the Sunday ceremony and then switches the governor to enforce | freeze condition 3 ("hardened AND actually enforcing") closes inside the ceremony, as planned in D6. AutoTrading stays untouched (Hard Rule). |
| — | XAGUSD / WS30 not in the T_Live Market Watch (Q16 check 9, finding B9) | **OWNER adds both symbols on Sunday before the ceremony** ("Market Watch mache ich Sonntag") | ceremony sequence fixed: OWNER Market Watch → orchestrator profile V3 → verification → governor enforce. If the symbols are missing at 09:00 local, the two affected charts (25/XAGUSD, 9641/WS30) are skipped and the rest of the book cuts over. |
| — | Antigravity credential expired (HTTP 401 since 05:40Z) | OWNER re-logged in; verified 07:4xZ: quota pull OK (98.4 % remaining, token valid to 10:40 local), `AGY_LOW_QUOTA.flag` released by the governor | agy is back as a seat for all lanes and as the cross-vendor critic for Claude-lane deliveries |

## What this does NOT change

- The T_Live AutoTrading toggle: OWNER-only, untouched by the orchestrator.
- Gate thresholds, verdicts, candidate universes, the FTMO qualification bar: untouched. The FTMO demo
  book v2 content decision is a separate orchestrator record (sprint file §2).
