# DL-072 — Cost-Cushion gate (Q08): edge must clear a margin over realistic cost

**Date:** 2026-06-09
**Status:** **RATIFIED + IMPLEMENTED (OWNER 2026-06-09)** — live in `framework/scripts/q08_davey/aggregate.py`
**Supersedes:** none — refines the cost treatment (does NOT remove the Q04 flat-$7 or the Q08 `live_commission.json` worst-case model; adds a margin-based signal on top)
**Related:** DL-071 (Q04 net-positive PASS_SOFT), `framework/registry/live_commission.json`, `tools/strategy_farm/portfolio/commission.py`, `docs/research/PRACTITIONER_SETUPS_AND_COST_MODEL_2026-06-09.md`

## Kontext (OWNER 2026-06-09)

OWNER: das Kosten-Thema bleibt ein eigenes Gate — sein Zweck ist, **EAs mit kleinem Edge
auszusortieren, der sich durch Kosten reduziert und dann nicht mehr erfolgreich ist.** Der
flat $7/Lot (Q04) ist nicht „die Wahrheit", sondern ein konservativer Filter. Frage: gibt es
eine *bessere* Idee, die diesen Zweck sauberer erfüllt?

## Entscheidung

Statt „wende eine (per-Instrument falsche) Kostenzahl an, prüfe PF>1" → **miss die Marge
zwischen Brutto-Edge und realistischen Kosten** und mache sie zur Gate-Größe:

**`cost_cushion = gross_total / realistic_cost_total`** — das Vielfache der *realistischen
per-Instrument-Kosten* (Q08s `max(0.005%×Notional, Flat)` aus `live_commission.json`), das der
Brutto-Edge schlucken kann, bevor der Netto-P&L auf 0 fällt.

- **PASS:** cushion ≥ 2.0 (Netto-Profit ≥ realistische Kosten → echte Marge).
- **EDGE_SOFT:** 1.0 ≤ cushion < 2.0 (netto-positiv, aber **dünne** Kosten-Marge — genau die
  „kleiner Edge, von Kosten reduziert"-Klasse → als soft geflaggt, läuft in den Portfolio-Track).
- **EDGE_HARD:** cushion < 1.0 (Kosten > Brutto → netto negativ; konsistent mit `portfolio_net_pf`).
- cost ≈ 0 (z.B. flat=0-Klasse / keine Trades) → cushion N/A → PASS (kein Kosten-Drag).

Wired in `_aggregate_verdict` neben `portfolio_net_pf` (Präzedenzfall): trägt zu FAIL_HARD
(cushion<1) bzw. zum SOFT-Tier (cushion 1–2) bei; erscheint in `verdict_classification`
als `cost_cushion` + als Top-Level-Metrik `cost_cushion` / `cost_cushion_tier` / `gross_total`.

## Warum besser als der flat $7

1. **Instrument-korrekt** — nutzt die echten %-Notional-Kosten (behebt „$7 zu lasch für
   Index/Gold, zu hart für FX" von selbst), nicht eine willkürliche Pauschalzahl.
2. **Konservativ by design** — das 2×-Multiple ist der bewusste Puffer (deckt Spread/Slippage/
   Kostensteigerung/Modellfehler), aber prinzipienbasiert statt willkürlich.
3. **Misst die Robustheits-Marge** — kontinuierliche Cushion-Kennzahl statt Binär-Pass; wir
   sehen *wie* kosten-robust ein Edge ist. Die neue Information ggü. `portfolio_net_pf` (binär >1)
   ist das **EDGE_SOFT-Band** (netto-positiv aber dünn) — exakt OWNERs Filter-Ziel.
4. **Kein Framework-Umbau / kein Re-Run** — post-hoc aus dem Trade-Stream berechnet (Q08 liest
   ihn ohnehin + wendet `live_commission.json` an). Greift auf **allen künftigen Q08-Läufen**;
   existierende Aggregate bekommen die Cushion beim nächsten Lauf (kein Backfill möglich, kein
   gross_total gespeichert).

## Schwellen (kalibrierbar)
`Q08_COST_CUSHION_PASS = 2.0`, `Q08_COST_CUSHION_SOFT = 1.0`. Unit-getestet
(robust 6.0→PASS, thin 1.4→EDGE_SOFT, cost-eaten 0.75→EDGE_HARD, loser→EDGE_HARD, no-cost→PASS).

## Caveat
Greift erst bei künftigen Q08-Läufen (forward, wie DL-071). Die DL-071-PASS_SOFT-Kohorte
trifft beim Q08-Durchlauf auf dieses Cushion-Gate — der konservative Kosten-Filter bleibt also
voll wirksam, nur als prinzipientreue Marge statt Pauschal-$7.
