# DL-078 — Q09 portfolio-context regime admission (regime catastrophe defers to the book)

**Date:** 2026-06-27
**Status:** **RATIFIED + IMPLEMENTED (OWNER 2026-06-27, "B")**
**Supersedes:** the standalone `q08_regime_catastrophe` hard-reject in `tools/strategy_farm/portfolio/portfolio_q08_contribution.py` (`evaluate_q08_soft_rescue`).
**Related:** [[DL-075]] (Q08 FAIL_SOFT → portfolio track), [[DL-064]] (portfolio-construction layer), OWNER feedback **F4 (2026-06-03)** (standalone PF<1 must not disqualify a portfolio sleeve). Files: `tools/strategy_farm/portfolio/portfolio_q08_contribution.py`, `tools/strategy_farm/tests/test_portfolio_q08_contribution.py`.

## Kontext (OWNER 2026-06-27)

Nach der Stream-Reparatur (10940 XAUUSD, 11132 SP500 hatten abgeschnittene q08_trades-Streams,
6/9 Trades statt 35/43 — kaputte Korrelations-/DD-Charakterisierung des Live-Buchs) lief der
Q09-Harvest über die volle FAIL_SOFT-Reserve. **Alle 7 nicht-im-Buch-Kandidaten wurden blockiert:**
6× `q08_regime_catastrophe` (AUDCAD, EURUSD, AUDUSD, 3× GDAXI), 1× redundant (11124 SP500, corr 0.51
zu 11132). Ergebnis mit altem Gate: 0 neue Sleeves, Buch bei 8.

## Das Problem (im Code verankert + inkonsistent)

`evaluate_q08_soft_rescue` lehnte jeden Kandidaten mit Q08-8.10-Flag `unprofitable_regimes`
**standalone hart ab** (`verdict=FAIL_PORTFOLIO`, `reason=q08_regime_catastrophe`), **bevor**
`portfolio_admission` überhaupt lief (`max_corr=None`, `diversifies=None`).

Das widerspricht direkt DL-075: *„FAIL_SOFT = robust-but-regime-dependent EAs, deren
Regime-Abhängigkeit das Antikorrelations-Portfolio absorbieren soll."* Ein Sleeve, dessen
schlechtes Regime **unkorreliert** zu denen des Buchs ist, **senkt** die Buch-DD — das Buch
absorbiert das Einzel-Regime-Risiko. Belege (echte Commission, durable Streams, risk-parity):

| Buch | Sharpe | MaxDD% |
|---|---|---|
| 8 (honest, nach Stream-Fix) | 1.564 | 5.66% |
| +AUDCAD (9) | 1.677 | 5.20% |
| +EURUSD (10) | 1.719 | 4.57% |
| +AUDUSD (11) | 1.741 | **4.50%** |

Jede der drei „regime-catastrophe"-Sleeves **senkt** die Buch-DD und hebt Sharpe — im greedy
Sequence-Test monoton. Zusatzbeleg für die Inkonsistenz: **10440:NDX ist bereits im Buch** mit
**derselben** `regime_catastrophe`-Flag (grandfathered), und es zu entfernen macht das Buch
*schlechter* (DD 5.66 → 6.68 %). Das Standalone-Gate verwarf also echte Diversifier, während es
einen gleich-„fragilen" Sleeve drin behielt.

## Entscheidung

Eine **standalone** Q08-8.10-Regime-Katastrophe **disqualifiziert einen Portfolio-Sleeve nicht
mehr hart.** Sie wird zur Audit-Transparenz aufgezeichnet (`q08_regime_catastrophe`), und das
Verdikt **deferiert an `portfolio_admission`** — exakt wie F4 (2026-06-03) den standalone-PF<1-Reject
behandelte. `portfolio_admission` admittiert **nur** wenn der Kandidat hinreichend unkorreliert ist
(corr ≤ 0.30) **und** das Buch nachweislich verbessert (Sharpe hoch ODER MaxDD runter). Die
Portfolio-Equity-Kurve **umspannt bereits** das schlechte Regime des Kandidaten — eine Admission
ist damit der Beweis, dass das Buch es absorbiert.

**Guards (kein Free-Pass):**
1. Ein regime-fragiler Sleeve, der das Buch **nicht** verbessert, **FAILt** weiterhin an der
   Admission (`reason=no_diversification` / `correlation_above_max_corr`). Test:
   `test_regime_catastrophe_still_fails_when_book_not_improved`.
2. Korrelations-Gate (≤ 0.30) und Overlap-/Trade-Min-Gates bleiben unverändert.
3. Audit-Flag `regime_catastrophe_absorbed_by_book=true` im Artefakt, wenn ein solcher Sleeve
   admittiert wurde — der Trail bleibt nachvollziehbar.
4. Die **absolute** Robustheit wird durch die risk-parity-Buch-MaxDD verifiziert (4.50 % « FTMO 10 %).

**Das ist keine „Gate-Aufweichung für Accuracy"** — es korrigiert eine logische Inkonsistenz
gegen die eigene Design-Absicht (DL-075) und ist durch die Buch-DD-Reduktion belegt.

## Ergebnis

Re-Admission der 3 Diversifier (AUDCAD, EURUSD, AUDUSD) durch das korrigierte Gate → erweitertes
Buch **8 → 11 Sleeves**, Sharpe **1.56 → 1.74**, MaxDD **5.66 % → 4.50 %**. Mittlere Paar-Korrelation
+0.008. Caveat: 3 der neuen Sleeves sind AUD/EUR-FX (milde Konzentration; corr-Gate je ≤ 0.30
bestanden).

## Tests

`tools/strategy_farm/tests/test_portfolio_q08_contribution.py` — 9/9 grün:
`test_regime_catastrophe_defers_to_portfolio_admission` (admit-Pfad),
`test_regime_catastrophe_still_fails_when_book_not_improved` (Guard).
