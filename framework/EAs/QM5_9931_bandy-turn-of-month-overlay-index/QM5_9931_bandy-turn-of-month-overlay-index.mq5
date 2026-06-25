#property strict
#property version   "5.0"
#property description "QM5_9931 Bandy Turn-of-Month Overlay Index"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9931;
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
input bool   qm_friday_close_enabled    = false;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_pre_month_end_days       = 3;
input int    strategy_post_month_start_days    = 2;
input int    strategy_exit_after_start_day     = 3;
input int    strategy_regime_sma_period        = 200;
input int    strategy_atr_period               = 14;
input double strategy_atr_stop_mult            = 2.5;
input int    strategy_time_stop_trading_days   = 7;
input bool   strategy_require_d1               = true;
input int    strategy_max_spread_points        = 0;

#define STRATEGY_SYMBOL_COUNT 3

string g_strategy_symbols[STRATEGY_SYMBOL_COUNT] = {"SP500.DWX", "NDX.DWX", "WS30.DWX"};
int    g_strategy_slots[STRATEGY_SYMBOL_COUNT]   = {0, 1, 2};

MqlRates g_strategy_d1_rates[];
int      g_strategy_d1_rates_count = 0;
int      g_strategy_day_key = 0;
int      g_strategy_tdom = 0;
int      g_strategy_tdays_to_month_end = 0;
int      g_strategy_window_id = 0;
bool     g_strategy_in_tom_window = false;
double   g_strategy_closed_close = 0.0;
datetime g_strategy_closed_time = 0;
bool     g_strategy_skip_tom_window = false;
int      g_strategy_skip_window_id = 0;

int Strategy_DateKey(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

int Strategy_MonthKey(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.year * 100 + dt.mon;
  }

bool Strategy_IsWeekday(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return (dt.day_of_week >= 1 && dt.day_of_week <= 5);
  }

datetime Strategy_StartOfDay(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
  }

datetime Strategy_StartOfNextMonth(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   dt.day = 1;
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   if(dt.mon == 12)
     {
      dt.year++;
      dt.mon = 1;
     }
   else
      dt.mon++;
   return StructToTime(dt);
  }

int Strategy_WeekdayTradingDaysToMonthEnd(const datetime closed_bar_time)
  {
   const datetime start_day = Strategy_StartOfDay(closed_bar_time);
   const datetime next_month = Strategy_StartOfNextMonth(closed_bar_time);
   int count = 0;
   for(datetime day = start_day; day < next_month; day += 86400)
     {
      if(Strategy_IsWeekday(day))
         count++;
     }
   return count;
  }

int Strategy_TradingDayOfMonthFromRates()
  {
   if(g_strategy_d1_rates_count <= 0)
      return 0;

   const int month_key = Strategy_MonthKey(g_strategy_d1_rates[0].time);
   int count = 0;
   for(int i = 0; i < g_strategy_d1_rates_count; ++i)
     {
      if(Strategy_MonthKey(g_strategy_d1_rates[i].time) != month_key)
         break;
      count++;
     }
   return count;
  }

int Strategy_WindowId(const datetime closed_bar_time)
  {
   MqlDateTime dt;
   TimeToStruct(closed_bar_time, dt);
   if(g_strategy_tdays_to_month_end > 0 &&
      g_strategy_tdays_to_month_end <= MathMax(1, strategy_pre_month_end_days))
     {
      datetime next_month = Strategy_StartOfNextMonth(closed_bar_time);
      MqlDateTime nm;
      TimeToStruct(next_month, nm);
      return nm.year * 100 + nm.mon;
     }
   return dt.year * 100 + dt.mon;
  }

bool Strategy_RefreshCalendarState()
  {
   const int today_key = Strategy_DateKey(TimeCurrent());
   if(today_key == g_strategy_day_key && g_strategy_d1_rates_count > 0)
      return true;

   ArrayResize(g_strategy_d1_rates, 0);
   ArraySetAsSeries(g_strategy_d1_rates, true);
   g_strategy_d1_rates_count = CopyRates(_Symbol, PERIOD_D1, 1, 260, g_strategy_d1_rates); // perf-allowed: cached once per broker day for D1 trading-day-of-month calendar math.
   if(g_strategy_d1_rates_count <= 0)
      return false;

   g_strategy_day_key = today_key;
   g_strategy_closed_time = g_strategy_d1_rates[0].time;
   g_strategy_closed_close = g_strategy_d1_rates[0].close;
   g_strategy_tdom = Strategy_TradingDayOfMonthFromRates();
   g_strategy_tdays_to_month_end = Strategy_WeekdayTradingDaysToMonthEnd(g_strategy_closed_time);
   g_strategy_in_tom_window = ((g_strategy_tdays_to_month_end > 0 &&
                                g_strategy_tdays_to_month_end <= MathMax(1, strategy_pre_month_end_days)) ||
                               (g_strategy_tdom > 0 &&
                                g_strategy_tdom <= MathMax(1, strategy_post_month_start_days)));
   g_strategy_window_id = Strategy_WindowId(g_strategy_closed_time);

   if(g_strategy_skip_tom_window &&
      g_strategy_skip_window_id > 0 &&
      g_strategy_window_id != g_strategy_skip_window_id &&
      !g_strategy_in_tom_window)
     {
      g_strategy_skip_tom_window = false;
      g_strategy_skip_window_id = 0;
     }

   return true;
  }

bool Strategy_IsAllowedSymbolSlot()
  {
   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
     {
      if(g_strategy_symbols[i] == _Symbol)
         return (g_strategy_slots[i] == qm_magic_slot_offset);
     }
   return false;
  }

bool Strategy_SelectOurPosition(ulong &ticket, datetime &opened_at)
  {
   ticket = 0;
   opened_at = 0;
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong pos_ticket = PositionGetTicket(i);
      if(pos_ticket == 0 || !PositionSelectByTicket(pos_ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      ticket = pos_ticket;
      opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

int Strategy_ClosedTradingDaysSince(const datetime opened_at)
  {
   if(opened_at <= 0 || g_strategy_d1_rates_count <= 0)
      return 0;

   int count = 0;
   for(int i = 0; i < g_strategy_d1_rates_count; ++i)
     {
      if(g_strategy_d1_rates[i].time >= opened_at)
         count++;
      else
         break;
     }
   return count;
  }

void Strategy_OnDeal(const ulong deal_ticket)
  {
   if(deal_ticket == 0 || !HistoryDealSelect(deal_ticket))
      return;
   if(HistoryDealGetString(deal_ticket, DEAL_SYMBOL) != _Symbol)
      return;
   if((int)HistoryDealGetInteger(deal_ticket, DEAL_MAGIC) != QM_FrameworkMagic())
      return;
   if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY) != DEAL_ENTRY_OUT)
      return;
   if((ENUM_DEAL_REASON)HistoryDealGetInteger(deal_ticket, DEAL_REASON) == DEAL_REASON_SL)
     {
      g_strategy_skip_tom_window = true;
      g_strategy_skip_window_id = 0;
     }
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if(strategy_require_d1 && _Period != PERIOD_D1)
      return true;
   if(!Strategy_IsAllowedSymbolSlot())
      return true;
   if(!Strategy_RefreshCalendarState())
      return true;

   if(strategy_max_spread_points > 0 && QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
     {
      const int spread_points = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
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
   req.reason = "QM5_9931_TOM_LONG";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!Strategy_RefreshCalendarState())
      return false;
   if(!g_strategy_in_tom_window)
      return false;
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(g_strategy_skip_tom_window)
     {
      if(g_strategy_skip_window_id == 0)
         g_strategy_skip_window_id = g_strategy_window_id;
      if(g_strategy_skip_window_id == g_strategy_window_id)
         return false;
      g_strategy_skip_tom_window = false;
      g_strategy_skip_window_id = 0;
     }

   if(strategy_regime_sma_period < 2 || strategy_atr_period < 1 || strategy_atr_stop_mult <= 0.0)
      return false;

   const double regime = QM_SMA(_Symbol, PERIOD_D1, strategy_regime_sma_period, 1);
   if(regime <= 0.0 || g_strategy_closed_close <= regime)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || point <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   const double stop = QM_StopATRFromValue(_Symbol, QM_BUY, ask, atr, strategy_atr_stop_mult);
   if(stop <= 0.0 || stop >= ask)
      return false;

   req.sl = stop;
   req.tp = 0.0;
   return ((ask - stop) / point > 0.0);
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // Card specifies a fixed catastrophic ATR stop only; no trailing, BE, scale-in, or partial close.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   if(!Strategy_RefreshCalendarState())
      return false;

   ulong ticket = 0;
   datetime opened_at = 0;
   if(!Strategy_SelectOurPosition(ticket, opened_at))
      return false;

   if(g_strategy_tdom > MathMax(strategy_post_month_start_days, strategy_exit_after_start_day))
      return true;

   const int held_trading_days = Strategy_ClosedTradingDaysSince(opened_at);
   if(strategy_time_stop_trading_days > 0 && held_trading_days >= strategy_time_stop_trading_days)
      return true;

   return false;
  }

// News Filter Hook (callable for P8 News Impact phase)
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_9931\",\"ea\":\"bandy-turn-of-month-overlay-index\"}");
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
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
      Strategy_OnDeal(trans.deal);
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
