# QM5_20007_intraday-config-engine — Strategy Spec

**EA ID:** QM5_20007
**Slug:** `intraday-config-engine`
**Source:** `intraday-momentum-orb-canonical-2026-06-29` (see `artifacts/cards_approved/QM5_20007_intraday-config-engine.md`)
**Author of this spec:** Development
**Last revised:** 2026-07-23

---

## 1. Strategy Logic

One parameterised intraday EA with three selectable signal lanes and three deterministic conditioning gates. On each closed M15 (or M5) bar within the session window, the EA checks: (1) whether the volatility regime is expanding (ATR_short/ATR_long ratio gate), (2) whether the session is within the configurable productive hours, and (3) which lane fires. LANE_MOMENTUM_BAND enters long (short) when the closed-bar price breaks above (below) the session open by more than 1×ATR, then trails the stop to the session VWAP; LANE_ORB builds the high/low of the first `orb_minutes` and enters on a close beyond the range plus an ATR buffer, with a fixed RR target; LANE_GOLD_BREAKOUT enters on a close beyond the daily open ± (gb_atr_mult × D1 ATR). All positions are force-closed at `eod_flat_hour` (EOD-flat, no overnight).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `intraday_lane` | 0 (MOMENTUM_BAND) | 0/1/2 | Signal lane: 0=momentum-band, 1=ORB, 2=gold-breakout |
| `session_start_hour` | 10 | 0-23 | Broker hour at which the session opens (entries allowed) |
| `session_end_hour` | 17 | 0-23 | Broker hour at which new entries stop |
| `eod_flat_hour` | 17 | 0-23 | Broker hour at which all positions are force-closed |
| `vol_short_period` | 8 | 3-20 | Short ATR period for vol-regime numerator |
| `vol_long_period` | 40 | 20-100 | Long ATR period for vol-regime denominator |
| `vol_expand_ratio` | 1.0 | 0-2.0 | ATR_short/ATR_long threshold; 0 = gate off |
| `mb_atr_period` | 14 | 5-30 | ATR period for momentum-band noise width |
| `mb_band_mult` | 1.0 | 0.5-3.0 | Band = mult × ATR; entry when close breaks this distance from session open |
| `mb_vwap_trail` | true | bool | Trail SL toward session VWAP when MOMENTUM_BAND lane active |
| `orb_minutes` | 30 | 5-60 | Opening-range window in minutes |
| `orb_buf_mult` | 0.25 | 0.1-1.0 | Entry buffer beyond OR extreme = mult × ATR |
| `orb_tp_rr` | 2.0 | 1.0-5.0 | TP at rr × initial R; 0 = no fixed TP |
| `gb_d1_atr_period` | 14 | 5-30 | D1 ATR period for gold-breakout band |
| `gb_atr_mult` | 1.5 | 0.5-3.0 | Band = daily_open ± mult × ATR(D1) |
| `stop_atr_mult` | 1.5 | 0.5-3.0 | Initial SL distance = mult × ATR(mb_atr_period) |
| `cost_mult` | 3.0 | >=0 | Require the expected ATR move to exceed positive modeled spread by this multiple |

---

## 3. Symbol Universe

**Designed for:**
- `GDAXI.DWX` — German 40 index; DAX cash session 10:00-17:00 broker; low spread vs 15-min move; lead instrument
- `NDX.DWX` — Nasdaq 100; US cash session 16:00-22:00 broker; high liquidity, low cost; live-tradable
- `SP500.DWX` — S&P 500 custom symbol (backtest-only; broker does not route live orders); backtest diversification
- `XAUUSD.DWX` — Gold spot; 24h market; GOLD_BREAKOUT lane designed for this instrument; overnight drift excluded by EOD-flat

**Explicitly NOT for:**
- Forex pairs — commission 10-20× index; momentum-band and ORB not cost-viable on FX intraday
- Oil/Natural Gas — spread 10-25× index; excluded per card cost-feasibility analysis
- `UK100.DWX` — Not included in initial book; may be added in P3 expansion if grid shows portfolio benefit

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` (primary); `M5` sweep in P3 grid |
| Multi-timeframe refs | `PERIOD_D1` for GOLD_BREAKOUT daily open + D1 ATR; none for MOMENTUM_BAND/ORB |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` latched once; AdvanceState_OnNewBar called on true |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~250 (1 per productive day; some days suppressed by vol-regime gate) |
| Typical hold time | 15-120 minutes (1-8 bars on M15; EOD-flat hard ceiling) |
| Expected drawdown profile | ~10% (card estimate; single-lane net-of-cost target) |
| Regime preference | Volatility-expansion / intraday momentum / breakout |
| Win rate target (qualitative) | medium (momentum + breakout style; ~45-55%) |

---

## 6. Source Citation

**Source ID:** `intraday-momentum-orb-canonical-2026-06-29`
**Source type:** peer-reviewed paper + reputable practitioner sources
**Pointer:** `artifacts/cards_approved/QM5_20007_intraday-config-engine.md`
**Sources:** Gao-Han-Li-Zhou (JFE 2018) intraday momentum; Zarattini-Aziz-Barbon (SSRN 4824172, 2024); Zarattini-Aziz ORB (SSRN 4416622, 2023)
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_20007_intraday-config-engine.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-23 | Initial build from card | 5388420a-129e-4068-923e-dbb1f22d7886 |
