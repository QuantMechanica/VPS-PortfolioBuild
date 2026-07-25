# FTMO Trial #2 Postmortem — 2026-07-25 (account 1513845506, Round25 book)

**Verdict: RESET** (OWNER 2026-07-25 — "Es wird ein Reset! War nur ein Demo Konto!").
Second consecutive falsification of the Round25 12-leg composition by the free-trial
loop, exactly as the loop is designed to do. No fees burned.

## Numbers (source: AccountMonitor deal export, deployed 2026-07-25)

Evidence: `<FTMO data dir 81A933…>\MQL5\Files\QM\journal\live_deals_normalized.csv`
(119 deals, full history 2026-06-29 → 2026-07-24), `account_snapshot.json`.

- Final equity **$90,002.40** = **−9.9976%** — $2.40 above the $90,000 max-loss floor.
- Costs are broker-booked and included: commission Σ −$89.41 (56 deals), swap Σ −$168.61 (23 deals).
- The EA day-close snapshot chain lagged ~38h and hid 2.3pp of the drawdown until the
  monitor deploy surfaced it (decisions/2026-07-25_ftmo_account_monitor_deploy.md).

### Attribution per magic (net $, closed exits; IN-magic used where weekend-flat OUT deals carry magic 0)

| magic | EA | symbol | net $ | exits |
|---|---|---|---|---|
| 109110003 | QM5_10911 grimes-complex-pb | GER40.cash | **−3,864.50** | 4 |
| 108470001 | QM5_10847 tv-inside-gem | GBPUSD | −2,313.35 | 4 |
| 108480002 | QM5_10848 tv-mtf-ambush | XAUUSD | −2,186.88 | 6 |
| 124750003 | QM5_12475 gh-macd-cross | US100.cash | −1,445.91 | 13 |
| 106920005 | QM5_10692 tv-ls-ms | US100.cash | −1,148.08 | 2 |
| 107000003 | QM5_10700 tv-liq-break | XAUUSD | −251.56 | 1 |
| 101630000 | QM5_10163 tv-rsi-macd-long | US100.cash | +11.57 | 1 |
| 114760002 | QM5_11476 lien-k-double-bb | USDJPY | +85.80 | 17 |
| 102860036 | QM5_10286 cinar-supertrend | USOIL.cash | +529.34 | 4 |
| 104400003 | QM5_10440 mql5-ohlc-mtf | US100.cash | +585.97 | 7 |
| — | QM5_12958, QM5_12990 | — | 0 | **never traded** |

Per symbol: GER40 −3,865 // XAUUSD −2,438 // GBPUSD −2,313 // US100 −1,996 //
USDJPY +86 // USOIL +529. Total **−9,997.60**.

## Reading

Identical failure signature to trial #1 (−8.7%, 05.–17.07., postmortem 2026-07-19):
1. **Broad index/gold bleed** — a handful of low-frequency swing legs concentrate the
   loss (10911 alone −3.9k in 4 trades).
2. **No density motor** — the only high-frequency leg (11476, 17 exits) ends flat;
   12958/12990 never trade. Carry ≈ 0, so drawdown is a one-way ratchet.
3. Confirms the sealed 2026-07-22 book-engine finding: the admissible-book bottleneck
   is density/carry, not sizing; the Round25 composition cannot pass a 10%/10% regime.

**Consequence:** the next trial does NOT redeploy Round25. New book per
`FTMO_CHALLENGE_EA_TARGET_BOOK_2026-07-17.md` (V3 5-role contract) + density cohort
(QM5_2003x/2004x + 20007 grid) once it clears Q02→Q08, MC-gated by
`tools/strategy_farm/portfolio/ftmo_p1_mc.py`.
