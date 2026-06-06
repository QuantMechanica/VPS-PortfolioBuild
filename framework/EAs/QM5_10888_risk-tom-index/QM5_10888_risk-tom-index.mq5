#property strict
#property version   "5.0"
#property description "QM5_10888 Risk.net Index Turn-Of-Month Long Window"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA
// Card: QM5_10888_risk-tom-index, G0 APPROVED 2026-05-22.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 10888;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours     = 336;
input string qm_news_min_impact          = "high";
input QM_NewsMode qm_news_mode_legacy    = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = false;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_entry_days_before_month_end = 2;
input int    strategy_exit_trading_day_new_month  = 2;
input int    strategy_atr_period                  = 20;
input double strategy_atr_stop_mult               = 1.75;
input bool   strategy_use_volatility_filter       = true;
input int    strategy_volatility_lookback_days    = 252;
input double strategy_volatility_percentile       = 0.95;
input int    strategy_max_spread_points           = 0;

// -----------------------------------------------------------------------------
// Strategy helpers - calendar logic is bounded and only called from the framework
// new-bar path, except exit checks which first pass QM_IsNewBar while a position
// is open. D1 date reads use CopyRates with small fixed windows.
// -----------------------------------------------------------------------------

bool StrategySymbolInBasket(const string symbol)
  {
   return (symbol == "GDAXI.DWX" ||
           symbol == "NDX.DWX" ||
           symbol == "WS30.DWX" ||
           symbol == "SP500.DWX");
  }

datetime StrategyDateFloor(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
  }

int StrategyMonthOf(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.mon;
  }

int StrategyYearOf(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.year;
  }

bool StrategySameMonthYear(const datetime a, const datetime b)
  {
   return (StrategyMonthOf(a) == StrategyMonthOf(b) &&
           StrategyYearOf(a) == StrategyYearOf(b));
  }

bool StrategyHasScheduledTradeSession(const datetime date_time)
  {
   MqlDateTime dt;
   TimeToStruct(date_time, dt);

   datetime session_from = 0;
   datetime session_to = 0;
   for(uint session = 0; session < 10; ++session)
     {
      if(SymbolInfoSessionTrade(_Symbol, (ENUM_DAY_OF_WEEK)dt.day_of_week, session, session_from, session_to))
         return true;
     }

   return (dt.day_of_week >= 1 && dt.day_of_week <= 5);
  }

int StrategyTradingDaysRemainingInMonth(const datetime date_time)
  {
   const int month = StrategyMonthOf(date_time);
   const datetime day_start = StrategyDateFloor(date_time);
   int remaining = 0;

   for(int day = 1; day <= 10; ++day)
     {
      const datetime candidate = day_start + day * 86400;
      if(StrategyMonthOf(candidate) != month)
         break;
      if(StrategyHasScheduledTradeSession(candidate))
         remaining++;
     }

   return remaining;
  }

int StrategyTradingDayOrdinalInMonth(const datetime date_time)
  {
   MqlDateTime dt;
   TimeToStruct(date_time, dt);
   const int target_day = dt.day;
   const int target_month = dt.mon;
   const int target_year = dt.year;

   dt.day = 1;
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   const datetime month_start = StructToTime(dt);

   int ordinal = 0;
   for(int day = 0; day < target_day; ++day)
     {
      const datetime candidate = month_start + day * 86400;
      MqlDateTime cdt;
      TimeToStruct(candidate, cdt);
      if(cdt.mon != target_month || cdt.year != target_year)
         break;
      if(StrategyHasScheduledTradeSession(candidate))
         ordinal++;
      if(cdt.day == target_day)
         return ordinal;
     }

   return 0;
  }

bool StrategyHasOurPosition(datetime &open_time)
  {
   open_time = 0;
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
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

bool StrategyLoadCurrentD1Bars(MqlRates &rates[], const int count)
  {
   if(count <= 0)
      return false;
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_D1, 0, count, rates); // perf-allowed: bounded D1 calendar read under framework new-bar gate.
   return (copied >= count);
  }

bool StrategyVolatilityAllowsEntry()
  {
   if(!strategy_use_volatility_filter)
      return true;

   const int period = MathMax(1, strategy_atr_period);
   const int lookback = MathMax(20, strategy_volatility_lookback_days);
   const double pct = MathMax(0.50, MathMin(0.99, strategy_volatility_percentile));

   const double current_atr = QM_ATR(_Symbol, PERIOD_D1, period, 1);
   if(current_atr <= 0.0)
      return false;

   double samples[];
   ArrayResize(samples, lookback);
   int valid = 0;
   for(int shift = 1; shift <= lookback; ++shift)
     {
      const double atr = QM_ATR(_Symbol, PERIOD_D1, period, shift);
      if(atr <= 0.0)
         continue;
      samples[valid] = atr;
      valid++;
     }

   if(valid < MathMin(60, lookback))
      return false;

   ArrayResize(samples, valid);
   ArraySort(samples);
   const int index = (int)MathFloor((valid - 1) * pct);
   const double threshold = samples[index];
   if(threshold <= 0.0)
      return false;

   return (current_atr <= threshold);
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if(!StrategySymbolInBasket(_Symbol))
      return true;

   if(_Period != PERIOD_D1)
      return true;

   if(strategy_max_spread_points > 0)
     {
      const long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread > strategy_max_spread_points)
         return true;
     }

   return false;
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   datetime open_time = 0;
   if(StrategyHasOurPosition(open_time))
      return false;

   MqlRates rates[];
   if(!StrategyLoadCurrentD1Bars(rates, 2))
      return false;

   const datetime closed_bar_time = rates[1].time;
   if(closed_bar_time <= 0)
      return false;

   const int entry_offset = MathMax(1, strategy_entry_days_before_month_end);
   if(StrategyTradingDaysRemainingInMonth(closed_bar_time) != entry_offset)
      return false;

   if(!StrategyVolatilityAllowsEntry())
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || point <= 0.0 || strategy_atr_stop_mult <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, MathMax(1, strategy_atr_period), 1);
   if(atr <= 0.0)
      return false;

   req.price = ask;
   req.sl = QM_StopATRFromValue(_Symbol, QM_BUY, ask, atr, strategy_atr_stop_mult);
   req.tp = 0.0;
   req.reason = "RISK_NET_TOM_T_MINUS_2_LONG";

   return (req.sl > 0.0 && req.sl < ask && ((ask - req.sl) / point) > 0.0);
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // Card baseline has no trailing, break-even, partial close, or pyramiding.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   datetime open_time = 0;
   if(!StrategyHasOurPosition(open_time))
      return false;

   if(!QM_IsNewBar(_Symbol, PERIOD_D1))
      return false;

   MqlRates rates[];
   if(!StrategyLoadCurrentD1Bars(rates, 2))
      return false;

   const datetime closed_bar_time = rates[1].time;
   if(closed_bar_time <= 0 || open_time <= 0)
      return false;

   if(StrategySameMonthYear(open_time, closed_bar_time))
      return false;

   const int exit_day = MathMax(1, strategy_exit_trading_day_new_month);
   return (StrategyTradingDayOrdinalInMonth(closed_bar_time) >= exit_day);
  }

// News Filter Hook (callable for P8 News Impact phase)
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(broker_time <= 0)
      return false;
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring - unchanged from template.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10888\",\"ea\":\"risk_tom_index\"}");
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
