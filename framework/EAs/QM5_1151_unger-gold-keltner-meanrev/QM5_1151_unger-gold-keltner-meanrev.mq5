#property strict
#property version   "5.0"
#property description "QM5_1151 Unger Gold Keltner Mean Reversion"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1151;
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
input int    strategy_ema_period          = 20;
input int    strategy_keltner_atr_period  = 20;
input double strategy_keltner_atr_mult    = 2.0;
input int    strategy_stop_atr_period     = 14;
input double strategy_sl_atr_mult         = 2.0;
input double strategy_tp_atr_mult         = 4.0;
input int    strategy_max_hold_bars       = 48;
input bool   strategy_use_midline_exit    = true;
input int    strategy_long_start_hour_ny  = 8;
input int    strategy_long_start_min_ny   = 0;
input int    strategy_long_end_hour_ny    = 15;
input int    strategy_long_end_min_ny     = 0;
input int    strategy_short_start_hour_ny = 9;
input int    strategy_short_start_min_ny  = 0;
input int    strategy_short_end_hour_ny   = 13;
input int    strategy_short_end_min_ny    = 0;
input int    strategy_max_spread_points   = 250;

const string STRATEGY_SYMBOL = "XAUUSD.DWX";

datetime g_last_long_session = 0;
datetime g_last_short_session = 0;
datetime g_last_signal_bar = 0;

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
   return (end_min > start_min && now_min >= start_min && now_min <= end_min);
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

double KeltnerMid(const int shift)
  {
   return QM_EMA(_Symbol, PERIOD_M30, MathMax(1, strategy_ema_period), shift);
  }

bool KeltnerBands(const int shift, double &middle, double &upper, double &lower)
  {
   middle = KeltnerMid(shift);
   const double atr = QM_ATR(_Symbol, PERIOD_M30, MathMax(1, strategy_keltner_atr_period), shift);
   if(middle <= 0.0 || atr <= 0.0 || strategy_keltner_atr_mult <= 0.0)
      return false;
   upper = middle + atr * strategy_keltner_atr_mult;
   lower = middle - atr * strategy_keltner_atr_mult;
   return (upper > middle && middle > lower);
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
   if(_Period != PERIOD_M30)
      return true;
   if(qm_magic_slot_offset != 0)
      return true;
   if(strategy_ema_period <= 1 || strategy_keltner_atr_period <= 0 || strategy_keltner_atr_mult <= 0.0)
      return true;
   if(strategy_stop_atr_period <= 0 || strategy_sl_atr_mult <= 0.0 || strategy_tp_atr_mult <= 0.0)
      return true;
   if(strategy_max_hold_bars <= 0)
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

   const datetime signal_bar = iTime(_Symbol, PERIOD_M30, 1);
   if(signal_bar <= 0 || signal_bar == g_last_signal_bar)
      return false;
   g_last_signal_bar = signal_bar;

   if(HasOpenPositionForMagic() || !SpreadAllowsEntry())
      return false;

   double mid1 = 0.0, upper1 = 0.0, lower1 = 0.0;
   double mid2 = 0.0, upper2 = 0.0, lower2 = 0.0;
   if(!KeltnerBands(1, mid1, upper1, lower1) || !KeltnerBands(2, mid2, upper2, lower2))
      return false;

   const double close1 = iClose(_Symbol, PERIOD_M30, 1);
   const double low2 = iLow(_Symbol, PERIOD_M30, 2);
   const double high2 = iHigh(_Symbol, PERIOD_M30, 2);
   if(close1 <= 0.0 || low2 <= 0.0 || high2 <= 0.0)
      return false;

   const datetime ny_session = NYMidnightForBrokerTime(signal_bar);
   QM_OrderType side = QM_BUY;
   string reason = "";
   bool signal = false;

   if(low2 < lower2 && close1 > lower1 &&
      InNYWindow(signal_bar, strategy_long_start_hour_ny, strategy_long_start_min_ny,
                 strategy_long_end_hour_ny, strategy_long_end_min_ny) &&
      g_last_long_session != ny_session)
     {
      side = QM_BUY;
      reason = "UNGER_GOLD_KELTNER_FALSE_BREAK_LONG";
      signal = true;
     }
   else if(high2 > upper2 && close1 < upper1 &&
           InNYWindow(signal_bar, strategy_short_start_hour_ny, strategy_short_start_min_ny,
                      strategy_short_end_hour_ny, strategy_short_end_min_ny) &&
           g_last_short_session != ny_session)
     {
      side = QM_SELL;
      reason = "UNGER_GOLD_KELTNER_FALSE_BREAK_SHORT";
      signal = true;
     }

   if(!signal)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_M30, MathMax(1, strategy_stop_atr_period), 1);
   const double entry = QM_EntryMarketPrice(side);
   if(atr <= 0.0 || entry <= 0.0)
      return false;

   req.type = side;
   req.price = entry;
   req.sl = QM_StopATRFromValue(_Symbol, side, entry, atr, strategy_sl_atr_mult);
   req.tp = QM_TakeATRFromValue(_Symbol, side, entry, atr, strategy_tp_atr_mult);
   req.reason = reason;
   if(!StopDistanceAllowed(side, entry, req.sl) || req.tp <= 0.0)
      return false;

   if(side == QM_BUY)
      g_last_long_session = ny_session;
   else
      g_last_short_session = ny_session;

   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies fixed ATR-derived SL/TP; no trailing stop or partial close.
  }

bool Strategy_ExitSignal()
  {
   if(_Period != PERIOD_M30)
      return false;

   const int magic = QM_FrameworkMagic();
   const double close1 = iClose(_Symbol, PERIOD_M30, 1);
   const double mid1 = KeltnerMid(1);

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
      if(strategy_use_midline_exit && close1 > 0.0 && mid1 > 0.0)
        {
         if(pos_type == POSITION_TYPE_BUY && close1 >= mid1)
            return true;
         if(pos_type == POSITION_TYPE_SELL && close1 <= mid1)
            return true;
        }

      const datetime opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened_at > 0 && iBarShift(_Symbol, PERIOD_M30, opened_at, false) >= strategy_max_hold_bars)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1151\",\"ea\":\"unger-gold-keltner-meanrev\"}");
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
