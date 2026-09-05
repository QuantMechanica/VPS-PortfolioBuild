# OWNER-Vorlage — C-6 Breach-/Zwei-Phasen-Schätzer (Entwurf, nicht aktiv)

Status: **REVIEW / ROT / keine Auffangregel**  
Scope: Methodenentscheidung. Keine Engine-, Contract-, Gate-, Kauf-, T_Live-
oder Deployment-Änderung.

## 1 · Entscheidung auf einer Seite (Deutsch)

**Lage.** Der gelieferte FTMO-Vertrag lässt `breach upper-95`,
`P2 conditional` und `joint two-phase` absichtlich
`INERT_UNTIL_C6_ENGINE_OWNER_APPROVED`. Das ist richtig: die bisherigen
Daily-/Closed-P&L-Streams sehen den zwischenzeitlichen Equity-Tiefpunkt inklusive
offener P&L nicht. Der neue Trial-Kollektor (Task `79772247`, Build
`27e85a0690`) liefert die benötigten Rohfelder — Balance, Account-Equity,
Positionen, Pending Orders, Prag-Tag und Intervallminimum — aber noch keine
ratifizierte Wahrscheinlichkeitsschätzung und noch keine lange Evidenzstrecke.

**Empfehlung C6-A.** Eine gemeinsame, buchweite M5/Prag-Tag-Pfadspur wird in
60-Tage-Blöcken resampled. Jede Bootstrap-Replikation baut eine neue Spur und
wertet ausschließlich vollständige 60+30-Tage-Gauntlets mit den bestehenden
strikten FTMO-Operatoren aus. Aus den Replikationen kommen vier Größen:

- P1: unteres 95%-Ende;
- irgendein offizieller Daily-/Max-Loss-Breach vor Abschluss: oberes 95%-Ende;
- P2 gegeben P1: unteres 95%-Ende;
- P1∩P2: unteres 95%-Ende.

Ein reines Perzentil-Bootstrap wäre bei null beobachteten Breaches gefährlich:
es kann `upper=0` ausgeben. Deshalb bindet die Empfehlung zusätzlich einen
fest-originären, nicht überlappenden 90-Tage-Zensus mit exakter
Clopper-Pearson-Grenze. Gutschrift ist immer die schlechtere Grenze:
`breach_upper=max(MBB, CP)`, bei den drei unteren Grenzen `min(MBB, CP)`.
Das verhindert ein Nullereignis-Fail-open.

**Explizite Zwei-Phasen-Gutschrift.** Pro Replikation seien `N` vollständige
Gauntlets, `S1` P1-Pässe und `S12` gemeinsame Pässe. Dann:

```text
p1 = S1/N
p2_given_p1 = S12/S1, falls S1>0; sonst 0 (fail-closed)
joint = S12/N = p1 * p2_given_p1
```

Die Joint-Grenze wird direkt aus `S12/N` gezogen, nicht aus unabhängig
gerundeten Marginalgrenzen. Eine Replikation ohne P1-Pass wird nicht verworfen.

**Unbequeme Mindestmenge.** Mit dem bestehenden zweiseitigen 95%-Vertrag ist
die relevante einseitige Tail-Masse `0,025`. Selbst bei perfekten Ergebnissen
braucht die exakte Guardrail mindestens:

| Kriterium | kleinste überhaupt passfähige unabhängige Zählung |
|---|---:|
| 0 Breaches, upper-95 ≤ 10% | 36 nicht überlappende 90-Tage-Gauntlets |
| P2 conditional, alle Erfolge, lower-95 ≥ 85% | 23 P1-Pässe |
| Joint, alle Erfolge, lower-95 ≥ 65% | 9 nicht überlappende 90-Tage-Gauntlets |

Damit verlangt allein das Breach-Gate bei festem Ursprung mindestens 3.240
versiegelte Kalendertage (≈8,9 Jahre), bevor es bei null Breaches überhaupt
passfähig ist. Ein echter Breach erhöht die erforderliche Menge. Das ist keine
neue Schwelle, sondern folgt aus 10%, α/2=2,5% und dem exakten Binomialband.
Der R4-P1-Floor (`p*=0,90`: 35×60 = 2.100 Tage) bleibt separat bestehen.

**Daten-Härte.** Die Produktionsfassung darf Blöcke nur an kompatiblen
Account-Zuständen zusammensetzen. V1 soll nur flache Blockgrenzen zulassen
(0 Positionen, 0 Pending Orders, vollständige Kosten-/Kontinuitätsreconciliation).
Gibt es zu wenige solche Blöcke, lautet das Ergebnis `ABSTAIN`, nicht
Interpolation. Ein späterer state-matched/event-replay-Schätzer wäre ein neuer
OWNER-Entscheid.

**Entscheidungsfragen.**

| ID | OWNER-Entscheid | Empfehlung |
|---|---|---|
| C6-1 | Hybrid `worst(MBB, exact guard)` oder reines MBB / nur disjunkte Zählung? | **Hybrid**; reines MBB ist bei 0 Breaches fail-open, nur CP verwirft zu viel Pfadinformation. |
| C6-2 | P2/Joint als Punktwert oder untere 95%-Grenze? | **Untere 95%-Grenze**; symmetrisch zum P1- und Breach-Unsicherheitsvertrag. |
| C6-3 | Block-Stitching V1 nur an flachen Zuständen? | **Ja**; state matching erst nach separater Replay-Validierung. |
| C6-4 | Fester Disjoint-Ursprung = erster versiegelter Prag-Tag? | **Ja**; kein Offset-Suchen nach Ergebnis. |
| C6-5 | R4-Ziel `p*=0,90` und die unten beschriebenen Feasibility-Floors ratifizieren? | **Ja für Feasibility-Floors; p\* zusammen mit R5 entscheiden.** |

**Rollback / Cost of wait.** Ablehnung ändert keine Daten und lässt C-6 inert.
Warten blockiert keine laufende DXZ-Fabrik, aber der FTMO-Positive-Evidence-Pfad
kann ohne C-6 nie bestehen. Ratifizierung autorisiert nur die spätere
Implementierung plus unabhängige Abnahme; sie kauft keinen Account und aktiviert
nichts.

---

# English method contract

## 2 · Estimands and event semantics

The observation unit is one exact-profile, book-level account path, not a sum of
independently sampled sleeves. All symbols and magics must be observed on the
same time grid so cross-sleeve loss coincidence remains intact.

For a challenge start `s`:

1. Evaluate P1 for at most 60 Prague calendar days.
2. At each interval, breach if account equity is strictly below either the
   Prague-midnight balance minus 5% of initial equity or 90% of initial equity.
3. Pass P1 only when balance is strictly above 110% while the account has zero
   positions and zero pending orders and the minimum-trading-day rule is met.
4. Begin P2 on the next Prague day, reset to initial equity, and evaluate at
   +5% over at most 30 days with the same loss rules.
5. `official_breach=1` if either daily or maximum loss occurs in P1 or, after a
   P1 pass, in P2. P1 timeout is not silently called “no risk evidence”; only
   complete generated 90-day gauntlets enter C-6.

The target probabilities over the sealed data-generating regime are:

```text
theta1  = Pr(P1 pass)
thetaB  = Pr(any official breach before completion)
theta2  = Pr(P2 pass | P1 pass)
theta12 = Pr(P1 pass and P2 pass) = theta1 * theta2
```

## 3 · Required telemetry and what closed-P&L streams cannot establish

The raw `qm.ftmo-trial-telemetry.raw/v1` stream supplies the necessary observed
account state: UTC time, Prague key, balance, `ACCOUNT_EQUITY` including open
P&L/swap/commission as represented by the account, full position/pending
inventories, and tick/timer samples. Its reader supplies M5 endpoint equity and
the minimum of all observed samples in each interval, plus continuity gaps and
Prague-day anchors.

Admissibility requires all of the following:

- exact trial/account/server/profile and candidate binary/set identities;
- continuous sampling within the predeclared maximum gap, with no manually
  repaired samples;
- complete Prague days and exact midnight anchors;
- reconciled positions, pending orders, balance, costs, swap and margin;
- exact-profile risk settings (`RISK_FIXED > 0`, `RISK_PERCENT = 0`);
- a hash-bound raw stream, compacted stream, rule snapshot, code and config;
- block-boundary state compatibility.

The collector measures the minimum of terminal-observed tick and timer samples;
it is not an exchange-tick completeness proof. That limitation must remain in
every result. A gap or unreconciled state makes affected blocks inadmissible.

Closed-P&L daily backtest streams can support balance-return and expectancy
diagnostics. They cannot support C-6 credit because they do not establish:

- the joint account-equity trough between closes, including concurrent open P&L;
- Prague-midnight balance anchors and the path below each daily floor;
- the timing of swap, entry/exit commission, fees and margin changes;
- endpoint and intrainterval position/pending-order state;
- whether separately recorded per-trade MAEs occurred simultaneously;
- a flat target crossing or a coherent P1-to-P2 reset.

Summing per-trade MAE is conservative in some paths but is not an observed
joint minimum and has no calibrated probability interpretation. It must never
be promoted to an upper-95 breach estimator.

## 4 · Path construction and moving-block bootstrap

### 4.1 Normalisation

Validate the raw stream first. Build book-level interval points and daily
capsules containing at least:

```text
Prague day; midnight anchor balance; interval minimum equity;
end balance/equity; positions/pending at both boundaries;
opened-position/trading-day evidence; continuity status; source identities.
```

Convert monetary changes to initial-account fractions only after confirming the
exact account size and fixed-risk profile. Preserve all within-block ordering.

### 4.2 Stitch contract

Recommended V1 admits a 60-day source block only when its boundary state is
flat and reconciled. Concatenation rebases balance/equity deltas to the
synthetic path's current balance; it never forward-fills positions or splices
an open lifecycle. If fewer admissible blocks exist than the sample rules
require, return `ABSTAIN_INSUFFICIENT_COMPATIBLE_BLOCKS`.

This restriction is deliberately stricter than the prototype, whose synthetic
capsules are flat at every day end to demonstrate the confidence arithmetic.
Supporting overnight swing positions inside a block is allowed; only the stitch
boundary must be compatible.

### 4.3 Bootstrap

Use the existing contract constants: block length 60 calendar days, seed
20260802, 2,000 replicates (hard floor 100), alpha 0.05, two-sided percentile
95%. For each replicate:

1. sample admissible contiguous 60-day blocks uniformly with replacement;
2. concatenate/rebase them to the sealed trace length;
3. evaluate every start having a complete 90-day observation horizon;
4. record `N_b`, `S1_b`, `S12_b`, and `B_b`;
5. set rates as in the German formula; if `S1_b=0`, set the conditional credit
   to zero rather than dropping the replicate.

MBB endpoints are:

```text
L1_mbb  = Q_0.025(S1_b/N_b)
UB_mbb  = Q_0.975(B_b/N_b)
L2_mbb  = Q_0.025(S12_b/S1_b), zero when S1_b=0
L12_mbb = Q_0.025(S12_b/N_b)
```

The implementation must assert per replicate that
`S12_b/N_b == (S1_b/N_b)*(S12_b/S1_b)` when `S1_b>0`.

## 5 · Finite-sample zero-event guard and credited bounds

Seal one disjoint origin before results: the first admissible Prague day. Take
non-overlapping 90-day gauntlets from that origin and compute exact binomial
Clopper-Pearson endpoints with tail alpha 0.025. This is exact conditional on
the OWNER-ratified independence/exchangeability treatment of non-overlapping
gauntlets; material remaining serial dependence is a refutation condition.

For disjoint counts `k/n`:

- upper bound solves `Pr_p[X <= k] = 0.025`;
- lower bound solves `Pr_p[X >= k] = 0.025`.

Credit only the conservative envelope:

```text
L1_credit  = min(L1_mbb,  L1_CP)
UB_credit  = max(UB_mbb,  UB_CP)
L2_credit  = min(L2_mbb,  L2_CP)
L12_credit = min(L12_mbb, L12_CP)
```

The direct joint endpoint `L12_credit` is decisive. A product of separately
rounded 95% endpoints is diagnostic only because separate marginal coverage
does not automatically yield joint 95% coverage.

The proposed C-6 gates become evaluable only after OWNER approval and then pass
only when `UB_credit <= 0.10`, `L2_credit >= 0.85`, and
`L12_credit >= 0.65`. Thresholds are unchanged; applying lower uncertainty
bounds to P2/joint is the explicit C6-2 OWNER choice.

## 6 · Sample-size floors

### 6.1 Derived feasibility floors (no effect-size constant)

For zero observed events, the CP upper endpoint is
`1 - alpha_tail^(1/n)`. Therefore the breach gate cannot possibly pass until:

```text
n >= ceil(log(0.025) / log(0.90)) = 36 disjoint 90-day gauntlets.
```

For all successes, the CP lower endpoint is `alpha_tail^(1/n)`. Therefore P2
cannot possibly pass below 23 P1-pass denominators and joint cannot possibly
pass below 9 disjoint gauntlets:

```text
ceil(log(0.025)/log(0.85)) = 23
ceil(log(0.025)/log(0.65)) = 9
```

These are feasibility floors, not promises of a pass. Any failure increases
the necessary `n` automatically through the exact endpoint.

### 6.2 Acceptance-test power consistency

Retain R4/R5's P1 rule
`ESS_min=ceil(1.96^2*p*(1-p*)/(p*-0.80)^2)` and its OWNER-chosen
`W60>=ESS_min`, with the degenerate-HAC substitution. For C-6, additionally
require:

- `floor(D/90) >= 36` before breach can pass;
- at least 23 disjoint P1 passes before P2 conditional can pass;
- `floor(D/90) >= 9` before joint can pass;
- no percentile bound when the usable MBB block inventory or replicate count is
  below its sealed floor;
- no use of overlapping raw start count as an independent sample count.

If OWNER wants power against a non-boundary true rate, use the same precision
form with an explicit predeclared design point: for lower gates
`ceil(z^2*p*(1-p*)/(p*-bar)^2)` with `p*>bar`; for breach
`ceil(z^2*q*(1-q*)/(bar-q*)^2)` with `q*<bar`. Those design points are new ROT
choices and are not silently selected by this Vorlage.

## 7 · Validation fixtures and refutation criteria

An implementation is not OWNER-approvable until tests cover:

1. equality at each loss floor does not breach; one cent below does;
2. a planted intrainterval equity trough breaches despite safe endpoints;
3. winter/summer Prague midnight and DST transition days;
4. an open-P&L trough, swap/commission timing, margin and pending state;
5. continuity gap, duplicate identity race and incomplete day all abstain;
6. target above/equal boundary and non-flat target behavior;
7. P1 pass, next-day reset, P2 pass/fail/breach and the 60/30 horizons;
8. zero P1 denominator maps conditional credit to zero, not row deletion;
9. complete-horizon starts only — no censored tail counted as no breach;
10. zero breaches at n=35 fails feasibility and n=36 can clear 10%;
11. all-success P2 n=22 vs 23 and joint n=8 vs 9 boundaries;
12. incompatible open-state block stitching refuses;
13. fixed seed reproducibility and replicate floor refusal;
14. monotonicity: lowering any interval minimum cannot reduce breach credit or
    increase P1/P2/joint credit;
15. direct joint identity versus conditional formula on hand-worked paths;
16. the task-79772247 native-shaped restart/midnight fixture and a real
    exact-profile trial artifact, kept distinct;
17. empirical coverage calibration under known synthetic generators, including
    clustered breaches and zero-event samples;
18. parity of every path outcome with the authoritative FTMO rules engine.

Refute / return `ABSTAIN` if any required provenance is mutable, an observation
gap exists, interval minima are reconstructed from closed P&L, a stitch crosses
incompatible state, fewer than the floors are available, bounds are sensitive
to an unsealed origin, serial dependence invalidates the disjoint-unit premise,
or synthetic coverage/monotonicity fixtures fail. A diagnostic point estimate
never substitutes for a refused confidence bound.

## 8 · Prototype and disposition

Read-only prototype:
`tools/strategy_farm/research/c6_breach_joint_estimator_prototype.py`.

It implements the hybrid endpoints on deterministic synthetic flat-boundary
capsules. The 540-day “perfect” fixture deliberately receives breach upper
`0.4593`, not zero: six disjoint gauntlets are insufficient even with no
breaches. The hazard fixture moves breach upper to 1 and joint lower to 0; the
no-P1 fixture retains conditional credit 0. The prototype sets
`decision_eligible=false` and is not wired into any engine.

OWNER decision C6-1..C6-5 is required before implementation. After build, Codex
review and an OWNER approval/version bump are separately required before the
contract may cease reporting C-6 as inert. Purchase, T_Live, AutoTrading and
deployment remain outside this proposal.
