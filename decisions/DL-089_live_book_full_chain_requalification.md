# DL-089 — The Live Book Is Re-Constituted Through the Complete Current Chain

**Date:** 2026-08-21
**Status:** ADOPTED (OWNER-authorized)
**Authority:** OWNER, 2026-08-21: *"Die Live EAs sind auch noch nicht durch die Optimierung
durch (die gabs damals nicht), wir können diese EAs also generell nochmal einreihen und durch
das neue EA Framework (mit den Andrea Unger Pattern Filter) und die Gates jagen, durch die
Optimierung und dann erst für das Buch qualifizieren. Kann sein, dass wir dadurch einzelne
Sleeves wieder verlieren, aber das spricht dann ja für unsere Qualitätsverbesserung! Am Ende
brauchen wir für die EAs die fürs Buch in Frage kommen schon die ganze Kette, damit wir alle
Informationen für das Buch tatsächlich zur Verfügung haben!"*
**Scope:** the 21 EAs / 24 sleeves of the current DXZ live book. It does **not** change what
trades today — see §3.

## 1 · The measured reason this is right

| Finding (measured 2026-08-21) | Number |
|---|---|
| Live EAs that have **never** been through Q14 optimization | **21 of 21** |
| Live EAs whose factory binary differs from the deployed live binary | **21 of 21** |
| Live sleeves standing on a Q07 that never varied its seed (proven injector collapse) | **8** |
| Live sleeves with no passing Q10 closing verdict | **1** (QM5_10440/NDX, Q10 FAIL) |
| Age of the factory binaries vs the framework they would be rebuilt against | 3–20 days stale |

The book was admitted before the optimization branch existed (DL-084) and before several
framework repairs landed. Its sleeves therefore carry evidence produced by a pipeline that no
longer exists in that form. That is not a scandal — it is what happens when a factory improves
faster than its inventory — but it does mean **book construction today runs on incomplete
information**, which is exactly the gap the OWNER named.

## 2 · What this authorizes

Every EA that is to be **eligible for the book** must carry the complete current chain:

```
rebuild on the current framework
  → Q02 … Q10   (the full evidence funnel, current gates, current thresholds)
  → Q14 → Q15 → Q16   (optimization admission, challenger, sealed head-to-head; DL-088 levers,
                       including the pattern-filter combos)
  → Q11   (dual-book construction: Q11_DXZ and Q11_FTMO)
  → OWNER book ceremony
```

An EA without the complete chain is **not book-eligible**, regardless of how long it has
already traded. Incumbency is not evidence.

## 3 · What this explicitly does NOT do — the point that must not be misread

**Requalification is a parallel track. Nothing about the live book changes as a side effect.**

The 21 live binaries keep trading, untouched, on their deployed artifacts. The requalification
runs in the **factory**, on **rebuilt** binaries. `C:\QM\mt5\T_Live` is not written to, no
preset changes, and the AutoTrading toggle remains OWNER-only — that hard rule is untouched
by this decision. Rebuilding a factory copy of an EA that also runs live is not "recompiling
in the active inventory": the protected artifact is the deployed one.

This matters for reading the OWNER's *"we may lose individual sleeves"* correctly. **A
requalification failure measures a rebuilt binary, not the one that is trading.** So:

- A sleeve that fails requalification is marked **not re-qualified** and is **excluded from
  the next book**. That is where a sleeve is lost — at book construction, not mid-flight.
- It does **not** trigger an immediate live change on its own. Pulling a live sleeve because a
  *different* binary failed a test would be acting on evidence about the wrong artifact.
- **Exception:** a failure that shows the strategy itself is broken rather than merely weaker
  — a mechanism defect, a lookahead, a rule that cannot be mechanized — is escalated to the
  OWNER immediately, because that finding does transfer across binaries.

This rule is written down **before any requalification result exists**, for the same reason the
probation matrix was: criteria decided after seeing the outcome are not criteria.

## 4 · Sequencing, and why it is in waves

**Wave 1 — rebuild + Q02…Q10 (can start now).** All 21 factory binaries are stale against the
current framework, so a rebuild precedes everything. This is the long pole: full-history runs
dominate. Backtests are never quota-throttled; the *rebuild* is agent work and is paced by the
Codex weekly limit (projected 130 % as of 2026-08-21), so the wave is dispatched in batches
rather than as one flood.

**Wave 2 — Q14 → Q16 (blocked).** The pattern-filter lever the OWNER names requires the T9
wiring, which requires Bug #4 (short-history lock, task `a764edd0`, in progress). Until then the
optimization leg can only use the existing levers. Wave 2 starts when T9 lands.

**Wave 3 — Q11 dual-book + ceremony.** First time both books are built from a cohort that
carries the complete chain.

The requalification cohort is priority-tracked so it does not starve behind a ~2,200-row queue.

## 5 · Consequences

- The current book keeps running and is re-constituted only at a ceremony, on evidence.
- Sleeves may be lost. That is the intended outcome of raising the bar, not a failure of it.
- Book construction gains, for the first time, a cohort where every candidate has the same
  complete evidence chain — which is what makes weights, correlations and admission decisions
  comparable at all.
- The four Q07 paper-stamp re-runs enqueued on 2026-08-21 remain useful as an early read on
  seed robustness, and are superseded by Wave 1 when it reaches those EAs.
- QM5_10440/NDX (live on a failed Q10) is not resolved by this decision — it remains an open
  OWNER item and should be parked rather than left carrying weight while it requalifies.

## 6 · Rollback

The programme is additive: it creates new evidence rows and rebuilt factory binaries. It
overwrites no verdict, touches no deployed artifact, and can be stopped at any wave boundary
without leaving the live book in a different state than it is in today.

## Evidence

- `docs/ops/evidence/2026-08-21_probation_package_mnt036.md` (binary deltas, gate vintage)
- `docs/ops/evidence/2026-08-21_q07_zero_variance_investigation.md` (paper-stamp cohort)
- DL-084 (optimization branch), DL-088 (Q14 levers + Q16 overfit contract)
- `portfolio_manifest_live_24sleeve_20260724.json` (the 21 EAs / 24 sleeves in scope)
