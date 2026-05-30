#property strict
#property version   "5.0"
#property description "QM5_1161 Unger Crude Intraday Bias"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1161;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours     = 336;
input string qm_news_min_impact          = "high";
input QM_NewsMode qm_news_mode_legacy    = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_signal_tf = PERIOD_M15;
input int    strategy_atr_period         = 14;
input double strategy_sl_atr_mult        = 2.0;
input bool   strategy_tp_enabled         = false;
input double strategy_tp_atr_mult        = 3.0;
input bool   strategy_ema_filter_enabled = true;
input int    strategy_ema_period         = 20;
input int    strategy_long_entry_hour_ny = 16;
input int    strategy_long_entry_minute_ny = 0;
input int    strategy_long_exit_hour_ny  = 3;
input int    strategy_long_exit_minute_ny = 0;
input int    strategy_short_entry_hour_ny = 10;
input int    strategy_short_entry_minute_ny = 0;
input int    strategy_short_exit_hour_ny = 15;
input int    strategy_short_exit_minute_ny = 0;
input int    strategy_entry_tolerance_minutes = 15;
input int    strategy_exit_tolerance_minutes = 15;
input int    strategy_spread_median_bars = 20;
input double strategy_spread_mult        = 2.0;
input bool   strategy_eia_skip_enabled   = true;
input int    strategy_eia_day_of_week_ny = 3;
input int    strategy_eia_hour_ny        = 10;
input int    strategy_eia_minute_ny      = 30;
input int    strategy_eia_skip_before_minutes = 30;
input int    strategy_eia_skip_after_minutes = 60;
input int    strategy_friday_last_entry_hour_ny = 15;

const string STRATEGY_SYMBOL = "XTIUSD.DWX";

datetime g_last_long_entry_day = 0;
datetime g_last_short_entry_day = 0;

int ClampInt(const int value, const int min_value, const int max_value)
  {
   return MathMax(min_value, MathMin(max_value, value));
  }

datetime BrokerToNYLocal(const datetime broker_time)
  {
   const datetime utc = QM_BrokerToUTC(broker_time);
   return utc - (QM_IsUSDSTUTC(utc) ? 4 * 3600 : 5 * 3600);
  }

datetime NYLocalToBroker(const datetime ny_day, const int hour, const int minute)
  {
   MqlDateTime ny;
   TimeToStruct(ny_day, ny);
   ny.hour = ClampInt(hour, 0, 23);
   ny.min = ClampInt(minute, 0, 59);
   ny.sec = 0;

   const datetime local_stamp = StructToTime(ny);
   datetime utc_guess = local_stamp + 5 * 3600;
   if(QM_IsUSDSTUTC(utc_guess))
      utc_guess = local_stamp + 4 * 3600;
   return QM_UTCToBroker(utc_guess);
  }

datetime NYMidnightForBrokerNow(const datetime broker_time)
  {
   MqlDateTime ny;
   TimeToStruct(BrokerToNYLocal(broker_time), ny);
   ny.hour = 0;
   ny.min = 0;
   ny.sec = 0;
   return StructToTime(ny);
  }

bool Strategy_HasOpenPosition()
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
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

bool Strategy_TradingDayAllowed(const datetime broker_time)
  {
   MqlDateTime ny;
   TimeToStruct(BrokerToNYLocal(broker_time), ny);
   if(ny.day_of_week < 1 || ny.day_of_week > 5)
      return false;
   if(ny.day_of_week == 5 && ny.hour >= strategy_friday_last_entry_hour_ny)
      return false;
   return true;
  }

bool Strategy_InNYTimeWindow(const datetime broker_time,
                             const int hour,
                             const int minute,
                             const int tolerance_minutes)
  {
   const datetime ny_midnight = NYMidnightForBrokerNow(broker_time);
   const datetime target = NYLocalToBroker(ny_midnight, hour, minute);
   const int window = MathMax(1, tolerance_minutes) * 60;
   return (broker_time >= target && broker_time < target + window);
  }

bool Strategy_InEiaSkipWindow(const datetime broker_time)
  {
   if(!strategy_eia_skip_enabled)
      return false;

   MqlDateTime ny;
   const datetime ny_local = BrokerToNYLocal(broker_time);
   TimeToStruct(ny_local, ny);
   if(ny.day_of_week != strategy_eia_day_of_week_ny)
      return false;

   ny.hour = ClampInt(strategy_eia_hour_ny, 0, 23);
   ny.min = ClampInt(strategy_eia_minute_ny, 0, 59);
   ny.sec = 0;
   const datetime release_local = StructToTime(ny);
   const datetime start_local = release_local - MathMax(0, strategy_eia_skip_before_minutes) * 60;
   const datetime end_local = release_local + MathMax(0, strategy_eia_skip_after_minutes) * 60;
   return (ny_local >= start_local && ny_local < end_local);
  }

bool Strategy_SpreadAllowsEntry()
  {
   const int current_spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(current_spread <= 0 || strategy_spread_median_bars <= 0 || strategy_spread_mult <= 0.0)
      return true;

   const int cap = MathMin(strategy_spread_median_bars, 256);
   int samples[256];
   int count = 0;
   for(int shift = 1; shift <= cap; ++shift)
     {
      const long spread_i = iSpread(_Symbol, strategy_signal_tf, shift);
      if(spread_i <= 0)
         continue;
      samples[count] = (int)spread_i;
      ++count;
     }
   if(count <= 0)
      return true;

   for(int i = 1; i < count; ++i)
     {
      const int key = samples[i];
      int j = i - 1;
      while(j >= 0 && samples[j] > key)
        {
         samples[j + 1] = samples[j];
         --j;
        }
      samples[j + 1] = key;
     }

   const double median = (count % 2 == 1)
                         ? (double)samples[count / 2]
                         : 0.5 * (double)(samples[(count / 2) - 1] + samples[count / 2]);
   return ((double)current_spread <= median * strategy_spread_mult);
  }

bool Strategy_EmaAllowsDirection(const int direction)
  {
   if(!strategy_ema_filter_enabled)
      return true;
   if(strategy_ema_period <= 0)
      return false;

   const double close_1 = iClose(_Symbol, strategy_signal_tf, 1);
   const double ema_1 = QM_EMA(_Symbol, strategy_signal_tf, strategy_ema_period, 1);
   if(close_1 <= 0.0 || ema_1 <= 0.0)
      return false;
   if(direction > 0)
      return (close_1 > ema_1);
   return (close_1 < ema_1);
  }

bool Strategy_BuildEntry(QM_EntryRequest &req, const int direction)
  {
   const double entry = (direction > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double atr = QM_ATR(_Symbol, strategy_signal_tf, strategy_atr_period, 1);
   if(entry <= 0.0 || atr <= 0.0)
      return false;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   req.price = 0.0;
   req.sl = QM_StopATRFromValue(_Symbol, req.type, entry, atr, strategy_sl_atr_mult);
   req.tp = 0.0;
   if(strategy_tp_enabled && strategy_tp_atr_mult > 0.0)
      req.tp = NormalizeDouble(entry + (direction > 0 ? 1.0 : -1.0) * strategy_tp_atr_mult * atr, _Digits);
   req.reason = (direction > 0) ? "QM5_1161_LONG_BIAS" : "QM5_1161_SHORT_BIAS";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(req.sl <= 0.0)
      return false;
   if(req.type == QM_BUY && req.sl >= entry)
      return false;
   if(req.type == QM_SELL && req.sl <= entry)
      return false;
   return true;
  }

bool Strategy_NoTradeFilter()
  {
   if(_Symbol != STRATEGY_SYMBOL)
      return true;
   if(strategy_signal_tf != PERIOD_M15)
      return true;
   if(strategy_atr_period <= 0 || strategy_sl_atr_mult <= 0.0)
      return true;
   if(strategy_entry_tolerance_minutes <= 0 || strategy_exit_tolerance_minutes <= 0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_1161_INTRADAY_BIAS";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(Strategy_HasOpenPosition())
      return false;

   const datetime broker_now = TimeCurrent();
   if(!Strategy_TradingDayAllowed(broker_now))
      return false;
   if(Strategy_InEiaSkipWindow(broker_now))
      return false;
   if(!Strategy_SpreadAllowsEntry())
      return false;

   const datetime ny_day = NYMidnightForBrokerNow(broker_now);
   int direction = 0;
   if(Strategy_InNYTimeWindow(broker_now, strategy_long_entry_hour_ny, strategy_long_entry_minute_ny, strategy_entry_tolerance_minutes))
     {
      if(g_last_long_entry_day == ny_day)
         return false;
      direction = 1;
     }
   else if(Strategy_InNYTimeWindow(broker_now, strategy_short_entry_hour_ny, strategy_short_entry_minute_ny, strategy_entry_tolerance_minutes))
     {
      if(g_last_short_entry_day == ny_day)
         return false;
      direction = -1;
     }
   else
      return false;

   if(!Strategy_EmaAllowsDirection(direction))
      return false;
   if(!Strategy_BuildEntry(req, direction))
      return false;

   if(direction > 0)
      g_last_long_entry_day = ny_day;
   else
      g_last_short_entry_day = ny_day;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, partial close, or add-on logic.
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const datetime broker_now = TimeCurrent();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const long type = PositionGetInteger(POSITION_TYPE);
      if(type == POSITION_TYPE_BUY &&
         Strategy_InNYTimeWindow(broker_now, strategy_long_exit_hour_ny, strategy_long_exit_minute_ny, strategy_exit_tolerance_minutes))
         return true;
      if(type == POSITION_TYPE_SELL &&
         Strategy_InNYTimeWindow(broker_now, strategy_short_exit_hour_ny, strategy_short_exit_minute_ny, strategy_exit_tolerance_minutes))
         return true;
     }
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
