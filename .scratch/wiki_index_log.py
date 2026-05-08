import os

wiki_base = "G:/My Drive/QuantMechanica - Company Reference/09 Strategy Wiki"

# ── _INDEX.md ──────────────────────────────────────────────────────────────
index_content = """# Strategy Wiki -- Index

> **Gepflegt durch:** Documentation-KM (jeder Wiki-Edit triggert Index-Update).
> **Format:** ein Knoten = eine Zeile mit One-line-Summary.
> **Zuletzt vollstaendig neu gebaut:** 2026-05-08 (QUA-836 Migrationslauf, 28 Cards)

Alle Backlinks gehen zu `09 Strategy Wiki/<area>/<slug>.md`.

---

## Sources

| Knoten | Summary |
|--------|---------|
| [[sources/chan-quantitative-trading-2009]] | Chan QT (2009) -- GLD/GDX stat-arb; 1 strategy extracted |
| [[sources/chan-algorithmic-trading-2013]] | Chan AT (2013) -- 12 strategies: MR, pairs, momentum, cal-spread |
| [[sources/davey-building-algo-trading-systems]] | Davey (2014) -- 2 strategies: 3-bar baseline + ES breakout |
| [[sources/lien-day-trading-forex-market]] | Lien (2015) -- 10 FX strategies: breakout, fade, trend, channels, carry |
| [[sources/williams-long-term-secrets]] | Williams (1999) -- 3 strategies: Vol-BO, Pro-Go, Pinch-Paunch |

---

## Strategies

### APPROVED (G0-Pass; in pipeline or awaiting ea_id)

| Knoten | ea_id | Phase | Summary |
|--------|-------|-------|---------|
| [[strategies/QM5_1017_chan-pairs-stat-arb]] | 1017 | P2 | GLD/GDX stat-arb; cointegration pair MR |
| [[strategies/davey-baseline-3bar]] | TBD | G0 | Davey 3-bar baseline MR pattern on EURUSD H1 |
| [[strategies/QM5_1004_davey-es-breakout]] | 1004 | P2 | Davey ES channel breakout |
| [[strategies/QM5_1013_lien-20day-breakout]] | 1013 | P2 | Lien 20-day Donchian FX breakout |
| [[strategies/QM5_1016_lien-carry-trade]] | 1016 | P2 | Lien FX carry-direction trade |
| [[strategies/QM5_1014_lien-channels]] | 1014 | P2 | Lien narrow-channel breakout on FX |
| [[strategies/QM5_1009_lien-fade-double-zeros]] | 1009 | P2 | Lien fade double-zero levels on FX M15/H1 |
| [[strategies/QM5_1012_lien-fader]] | 1012 | P2 | Lien failed-breakout fade on FX |
| [[strategies/QM5_1011_lien-inside-day-breakout]] | 1011 | P2 | Lien inside-day breakout on FX D1 |
| [[strategies/QM5_1015_lien-perfect-order]] | 1015 | P2 | Lien moving-average perfect-order trend |
| [[strategies/QM5_1010_lien-waiting-deal]] | 1010 | P2 | Lien waiting-deal: Asia session range -> London entry |
| [[strategies/williams-pinch-paunch]] | TBD | G0 | Williams Pinch-Paunch volatility squeeze/expand |
| [[strategies/williams-pro-go]] | TBD | G0 | Williams Pro-Go momentum entry |

### DRAFT (awaiting G0 CEO review)

| Knoten | src_id | Summary |
|--------|--------|---------|
| [[strategies/chan-at-bb-pair]] | SRC05_S01 | Chan AT: Bollinger-band pair spread MR (GLD-USO daily) |
| [[strategies/chan-at-buy-on-gap]] | SRC05_S03 | Chan AT: Cross-sectional gap-fade on SPX stocks (V5-arch-challenged) |
| [[strategies/chan-at-cal-spread]] | SRC05_S06 | Chan AT: Calendar spread MR via roll-return Z-score (CL futures) |
| [[strategies/chan-at-fstx-gap-mom]] | SRC05_S12 | Chan AT: Futures opening-gap momentum (go-with) |
| [[strategies/chan-at-fx-coint-pair]] | SRC05_S05 | Chan AT: FX cointegration pair MR |
| [[strategies/chan-at-kf-pair]] | SRC05_S02 | Chan AT: Kalman-filter dynamic-hedge pair MR |
| [[strategies/chan-at-roll-arb-etf]] | SRC05_S08 | Chan AT: ETF roll-return arbitrage |
| [[strategies/chan-at-spy-arb]] | SRC05_S04 | Chan AT: SPY/futures cointegration arb |
| [[strategies/chan-at-ts-mom-fut]] | SRC05_S07 | Chan AT: Time-series futures momentum (12-month) |
| [[strategies/chan-at-vx-es-roll-mom]] | SRC05_S09 | Chan AT: VX/ES roll-return momentum |
| [[strategies/chan-at-xs-mom-fut]] | SRC05_S10 | Chan AT: Cross-sectional futures momentum (V5-arch-challenged) |
| [[strategies/chan-at-xs-mom-stock]] | SRC05_S11 | Chan AT: Cross-sectional stock momentum (V5-arch-challenged) |
| [[strategies/lien-dbb-pick-tops]] | SRC04_S02a | Lien: Double Bollinger Band fade outer zone |
| [[strategies/lien-dbb-trend-join]] | SRC04_S02b | Lien: Double Bollinger Band trend-join middle zone |
| [[strategies/williams-vol-bo]] | SRC03_S01 | Williams: Volatility expansion breakout |

---

## Concepts

| Knoten | Summary |
|--------|---------|
| [[concepts/mean-reversion]] | Price reverts to statistical mean; Z-score / Bollinger / Kalman signals |
| [[concepts/breakout]] | Price breaks through support/resistance; continuation entry |
| [[concepts/pair-trade]] | Long one leg / short correlated leg; spread mean-reversion |
| [[concepts/trend-following]] | Enter in direction of identified trend or momentum signal |
| [[concepts/range-trade]] | Buy support, sell resistance within bounded oscillation zone |
| [[concepts/news-trade]] | Enter on anticipated or actual news event volatility (no strategies in pipeline yet) |
| [[concepts/volatility-filter]] | Volatility expansion/compression as primary signal or regime filter |

---

*Pflege: Bei jedem Knoten-Add/Remove/Rename muss diese Datei eine Zeile bekommen/verlieren. Inkonsistenz = Lint-Fail.*
"""

index_path = os.path.join(wiki_base, "_INDEX.md")
with open(index_path, "w", encoding="utf-8") as f:
    f.write(index_content)
print("INDEX written:", index_path)

# ── _LOG.md -- append ──────────────────────────────────────────────────────
log_path = os.path.join(wiki_base, "_LOG.md")
with open(log_path, "r", encoding="utf-8") as f:
    existing_log = f.read()

log_entry = """
## 2026-05-08

- `INIT` -- Strategy Wiki initialisiert nach Karpathy LLM-Wiki-Schema. Schema-Datei + Templates + Index angelegt. Migration aus `strategy-seeds/cards/` ausstehend (Doc-KM-Aufgabe).

- `MIGRATE` -- QUA-836: Bulk-Migration 28 Strategy Cards aus `C:/QM/repo/strategy-seeds/cards/` in `09 Strategy Wiki/strategies/` abgeschlossen.
  - **28 Strategy-Knoten** angelegt unter `strategies/` (10 APPROVED mit ea_id; 3 APPROVED TBD; 15 DRAFT)
  - **7 Concept-Knoten** angelegt: mean-reversion, breakout, pair-trade, trend-following, range-trade, news-trade, volatility-filter
  - **5 Source-Knoten** angelegt: chan-quantitative-trading-2009, chan-algorithmic-trading-2013, davey-building-algo-trading-systems, lien-day-trading-forex-market, williams-long-term-secrets
  - `_INDEX.md` vollstaendig neu gebaut mit One-Line-Summary aller 40 Knoten
  - Ausgangsbasis: `strategy-seeds/cards/*.md` + Card-YAML-Header (pipeline_phase, g0_status, R1-R4 wie im Original vorhanden)
  - Naechster Schritt: Lint-Skript (`lint_strategy_wiki.py`, DevOps-Issue parallel) validiert Cross-Refs
"""

# Avoid adding duplicate entry
if "MIGRATE" not in existing_log:
    new_log = log_entry
    with open(log_path, "w", encoding="utf-8") as f:
        f.write(new_log.strip() + "\n")
    print("LOG written:", log_path)
else:
    print("LOG: MIGRATE entry already present, skip")
