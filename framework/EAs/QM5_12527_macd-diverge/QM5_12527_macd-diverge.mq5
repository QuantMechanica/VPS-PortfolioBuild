#property strict
#property version   "5.0"
#property description "QM5_12527 macd-diverge — MACD regular divergence reversal (counter-trend, D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_12527 macd-diverge
// -----------------------------------------------------------------------------
// Source: Backtest Rookies/Rookie1, "Backtrader MACD Indicator Review", 2017-10-03.
//   https://backtest-rookies.com/2017/10/03/backtrader-macd-indicator-review/
//   Card: artifacts/cards_approved/QM5_12527_macd-diverge.md (g0_status: APPROVED).
//
// Mechanics (counter-trend reversal, closed-bar reads only, D1):
//   Divergence STATE (regular MACD divergence from the last two swing extremes):
//     Bullish  : price LOWER low  at T2 vs T1  AND  MACD HIGHER low  at T2 vs T1.
//     Bearish  : price HIGHER high at T2 vs T1  AND  MACD LOWER high at T2 vs T1.
//     Swings   : a candidate low/high is the extreme over `swing_period` bars on
//                EACH side (a local pivot), scanned over a bounded lookback window.
//     The MACD value compared is QM_MACD_Main (MACD line) at the swing bar.
//     A divergence STATE latches once detected and is held until the opposite
//     divergence appears (which both flips the state AND is the exit trigger for
//     an open position) or until it is consumed by an entry.
//   Trigger EVENT (single, one per bar — avoids the two-cross-same-bar trap):
//     The divergence completing is the SETUP. The CONFIRMATION CANDLE is the
//     single trigger EVENT:
//       Long  : bullish divergence active AND the last closed bar closes UP
//               (close[1] > open[1]) — momentum confirms the reversal.
//       Short : bearish divergence active AND the last closed bar closes DOWN
//               (close[1] < open[1]).
//     If BOTH bullish and bearish divergence are detected on the same bar while
//     flat, do NOT enter (card rule).
//   Exit  : opposite divergence detected closes the open position
//           (Strategy_ExitSignal) — this is the card's primary close. The ATR
//           stop is the catastrophic protective bracket; a wide RR take-profit is
//           a safety backstop only.
//   Stop  : protective 3.0 * ATR(14) catastrophic stop (card V5 default).
//   Take  : wide RR safety backstop (tp_rr default 4R); primary close = opposite
//           divergence, so the TP rarely binds.
//   Spread guard: blocks only a genuinely wide spread (fail-open on .DWX zero
//           modeled spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
//
// Symbols: AUDUSD.DWX, GBPUSD.DWX, EURUSD.DWX, NZDUSD.DWX — all present in
//   dwx_symbol_matrix.csv (forex majors), no porting required.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12527;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_macd_fast         = 12;     // MACD fast EMA (card baseline)
input int    strategy_macd_slow         = 26;     // MACD slow EMA (card baseline)
input int    strategy_macd_signal       = 9;      // MACD signal EMA (card baseline)
input int    strategy_swing_period      = 7;      // bars EACH side for a local pivot (card baseline)
input int    strategy_swing_lookback    = 60;     // bars to scan for the last two swings
input int    strategy_atr_period        = 14;     // ATR period for the protective stop
input double strategy_sl_atr_mult       = 3.0;    // protective catastrophic stop = mult * ATR
input double strategy_tp_rr             = 4.0;    // safety-backstop take-profit as RR multiple
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// File-scope cached divergence state (advanced once per closed bar).
// -----------------------------------------------------------------------------
bool   g_bull_div_active = false;   // bullish (long) divergence latched
bool   g_bear_div_active = false;   // bearish (short) divergence latched
bool   g_bull_div_fresh  = false;   // bullish divergence newly detected THIS bar
bool   g_bear_div_fresh  = false;   // bearish divergence newly detected THIS bar
double g_bull_swing_low  = 0.0;     // price of most recent swing low (for reference)
double g_bear_swing_high = 0.0;     // price of most recent swing high (for reference)

// -----------------------------------------------------------------------------
// Swing pivot detection — bounded closed-bar scans, run once per new bar.
// A swing high at shift s: high[s] is strictly the max of high[s-N..s+N].
// A swing low  at shift s: low[s]  is strictly the min of low[s-N..s+N].
// perf-allowed: bounded iHigh/iLow reads inside a QM_IsNewBar-gated path.
// -----------------------------------------------------------------------------
bool IsSwingHigh(const int s, const int strength)
  {
   const double h = iHigh(_Symbol, _Period, s); // perf-allowed
   if(h <= 0.0)
      return false;
   for(int j = 1; j <= strength; ++j)
     {
      if(iHigh(_Symbol, _Period, s - j) >= h) // perf-allowed
         return false;
      if(iHigh(_Symbol, _Period, s + j) >  h) // perf-allowed
         return false;
     }
   return true;
  }

bool IsSwingLow(const int s, const int strength)
  {
   const double l = iLow(_Symbol, _Period, s); // perf-allowed
   if(l <= 0.0)
      return false;
   for(int j = 1; j <= strength; ++j)
     {
      if(iLow(_Symbol, _Period, s - j) <= l) // perf-allowed
         return false;
      if(iLow(_Symbol, _Period, s + j) <  l) // perf-allowed
         return false;
     }
   return true;
  }

// Recompute the divergence STATE from the last two confirmed swings. Called
// once per closed bar (QM_IsNewBar gate). The newest usable swing is at shift
// strategy_swing_period+1 (it needs `swing_period` newer bars to be confirmed).
void AdvanceState_OnNewBar()
  {
   g_bull_div_fresh = false;
   g_bear_div_fresh = false;

   const int strength = (strategy_swing_period < 1 ? 1 : strategy_swing_period);
   const int lookback = (strategy_swing_lookback < (2 * strength + 3)
                         ? (2 * strength + 3) : strategy_swing_lookback);
   const int first = strength + 1;        // newest confirmable swing shift
   const int last  = first + lookback;    // oldest shift we scan

   // --- Collect the two most recent swing HIGHS (T2 = newer, T1 = older) ---
   int    hi2_shift = -1, hi1_shift = -1;
   double hi2_price = 0.0, hi1_price = 0.0;
   for(int s = first; s <= last; ++s)
     {
      if(!IsSwingHigh(s, strength))
         continue;
      if(hi2_shift < 0)
        {
         hi2_shift = s;
         hi2_price = iHigh(_Symbol, _Period, s); // perf-allowed
        }
      else
        {
         hi1_shift = s;
         hi1_price = iHigh(_Symbol, _Period, s); // perf-allowed
         break;
        }
     }

   // --- Collect the two most recent swing LOWS (T2 = newer, T1 = older) ---
   int    lo2_shift = -1, lo1_shift = -1;
   double lo2_price = 0.0, lo1_price = 0.0;
   for(int s = first; s <= last; ++s)
     {
      if(!IsSwingLow(s, strength))
         continue;
      if(lo2_shift < 0)
        {
         lo2_shift = s;
         lo2_price = iLow(_Symbol, _Period, s); // perf-allowed
        }
      else
        {
         lo1_shift = s;
         lo1_price = iLow(_Symbol, _Period, s); // perf-allowed
         break;
        }
     }

   // --- Bullish divergence: price LOWER low, MACD HIGHER low at T2 vs T1 ---
   bool bull = false;
   if(lo2_shift > 0 && lo1_shift > 0)
     {
      const double macd_lo2 = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                           strategy_macd_slow, strategy_macd_signal, lo2_shift);
      const double macd_lo1 = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                           strategy_macd_slow, strategy_macd_signal, lo1_shift);
      if(lo2_price < lo1_price && macd_lo2 > macd_lo1)
        {
         bull = true;
         g_bull_swing_low = lo2_price;
        }
     }

   // --- Bearish divergence: price HIGHER high, MACD LOWER high at T2 vs T1 ---
   bool bear = false;
   if(hi2_shift > 0 && hi1_shift > 0)
     {
      const double macd_hi2 = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                           strategy_macd_slow, strategy_macd_signal, hi2_shift);
      const double macd_hi1 = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                           strategy_macd_slow, strategy_macd_signal, hi1_shift);
      if(hi2_price > hi1_price && macd_hi2 < macd_hi1)
        {
         bear = true;
         g_bear_swing_high = hi2_price;
        }
     }

   // Mark which divergences are FRESH this bar (used by the exit-on-opposite
   // rule, which keys off a newly-detected opposite divergence).
   g_bull_div_fresh = bull;
   g_bear_div_fresh = bear;

   // Latch / flip the active STATE. A fresh divergence in one direction
   // contradicts and clears a stale opposite-direction setup.
   if(bull)
     {
      g_bull_div_active = true;
      g_bear_div_active = false;
     }
   if(bear)
     {
      g_bear_div_active = true;
      g_bull_div_active = false;
     }
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only. Fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate, do not block here

   const double stop_distance = strategy_sl_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Counter-trend entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
// Divergence is the latched STATE; the confirmation candle (last closed bar
// closing in the trade direction) is the single trigger EVENT (one per bar) —
// this avoids the two-cross-same-bar zero-trade trap.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Card rule: if BOTH divergences are fresh on the same bar while flat, skip.
   if(g_bull_div_fresh && g_bear_div_fresh)
      return false;

   if(!g_bull_div_active && !g_bear_div_active)
      return false;

   // Confirmation candle: direction of the last closed bar (shift 1).
   const double open1  = iOpen(_Symbol, _Period, 1);  // perf-allowed: single closed-bar read
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(open1 <= 0.0 || close1 <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   // --- Long: bullish divergence + confirmation candle closes UP ---
   if(g_bull_div_active && close1 > open1)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;

      const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_sl_atr_mult);
      if(sl <= 0.0 || sl >= entry)
         return false;
      const double tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, strategy_tp_rr);
      if(tp <= 0.0)
         return false;

      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "macd_div_long";
      g_bull_div_active = false; // consume the setup
      return true;
     }

   // --- Short: bearish divergence + confirmation candle closes DOWN ---
   if(g_bear_div_active && close1 < open1)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;

      const double sl = QM_StopATRFromValue(_Symbol, QM_SELL, entry, atr_value, strategy_sl_atr_mult);
      if(sl <= entry)
         return false;
      const double tp = QM_TakeRR(_Symbol, QM_SELL, entry, sl, strategy_tp_rr);
      if(tp <= 0.0)
         return false;

      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "macd_div_short";
      g_bear_div_active = false; // consume the setup
      return true;
     }

   return false;
  }

// Fixed protective SL + safety RR TP only (set at entry). Primary close is the
// opposite-divergence exit in Strategy_ExitSignal. No active trailing per card.
void Strategy_ManageOpenPosition()
  {
  }

// Primary close per the card: exit when the OPPOSITE divergence is detected.
//   Close a long  when a fresh BEARISH divergence appears.
//   Close a short when a fresh BULLISH divergence appears.
// Keyed off the freshly-detected divergence (one event per closed bar).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Determine the side of the open position for this magic.
   bool is_long = false, is_short = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)
         is_long = true;
      else if(ptype == POSITION_TYPE_SELL)
         is_short = true;
      break;
     }

   if(is_long && g_bear_div_fresh)
      return true;  // opposite (bearish) divergence closes the long
   if(is_short && g_bull_div_fresh)
      return true;  // opposite (bullish) divergence closes the short

   return false;
  }

// Defer to the central news filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line unless you know why.
// -----------------------------------------------------------------------------

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy,           // legacy back-compat
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,                            // pause-before (legacy hint)
                        30,                            // pause-after (legacy hint)
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,              // FW1 Axis A
                        qm_news_compliance))           // FW1 Axis B
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   Strategy_ManageOpenPosition();

   // Advance the divergence STATE once per closed bar BEFORE exit/entry
   // evaluation so both the opposite-divergence exit and the confirmation-candle
   // entry see the freshest swing set. QM_IsNewBar is consumed exactly once here.
   const bool new_bar = QM_IsNewBar();
   if(new_bar)
      AdvanceState_OnNewBar();

   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket))
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
        }
     }

   if(!new_bar)
      return;

   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
     {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
     }
  }

void OnTimer()
  {
   QM_FrameworkOnTimer();
  }

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
