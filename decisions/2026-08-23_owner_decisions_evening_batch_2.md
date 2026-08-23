# OWNER decisions — 2026-08-23 evening batch 2 (vault `12 ToDo/AI ToDos/OWNER.md` inline answers)

Date: 2026-08-23 (evening). Authority: OWNER, inline answers in the vault OWNER board. Recorded
by Claude (Orchestrator). Each item lists the executing ticket.

| ID | OWNER answer (verbatim) | Decision | Execution |
|---|---|---|---|
| `OWNER-DEC-13036-XAU` | „generell um andere Indizes, Gold und Majors Forex erweitern!" | **Candidate-pool definition (ROT) decided:** card target universes are to be extended generally to the other tradable indices, XAUUSD and the FX majors — not only for QM5_13036. Economics unchanged (Q02 stays the hard filter). | Codex `rb-universe-expansion`: policy + dry-run census of the added (EA,Symbol) pairs, then governed Q02 enqueue **behind** the rebaseline backfill (lower priority), symbol cap respected, append-only. Tradability always from `dwx_symbol_matrix.csv`. |
| `OWNER-DEC-ARCHIVE-PUBLIC` | „ich tendiere zu b, wir wollen ja unsere Kompetenz zeigen und zeigen auch was die Gates tun auf der Website (das muss aktualisiert werden außerdem!)" | **Variant (b)**: public archive shows PASS/FAIL per gate without numbers; website gate description must be updated to the v4 linear pipeline (Q00–Q17, three phases). | Codex `rb-archive-public-website`: public snapshot/website contract level (b) + gates page update; redaction guard (no paths/mails/thresholds) stays fail-closed. |
| `OWNER-TODO-GATE-MANIFEST-V3-DIFF` / `OWNER-DEC-STRANDED-182` / `OWNER-DEC-Q02-BYPASS-88ba4560` | „alle drei genehmigt" | v3 diff acknowledged (superseded by v4 activation, same criteria); 182 DETERMINISTIC_NO_SUMMARY Q02 pairs INFRA_FAIL→INVALID reclassification approved; Q02-bypass hold QM5_20172/XTIUSD to be closed against the stale-build finding, snapshot guard stays fail-closed. | Codex `rb-stranded182-q02bypass`: `classify_summary_missing.py --apply` with receipt; hold closure via the governed path; public snapshot re-enabled only when the guard passes. |
| `OWNER-DEC-POINTER-PRESETS` | „folge deiner Empfehlung genehmigt" | **Option (a) approved:** regenerate the 10 unprovenanced T_Live presets value-conserving via `gen_setfile.ps1` (`build_check -EALabel` scope only), prove every functional key byte-equal, redeploy, then sign the pointer. Live-book binding = ROT, now OWNER-approved in writing. | Codex `rb-pointer-presets-repair` prepares regeneration + byte-equality proof + deploy manifest; **deploy to T_Live and signature are executed by Claude after SHA verification** (T_Live workflow, CLAUDE.md); AutoTrading untouched. |

Mirror: vault OWNER board entries ticked with pointer to this file; Mission Control status to
be set by the heartbeat mirror.
