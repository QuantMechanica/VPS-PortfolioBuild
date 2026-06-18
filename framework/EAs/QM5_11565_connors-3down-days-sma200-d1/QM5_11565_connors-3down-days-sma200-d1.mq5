#property strict
#property version   "5.0"
#property description "QM5_11565 connors-3down-days-sma200-d1 — 3 consecutive down closes + SMA200 (D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11565 connors-3down-days-sma200-d1
// -----------------------------------------------------------------------------
// Source: Larry Connors & Cesar Alvarez, "Short-Term Trading Strategies That
// Work", TradingMarkets Publishing LLC, 2009 — Strategies 1-2 (Buy Pullbacks /
// Buy After Drop) + the S&P Short strategy.
// Card: artifacts/cards_approved/QM5_11565_connors-3down-days-sma200-d1.md
//       (g0_status APPROVED).
//
// Mechanics (D1, closed-bar reads at shift 1; long + symmetric short):
//   Trend STATE  : LONG when close[1] > SMA(sma_period); SHORT when below.
//   Entry EVENT  : LONG  fires when the last `long_down_days` closed bars each
//                  closed below their immediate predecessor (consecutive lower
//                  closes / a multi-day pullback). The consecutive-lower-close
//                  RUN is the SINGLE trigger EVENT; the SMA is a STATE, never a
//                  second event on the same bar (avoids the two-cross trap).
//                  SHORT fires symmetrically on `short_up_days` consecutive
//                  higher closes while below the SMA.
//   Exit EVENT   : LONG  exits when RSI(rsi_period) > rsi_exit_long (strength
//                  signal — pullback reverted). SHORT exits when close[1] falls
//                  back below SMA(short_exit_sma) (strength faded). Both are
//                  evaluated once per closed bar and only on a bar AFTER the
//                  entry bar, so entry and exit never collide on one bar.
//   Stop loss    : LONG  entry - sl_atr_mult * ATR(atr_period);
//                  SHORT entry + sl_atr_mult * ATR(atr_period).
//                  Skip the trade when the stop distance exceeds max_sl_pips.
//   No-trade     : skip entries on Friday (broker time); spread cap fail-open
//                  (.DWX models zero spread, so the guard only blocks a
//                  genuinely wide quote).
//
// The consecutive-close run is computed in-EA from bounded closed-bar closes
// (shift 1..N) — a tiny fixed loop, no CopyRates, no raw indicator handles.
// SMA / RSI / ATR come from the pooled QM_* readers. Only the 5 Strategy_*
// hooks + Strategy inputs are EA-specific.
//
// PORT FLAG: original tested on SPY (US equity). Card R3 ports the concept to
// FX D1 (EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX). Forex adaptation is untested in
// the source — flagged for the reviewer.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11565;
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
input int    strategy_sma_period        = 200;   // SMA200 trend-state filter
input int    strategy_long_down_days    = 3;      // consecutive lower closes -> LONG pullback (P3: 2/3/4)
input int    strategy_short_up_days     = 4;      // consecutive higher closes -> SHORT (P3: 3/4/5)
input int    strategy_rsi_period        = 2;      // RSI period for the LONG exit
input double strategy_rsi_exit_long     = 65.0;   // exit LONG when RSI > this (P3: 55/65/75)
input int    strategy_short_exit_sma    = 5;      // exit SHORT when close[1] < SMA(this)
input int    strategy_atr_period        = 14;    // ATR period for the protective stop
input double strategy_sl_atr_mult       = 2.0;   // stop distance = mult * ATR
input int    strategy_max_sl_pips       = 150;   // skip trade if ATR stop wider than this (card cap)
input bool   strategy_allow_short       = true;  // symmetric short below SMA200
input bool   strategy_block_friday      = true;  // no new entries on Friday (broker time)
input double strategy_spread_cap_pips   = 15.0;  // skip a genuinely wide spread (card: 15p)

// -----------------------------------------------------------------------------
// Internal helpers
// -----------------------------------------------------------------------------

// TRUE if the last `run` closed bars are strictly DECREASING in close, i.e.
//   close[1] < close[2] < ... < close[run+1]  (run consecutive lower closes).
// Bounded fixed loop over closed bars — no handles, no CopyRates.
bool IsConsecutiveLowerCloses(const int run)
  {
   if(run < 1)
      return false;
   for(int s = 1; s <= run; ++s)
     {
      const double c_near = iClose(_Symbol, _Period, s);     // perf-allowed: bounded closed-bar read
      const double c_prev = iClose(_Symbol, _Period, s + 1); // perf-allowed: bounded closed-bar read
      if(c_near <= 0.0 || c_prev <= 0.0)
         return false;
      if(!(c_near < c_prev))
         return false; // this step did not close lower -> run broken
     }
   return true;
  }

// TRUE if the last `run` closed bars are strictly INCREASING in close, i.e.
//   close[1] > close[2] > ... > close[run+1]  (run consecutive higher closes).
bool IsConsecutiveHigherCloses(const int run)
  {
   if(run < 1)
      return false;
   for(int s = 1; s <= run; ++s)
     {
      const double c_near = iClose(_Symbol, _Period, s);     // perf-allowed: bounded closed-bar read
      const double c_prev = iClose(_Symbol, _Period, s + 1); // perf-allowed: bounded closed-bar read
      if(c_near <= 0.0 || c_prev <= 0.0)
         return false;
      if(!(c_near > c_prev))
         return false; // this step did not close higher -> run broken
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
// LONG  : close[1] > SMA AND `long_down_days` consecutive lower closes.
// SHORT : close[1] < SMA AND `short_up_days` consecutive higher closes.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // No new entries on Friday (broker time) — exits still run normally (card filter).
   if(strategy_block_friday)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.day_of_week == 5)
         return false;
     }

   // --- Trend STATE: price vs SMA on the closed bar ---
   const double sma    = QM_SMA(_Symbol, _Period, strategy_sma_period, 1);
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(sma <= 0.0 || close1 <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double max_sl_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_max_sl_pips);

   // LONG: uptrend + consecutive lower closes (buy the pullback).
   if(close1 > sma && IsConsecutiveLowerCloses(strategy_long_down_days))
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_sl_atr_mult);
      if(sl <= 0.0)
         return false;
      // Card P2 cap: skip if the ATR stop is wider than max_sl_pips.
      if(max_sl_dist > 0.0 && (entry - sl) > max_sl_dist)
         return false;

      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = 0.0;   // dynamic exit: RSI strength (Strategy_ExitSignal)
      req.reason = "connors3down_long";
      return true;
     }

   // SHORT: downtrend + consecutive higher closes (symmetric).
   if(strategy_allow_short && close1 < sma && IsConsecutiveHigherCloses(strategy_short_up_days))
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
      req.tp     = 0.0;   // dynamic exit: close back below SMA(short_exit_sma)
      req.reason = "connors3down_short";
      return true;
     }

   return false;
  }

// No active trade management beyond the fixed ATR stop. The strength-signal
// exits live in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Exit (evaluated once per closed bar, only on a bar AFTER the entry bar so
// entry and exit never collide on the same bar):
//   LONG  -> RSI(rsi_period) at shift 1 > rsi_exit_long (pullback reverted).
//   SHORT -> close[1] < SMA(short_exit_sma) (upswing strength faded).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Find this EA's position to read its direction + open time.
   bool     is_long  = false;
   bool     have_pos = false;
   datetime open_tm  = 0;
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

   // Only evaluate the exit on a bar strictly after the entry bar — prevents an
   // entry+exit on the same closed bar (two-event-same-bar trap).
   const int bars_since = iBarShift(_Symbol, _Period, open_tm, false); // perf-allowed: hold gate
   if(bars_since < 1)
      return false;

   if(is_long)
     {
      const double rsi = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
      if(rsi <= 0.0)
         return false;
      return (rsi > strategy_rsi_exit_long);
     }
   else
     {
      const double sma_exit = QM_SMA(_Symbol, _Period, strategy_short_exit_sma, 1);
      const double close1   = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
      if(sma_exit <= 0.0 || close1 <= 0.0)
         return false;
      return (close1 < sma_exit);
     }
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
