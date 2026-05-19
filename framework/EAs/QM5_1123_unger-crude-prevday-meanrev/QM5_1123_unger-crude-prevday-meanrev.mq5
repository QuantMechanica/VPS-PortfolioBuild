#property strict
#property version   "5.0"
#property description "QM5_1123 Unger crude previous-day mean reversion"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails). The framework provides:
//
//   - QM_IsNewBar(sym="", tf=PERIOD_CURRENT)  — closed-bar gate
//   - QM_ATR / QM_EMA / QM_SMA / QM_RSI / QM_MACD_Main / QM_MACD_Signal /
//     QM_ADX / QM_ADX_PlusDI / QM_ADX_MinusDI /
//     QM_BB_Upper / QM_BB_Middle / QM_BB_Lower    (from QM_Indicators.mqh)
//   - QM_TM_OpenPosition(req, ticket) / QM_TM_ClosePosition(ticket, reason)
//   - QM_TM_MoveToBreakEven / QM_TM_TrailATR / QM_TM_TrailStep / QM_TM_PartialClose
//   - QM_LotsForRisk(symbol, sl_points)        — risk model lot sizing
//   - QM_StopFixedPips / QM_StopATR / QM_StopStructure / QM_StopVolatility
//   - QM_FrameworkHandleFridayClose / QM_KillSwitchCheck / QM_NewsAllowsTrade
//
// DO NOT
//   - Write per-EA IsNewBar() — use QM_IsNewBar()
//   - Call iATR / iMA / iRSI / iMACD / iADX / iBands or CopyBuffer directly —
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
input int    qm_ea_id                   = 1123;
input int    qm_magic_slot_offset       = 0;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsMode qm_news_mode          = QM_NEWS_PAUSE;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input int    strategy_atr_period         = 14;
input double strategy_atr_sl_mult        = 1.5;
input bool   strategy_use_vwap_proxy_tp  = true;
input double strategy_tp_rr              = 1.0;
input int    strategy_daily_atr_lookback = 120;
input double strategy_daily_atr_pctile   = 25.0;
input bool   strategy_skip_eia_day       = true;
input int    strategy_eia_day_of_week    = 3;     // Sunday=0, Wednesday=3.
input int    strategy_session_start_hhmm = 100;
input int    strategy_flatten_hhmm       = 2200;
input int    strategy_max_spread_points  = 80;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

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

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(HasOurOpenPosition())
      return false;

   const datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);
   const int hhmm = dt.hour * 100 + dt.min;

   // No Trade Filter: time window.
   if(hhmm < strategy_session_start_hhmm)
      return true;

   // No Trade Filter: EIA inventory release day proxy.
   if(strategy_skip_eia_day && dt.day_of_week == strategy_eia_day_of_week)
      return true;

   // No Trade Filter: spread ceiling.
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return true;
   if((ask - bid) / point > strategy_max_spread_points)
      return true;

   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
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

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   const int hhmm = dt.hour * 100 + dt.min;
   if(hhmm < strategy_session_start_hhmm || hhmm >= strategy_flatten_hhmm)
      return false;

   const int day_key = dt.year * 10000 + dt.mon * 100 + dt.day;

   static int  tracked_day_key = 0;
   static bool long_taken_today = false;
   static bool short_taken_today = false;
   if(day_key != tracked_day_key)
     {
      tracked_day_key = day_key;
      long_taken_today = false;
      short_taken_today = false;
     }

   datetime day_start = StructToTime(dt) - (dt.hour * 3600 + dt.min * 60 + dt.sec);
   bool stopped_out_today = false;
   if(HistorySelect(day_start, TimeCurrent()))
     {
      const int total_deals = HistoryDealsTotal();
      const int magic = QM_FrameworkMagic();
      for(int i = 0; i < total_deals; ++i)
        {
         const ulong deal = HistoryDealGetTicket(i);
         if(deal == 0)
            continue;
         if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol)
            continue;
         if((int)HistoryDealGetInteger(deal, DEAL_MAGIC) != magic)
            continue;
         if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY) != DEAL_ENTRY_OUT)
            continue;
         if((ENUM_DEAL_REASON)HistoryDealGetInteger(deal, DEAL_REASON) == DEAL_REASON_SL)
           {
            stopped_out_today = true;
            break;
           }
        }
     }
   if(stopped_out_today)
      return false;

   const double prev_low = iLow(_Symbol, PERIOD_D1, 1);
   const double prev_high = iHigh(_Symbol, PERIOD_D1, 1);
   const double prev_close = iClose(_Symbol, PERIOD_D1, 1);
   const double fifth_low = iLow(_Symbol, PERIOD_D1, 5);
   const double fifth_high = iHigh(_Symbol, PERIOD_D1, 5);
   if(prev_low <= 0.0 || prev_high <= 0.0 || fifth_low <= 0.0 || fifth_high <= 0.0)
      return false;

   double current_daily_atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(current_daily_atr <= 0.0)
      return false;

   double ranges[];
   ArrayResize(ranges, strategy_daily_atr_lookback);
   int range_count = 0;
   for(int i = 1; i <= strategy_daily_atr_lookback; ++i)
     {
      const double atr_value = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, i);
      if(atr_value > 0.0)
        {
         ranges[range_count] = atr_value;
         ++range_count;
        }
     }
   if(range_count < 20)
      return false;
   ArrayResize(ranges, range_count);
   ArraySort(ranges);
   int pct_index = (int)MathFloor((strategy_daily_atr_pctile / 100.0) * (range_count - 1));
   pct_index = MathMax(0, MathMin(range_count - 1, pct_index));
   if(current_daily_atr < ranges[pct_index])
      return false;

   const double low_trigger = MathMin(prev_low, fifth_low);
   const double high_trigger = MathMax(prev_high, fifth_high);
   const double close_last = iClose(_Symbol, PERIOD_M15, 1);
   const double high_last = iHigh(_Symbol, PERIOD_M15, 1);
   const double low_last = iLow(_Symbol, PERIOD_M15, 1);
   if(close_last <= 0.0 || high_last <= 0.0 || low_last <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;

   const double vwap_proxy = (prev_high + prev_low + prev_close) / 3.0;
   double entry = 0.0;
   if(!long_taken_today && low_last < low_trigger && close_last > low_trigger)
     {
      req.type = QM_BUY;
      entry = ask;
      req.reason = "PREVDAY_RECLAIM_LONG";
      long_taken_today = true;
     }
   else if(!short_taken_today && high_last > high_trigger && close_last < high_trigger)
     {
      req.type = QM_SELL;
      entry = bid;
      req.reason = "PREVDAY_RECLAIM_SHORT";
      short_taken_today = true;
     }
   else
      return false;

   req.price = 0.0;
   req.sl = QM_StopATR(_Symbol, req.type, entry, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;

   if(strategy_use_vwap_proxy_tp)
     {
      const bool tp_valid = (req.type == QM_BUY && vwap_proxy > entry) ||
                            (req.type == QM_SELL && vwap_proxy < entry);
      req.tp = tp_valid ? NormalizeDouble(vwap_proxy, _Digits) : 0.0;
     }
   else
      req.tp = QM_TakeRR(_Symbol, req.type, entry, req.sl, strategy_tp_rr);

   if(MathAbs(entry - req.sl) / point <= 0.0)
      return false;

   // Trade Entry: market entry at the next bar open through framework trade management.
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Trade Management: card specifies no trailing, break-even, partial close, or pyramiding.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   // Trade Close: flatten all open positions before session end.
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   const int hhmm = dt.hour * 100 + dt.min;
   if(hhmm >= strategy_flatten_hhmm)
      return true;

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   // News Filter Hook: EIA release-day proxy is handled by Strategy_NoTradeFilter;
   // central V5 news modes remain active through QM_NewsAllowsTrade.
   return false; // defer to QM_NewsAllowsTrade(...)
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
                        qm_news_mode,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker))
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
   if(!QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // Per-tick: trade management can adjust SL/TP on open positions.
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit (e.g. time stop). Separate from SL/TP.
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

   // Per-closed-bar: entry-signal evaluation. Gating here avoids 99% of
   // per-tick recompute mistakes — EntrySignal sees one new closed bar per
   // call, not every incoming tick.
   if(!QM_IsNewBar())
      return;

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

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
