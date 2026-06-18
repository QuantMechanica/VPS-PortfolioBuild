#property strict
#property version   "5.0"
#property description "QM5_11497 connors-alvarez-double7s-sma200-d1 — Double 7's mean reversion (D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11497 connors-alvarez-double7s-sma200-d1
// -----------------------------------------------------------------------------
// Source: Larry Connors & Cesar Alvarez, "Short-Term Trading Strategies That
// Work", TradingMarkets Publishing LLC, 2009 — "Double 7's Strategy".
// Card: artifacts/cards_approved/QM5_11497_connors-alvarez-double7s-sma200-d1.md
//       (g0_status APPROVED).
//
// Mechanics (D1, closed-bar reads at shift 1; long + symmetric short):
//   Trend STATE  : LONG when close[1] > SMA(sma_period); SHORT when below.
//   Entry EVENT  : LONG  fires when close[1] is the LOWEST close of the last
//                  `extreme_lookback` closed bars (a new N-day closing low).
//                  SHORT fires when close[1] is the HIGHEST close (new N-day
//                  closing high). The new N-day extreme is the SINGLE trigger;
//                  the SMA is a state, never a second event on the same bar.
//   Exit EVENT   : LONG  exits when close[1] is the new N-day HIGHEST close.
//                  SHORT exits when close[1] is the new N-day LOWEST close.
//   Stop loss    : LONG  entry - sl_atr_mult * ATR(atr_period);
//                  SHORT entry + sl_atr_mult * ATR(atr_period).
//                  Skip the trade when the stop distance exceeds max_sl_pips.
//   Max hold     : exit at the close of the `max_hold_bars`-th bar if neither
//                  the N-day-extreme exit nor the stop has triggered.
//   No-trade     : skip entries on Friday (broker time); spread cap fail-open.
//
// The N-day extreme is computed in-EA from bounded closed-bar closes (shift
// 1..extreme_lookback) — a tiny fixed loop, no CopyRates, no raw indicator
// handles. Only the 5 Strategy_* hooks + Strategy inputs are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11497;
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
input int    strategy_sma_period        = 200;   // SMA200 trend filter period
input int    strategy_extreme_lookback  = 7;     // N-day closing extreme (Double 7's)
input int    strategy_atr_period        = 14;    // ATR period for the protective stop
input double strategy_sl_atr_mult       = 2.0;   // stop distance = mult * ATR
input int    strategy_max_sl_pips       = 100;   // skip trade if ATR stop wider than this
input int    strategy_max_hold_bars     = 10;    // force exit after this many D1 bars
input bool   strategy_allow_short       = true;  // symmetric short below SMA200
input bool   strategy_block_friday      = true;  // no new entries on Friday (broker time)
input double strategy_spread_cap_pips   = 30.0;  // skip a genuinely wide spread

// -----------------------------------------------------------------------------
// Internal helpers
// -----------------------------------------------------------------------------

// TRUE if close[1] is the lowest close of bars [1 .. lookback] (a new N-day
// closing low). Bounded fixed loop over closed bars — no handles, no CopyRates.
bool IsNewLowestClose(const int lookback)
  {
   const double c1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(c1 <= 0.0)
      return false;
   for(int s = 2; s <= lookback; ++s)
     {
      const double cs = iClose(_Symbol, _Period, s); // perf-allowed: bounded closed-bar read
      if(cs <= 0.0)
         return false;
      if(cs < c1)
         return false; // an earlier bar closed lower -> not a new N-day low
     }
   return true;
  }

// TRUE if close[1] is the highest close of bars [1 .. lookback].
bool IsNewHighestClose(const int lookback)
  {
   const double c1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(c1 <= 0.0)
      return false;
   for(int s = 2; s <= lookback; ++s)
     {
      const double cs = iClose(_Symbol, _Period, s); // perf-allowed: bounded closed-bar read
      if(cs <= 0.0)
         return false;
      if(cs > c1)
         return false; // an earlier bar closed higher -> not a new N-day high
     }
   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only; fail-open on .DWX zero spread.
// The Friday-entry block lives in Strategy_EntrySignal (closed-bar path) so it
// does not interfere with exits / trade management on Fridays.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double spread       = ask - bid;
   const double spread_limit = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_spread_cap_pips);
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread_limit > 0.0 && spread > spread_limit)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
// LONG  : close[1] > SMA AND close[1] is a new N-day closing low.
// SHORT : close[1] < SMA AND close[1] is a new N-day closing high.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // No new entries on Friday (broker time) — exits still run normally.
   if(strategy_block_friday)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.day_of_week == 5)
         return false;
     }

   // --- Trend STATE: price vs SMA on the closed bar ---
   const double sma   = QM_SMA(_Symbol, _Period, strategy_sma_period, 1);
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(sma <= 0.0 || close1 <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double max_sl_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_max_sl_pips);

   // LONG: uptrend + new N-day closing low (mean-reversion buy).
   if(close1 > sma && IsNewLowestClose(strategy_extreme_lookback))
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_sl_atr_mult);
      if(sl <= 0.0)
         return false;
      // P2 cap: skip if the ATR stop is wider than max_sl_pips.
      if(max_sl_dist > 0.0 && (entry - sl) > max_sl_dist)
         return false;

      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = 0.0;   // dynamic exit: N-day high close (Strategy_ExitSignal)
      req.reason = "double7s_long";
      return true;
     }

   // SHORT: downtrend + new N-day closing high (symmetric mean-reversion sell).
   if(strategy_allow_short && close1 < sma && IsNewHighestClose(strategy_extreme_lookback))
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_SELL, entry, atr_value, strategy_sl_atr_mult);
      if(sl <= 0.0)
         return false;
      if(max_sl_dist > 0.0 && (sl - entry) > max_sl_dist)
         return false;

      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = 0.0;
      req.reason = "double7s_short";
      return true;
     }

   return false;
  }

// No active trade management beyond the fixed ATR stop. The N-day-extreme exit
// and the max-hold time stop live in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Exit:
//   LONG  -> close[1] is a new N-day HIGHEST close, OR max-hold elapsed.
//   SHORT -> close[1] is a new N-day LOWEST  close, OR max-hold elapsed.
// One closed-bar evaluation per call (driven once per new bar from OnTick).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Find this EA's position to read its direction + open time.
   bool   is_long   = false;
   bool   have_pos  = false;
   datetime open_tm = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      is_long  = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      open_tm  = (datetime)PositionGetInteger(POSITION_TIME);
      have_pos = true;
      break;
     }
   if(!have_pos)
      return false;

   // Max-hold time stop: count closed D1 bars elapsed since the entry bar.
   if(strategy_max_hold_bars > 0)
     {
      const int bars_since = iBarShift(_Symbol, _Period, open_tm, false); // perf-allowed: time stop
      if(bars_since >= strategy_max_hold_bars)
         return true;
     }

   // N-day-extreme exit (mean reversion completed).
   if(is_long)
      return IsNewHighestClose(strategy_extreme_lookback);
   else
      return IsNewLowestClose(strategy_extreme_lookback);
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
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   if(!QM_IsNewBar())
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
