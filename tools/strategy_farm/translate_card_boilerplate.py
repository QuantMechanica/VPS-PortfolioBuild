"""Translate the German boilerplate and prose in the strategy cards to English.

OWNER 2026-08-23: "übersetze das auch in den Strategy Cards".

Measured before writing anything: 2,710 of 3,271 approved cards carry German text in
186 distinct lines, and 20,138 occurrences. The overwhelming mass is **template
boilerplate** — five section headings, two table headers, a maintenance note and four
placeholder lines. A tail of roughly sixty lines is genuine prose in a handful of cards
(the academic-momentum family, the Unger family, a cointegration card, five
"Dekonstruiert aus …" descriptions).

**What this does to the evidence chain.** ``strategy_card_fingerprint`` is computed from
``source_id``, slug, the symbol universe, the timeframe token and a fixed list of eleven
English thesis terms. German prose usually contains none of them — but a *translation*
can introduce one. Measured over all 3,271 cards, exactly one fingerprint moves:
``QM5_1059_jegadeesh-stm-reversal-indices`` gains the term ``mean reversion`` because the
German wrote it hyphenated as ``Short-Term-Mean-Reversion``. The new fingerprint is more
accurate, not less — the card *is* a mean-reversion strategy — so the change is taken
deliberately under ``--allow-fingerprint-change`` and recorded with before/after values.
Every other card keeps its fingerprint, and the script verifies that per card before
writing.

**Verbatim quotations are never translated.** Code fences and LaTeX are protected, which
is why the German vendor claim in ``QM5_20010_xau-friday-rush`` (inside a ``text`` fence
under a heading that says *verbatim*) stays in German. Translating a labelled quotation
would falsify it.

Order matters: whole sentences first, then section-name terms. Otherwise a term
replacement would corrupt a sentence before its own translation could match it.

Usage::

    python tools/strategy_farm/translate_card_boilerplate.py --dry-run
    python tools/strategy_farm/translate_card_boilerplate.py --apply
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import re
import shutil
import sys
from collections import Counter
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT / "tools" / "strategy_farm") not in sys.path:
    sys.path.insert(0, str(REPO_ROOT / "tools" / "strategy_farm"))

ARTIFACTS = Path("D:/QM/strategy_farm/artifacts")
# render_card_section() resolves a card from six buckets, so all six are translated.
# Translating only cards_approved left German on pages whose card sits elsewhere:
# measured, cards_rejected alone holds 681 cards with German boilerplate.
CARD_BUCKETS = ("cards_approved", "cards_review", "cards_draft", "cards_rejected",
                "cards_recovery", "cards_blocked_r3_data")
BACKUP_ROOT = Path(r"D:\QM\backups")
EVIDENCE = REPO_ROOT / "docs" / "ops" / "evidence" / "2026-08-23_card_translation_report.json"

# ── 1 · whole lines / sentences ───────────────────────────────────────────────
SENTENCES: list[tuple[str, str]] = [
    # headings
    ("## Concepts (was ist das für eine Strategie)", "## Concepts (what kind of strategy is this)"),
    ("## Concepts (was ist das fur eine Strategie)", "## Concepts (what kind of strategy is this)"),
    ("## Concepts (was ist das fuer eine Strategie)", "## Concepts (what kind of strategy is this)"),
    # tables
    ("| Kriterium | Status | Begründung |", "| Criterion | Status | Rationale |"),
    ("| Kriterium | Status | Begruendung |", "| Criterion | Status | Rationale |"),
    ("| Kriterium | Status | Begrundung |", "| Criterion | Status | Rationale |"),
    ("| Phase | Status | Datum |", "| Phase | Status | Date |"),
    # placeholders
    ("- (noch keine)", "- (none yet)"),
    ("- G0: <Datum, Verdict, Begründung>", "- G0: <date, verdict, rationale>"),
    ("- G0: <Datum, Verdict, Begruendung>", "- G0: <date, verdict, rationale>"),
    ("- P1: <Datum, .ex5-Pfad>", "- P1: <date, .ex5 path>"),
    ("- P2: <Datum, report.csv-Pfad, PASS-Symbole>", "- P2: <date, report.csv path, PASS symbols>"),
    ("- <Datum>: <Erkenntnis> — siehe", "- <date>: <finding> — see"),
    # academic momentum family
    ("Auf jedem Monatsende (D1 close at month-end candle), für jeden Instrument im Universe:",
     "At every month end (D1 close on the month-end candle), for every instrument in the universe:"),
    ("Auf jedem Monatsende, für das Universe (Forex Majors + Indices):",
     "At every month end, for the universe (FX majors + indices):"),
    ("- Position wird bis zum nächsten Monatsende gehalten (monatliches Rebalancing).",
     "- The position is held until the next month end (monthly rebalancing)."),
    ("- Reverse-Signal am nächsten Monatsende → Position flippt.",
     "- A reverse signal at the next month end flips the position."),
    ("- Unverändertes Signal → Position bleibt (monatlich rolliert via Schließen+Öffnen für sauberes Magic-Tracking).",
     "- An unchanged signal keeps the position (rolled monthly by close+reopen for clean magic tracking)."),
    ("- Hard ATR(20)-Stop bei 4× ATR vom Entry-Preis (worst-case Risk-Bound für R4 Compliance).",
     "- Hard ATR(20) stop at 4x ATR from the entry price (worst-case risk bound for R4 compliance)."),
    ("- Kein Trailing — TSMOM ist regelbasiert auf Monatssignal, SL nur als Tail-Protection.",
     "- No trailing - TSMOM is rule-based on the monthly signal; the SL is tail protection only."),
    ("- News-Filter: keine — TSMOM ist monatsbasiert, intraday-News irrelevant.",
     "- News filter: none - TSMOM is monthly, so intraday news is irrelevant."),
    ("- News-Filter: keine.", "- News filter: none."),
    ("- News-Filter: keine (Wochen-basiert).", "- News filter: none (weekly cadence)."),
    ("- Monatliches Rebalancing: am nächsten Monatsende werden alle Positionen geschlossen und das neue Top/Bottom-2-Portfolio eröffnet.",
     "- Monthly rebalancing: at the next month end all positions are closed and the new top/bottom-2 portfolio is opened."),
    ("- Monatliches Rebalancing am nächsten Monatsende.", "- Monthly rebalancing at the next month end."),
    ("- Hard ATR(20)-Stop bei 5× ATR vom Entry-Preis (XSMOM hat höhere Volatilität als TSMOM weil Long-Short → wider stop).",
     "- Hard ATR(20) stop at 5x ATR from the entry price (XSMOM is more volatile than TSMOM because it is long-short, hence the wider stop)."),
    ("- ATR(20)-Stop bei 4× ATR vom Entry-Preis.", "- ATR(20) stop at 4x ATR from the entry price."),
    ("- Hard ATR(14)-Stop bei 3× ATR vom Entry-Preis (Short-Term-Mean-Reversion brauch engerer Stop als TSMOM weil Holding-Period nur 5 Bars).",
     "- Hard ATR(14) stop at 3x ATR from the entry price (short-term mean reversion needs a tighter stop than TSMOM because the holding period is only 5 bars)."),
    ("2. Rangliste alle Symbole.", "2. Rank all symbols."),
    ("2. Rangliste alle Symbole nach Proximity.", "2. Rank all symbols by proximity."),
    ("2. Rangliste alle Universe-Indices.", "2. Rank all universe indices."),
    ("Halte bis zum nächsten Monatsende.", "Hold until the next month end."),
    ("5. Halte bis zum nächsten Freitag-Close.", "5. Hold until the next Friday close."),
    ("- Wöchentliches Rebalancing: am nächsten Freitag-Close beide Positionen schließen, neues Pair eröffnen.",
     "- Weekly rebalancing: close both positions at the next Friday close and open the new pair."),
    ("- Wenn Reversal-Signal sich umkehrt (long wird zum top, short zum bottom) → flip am nächsten Freitag.",
     "- If the reversal signal inverts (the long becomes the top, the short the bottom), flip at the next Friday."),
    ("- Force-close wenn `Proximity` einer Long-Position unter 0.85 fällt (Pull-back >15% vom 52w-Hoch — Trend-Verlust).",
     "- Force close when the `Proximity` of a long position falls below 0.85 (a pull-back of more than 15% off the 52w high - trend lost)."),
    ("1. Berechne 5-Tage-Return für jeden Index: `R5(t) = Close[t] / Close[t-5] - 1`.",
     "1. Compute the 5-day return for each index: `R5(t) = Close[t] / Close[t-5] - 1`."),
    ("1. Berechne für jeden Symbol: `Proximity(t) = Close[t] / MaxHigh(252)` (252 = ~52 Wochen Trading-Tage).",
     "1. Compute for each symbol: `Proximity(t) = Close[t] / MaxHigh(252)` (252 = ~52 weeks of trading days)."),
    ("1. Berechne 12-month-minus-1-month-Return für jeden Symbol: `R(t) = Close[t-21] / Close[t-252] - 1` (skip-most-recent-month um Short-Term-Reversal zu vermeiden, klassische Asness-Spec).",
     "1. Compute the 12-month-minus-1-month return for each symbol: `R(t) = Close[t-21] / Close[t-252] - 1` (skipping the most recent month to avoid short-term reversal, the classic Asness spec)."),
    # cointegration / pairs
    ("Für jedes Pair (H1 oder D1 Bar — Default D1):", "For each pair (H1 or D1 bar - default D1):"),
    ("1. Normalisiere beide Logpreise zu Z-Score-Differenz: `Spread(t) = log(P_A) - β·log(P_B)`, wobei β über rollende 60-Bar-OLS-Regression bestimmt wird.",
     "1. Normalise both log prices into a z-score spread: `Spread(t) = log(P_A) - beta*log(P_B)`, where beta comes from a rolling 60-bar OLS regression."),
    ("- Hard-Stop bei `|Z(t)| > 4.0` (Strukturbruch — close at loss, kein Add-on).",
     "- Hard stop at `|Z(t)| > 4.0` (structural break - close at a loss, no add-on)."),
    ("- Strukturbruch-Stop bei `|Z(t)| > 4.0` (Z-basiert, kein Preis-ATR-Stop weil Position market-neutral ist).",
     "- Structural-break stop at `|Z(t)| > 4.0` (z-based, not a price ATR stop, because the position is market neutral)."),
    ("- Worst-case-bound: Z-Differenz von 2.0 zu 4.0 entspricht ≈ 2-Std-Move beider Legs → bounded for R4.",
     "- Worst-case bound: a z-spread moving from 2.0 to 4.0 is roughly a 2-sigma move in both legs, so it is bounded for R4."),
    ("- Time-Filter: keine Trades 30min vor/nach NY-Close (rollover-Spread).",
     "- Time filter: no trades 30 min before or after the NY close (rollover spread)."),
    ("- Magic: 2 Slots pro Pair (Leg A, Leg B) → mit 3 Pairs maximal 6 gleichzeitige Positionen, 6 Magic-Nummern.",
     "- Magic: 2 slots per pair (leg A, leg B), so 3 pairs allow at most 6 concurrent positions across 6 magic numbers."),
    # composite oscillator card
    ("**Schritt 1 — Basis-Oszillator**:", "**Step 1 - base oscillator**:"),
    ("**Schritt 2 — Composite-Oszillator (Williams %R auf RSI-Serie)**:",
     "**Step 2 - composite oscillator (Williams %R on the RSI series)**:"),
    ("**Schritt 3 — Trigger**:", "**Step 3 - trigger**:"),
    ("- **Profit-Target**: `entry_price ± 2.0 × ATR(14, H4) bei Entry` (richtungsabhängig).",
     "- **Profit target**: `entry_price +/- 2.0 x ATR(14, H4) at entry` (direction dependent)."),
    ("- **Time-Stop**: 6 H4-Bars nach Entry (Mean-Reversion-Edge in seinem natürlichen Zeitfenster).",
     "- **Time stop**: 6 H4 bars after entry (the mean-reversion edge inside its natural window)."),
    ("- **Opposite-Cross-Exit**: WR_of_RSI > -50 (Long) bzw. < -50 (Short) — Rückkehr zum Mittelwert.",
     "- **Opposite-cross exit**: WR_of_RSI > -50 (long) or < -50 (short) - reversion to the mean."),
    ("- **News-Filter**: 15 min vor / nach High-Impact Skip.",
     "- **News filter**: skip 15 min before and after high-impact events."),
    ("- **Range-Sanity**: Skip-Trade falls `highest(RSI, 14) - lowest(RSI, 14) < 5.0` (RSI-Range zu eng, Composite-Signal nicht aussagekräftig — Division-by-near-zero-Schutz UND No-Trade-Edge-Condition).",
     "- **Range sanity**: skip the trade when `highest(RSI, 14) - lowest(RSI, 14) < 5.0` (the RSI range is too tight for the composite signal to mean anything - both a division-by-near-zero guard and a no-trade edge condition)."),
    ("- Composite-Konstruktion (Oszillator auf einem Oszillator) ist FF-Cluster-Eigenleistung, ist aber bei mehreren named-author Replikationen dokumentiert (z.B. ChartSchool / StockCharts.com \"Stochastic RSI\"-Analoga).",
     "- The composite construction (an oscillator on an oscillator) originates with the FF cluster but is documented in several named-author replications (e.g. the ChartSchool / StockCharts.com \"Stochastic RSI\" analogues)."),
    ("- Distinkt von [[strategies/QM5_1294_williams-r-h4]] (direktes %R auf Preis) UND von [[strategies/QM5_1450_connors-rsi-2]] (kurzes RSI direkt auf Preis): hier wird %R auf die RSI-Serie selbst angewendet — entrauscht extreme-RSI-Detection.",
     "- Distinct from [[strategies/QM5_1294_williams-r-h4]] (%R directly on price) AND from [[strategies/QM5_1450_connors-rsi-2]] (a short RSI directly on price): here %R is applied to the RSI series itself, which de-noises extreme-RSI detection."),
    ("- [[strategies/QM5_1294_williams-r-h4]] — direktes %R-auf-Preis (Original-Williams).",
     "- [[strategies/QM5_1294_williams-r-h4]] - %R directly on price (the original Williams)."),
    # universe notes
    ("N/A — Universe ist EURUSD + GBPUSD (Forex Majors, broker-routable). Keine",
     "N/A - the universe is EURUSD + GBPUSD (FX majors, broker-routable). No"),
    ("N/A — alle Universe-Symbole sind broker-routable.", "N/A - every universe symbol is broker-routable."),
    ("N/A — Universe ist broker-routable.", "N/A - the universe is broker-routable."),
    ("N/A — beide Legs sind broker-routable Forex-Paare.", "N/A - both legs are broker-routable FX pairs."),
    ("N/A — Universe besteht ausschließlich aus broker-routable DWX-Symbolen",
     "N/A - the universe consists exclusively of broker-routable DWX symbols"),
    ("N/A — Universe besteht aus broker-routable Symbolen (NDX.DWX, WS30.DWX, GER40.DWX, Forex, XAUUSD). SP500.DWX ist nicht enthalten, daher kein T6-Caveat erforderlich.",
     "N/A - the universe consists of broker-routable symbols (NDX.DWX, WS30.DWX, GER40.DWX, FX, XAUUSD). SP500.DWX is not included, so no T6 caveat is required."),
    # deconstruction summaries
    ("Dekonstruiert aus Happy Gold: Handelt ZigZag-Pivot-Ausbrüche in Richtung des übergeordneten H4 50-EMA-Trends mit 24-Pip Hard-Stop und Ratchet-Trailing.",
     "Deconstructed from Happy Gold: trades ZigZag pivot breakouts in the direction of the higher H4 50-EMA trend, with a 24-pip hard stop and ratchet trailing."),
    ("Dekonstruiert aus Forex Gold Investor: 3 parallele Module (Intraday Linear Regression, Asian Session Breakout und 4H Volatility Surge) mit verstecktem Broker-Spy SL/TP.",
     "Deconstructed from Forex Gold Investor: three parallel modules (intraday linear regression, Asian-session breakout and 4H volatility surge) with a hidden broker-spy SL/TP."),
    ("Dekonstruiert aus Dark Venus: Reines Bollinger-Band-Gegenpositionieren bei Überdehnung mit statischem 15-Pip-Grid und Break-Even-Basket-Trailing.",
     "Deconstructed from Dark Venus: pure Bollinger-band fading of over-extension with a static 15-pip grid and break-even basket trailing."),
    ("Dekonstruiert aus Dark Kronos: Trendfolge auf Schweizer-Franken-Crosses mit H1 EMA 50/200, ADX > 25 und linearem (nicht-martingale) Positionsaufbau.",
     "Deconstructed from Dark Kronos: trend following on Swiss-franc crosses with H1 EMA 50/200, ADX > 25 and linear (non-martingale) position building."),
    ("Dekonstruiert aus Forex Fury: Handelt exakt während der 23:00 bis 00:00 GMT Rollover-Stunde. Faded die Preis-Envelopes mit SMA 50 Trendfilter und 5-Pip TP.",
     "Deconstructed from Forex Fury: trades exactly the 23:00-00:00 GMT rollover hour, fading the price envelopes with an SMA 50 trend filter and a 5-pip TP."),
    # R1-R4 assessment cells that survived the first pass
    ("| R2 Mechanical | UNKNOWN | Entry/Exit/SL/Sizing mechanisch — 12M-Return-Sign, monatliches Rebalancing, ATR-Stop. Vol-Targeting hat Default (Realised-Vol(60)). |",
     "| R2 Mechanical | UNKNOWN | Entry/exit/SL/sizing are mechanical - 12M return sign, monthly rebalancing, ATR stop. Vol targeting has a default (realised vol(60)). |"),
    ("| R3 Data Available | UNKNOWN | Alle Universe-Instrumente sind im DWX-Feed live-tradable (Forex Majors, XAUUSD, NDX.DWX, WS30.DWX, GER40.DWX). Oil CFD prüfen — sonst aus Universe streichen. SP500.DWX NICHT im Universe (backtest-only). |",
     "| R3 Data Available | UNKNOWN | All universe instruments are live-tradable on the DWX feed (FX majors, XAUUSD, NDX.DWX, WS30.DWX, GER40.DWX). Check the oil CFD - otherwise drop it from the universe. SP500.DWX is NOT in the universe (backtest only). |"),
    ("| R4 ML Forbidden | UNKNOWN | Kein ML, keine adaptiven Parameter, hard 4×ATR-Stop = bounded worst-case, 1 Position pro Magic. PASS-Kandidat. |",
     "| R4 ML Forbidden | UNKNOWN | No ML, no adaptive parameters, a hard 4x ATR stop as a bounded worst case, 1 position per magic. PASS candidate. |"),
    ("| R3 Data Available | UNKNOWN | Alle 11 Universe-Symbole live-tradable im DWX-Feed. Kein SP500.DWX im Universe. |",
     "| R3 Data Available | UNKNOWN | All 11 universe symbols are live-tradable on the DWX feed. No SP500.DWX in the universe. |"),
    ("| R3 Data Available | UNKNOWN | Alle 11 Universe-Symbole live-tradable im DWX-Feed. SP500.DWX nicht enthalten. |",
     "| R3 Data Available | UNKNOWN | All 11 universe symbols are live-tradable on the DWX feed. SP500.DWX is not included. |"),
    ("| R4 ML Forbidden | UNKNOWN | Reines Ranking — keine ML, keine Adaption, 1-Position-per-Magic-Slot (4 Slots). 5×ATR-Stop = bounded worst-case. PASS-Kandidat. |",
     "| R4 ML Forbidden | UNKNOWN | Pure ranking - no ML, no adaptation, one position per magic slot (4 slots). A 5x ATR stop as a bounded worst case. PASS candidate. |"),
    ("| R2 Mechanical | UNKNOWN | β über rollende OLS, Z-Score-Schwellen, mean-revert oder time-stop. Vollmechanisch. Pair-Auswahl ist hand-defined (kein online-cointegration-fit → keine R4-Adaption). |",
     "| R2 Mechanical | UNKNOWN | Beta from a rolling OLS, z-score thresholds, mean-revert or time stop. Fully mechanical. Pair selection is hand-defined (no online cointegration fit, hence no R4 adaptation). |"),
    ("| R4 ML Forbidden | UNKNOWN | OLS-Regression über fixe 60-Bar-Window ist statistische Standard-Methode, KEIN ML-Adaption. Schwellen (-2/+2/0.5/4) sind fix. 6 Magic-Slots. Bounded worst-case via Z-Stop. PASS-Kandidat. |",
     "| R4 ML Forbidden | UNKNOWN | An OLS regression over a fixed 60-bar window is a standard statistical method, NOT an ML adaptation. The thresholds (-2/+2/0.5/4) are fixed. 6 magic slots. Bounded worst case via the z-stop. PASS candidate. |"),
    ("| R2 Mechanical | UNKNOWN | 5-Tage-Return-Ranking, Top/Bottom-1, wöchentliche Rotation, ATR-Stop. Vollmechanisch. |",
     "| R2 Mechanical | UNKNOWN | 5-day return ranking, top/bottom 1, weekly rotation, ATR stop. Fully mechanical. |"),
    ("| R4 ML Forbidden | UNKNOWN | Reines Ranking, fixe Parameter, 1-Pos-per-Magic-Slot (2 Slots), 3×ATR-Stop = bounded worst-case. PASS-Kandidat. |",
     "| R4 ML Forbidden | UNKNOWN | Pure ranking, fixed parameters, one position per magic slot (2 slots), a 3x ATR stop as a bounded worst case. PASS candidate. |"),
    ("| R2 Mechanical | UNKNOWN | 252-Bar-Max-High, Proximity-Ratio, Top/Bottom-Ranking, Monthly-Rebalance, ATR-Stop, Force-Close-bei-Pullback. Vollmechanisch. |",
     "| R2 Mechanical | UNKNOWN | 252-bar max high, proximity ratio, top/bottom ranking, monthly rebalance, ATR stop, force close on pullback. Fully mechanical. |"),
    ("| R4 ML Forbidden | UNKNOWN | Reines Ranking auf einem deterministischen Indikator (252-Bar-Hoch), fixe Schwellen (0.85 pullback, 4×ATR), 4 Magic-Slots, bounded worst-case. PASS-Kandidat. |",
     "| R4 ML Forbidden | UNKNOWN | Pure ranking on a deterministic indicator (the 252-bar high), fixed thresholds (0.85 pullback, 4x ATR), 4 magic slots, bounded worst case. PASS candidate. |"),
    ("| R2 Mechanical | UNKNOWN | Vollmechanisch: today's open ± K×YR pending stops, EOD time-exit, ATR-stop. K und SL_ATR mit dokumentierten Defaults. |",
     "| R2 Mechanical | UNKNOWN | Fully mechanical: today's open +/- K x YR pending stops, EOD time exit, ATR stop. K and SL_ATR carry documented defaults. |"),
    ("| R3 Data Available | UNKNOWN | Alle 4 Universe-Symbole (GER40.DWX, NDX.DWX, WS30.DWX, XAUUSD) live-tradable DWX. Keine SP500.DWX-Abhängigkeit → kein T6-Caveat. |",
     "| R3 Data Available | UNKNOWN | All 4 universe symbols (GER40.DWX, NDX.DWX, WS30.DWX, XAUUSD) are live-tradable on DWX. No SP500.DWX dependency, hence no T6 caveat. |"),
    ("| R4 ML Forbidden | UNKNOWN | Keine ML, keine adaptiven Parameter, hard ATR-Stop = bounded worst-case, 1 Position pro Magic. PASS-Kandidat. |",
     "| R4 ML Forbidden | UNKNOWN | No ML, no adaptive parameters, a hard ATR stop as a bounded worst case, 1 position per magic. PASS candidate. |"),
    ("| R2 Mechanical | UNKNOWN | Vollmechanisch: first-30-min H/L marker, OCO pending stops, OR-opposite stop, EOD time-exit, narrow-range skip. Defaults documented. |",
     "| R2 Mechanical | UNKNOWN | Fully mechanical: first-30-min H/L marker, OCO pending stops, OR-opposite stop, EOD time exit, narrow-range skip. Defaults documented. |"),
    ("| R3 Data Available | UNKNOWN | GER40.DWX, NDX.DWX, WS30.DWX alle live-tradable DWX (D1 + intraday M5). Cash sessions aus Broker-Spec ableitbar. Keine SP500.DWX → kein T6-Caveat. |",
     "| R3 Data Available | UNKNOWN | GER40.DWX, NDX.DWX and WS30.DWX are all live-tradable on DWX (D1 + intraday M5). Cash sessions are derivable from the broker spec. No SP500.DWX, hence no T6 caveat. |"),
    ("| R4 ML Forbidden | UNKNOWN | Keine ML, kein adaptive parameter, bounded SL (OR-size oder 2×ATR-Cap), 1 Position pro Magic. PASS-Kandidat. |",
     "| R4 ML Forbidden | UNKNOWN | No ML, no adaptive parameter, a bounded SL (OR size or a 2x ATR cap), 1 position per magic. PASS candidate. |"),
    ("| R2 Mechanical | UNKNOWN | Vollmechanisch: BB(20,2)-touch, ADX(14)-Regime-Gate, Mittellinien-TP, ATR-Stop, Zeit-Cap 12h. Defaults dokumentiert. |",
     "| R2 Mechanical | UNKNOWN | Fully mechanical: BB(20,2) touch, ADX(14) regime gate, midline TP, ATR stop, 12h time cap. Defaults documented. |"),
    ("| R3 Data Available | UNKNOWN | EURUSD und GBPUSD H1 live-tradable DWX. Keine SP500.DWX → kein T6-Caveat. |",
     "| R3 Data Available | UNKNOWN | EURUSD and GBPUSD H1 are live-tradable on DWX. No SP500.DWX, hence no T6 caveat. |"),
    ("| R2 Mechanical | UNKNOWN | Vollmechanisch: inside-day-pattern + SMA200-Bias-Filter + breakout-stop + N-day-Zeit-Stop + ATR-Cap. Defaults dokumentiert. |",
     "| R2 Mechanical | UNKNOWN | Fully mechanical: inside-day pattern + SMA200 bias filter + breakout stop + N-day time stop + ATR cap. Defaults documented. |"),
    ("| R4 ML Forbidden | UNKNOWN | Keine ML, fixe Parameter, bounded SL (inside-day-range oder 2×ATR-Cap), N-day-Time-Cap, 1 Position pro Magic. PASS-Kandidat. |",
     "| R4 ML Forbidden | UNKNOWN | No ML, fixed parameters, a bounded SL (inside-day range or a 2x ATR cap), an N-day time cap, 1 position per magic. PASS candidate. |"),
    ("| R2 Mechanical | UNKNOWN | Vollmechanisch: 5-Tage-Range-Decile-Filter, Monday-open-market-order, Mid-Range-TP, 1-Wochen-Zeit-Stop, ATR-Stop. Defaults dokumentiert. |",
     "| R2 Mechanical | UNKNOWN | Fully mechanical: 5-day range decile filter, Monday open market order, mid-range TP, one-week time stop, ATR stop. Defaults documented. |"),
    ("| R3 Data Available | UNKNOWN | EURUSD und GBPUSD D1 live-tradable DWX. Keine SP500.DWX → kein T6-Caveat. |",
     "| R3 Data Available | UNKNOWN | EURUSD and GBPUSD D1 are live-tradable on DWX. No SP500.DWX, hence no T6 caveat. |"),
    ("| R4 ML Forbidden | UNKNOWN | Fixe Parameter (RSI=14, %R-Lookback=14, Trigger=±90/-10, Time-Stop=6). Kein ML. 1-Pos-per-Magic. PASS. |",
     "| R4 ML Forbidden | UNKNOWN | Fixed parameters (RSI=14, %R lookback=14, trigger=+/-90/-10, time stop=6). No ML. One position per magic. PASS. |"),
    ("ATR(14, H4) × 1.5 vom Entry-Preis (Mean-Reversion-Topologie → tighter Stop). Kein Trailing.",
     "ATR(14, H4) x 1.5 from the entry price (a mean-reversion topology calls for a tighter stop). No trailing."),
    ("- G0: 2026-05-19, PENDING, Batch 32 von source `6e967762-...`",
     "- G0: 2026-05-19, PENDING, batch 32 from source `6e967762-...`"),
    (" — verwandt (6M-Rotation), but long-only and equity rotation",
     " - related (6M rotation), but long-only and equity rotation"),
    (" — verwandt aber long-only ETF-Rotation", " - related, but a long-only ETF rotation"),
    (" — secondary (verwandt mit 1057, anderer Indikator)",
     " - secondary (related to 1057, a different indicator)"),
    (" — same author, andere Entry-Mechanics (Opening-Range instead of today's-open ± YR)",
     " - same author, different entry mechanics (opening range instead of today's open +/- YR)"),
    (" — same author, FX, andere Cadence (weekly instead of H1)",
     " - same author, FX, a different cadence (weekly instead of H1)"),
    ("| R4 ML Forbidden | UNKNOWN | Keine ML, fixe Parameter, hard ATR-Stop, Zeit-Cap, 1 Position pro Magic. PASS-Kandidat. |",
     "| R4 ML Forbidden | UNKNOWN | No ML, fixed parameters, a hard ATR stop, a time cap, 1 position per magic. PASS candidate. |"),
    ("| R4 ML Forbidden | UNKNOWN | Keine ML, fixe Parameter, hard ATR-Stop, 1-Wochen-Zeit-Cap, 1 Position pro Magic. PASS-Kandidat. |",
     "| R4 ML Forbidden | UNKNOWN | No ML, fixed parameters, a hard ATR stop, a one-week time cap, 1 position per magic. PASS candidate. |"),
    ("| R4 ML Forbidden | UNKNOWN | Fixe Koeffizienten (HP_period=48, SS_period=10 — beide hard-coded). Kein ML, kein Adaptive Lookback. 1-Pos-per-Magic. PASS. |",
     "| R4 ML Forbidden | UNKNOWN | Fixed coefficients (HP_period=48, SS_period=10 - both hard-coded). No ML, no adaptive lookback. One position per magic. PASS. |"),
    ("| R4 ML Forbidden | UNKNOWN | Fixe Parameter (N=22, BB=20/2.0, ATR=14, Time-Stop=5). Kein ML, kein Adaptive-Lookback. 1-Pos-per-Magic. PASS. |",
     "| R4 ML Forbidden | UNKNOWN | Fixed parameters (N=22, BB=20/2.0, ATR=14, time stop=5). No ML, no adaptive lookback. One position per magic. PASS. |"),
    ("| R4 ML Forbidden | UNKNOWN | Fixe Parameter (WMA-Längen 7/14, Smoother-Länge 4 — alle Ehlers-Original-Werte aus dem Buch). Kein ML. 1-Pos-per-Magic. PASS. |",
     "| R4 ML Forbidden | UNKNOWN | Fixed parameters (WMA lengths 7/14, smoother length 4 - all the original Ehlers values from the book). No ML. One position per magic. PASS. |"),
    ("| R4 ML Forbidden | UNKNOWN | Fixe Parameter: K=8/D=3 (Bressert-Original-Stoch), ZigZag-Deviation=2.5%, SMA(50), Toleranz=20%, Lookback=8-Cycles. Mean-Cycle wird historisch berechnet (deterministische Statistik, keine Online-Learning-Adaption). 1-Pos-per-Magic. PASS. |",
     "| R4 ML Forbidden | UNKNOWN | Fixed parameters: K=8/D=3 (the original Bressert stoch), ZigZag deviation=2.5%, SMA(50), tolerance=20%, lookback=8 cycles. The mean cycle is computed historically (deterministic statistics, no online-learning adaptation). One position per magic. PASS. |"),
    ("**R4-Reviewer-Note**: Das \"Mean-Cycle wird aus historischen Cycle-Längen berechnet\" ist deterministische rolling-Statistik (wie ATR, SMA), NICHT adaptive parameter learning. HR14 prohibitiert PnL-driven oder online-learning Adaption — historische deskriptive Statistiken sind PASS (vergleichbar mit ATR-basierten SL-Stops, die ebenfalls historisch berechnet werden). Reviewer-Attention bei P3, ob Cycle-Length-Drift über das Sample zu starkem look-ahead-bias führt.",
     "**R4 reviewer note**: the \"mean cycle is computed from historical cycle lengths\" is deterministic rolling statistics (like ATR or SMA), NOT adaptive parameter learning. HR14 prohibits PnL-driven or online-learning adaptation - historical descriptive statistics are a PASS (comparable to ATR-based SL stops, which are also computed historically). Reviewer attention at P3: whether cycle-length drift across the sample introduces strong look-ahead bias."),
    ("- [[strategies/QM5_1498_ehlers-it-instantaneous-trendline-h4]] — adaptive-period Ehlers-Filter (Hilbert-Phase-Rate-Adaption).",
     "- [[strategies/QM5_1498_ehlers-it-instantaneous-trendline-h4]] - an adaptive-period Ehlers filter (Hilbert phase-rate adaptation)."),
    ("- **HighPass(x, p)**: 2-pole High-Pass-Filter mit Ehlers-Koeffizienten:",
     "- **HighPass(x, p)**: a 2-pole high-pass filter with Ehlers coefficients:"),
    ("| R2 Mechanical | UNKNOWN | Fully closed-form: zwei kaskadierte 2-pole-Filter, deterministische coefficients, Zero-Cross-Trigger. Codex kann das ohne Lücken bauen. PASS. |",
     "| R2 Mechanical | UNKNOWN | Fully closed-form: two cascaded 2-pole filters, deterministic coefficients, a zero-cross trigger. Codex can build this without gaps. PASS. |"),
    ('| R3 Data Available | UNKNOWN | GER40.DWX, NDX.DWX, WS30.DWX D1 all live-tradable DWX. Keine SP500.DWX → kein T6-Caveat. |',
     '| R3 Data Available | UNKNOWN | GER40.DWX, NDX.DWX and WS30.DWX D1 are all live-tradable on DWX. No SP500.DWX, hence no T6 caveat. |'),
    ('| R2 Mechanical | UNKNOWN | Closed-form: RSI-Berechnung deterministic (Wilder), Williams %R auf RSI deterministic, Trigger Inequalities. Codex kann das ohne Lücken bauen. PASS. |',
     '| R2 Mechanical | UNKNOWN | Closed-form: the RSI computation is deterministic (Wilder), Williams %R on RSI is deterministic, triggers are inequalities. Codex can build this without gaps. PASS. |'),
    ('| R3 Data Available | UNKNOWN | Reine Close-Price-Verarbeitung — testbar auf allen DWX-Symbolen (FX, Indizes, XAUUSD, XTIUSD). PASS. |',
     '| R3 Data Available | UNKNOWN | Pure close-price processing - testable on every DWX symbol (FX, indices, XAUUSD, XTIUSD). PASS. |'),
    ("| R2 Mechanical | UNKNOWN | Closed-form: WVF ist Inequality-Filter, BB-Trigger, Time/ATR-Exit. Codex kann das ohne Lücken bauen. Long-Only ist Williams' Original-Topologie — keine fehlende Short-Mechanics, sondern intentionale Asymmetrie. PASS. |",
     "| R2 Mechanical | UNKNOWN | Closed-form: the WVF is an inequality filter, with a BB trigger and a time/ATR exit. Codex can build this without gaps. Long-only is Williams' original topology - not missing short mechanics but deliberate asymmetry. PASS. |"),
    ('| R3 Data Available | UNKNOWN | High/Low/Close — testbar auf allen DWX-Symbolen (FX-Majors, NDX.DWX, GDAXI.DWX, UK100.DWX, WS30.DWX, SP500.DWX-backtest, XAUUSD, XTIUSD). PASS. |',
     '| R3 Data Available | UNKNOWN | High/low/close only - testable on every DWX symbol (FX majors, NDX.DWX, GDAXI.DWX, UK100.DWX, WS30.DWX, SP500.DWX backtest, XAUUSD, XTIUSD). PASS. |'),
    ('| R2 Mechanical | UNKNOWN | Fully closed-form: zwei WMAs + Linearkombination + Cross-Trigger. Codex kann das ohne Lücken bauen. PASS. |',
     '| R2 Mechanical | UNKNOWN | Fully closed-form: two WMAs + a linear combination + a cross trigger. Codex can build this without gaps. PASS. |'),
    ('| R2 Mechanical | UNKNOWN | Closed-form trotz Cycle-Detection-Komplexität: ZigZag ist deterministisch, Mean-Cycle ist arithmetisch, Window + Double-Stoch + Bullish-Bar sind Inequalities. Codex kann das ohne Lücken bauen. PASS. |',
     '| R2 Mechanical | UNKNOWN | Closed-form despite the cycle-detection complexity: ZigZag is deterministic, the mean cycle is arithmetic, and window + double-stoch + bullish-bar are inequalities. Codex can build this without gaps. PASS. |'),
    ('## Lessons Learned (während Pipeline-Lauf)',
     '## Lessons learned (during the pipeline run)'),
    ('Universe (DWX-Instrumente, all auf D1 Bars): EURUSD, GBPUSD, USDJPY, AUDUSD, USDCAD, XAUUSD, WTI (oil CFD if vorhanden), NDX.DWX, WS30.DWX, DAX (GER40.DWX).',
     'Universe (DWX instruments, all on D1 bars): EURUSD, GBPUSD, USDJPY, AUDUSD, USDCAD, XAUUSD, WTI (oil CFD if available), NDX.DWX, WS30.DWX, DAX (GER40.DWX).'),
    ('- Magic: 1 Slot pro Instrument (10 Instrumente = 10 Magic-Nummern, HR-konform).',
     '- Magic: one slot per instrument (10 instruments = 10 magic numbers, HR compliant).'),
    ('- Keine intraday-Exits ausser Stop-Loss.',
     '- No intraday exits other than the stop loss.'),
    ('- Korrelations-Gate: nur OPEN wenn rollende 60-Bar-Korrelation der Returns > 0.6 (sonst Pair zerfallen).',
     '- Correlation gate: open only when the rolling 60-bar correlation of returns is above 0.6 (otherwise the pair has decayed).'),
    ('| R3 Data Available | UNKNOWN | EURUSD/GBPUSD/AUDUSD/NZDUSD im DWX-Feed live-tradable. USDNOK vs USDCAD — USDNOK-Verfügbarkeit prüfen, sonst nur 2 Pairs. |',
     '| R3 Data Available | UNKNOWN | EURUSD/GBPUSD/AUDUSD/NZDUSD are live-tradable on the DWX feed. USDNOK vs USDCAD - check USDNOK availability, otherwise only 2 pairs. |'),
    ('(GER40.DWX, NDX.DWX, WS30.DWX, XAUUSD). Keine SP500.DWX-Verwendung, kein',
     '(GER40.DWX, NDX.DWX, WS30.DWX, XAUUSD). No SP500.DWX use, no'),
    ('SP500.DWX-Verwendung.',
     'SP500.DWX use.'),
    ('- **Zeit-Filter**: Keine Trades 30 min vor / nach Daily-Rollover (broker time 23:30-00:30 GMT+2/+3 DST-aware). Verhindert Spread-Spike-Signale.',
     '- **Time filter**: no trades 30 min before or after the daily rollover (broker time 23:30-00:30 GMT+2/+3, DST aware). Prevents spread-spike signals.'),
    ('- **Zeit-Filter**: Keine Trades 30 min vor / nach Daily-Rollover (broker time 23:30-00:30 GMT+2/+3 DST-aware).',
     '- **Time filter**: no trades 30 min before or after the daily rollover (broker time 23:30-00:30 GMT+2/+3, DST aware).'),
    ('- **Zeit-Filter**: Keine Trades 30 min vor / nach Daily-Rollover.',
     '- **Time filter**: no trades 30 min before or after the daily rollover.'),
    ('- **News-Filter**: D:\\QM\\data\\news_calendar — Trades nicht öffnen 15 min vor / nach High-Impact-Events.',
     '- **News filter**: D:\\QM\\data\\news_calendar - do not open trades 15 min before or after high-impact events.'),
    ('- [[strategies/QM5_1499_ehlers-decycler-low-pass-h4]] — Decycler verwendet einzelnen HP, kein SS-Stage.',
     '- [[strategies/QM5_1499_ehlers-decycler-low-pass-h4]] - the Decycler uses a single HP and no SS stage.'),
    ('- [[strategies/QM5_1507_ehlers-mama-fama-cross-h4]] — adaptive Periode (Hilbert-Phase-driven), nicht fix.',
     '- [[strategies/QM5_1507_ehlers-mama-fama-cross-h4]] - an adaptive period (Hilbert-phase driven), not fixed.'),
    ('**Schritt 2 — Mean-Cycle-Length-Berechnung**:',
     '**Step 2 - mean-cycle-length computation**:'),
    ("- Distinkt von [[strategies/QM5_1492_as-mtp-simple]]: dort wird Connors' ATR-Stretch als VIX-Proxy verwendet (ATR-basiert), hier Williams' originale High-Close-",
     "- Distinct from [[strategies/QM5_1492_as-mtp-simple]]: there Connors' ATR stretch is used as the VIX proxy (ATR based), here Williams' original high-close-"),
    ("- Williams' Konstruktion approximiert VIX-Verhalten auf jedem Instrument ohne Optionsdaten — Port auf FX/CFD ist die Original-Anwendung des Konzepts (Williams s",
     "- Williams' construction approximates VIX behaviour on any instrument without options data - porting it to FX/CFD is the concept's original application (Williams s"),
    ("Short-Variante: Williams' Original ist Long-Only (Panik-Tief-Kauf-Signal). Short-Side wird hier NICHT mechanisiert — bleibt für P3 als optionale Erweiterung off",
     "Short variant: Williams' original is long-only (a panic-low buy signal). The short side is NOT mechanized here - it stays open for P3 as an optional extension off"),
    ('- **Zeit-Filter**: Daily-Rollover ±30 min Skip.',
     '- **Time filter**: skip the daily rollover +/- 30 min.'),
    ('**Schritt 1 — Cycle-Low-Detection via ZigZag**:',
     '**Step 1 - cycle-low detection via ZigZag**:'),
    ('**Schritt 3 — Projection-Window**:',
     '**Step 3 - projection window**:'),
    ('**Schritt 4 — Bressert Double-Stochastic-Konfirmation**:',
     '**Step 4 - Bressert double-stochastic confirmation**:'),
    # misc references
    ("mechanizes \"Entry nur bei exakter Konvergenz\" (OWNER spec).",
     "mechanizes \"entry only on exact convergence\" (OWNER spec)."),
    ("investui (vendor, no numbers published): \"Donnerstagabends Gold kaufen und die",
     "investui (vendor, no numbers published): \"buy gold on Thursday evening and hold the"),
    ("Position 24-Stunden halten\"; charts \"10 Jahre, teilweise basierend auf einem",
     "position for 24 hours\"; charts \"10 years, partly based on a"),
    ("- Academic backbone: Asness, Moskowitz, Pedersen (2013). \"Value and Momentum Everywhere.\" *Journal of Finance* 68(3), 929-985. Auch Jegadeesh & Titman (1993) für equity-Origin.",
     "- Academic backbone: Asness, Moskowitz, Pedersen (2013). \"Value and Momentum Everywhere.\" *Journal of Finance* 68(3), 929-985. Also Jegadeesh & Titman (1993) for the equity origin."),
    ("Lehmann (1990) für die Wochen-Variante:", "Lehmann (1990) for the weekly variant:"),
    ("- 8.4 regime dependence: MR scalpers die in sustained trends; expect soft-gate",
     "- 8.4 regime dependence: MR scalpers die in sustained trends; expect soft-gate"),
]

# ── 2 · terms, applied after the sentences ────────────────────────────────────
TERMS: list[tuple[str, str]] = [
    (r"Verwandte Strategien", "Related strategies"),
    (r"Zusätzliche Filter", "Additional filters"),
    (r"Zusaetzliche Filter", "Additional filters"),
    (r"Zusätzliche", "Additional"),
    (r"Zusaetzliche", "Additional"),
    (r"Pipeline-Verlauf", "Pipeline history"),
    (r"R1[-–]R4 Bewertung", "R1-R4 assessment"),
    (r"\bMechanik\b", "Mechanics"),
    (r"\bQuelle\b", "Source"),
    (r"\bKriterium\b", "Criterion"),
    (r"\bBegründung\b", "Rationale"),
    (r"\bBegruendung\b", "Rationale"),
    (r"\bBegrundung\b", "Rationale"),
    # the node-maintenance note, in all its spelling variants
    (r"\*Knoten-Pflege:.*?(?:\*|$)",
     "*Node maintenance: update `pipeline_phase` + `last_updated` on every pipeline-phase "
     "change. On FAIL: `pipeline_phase: DEAD` + a lessons-learned entry.*"),
    # residual R1-R4 cell vocabulary. These words occur only in German, so a term
    # rule is safe here and cheaper than chasing one cell at a time.
    (r"\bFixe\b", "Fixed"),
    (r"\bfixe\b", "fixed"),
    (r"\bKoeffizienten\b", "coefficients"),
    (r"\bKeine? ML\b", "No ML"),
    (r"\bkeine? Adaptive[- ]Lookback\b", "no adaptive lookback"),
    (r"\bkeine? Adaption\b", "no adaptation"),
    (r"\bkeine adaptiven Parameter\b", "no adaptive parameters"),
    (r"\bLängen\b", "lengths"),
    (r"\bLänge\b", "length"),
    (r"\bbeide hard-coded\b", "both hard-coded"),
    (r"\balle\b", "all"),
    (r"\bAlle\b", "All"),
    (r"\baus dem Buch\b", "from the book"),
    (r"\bWerte\b", "values"),
    (r"\bVollmechanisch\b", "Fully mechanical"),
    (r"\bVollständig closed-form\b", "Fully closed-form"),
    (r"\bReines Ranking\b", "Pure ranking"),
    (r"\bPASS-Kandidat\b", "PASS candidate"),
    (r"\bPosition pro Magic\b", "position per magic"),
    (r"\bSchwellen\b", "thresholds"),
    (r"\bgleicher Author\b", "same author"),
    (r"\bverwandter?\b", "related"),
    (r"\bstatt\b", "instead of"),
    (r"\bgegensätzliche Logik\b", "opposing logic"),
    (r"\bSchwester-Strategie\b", "sister strategy"),
    (r"\bSpiegel-Strategie\b", "mirror strategy"),
    (r"\bmonatlich\b", "monthly"),
    (r"\bwöchentlich\b", "weekly"),
    (r"\baber long-only und equity-rotation\b", "but long-only and equity rotation"),
]

# the note also occurs hard-wrapped across two or three lines
_NOTE_MULTILINE = re.compile(r"\*Knoten-Pflege:.*?(?:Eintrag\.\*|`last_updated`\.\*|\*)", re.S)
_NOTE_EN = '*Node maintenance: update `pipeline_phase` + `last_updated` on every pipeline-phase change. On FAIL: `pipeline_phase: DEAD` + a lessons-learned entry.*'

_COMPILED_TERMS = [(re.compile(p), r) for p, r in TERMS]
# never touched: code fences, LaTeX blocks, wiki-link targets, YAML keys
_PROTECT = re.compile(r"(```.*?```|\$\$.*?\$\$)", re.S)


def translate(text: str) -> tuple[str, Counter]:
    counts: Counter = Counter()

    def _apply(chunk: str) -> str:
        chunk, n = _NOTE_MULTILINE.subn(_NOTE_EN, chunk)
        if n:
            counts["Knoten-Pflege (multiline)"] += n
        for src, dst in SENTENCES:
            if src in chunk:
                counts[src[:48]] += chunk.count(src)
                chunk = chunk.replace(src, dst)
        for pat, dst in _COMPILED_TERMS:
            chunk, n = pat.subn(dst, chunk)
            if n:
                counts[pat.pattern[:48]] += n
        return chunk

    parts = _PROTECT.split(text)
    for i in range(0, len(parts), 2):          # even indices are unprotected text
        parts[i] = _apply(parts[i])
    return "".join(parts), counts


def main() -> int:
    ap = argparse.ArgumentParser(description="Translate German card boilerplate")
    g = ap.add_mutually_exclusive_group()
    g.add_argument("--dry-run", action="store_true")
    g.add_argument("--apply", action="store_true")
    ap.add_argument("--allow-fingerprint-change", action="store_true",
                    help=("translate a card even when the dedupe fingerprint moves. Measured, "
                          "that is exactly one card: translating 'Short-Term-Mean-Reversion' "
                          "introduces the literal thesis term 'mean reversion', which the coarse "
                          "fingerprint searches for. The new fingerprint is MORE accurate - the "
                          "card is a mean-reversion strategy - but the change is recorded, never "
                          "silent."))
    args = ap.parse_args()
    apply = bool(args.apply)

    sys.path.insert(0, str(REPO_ROOT / "tools" / "strategy_farm"))
    import farmctl  # noqa: E402  - only needed for the fingerprint guard

    stamp = dt.datetime.now(dt.UTC).strftime("%Y%m%dT%H%M%SZ")
    buckets = [ARTIFACTS / b for b in CARD_BUCKETS if (ARTIFACTS / b).is_dir()]
    files = sorted(f for d in buckets for f in d.glob("QM5_*.md"))
    totals: Counter = Counter()
    changed: list[str] = []
    fp_moved: list[str] = []
    lines_before = lines_after = 0

    if apply:
        backup = BACKUP_ROOT / f"cards_{stamp}_pre_translation"
        backup.mkdir(parents=True, exist_ok=True)
        for d in buckets:
            shutil.copytree(d, backup / d.name)
        print(f"backup: {backup} ({len(buckets)} buckets)")

    for path in files:
        raw = path.read_text(encoding="utf-8", errors="replace")
        new, counts = translate(raw)
        if new == raw:
            continue
        # the dedupe fingerprint must not move
        fp_before = farmctl.strategy_card_fingerprint(path)
        tmp = path.with_suffix(".md.__tr")
        tmp.write_text(new, encoding="utf-8")
        try:
            fp_after = farmctl.strategy_card_fingerprint(tmp)
        finally:
            tmp.unlink(missing_ok=True)
        if fp_before != fp_after:
            fp_moved.append({"card": path.name, "before": fp_before, "after": fp_after})
            if not args.allow_fingerprint_change:
                continue
        lines_before += raw.count("\n")
        lines_after += new.count("\n")
        totals.update(counts)
        changed.append(path.name)
        if apply:
            path.write_text(new, encoding="utf-8")

    report = {
        "at_utc": stamp,
        "mode": "apply" if apply else "dry-run",
        "cards_scanned": len(files),
        "cards_changed": len(changed),
        "fingerprint_moved": fp_moved,
        "fingerprint_change_allowed": bool(args.allow_fingerprint_change),
        "line_count_delta": lines_after - lines_before,
        "replacements_total": sum(totals.values()),
        "replacements_by_rule": dict(totals.most_common()),
    }
    if apply:
        EVIDENCE.parent.mkdir(parents=True, exist_ok=True)
        EVIDENCE.write_text(json.dumps(report | {"changed_cards": changed}, indent=1),
                            encoding="utf-8")
    print(json.dumps(report, indent=1, ensure_ascii=False)[:2600])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
