#property strict
#property version   "5.0"
#property description "QM5_1205 Bhatti Gold VWAP EMA Pullback"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1205;
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
input int    strategy_fast_ema_period     = 50;
input int    strategy_regime_ema_period   = 200;
input int    strategy_atr_period          = 14;
input double strategy_pullback_atr_mult   = 0.15;
input double strategy_sl_atr_mult         = 1.50;
input int    strategy_vwap_skip_minutes   = 45;
input int    strategy_session_start_hour_broker = 0;
input int    strategy_session_start_minute_broker = 0;
input int    strategy_entry_cutoff_hour_broker = 22;
input int    strategy_entry_cutoff_minute_broker = 30;
input int    strategy_max_spread_points   = 250;

const string STRATEGY_SYMBOL = "XAUUSD.DWX";

datetime g_last_signal_bar = 0;

int ClampInt(const int value, const int min_value, const int max_value)
  {
   return MathMax(min_value, MathMin(max_value, value));
  }

int MinutesOfDay(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   return dt.hour * 60 + dt.min;
  }

int SessionStartMinute()
  {
   return ClampInt(strategy_session_start_hour_broker, 0, 23) * 60 +
          ClampInt(strategy_session_start_minute_broker, 0, 59);
  }

int EntryCutoffMinute()
  {
   return ClampInt(strategy_entry_cutoff_hour_broker, 0, 23) * 60 +
          ClampInt(strategy_entry_cutoff_minute_broker, 0, 59);
  }

bool InEntryWindow(const datetime signal_bar)
  {
   const int minute_now = MinutesOfDay(signal_bar);
   const int start_min = SessionStartMinute() + MathMax(0, strategy_vwap_skip_minutes);
   const int cutoff_min = EntryCutoffMinute();
   if(cutoff_min > start_min)
      return (minute_now >= start_min && minute_now <= cutoff_min);
   return (minute_now >= start_min || minute_now <= cutoff_min);
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

datetime SessionStartForBar(const datetime bar_time)
  {
   MqlDateTime dt;
   TimeToStruct(bar_time, dt);
   dt.hour = ClampInt(strategy_session_start_hour_broker, 0, 23);
   dt.min = ClampInt(strategy_session_start_minute_broker, 0, 59);
   dt.sec = 0;
   datetime session_start = StructToTime(dt);
   if(bar_time < session_start)
      session_start -= 86400;
   return session_start;
  }

bool SessionVWAP(const int target_shift, double &vwap)
  {
   vwap = 0.0;
   const datetime bar_time = iTime(_Symbol, PERIOD_M15, target_shift);
   if(bar_time <= 0)
      return false;

   const datetime session_start = SessionStartForBar(bar_time);
   const int start_shift = iBarShift(_Symbol, PERIOD_M15, session_start, false);
   if(start_shift < target_shift || start_shift < 0)
      return false;

   double pv_sum = 0.0;
   double vol_sum = 0.0;
   for(int shift = start_shift; shift >= target_shift; --shift)
     {
      const double high_price = iHigh(_Symbol, PERIOD_M15, shift);
      const double low_price = iLow(_Symbol, PERIOD_M15, shift);
      const double close_price = iClose(_Symbol, PERIOD_M15, shift);
      const long tick_volume = iVolume(_Symbol, PERIOD_M15, shift);
      if(high_price <= 0.0 || low_price <= 0.0 || close_price <= 0.0 || tick_volume <= 0)
         continue;

      const double typical = (high_price + low_price + close_price) / 3.0;
      pv_sum += typical * (double)tick_volume;
      vol_sum += (double)tick_volume;
     }

   if(vol_sum <= 0.0)
      return false;

   vwap = pv_sum / vol_sum;
   return (vwap > 0.0);
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
   if(strategy_fast_ema_period <= 1 || strategy_regime_ema_period <= strategy_fast_ema_period)
      return true;
   if(strategy_atr_period <= 0 || strategy_pullback_atr_mult <= 0.0 || strategy_sl_atr_mult <= 0.0)
      return true;
   if(Bars(_Symbol, PERIOD_M15) < strategy_regime_ema_period + 20)
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

   if(!InEntryWindow(signal_bar) || HasOpenPositionForMagic() || !SpreadAllowsEntry())
      return false;

   const double close1 = iClose(_Symbol, PERIOD_M15, 1);
   const double high1 = iHigh(_Symbol, PERIOD_M15, 1);
   const double low1 = iLow(_Symbol, PERIOD_M15, 1);
   const double ema50 = QM_EMA(_Symbol, PERIOD_M15, MathMax(2, strategy_fast_ema_period), 1);
   const double ema200 = QM_EMA(_Symbol, PERIOD_M15, MathMax(3, strategy_regime_ema_period), 1);
   const double atr = QM_ATR(_Symbol, PERIOD_M15, MathMax(1, strategy_atr_period), 1);
   double vwap = 0.0;

   if(close1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0 || ema50 <= 0.0 || ema200 <= 0.0 || atr <= 0.0)
      return false;
   if(!SessionVWAP(1, vwap))
      return false;

   const double tolerance = atr * strategy_pullback_atr_mult;
   const bool touched_ema = (low1 <= ema50 + tolerance && high1 >= ema50 - tolerance) ||
                            (MathAbs(close1 - ema50) <= tolerance);

   QM_OrderType side = QM_BUY;
   string reason = "";
   double rejection_extreme = 0.0;

   if(close1 > ema200 && close1 > vwap && touched_ema && close1 > ema50)
     {
      side = QM_BUY;
      reason = "BHATTI_GOLD_VWAP_EMA_LONG";
      rejection_extreme = low1;
     }
   else if(close1 < ema200 && close1 < vwap && touched_ema && close1 < ema50)
     {
      side = QM_SELL;
      reason = "BHATTI_GOLD_VWAP_EMA_SHORT";
      rejection_extreme = high1;
     }
   else
      return false;

   const double entry = QM_EntryMarketPrice(side);
   if(entry <= 0.0)
      return false;

   double sl = 0.0;
   if(side == QM_BUY)
      sl = rejection_extreme - atr * strategy_sl_atr_mult;
   else
      sl = rejection_extreme + atr * strategy_sl_atr_mult;

   req.type = side;
   req.price = entry;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = reason;

   return StopDistanceAllowed(side, entry, req.sl);
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies close-based EMA(50) trailing exit; Strategy_ExitSignal handles it on closed bars.
  }

bool Strategy_ExitSignal()
  {
   if(_Period != PERIOD_M15)
      return false;

   const double close1 = iClose(_Symbol, PERIOD_M15, 1);
   const double ema50 = QM_EMA(_Symbol, PERIOD_M15, MathMax(2, strategy_fast_ema_period), 1);
   if(close1 <= 0.0 || ema50 <= 0.0)
      return false;

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

      const long pos_type = PositionGetInteger(POSITION_TYPE);
      if(pos_type == POSITION_TYPE_BUY && close1 < ema50)
         return true;
      if(pos_type == POSITION_TYPE_SELL && close1 > ema50)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1205\",\"ea\":\"bhatti-gold-vwap-ema\"}");
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
