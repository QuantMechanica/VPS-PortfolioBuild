#property strict
#property version   "5.0"
#property description "QM5_12788 Turnaround Tuesday FX calendar reversal"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12788 - Turnaround Tuesday
// -----------------------------------------------------------------------------
// Weekly FX calendar anomaly:
//   - after a strong down Monday, buy Tuesday open for reversal
//   - after a strong up Monday, sell Tuesday open for reversal
// Runtime uses broker-time H1/D1 OHLC only; no external data.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12788;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal      = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance    = QM_NEWS_COMPLIANCE_DXZ;
input int                      qm_news_stale_max_hours = 336;
input string                   qm_news_min_impact      = "high";
input QM_NewsMode              qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_atr_period          = 20;
input double strategy_min_monday_atr      = 0.50;
input double strategy_close_zone_pct      = 40.0;
input double strategy_sl_atr_mult         = 1.00;
input double strategy_sl_floor_atr_mult   = 0.75;
input double strategy_tp_r                = 1.50;
input int    strategy_entry_start_hour    = 0;
input int    strategy_entry_end_hour      = 1;
input int    strategy_exit_hour_tuesday   = 22;
input int    strategy_max_hold_hours      = 30;
input int    strategy_history_bars_h1     = 120;
input int    strategy_max_spread_points   = 80;

int g_last_entry_monday_key = 0;

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

bool Strategy_LoadMondayState(datetime &monday_latest_time,
                              double &monday_high,
                              double &monday_low,
                              double &monday_close,
                              double &friday_close)
  {
   monday_latest_time = 0;
   monday_high = 0.0;
   monday_low = 0.0;
   monday_close = 0.0;
   friday_close = 0.0;

   MqlRates rates[];
   ArraySetAsSeries(rates, false);
   const int want = MathMax(72, MathMin(strategy_history_bars_h1, 168));
   const int copied = CopyRates(_Symbol, PERIOD_H1, 1, want, rates); // perf-allowed: bounded H1 calendar window, called only from framework new-bar entry path.
   if(copied <= 0)
      return false;

   datetime monday_first_time = 0;
   for(int i = 0; i < copied; ++i)
     {
      const datetime bar_time = rates[i].time;
      if(bar_time <= 0)
         continue;
      if(Strategy_DayOfWeek(bar_time) != 1)
         continue;

      if(monday_first_time == 0 || bar_time < monday_first_time)
         monday_first_time = bar_time;
      if(bar_time > monday_latest_time)
        {
         monday_latest_time = bar_time;
         monday_close = rates[i].close;
        }

      if(monday_high <= 0.0 || rates[i].high > monday_high)
         monday_high = rates[i].high;
      if(monday_low <= 0.0 || rates[i].low < monday_low)
         monday_low = rates[i].low;
     }

   if(monday_first_time <= 0 || monday_latest_time <= 0 ||
      monday_high <= 0.0 || monday_low <= 0.0 || monday_close <= 0.0)
      return false;

   datetime friday_latest_time = 0;
   for(int i = 0; i < copied; ++i)
     {
      const datetime bar_time = rates[i].time;
      if(bar_time <= 0 || bar_time >= monday_first_time)
         continue;
      if(Strategy_DayOfWeek(bar_time) != 5)
         continue;
      if(bar_time > friday_latest_time)
        {
         friday_latest_time = bar_time;
         friday_close = rates[i].close;
        }
     }

   return (friday_latest_time > 0 && friday_close > 0.0);
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_H1)
      return true;
   if(strategy_atr_period <= 1)
      return true;
   if(strategy_min_monday_atr <= 0.0)
      return true;
   if(strategy_close_zone_pct <= 0.0 || strategy_close_zone_pct >= 50.0)
      return true;
   if(strategy_sl_atr_mult <= 0.0 || strategy_sl_floor_atr_mult <= 0.0)
      return true;
   if(strategy_entry_start_hour < 0 || strategy_entry_end_hour > 23 ||
      strategy_entry_start_hour > strategy_entry_end_hour)
      return true;
   if(strategy_exit_hour_tuesday < 0 || strategy_exit_hour_tuesday > 23)
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

   if(Strategy_HasOpenPosition())
      return false;

   const datetime current_bar_time = iTime(_Symbol, PERIOD_H1, 0); // perf-allowed: current H1 bar timestamp for Tuesday entry window.
   if(current_bar_time <= 0)
      return false;
   if(Strategy_DayOfWeek(current_bar_time) != 2)
      return false;
   const int entry_hour = Strategy_Hour(current_bar_time);
   if(entry_hour < strategy_entry_start_hour || entry_hour > strategy_entry_end_hour)
      return false;

   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return false;
     }

   datetime monday_latest_time = 0;
   double monday_high = 0.0;
   double monday_low = 0.0;
   double monday_close = 0.0;
   double friday_close = 0.0;
   if(!Strategy_LoadMondayState(monday_latest_time, monday_high, monday_low, monday_close, friday_close))
      return false;

   const int monday_key = Strategy_DayKey(monday_latest_time);
   if(monday_key <= 0 || monday_key == g_last_entry_monday_key)
      return false;

   const double monday_range = monday_high - monday_low;
   const double atr_d1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(monday_range <= 0.0 || atr_d1 <= 0.0)
      return false;
   if(monday_range < strategy_min_monday_atr * atr_d1)
      return false;

   const double close_position = (monday_close - monday_low) / monday_range;
   const double zone = strategy_close_zone_pct / 100.0;

   int direction = 0;
   if(monday_close < friday_close && close_position <= zone)
      direction = 1;
   else if(monday_close > friday_close && close_position >= (1.0 - zone))
      direction = -1;
   else
      return false;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0)
      return false;

   const double stop_distance = MathMax(strategy_sl_floor_atr_mult, strategy_sl_atr_mult) * atr_d1;
   if(stop_distance <= 0.0)
      return false;

   req.sl = QM_StopRulesStopFromDistance(_Symbol, req.type, entry_price, stop_distance);
   if(req.sl <= 0.0)
      return false;

   if(strategy_tp_r > 0.0)
      req.tp = QM_TakeRR(_Symbol, req.type, entry_price, req.sl, strategy_tp_r);
   else
      req.tp = 0.0;

   req.reason = (direction > 0) ? "TURNAROUND_TUESDAY_LONG" : "TURNAROUND_TUESDAY_SHORT";
   g_last_entry_monday_key = monday_key;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, partial close, or pyramiding.
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

   if(dow == 2 && hour >= strategy_exit_hour_tuesday)
      return true;
   if(dow >= 3 || dow == 0)
      return true;
   if(open_time > 0 && strategy_max_hold_hours > 0 &&
      broker_now >= open_time + strategy_max_hold_hours * 3600)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12788\",\"strategy\":\"turnaround-tuesday\"}");
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
