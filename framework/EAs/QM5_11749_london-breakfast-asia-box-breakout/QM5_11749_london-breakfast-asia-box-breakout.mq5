#property strict
#property version   "5.0"
#property description "QM5_11749 London Breakfast Asia Box Breakout"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails). The framework provides:
//
//   - QM_IsNewBar(sym="", tf=PERIOD_CURRENT)  - closed-bar gate
//   - QM_ATR / QM_EMA / QM_SMA / QM_RSI / QM_MACD_Main / QM_MACD_Signal /
//     QM_ADX / QM_ADX_PlusDI / QM_ADX_MinusDI /
//     QM_BB_Upper / QM_BB_Middle / QM_BB_Lower    (from QM_Indicators.mqh)
//   - QM_TM_OpenPosition(req, ticket) / QM_TM_ClosePosition(ticket, reason)
//   - QM_TM_MoveToBreakEven / QM_TM_TrailATR / QM_TM_TrailStep / QM_TM_PartialClose
//   - QM_LotsForRisk(symbol, sl_points)        - risk model lot sizing
//   - QM_StopFixedPips / QM_StopATR / QM_StopStructure / QM_StopVolatility
//   - QM_FrameworkHandleFridayClose / QM_KillSwitchCheck / QM_NewsAllowsTrade
//
// DO NOT
//   - Write per-EA IsNewBar() - use QM_IsNewBar()
//   - Call iATR / iMA / iRSI / iMACD / iADX / iBands or CopyBuffer directly -
//     use the QM_* readers above. The framework pools handles and releases them
//     on shutdown.
//   - CopyRates over warmup windows on every tick. If you genuinely need raw
//     bar arrays, gate by QM_IsNewBar so the work runs once per closed bar.
//   - Hand-edit framework/include/QM/QM_MagicResolver.mqh. After adding rows
//     to magic_numbers.csv, run:
//         python framework/scripts/update_magic_resolver.py
//     This is idempotent and preserves all rows.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11749;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_asia_start_hour_utc     = 0;
input int    strategy_asia_end_hour_utc       = 7;
input int    strategy_breakout_start_hour_utc = 7;
input int    strategy_session_cutoff_hour_utc = 16;
input int    strategy_take_profit_pips        = 40;
input int    strategy_history_bars_m15        = 96;
input int    strategy_min_asia_bars           = 20;
input int    strategy_max_spread_points       = 0;

// -----------------------------------------------------------------------------
// Strategy hooks - implement these against the card mechanically.
// -----------------------------------------------------------------------------

int UtcDayKey(const datetime utc_time)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(utc_time, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

int UtcMinuteOfDay(const datetime utc_time)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(utc_time, dt);
   return dt.hour * 60 + dt.min;
  }

bool HasOurOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      return true;
     }

   return false;
  }

bool Strategy_NoTradeFilter()
  {
   if(HasOurOpenPosition())
      return false;

   if(strategy_max_spread_points > 0 &&
      (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > strategy_max_spread_points)
      return true;

   const int minute = UtcMinuteOfDay(QM_BrokerToUTC(TimeCurrent()));
   const int watch_start = strategy_breakout_start_hour_utc * 60;
   const int cutoff = strategy_session_cutoff_hour_utc * 60;
   if(minute < watch_start || minute >= cutoff)
      return true;

   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(_Period != PERIOD_M15)
      return false;
   if(strategy_asia_start_hour_utc < 0 || strategy_asia_start_hour_utc > 23 ||
      strategy_asia_end_hour_utc <= strategy_asia_start_hour_utc || strategy_asia_end_hour_utc > 24 ||
      strategy_breakout_start_hour_utc < strategy_asia_end_hour_utc || strategy_breakout_start_hour_utc > 23 ||
      strategy_session_cutoff_hour_utc <= strategy_breakout_start_hour_utc || strategy_session_cutoff_hour_utc > 24 ||
      strategy_take_profit_pips <= 0 || strategy_min_asia_bars <= 0)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int bars_to_copy = strategy_history_bars_m15;
   if(bars_to_copy < 32)
      bars_to_copy = 32;
   if(bars_to_copy > 192)
      bars_to_copy = 192;

   const int copied = CopyRates(_Symbol, PERIOD_M15, 1, bars_to_copy, rates); // perf-allowed: bounded M15 session-structure read, called only after framework QM_IsNewBar()
   if(copied < strategy_min_asia_bars + 1)
      return false;

   const datetime current_bar_utc = QM_BrokerToUTC(rates[0].time);
   const int current_day = UtcDayKey(current_bar_utc);
   const int current_minute = UtcMinuteOfDay(current_bar_utc);
   const int asia_start = strategy_asia_start_hour_utc * 60;
   const int asia_end = strategy_asia_end_hour_utc * 60;
   const int breakout_start = strategy_breakout_start_hour_utc * 60;
   const int session_cutoff = strategy_session_cutoff_hour_utc * 60;

   static int session_day = -1;
   static bool trade_taken_today = false;
   if(current_day != session_day)
     {
      session_day = current_day;
      trade_taken_today = false;
     }

   if(trade_taken_today || HasOurOpenPosition())
      return false;
   if(current_minute < breakout_start || current_minute >= session_cutoff)
      return false;

   double asia_high = -DBL_MAX;
   double asia_low = DBL_MAX;
   int asia_bars = 0;

   for(int i = 0; i < copied; ++i)
     {
      const datetime bar_utc = QM_BrokerToUTC(rates[i].time);
      if(UtcDayKey(bar_utc) != current_day)
         continue;

      const int minute = UtcMinuteOfDay(bar_utc);
      if(minute < asia_start || minute >= asia_end)
         continue;

      asia_high = MathMax(asia_high, rates[i].high);
      asia_low = MathMin(asia_low, rates[i].low);
      ++asia_bars;
     }

   if(asia_bars < strategy_min_asia_bars || asia_high <= 0.0 ||
      asia_low <= 0.0 || asia_high <= asia_low)
      return false;

   int first_breakout_index = -1;
   int first_breakout_side = 0;

   for(int i = copied - 1; i >= 0; --i)
     {
      const datetime bar_utc = QM_BrokerToUTC(rates[i].time);
      if(UtcDayKey(bar_utc) != current_day)
         continue;

      const int minute = UtcMinuteOfDay(bar_utc);
      if(minute < breakout_start || minute >= session_cutoff)
         continue;

      if(rates[i].close > asia_high)
        {
         first_breakout_index = i;
         first_breakout_side = 1;
         break;
        }
      if(rates[i].close < asia_low)
        {
         first_breakout_index = i;
         first_breakout_side = -1;
         break;
        }
     }

   if(first_breakout_index < 0)
      return false;
   if(first_breakout_index != 0)
     {
      trade_taken_today = true;
      return false;
     }

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(first_breakout_side > 0)
     {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = NormalizeDouble(rates[0].low, _Digits);
      req.tp = QM_TakeFixedPips(_Symbol, QM_BUY, ask, strategy_take_profit_pips);
      req.reason = "LONDON_BREAKFAST_LONG";
      if(req.sl >= ask || req.tp <= ask)
         return false;
      trade_taken_today = true;
      return true;
     }

   if(first_breakout_side < 0)
     {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = NormalizeDouble(rates[0].high, _Digits);
      req.tp = QM_TakeFixedPips(_Symbol, QM_SELL, bid, strategy_take_profit_pips);
      req.reason = "LONDON_BREAKFAST_SHORT";
      if(req.sl <= bid || req.tp >= bid)
         return false;
      trade_taken_today = true;
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies no break-even, trailing, partial close, or pyramiding.
  }

bool Strategy_ExitSignal()
  {
   if(!HasOurOpenPosition())
      return false;

   const int minute = UtcMinuteOfDay(QM_BrokerToUTC(TimeCurrent()));
   return (minute >= strategy_session_cutoff_hour_utc * 60);
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to the framework news filter
  }

// -----------------------------------------------------------------------------
// Framework wiring - do NOT edit below this line unless you know why.
// -----------------------------------------------------------------------------

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,
                        30,
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,
                        qm_news_compliance))
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

