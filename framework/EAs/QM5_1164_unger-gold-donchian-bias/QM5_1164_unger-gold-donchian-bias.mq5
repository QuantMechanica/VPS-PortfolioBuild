#property strict
#property version   "5.0"
#property description "QM5_1164 Unger Gold Donchian Bias"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1164;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal    = QM_NEWS_TEMPORAL_SKIP_DAY;
input QM_NewsComplianceProfile qm_news_compliance  = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_SKIP_DAY;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_donchian_period     = 20;
input int    strategy_atr_period          = 14;
input double strategy_sl_atr_mult         = 1.50;
input int    strategy_long_start_hour_ny  = 8;
input int    strategy_long_start_min_ny   = 0;
input int    strategy_long_end_hour_ny    = 12;
input int    strategy_long_end_min_ny     = 0;
input int    strategy_short_start_hour_ny = 20;
input int    strategy_short_start_min_ny  = 0;
input int    strategy_short_end_hour_ny   = 2;
input int    strategy_short_end_min_ny    = 0;
input int    strategy_max_spread_points   = 250;

const string STRATEGY_SYMBOL = "XAUUSD.DWX";

datetime g_last_signal_bar = 0;
datetime g_last_long_session = 0;
datetime g_last_short_session = 0;

int ClampInt(const int value, const int min_value, const int max_value)
  {
   return MathMax(min_value, MathMin(max_value, value));
  }

datetime BrokerToNYLocal(const datetime broker_time)
  {
   const datetime utc = QM_BrokerToUTC(broker_time);
   return utc - (QM_IsUSDSTUTC(utc) ? 4 * 3600 : 5 * 3600);
  }

datetime NYMidnightForBrokerTime(const datetime broker_time)
  {
   MqlDateTime ny;
   TimeToStruct(BrokerToNYLocal(broker_time), ny);
   ny.hour = 0;
   ny.min = 0;
   ny.sec = 0;
   return StructToTime(ny);
  }

int MinutesOfDayNY(const datetime broker_time)
  {
   MqlDateTime ny;
   TimeToStruct(BrokerToNYLocal(broker_time), ny);
   return ny.hour * 60 + ny.min;
  }

bool InNYWindow(const datetime broker_time, const int start_hour, const int start_minute,
                const int end_hour, const int end_minute)
  {
   const int now_min = MinutesOfDayNY(broker_time);
   const int start_min = ClampInt(start_hour, 0, 23) * 60 + ClampInt(start_minute, 0, 59);
   const int end_min = ClampInt(end_hour, 0, 23) * 60 + ClampInt(end_minute, 0, 59);

   if(start_min == end_min)
      return false;
   if(end_min > start_min)
      return (now_min >= start_min && now_min <= end_min);
   return (now_min >= start_min || now_min <= end_min);
  }

datetime WindowSessionKeyNY(const datetime broker_time, const int start_hour, const int start_minute,
                            const int end_hour, const int end_minute)
  {
   datetime key = NYMidnightForBrokerTime(broker_time);
   const int now_min = MinutesOfDayNY(broker_time);
   const int start_min = ClampInt(start_hour, 0, 23) * 60 + ClampInt(start_minute, 0, 59);
   const int end_min = ClampInt(end_hour, 0, 23) * 60 + ClampInt(end_minute, 0, 59);
   if(end_min < start_min && now_min <= end_min)
      key -= 24 * 3600;
   return key;
  }

bool HasOpenPositionForMagic()
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

bool SpreadAllowsEntry()
  {
   if(strategy_max_spread_points <= 0)
      return true;
   const int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (spread > 0 && spread <= strategy_max_spread_points);
  }

bool DonchianPriorChannel(double &upper, double &lower)
  {
   upper = -DBL_MAX;
   lower = DBL_MAX;
   const int period = MathMax(1, strategy_donchian_period);

   for(int shift = 2; shift <= period + 1; ++shift)
     {
      const double high_i = iHigh(_Symbol, PERIOD_M15, shift);
      const double low_i = iLow(_Symbol, PERIOD_M15, shift);
      if(high_i <= 0.0 || low_i <= 0.0 || high_i < low_i)
         return false;
      if(high_i > upper)
         upper = high_i;
      if(low_i < lower)
         lower = low_i;
     }

   return (upper > 0.0 && lower > 0.0 && upper > lower);
  }

bool StopDistanceAllowed(const QM_OrderType side, const double entry, const double sl)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || entry <= 0.0 || sl <= 0.0)
      return false;
   if(side == QM_BUY && sl >= entry)
      return false;
   if(side == QM_SELL && sl <= entry)
      return false;

   const int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const double stop_points = MathAbs(entry - sl) / point;
   return (stops_level <= 0 || stop_points > (double)stops_level);
  }

bool Strategy_NoTradeFilter()
  {
   if(_Symbol != STRATEGY_SYMBOL)
      return true;
   if(_Period != PERIOD_M15)
      return true;
   if(qm_magic_slot_offset != 0)
      return true;
   if(strategy_donchian_period <= 1 || strategy_atr_period <= 0 || strategy_sl_atr_mult <= 0.0)
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

   const datetime signal_bar = iTime(_Symbol, PERIOD_M15, 1);
   if(signal_bar <= 0 || signal_bar == g_last_signal_bar)
      return false;
   g_last_signal_bar = signal_bar;

   if(HasOpenPositionForMagic() || !SpreadAllowsEntry())
      return false;

   double upper = 0.0;
   double lower = 0.0;
   if(!DonchianPriorChannel(upper, lower))
      return false;

   const double close1 = iClose(_Symbol, PERIOD_M15, 1);
   const double atr = QM_ATR(_Symbol, PERIOD_M15, MathMax(1, strategy_atr_period), 1);
   if(close1 <= 0.0 || atr <= 0.0)
      return false;

   const datetime long_session = WindowSessionKeyNY(signal_bar,
                                                    strategy_long_start_hour_ny,
                                                    strategy_long_start_min_ny,
                                                    strategy_long_end_hour_ny,
                                                    strategy_long_end_min_ny);
   const datetime short_session = WindowSessionKeyNY(signal_bar,
                                                     strategy_short_start_hour_ny,
                                                     strategy_short_start_min_ny,
                                                     strategy_short_end_hour_ny,
                                                     strategy_short_end_min_ny);

   QM_OrderType side = QM_BUY;
   string reason = "";
   bool signal = false;

   if(close1 > upper &&
      InNYWindow(signal_bar, strategy_long_start_hour_ny, strategy_long_start_min_ny,
                 strategy_long_end_hour_ny, strategy_long_end_min_ny) &&
      g_last_long_session != long_session)
     {
      side = QM_BUY;
      reason = "UNGER_GOLD_DONCHIAN_BIAS_LONG";
      signal = true;
     }
   else if(close1 < lower &&
           InNYWindow(signal_bar, strategy_short_start_hour_ny, strategy_short_start_min_ny,
                      strategy_short_end_hour_ny, strategy_short_end_min_ny) &&
           g_last_short_session != short_session)
     {
      side = QM_SELL;
      reason = "UNGER_GOLD_DONCHIAN_BIAS_SHORT";
      signal = true;
     }

   if(!signal)
      return false;

   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, side, entry, atr, strategy_sl_atr_mult);
   if(!StopDistanceAllowed(side, entry, sl))
      return false;

   req.type = side;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = reason;

   if(side == QM_BUY)
      g_last_long_session = long_session;
   else
      g_last_short_session = short_session;

   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies fixed ATR safety stop and time-based exits only.
  }

bool PositionPastWindowExit(const long pos_type, const datetime opened_at, const datetime broker_now)
  {
   const int now_min = MinutesOfDayNY(broker_now);

   if(pos_type == POSITION_TYPE_BUY)
     {
      const int exit_min = ClampInt(strategy_long_end_hour_ny, 0, 23) * 60 +
                           ClampInt(strategy_long_end_min_ny, 0, 59);
      return (now_min >= exit_min);
     }

   if(pos_type == POSITION_TYPE_SELL)
     {
      const int exit_min = ClampInt(strategy_short_end_hour_ny, 0, 23) * 60 +
                           ClampInt(strategy_short_end_min_ny, 0, 59);
      const datetime open_key = WindowSessionKeyNY(opened_at,
                                                   strategy_short_start_hour_ny,
                                                   strategy_short_start_min_ny,
                                                   strategy_short_end_hour_ny,
                                                   strategy_short_end_min_ny);
      const datetime now_key = WindowSessionKeyNY(broker_now,
                                                  strategy_short_start_hour_ny,
                                                  strategy_short_start_min_ny,
                                                  strategy_short_end_hour_ny,
                                                  strategy_short_end_min_ny);
      return (now_key > open_key || (now_key == open_key && now_min >= exit_min &&
              MinutesOfDayNY(opened_at) > exit_min));
     }

   return false;
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

      const long pos_type = PositionGetInteger(POSITION_TYPE);
      const datetime opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      if(PositionPastWindowExit(pos_type, opened_at, broker_now))
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1164\",\"ea\":\"unger-gold-donchian-bias\"}");
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
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
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
