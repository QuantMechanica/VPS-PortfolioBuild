# DL-079 — Sharpe-protective portfolio admission (no Sharpe dilution on noise-floor MaxDD gains)

**Date:** 2026-06-28
**Status:** **RATIFIED + IMPLEMENTED (OWNER 2026-06-28, "Mach A und B")**
**Supersedes:** the `diversifies = sharpe_improved or maxdd_improved` rule in `tools/strategy_farm/portfolio/portfolio_admission.py` (`evaluate_candidate`).
**Related:** [[DL-078]] (regime catastrophe defers to admission), [[DL-075]] (Q08 FAIL_SOFT portfolio track), [[DL-064]] (portfolio-construction layer). Files: `tools/strategy_farm/portfolio/portfolio_admission.py`, `tools/strategy_farm/tests/test_portfolio_admission.py`.

## Kontext (OWNER 2026-06-28)

Ein Fan-out (4 Subagenten) zur Frage „welche EAs vervollständigen das Buch fürs Live-Trading"
ergab einstimmig: die einzige Strukturlücke ist EU-Equity (GDAXI); drei Q08-FAIL_SOFT-EAs
(10115/10911/10938 GDAXI) liegen bereit. Das Admission-Gate (`evaluate_candidate`) sagte für
10115/10911 **ADMIT** — aber eine Voll-Historie-Risk-Parity-Gegenrechnung zeigte, dass alle drei
das Buch **verschlechtern** (Sharpe 2.00 → 1.89). Diskrepanz zwischen Gate und maßgeblicher
Buch-Metrik → Fix-Auftrag B.

## Root-Cause (diagnostiziert, mit Evidence)

`evaluate_candidate` rechnet `diversifies = sharpe_improved OR maxdd_improved` auf inverse-vol-
gewichteten with/without-Metriken. Zwei verkoppelte Probleme:

1. **Kapital-Basis-Rauschen.** Die q08_trades-Streams sind RISK_FIXED-$1000-Backtests auf dem
   kanonischen $100k-Tester (= 1%/Trade, `tester_defaults.json`). Auf dieser Basis ist die
   Buch-MaxDD **sub-1%** (~0.4%). Bei dieser Größe ist das with/without-**MaxDD-Delta von
   Rauschen dominiert** (welcher einzelne Tag den Peak setzt) und kann das Vorzeichen drehen —
   bei $100k-Durable-Streams meldete das Gate für 10115 fälschlich „DD verbessert 0.389→0.377",
   bei $10k bzw. Common-Streams korrekt „DD verschlechtert". (Hinweis: das früher zitierte
   „MaxDD 3.23%" stammte aus `build_real_portfolio`'s **nicht-kanonischer $10k-Basis**, die DD
   ~8-10× überzeichnet; die kanonische Buch-MaxDD ist sub-1%. Live-Readiness unberührt — beide
   « FTMO 10%.)
2. **OR-Regel.** Der `OR maxdd_improved`-Term ließ einen Sleeve, der den **Sharpe verwässert**
   (Sharpe ist skalierungs-invariant und sagte konsistent „degradiert": 2.00→1.89), über einen
   solchen Rausch-MaxDD-„Gewinn" trotzdem zu.

## Entscheidung

**Sharpe-schützende Diversifikationsregel.** Da das Buch ein High-Sharpe-Risk-Parity-Portfolio
mit MaxDD **weit unter** dem FTMO-Cap ist (DD-Spielraum reichlich), ist eine marginale
MaxDD-Verbesserung keinen Sharpe-Verlust wert. Neu:

```
diversifies = sharpe_improved OR (maxdd_improved AND NOT sharpe_degraded)
```
mit `sharpe_degraded = sharpe_with < sharpe_without - 1e-3`.

D.h.: ein Kandidat diversifiziert, wenn er den Sharpe verbessert, ODER die MaxDD verbessert
**ohne den Sharpe zu verschlechtern**. Sharpe (skalierungs-invariant, kapital-basis-unabhängig)
ist das verlässliche Signal, solange DD nicht bindet.

**Guard / Regime-Annahme:** Gilt im aktuellen DD-unkritischen Regime. Sollte die Buch-MaxDD je
an den Cap heranreichen (DD-bindendes Regime), ist ein DD-für-Sharpe-Tausch wieder erwünscht —
dann diese Regel erneut betrachten. Korrelations-Gate (≤0.30) und Overlap-Gates unverändert.

## Ergebnis

Nach dem Fix werden 10115/10911/10938 GDAXI korrekt **abgelehnt** (no_diversification bzw.
insufficient_overlap; alle senken den Buch-Sharpe). Das 12-Sleeve-Buch (Sharpe ~2.00) bleibt
unverwässert. Befund fürs Buch-Wachstum: die *vorhandenen* GDAXI-EAs sind zu schwach (PF
1.0-1.1) — die EU-Equity-Lücke braucht **bessere** Edges (Auftrag A: stärkere GDAXI/Öl/Silber-
Kandidaten bauen), nicht das Seaten vorhandener.

## Tests

`tools/strategy_farm/tests/test_portfolio_admission.py` — 11/11 grün, inkl. neuem
`test_dl079_maxdd_only_gain_with_sharpe_degradation_is_rejected` (MaxDD-only-Gain bei
Sharpe-Degradation → reject; Kontrolle: Sharpe-Gain → admit). Real-Daten-Verifikation:
10115/10911/10938 GDAXI alle admit=False.
