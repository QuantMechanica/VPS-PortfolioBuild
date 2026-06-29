#property strict
#property version   "5.0"
#property description "QM5_12791 Monday Range Breakout FX calendar breakout"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12791 - Monday Range Breakout
// -----------------------------------------------------------------------------
// Weekly FX calendar breakout:
//   - use Monday's completed D1 high/low as the reference box
//   - trade Tue-Thu broker-time H1 breaks beyond the box plus buffer
//   - hard stop beyond the opposite box side, 1.5R target, BE at 1R
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 12791;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal        = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance      = QM_NEWS_COMPLIANCE_DXZ;
input int                      qm_news_stale_max_hours = 336;
input string                   qm_news_min_impact      = "high";
input QM_NewsMode              qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_min_monday_range_pips = 30;
input int    strategy_max_monday_range_pips = 150;
input int    strategy_breakout_buffer_pips  = 5;
input int    strategy_stop_buffer_pips      = 10;
input double strategy_tp_r                  = 1.50;
input bool   strategy_move_to_breakeven     = true;
input int    strategy_entry_start_hour      = 8;
input int    strategy_entry_end_hour        = 18;
input int    strategy_max_trades_per_week   = 2;
input int    strategy_friday_exit_hour      = 21;
input int    strategy_max_spread_points     = 80;
input int    strategy_d1_history_bars       = 12;

int g_active_monday_key = 0;
int g_week_entry_signals = 0;

int Strategy_DayKey(const datetime t)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

int Strategy_DayOfWeek(const datetime t)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(t, dt);
   return dt.day_of_week;
  }

int Strategy_Hour(const datetime t)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(t, dt);
   return dt.hour;
  }

double Strategy_NormalizePrice(const double price)
  {
   if(price <= 0.0)
      return 0.0;
   return QM_StopRulesNormalizePrice(_Symbol, price);
  }

void Strategy_InitRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

bool Strategy_SelectOurPosition(ENUM_POSITION_TYPE &position_type, datetime &open_time)
  {
   position_type = POSITION_TYPE_BUY;
   open_time = 0;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }
   return false;
  }

bool Strategy_HasOpenPosition()
  {
   ENUM_POSITION_TYPE position_type;
   datetime open_time = 0;
   return Strategy_SelectOurPosition(position_type, open_time);
  }

bool Strategy_LoadLastClosedH1(MqlRates &bar)
  {
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_H1, 1, 1, rates); // perf-allowed: one closed H1 bar for breakout trigger.
   if(copied != 1)
      return false;
   bar = rates[0];
   return (bar.time > 0 && bar.high > 0.0 && bar.low > 0.0 && bar.close > 0.0);
  }

bool Strategy_LoadMondayBox(const datetime signal_time,
                            datetime &monday_time,
                            double &monday_high,
                            double &monday_low,
                            int &monday_key)
  {
   monday_time = 0;
   monday_high = 0.0;
   monday_low = 0.0;
   monday_key = 0;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int bars_to_read = MathMax(5, MathMin(strategy_d1_history_bars, 20));
   const int copied = CopyRates(_Symbol, PERIOD_D1, 0, bars_to_read, rates); // perf-allowed: bounded D1 calendar lookup for Monday box.
   if(copied <= 0)
      return false;

   for(int i = 0; i < copied; ++i)
     {
      const datetime bar_time = rates[i].time;
      if(bar_time <= 0 || bar_time >= signal_time)
         continue;
      if(Strategy_DayOfWeek(bar_time) != 1)
         continue;
      if(monday_time > 0 && bar_time <= monday_time)
         continue;

      monday_time = bar_time;
      monday_high = rates[i].high;
      monday_low = rates[i].low;
      monday_key = Strategy_DayKey(bar_time);
     }

   return (monday_time > 0 && monday_high > monday_low && monday_key > 0);
  }

void Strategy_SyncWeek(const int monday_key)
  {
   if(monday_key <= 0)
      return;
   if(monday_key == g_active_monday_key)
      return;

   g_active_monday_key = monday_key;
   g_week_entry_signals = 0;
  }

bool Strategy_SignalWindowAllows(const datetime signal_time)
  {
   const int dow = Strategy_DayOfWeek(signal_time);
   if(dow < 2 || dow > 4)
      return false;

   const int hour = Strategy_Hour(signal_time);
   return (hour >= strategy_entry_start_hour && hour < strategy_entry_end_hour);
  }

bool Strategy_SpreadAllows()
  {
   if(strategy_max_spread_points <= 0)
      return true;

   const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (spread_points <= strategy_max_spread_points);
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_H1)
      return true;
   if(strategy_min_monday_range_pips <= 0 ||
      strategy_max_monday_range_pips < strategy_min_monday_range_pips)
      return true;
   if(strategy_breakout_buffer_pips <= 0 || strategy_stop_buffer_pips < 0)
      return true;
   if(strategy_tp_r <= 0.0)
      return true;
   if(strategy_entry_start_hour < 0 || strategy_entry_start_hour > 23 ||
      strategy_entry_end_hour < 1 || strategy_entry_end_hour > 24 ||
      strategy_entry_start_hour >= strategy_entry_end_hour)
      return true;
   if(strategy_max_trades_per_week < 1 || strategy_d1_history_bars < 5)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   Strategy_InitRequest(req);

   if(Strategy_HasOpenPosition())
      return false;
   if(g_week_entry_signals >= strategy_max_trades_per_week)
      return false;
   if(!Strategy_SpreadAllows())
      return false;

   MqlRates signal_bar;
   if(!Strategy_LoadLastClosedH1(signal_bar))
      return false;
   if(!Strategy_SignalWindowAllows(signal_bar.time))
      return false;

   datetime monday_time = 0;
   double monday_high = 0.0;
   double monday_low = 0.0;
   int monday_key = 0;
   if(!Strategy_LoadMondayBox(signal_bar.time, monday_time, monday_high, monday_low, monday_key))
      return false;
   Strategy_SyncWeek(monday_key);
   if(g_week_entry_signals >= strategy_max_trades_per_week)
      return false;

   const double pip_distance = QM_StopRulesPipsToPriceDistance(_Symbol, 1);
   if(pip_distance <= 0.0)
      return false;

   const double range_pips = (monday_high - monday_low) / pip_distance;
   if(range_pips < strategy_min_monday_range_pips ||
      range_pips > strategy_max_monday_range_pips)
      return false;

   const double breakout_buffer = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_breakout_buffer_pips);
   const double stop_buffer = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_stop_buffer_pips);
   if(breakout_buffer <= 0.0 || stop_buffer < 0.0)
      return false;

   const double buy_trigger = monday_high + breakout_buffer;
   const double sell_trigger = monday_low - breakout_buffer;
   const bool long_break = (signal_bar.high >= buy_trigger);
   const bool short_break = (signal_bar.low <= sell_trigger);
   if(!long_break && !short_break)
      return false;

   int direction = 0;
   if(long_break && !short_break)
      direction = 1;
   else if(short_break && !long_break)
      direction = -1;
   else
     {
      const double midpoint = 0.5 * (monday_high + monday_low);
      if(signal_bar.close > midpoint)
         direction = 1;
      else if(signal_bar.close < midpoint)
         direction = -1;
      else
         return false;
     }

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0)
      return false;

   if(direction > 0)
      req.sl = Strategy_NormalizePrice(monday_low - stop_buffer);
   else
      req.sl = Strategy_NormalizePrice(monday_high + stop_buffer);
   if(req.sl <= 0.0)
      return false;

   if((direction > 0 && req.sl >= entry_price) ||
      (direction < 0 && req.sl <= entry_price))
      return false;

   req.tp = QM_TakeRR(_Symbol, req.type, entry_price, req.sl, strategy_tp_r);
   if(req.tp <= 0.0)
      return false;

   req.reason = (direction > 0) ? "MONDAY_RANGE_BREAK_LONG" : "MONDAY_RANGE_BREAK_SHORT";
   g_week_entry_signals++;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   if(!strategy_move_to_breakeven)
      return;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const bool is_buy = (pos_type == POSITION_TYPE_BUY);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(open_price <= 0.0 || current_sl <= 0.0 || point <= 0.0)
         continue;

      const bool already_be = is_buy ? (current_sl >= open_price - point * 0.5)
                                     : (current_sl <= open_price + point * 0.5);
      if(already_be)
         continue;

      const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                   : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(market <= 0.0)
         continue;

      const double initial_risk = MathAbs(open_price - current_sl);
      const double moved = is_buy ? (market - open_price) : (open_price - market);
      if(initial_risk <= 0.0 || moved < initial_risk)
         continue;

      const double target_sl = Strategy_NormalizePrice(open_price);
      if(target_sl <= 0.0)
         continue;

      const bool improves = is_buy ? (target_sl > current_sl + point * 0.5)
                                   : (target_sl < current_sl - point * 0.5);
      if(improves)
         QM_TM_MoveSL(ticket, target_sl, "monday_range_breakout_1r_breakeven");
     }
  }

bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE position_type;
   datetime open_time = 0;
   if(!Strategy_SelectOurPosition(position_type, open_time))
      return false;

   const datetime broker_now = TimeCurrent();
   const int dow = Strategy_DayOfWeek(broker_now);
   const int hour = Strategy_Hour(broker_now);
   if(dow == 5 && hour >= strategy_friday_exit_hour)
      return true;

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12791\",\"strategy\":\"monday-range-breakout\"}");
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

