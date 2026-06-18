#property strict
#property version   "5.0"
#property description "QM5_11029 atc-time-momo - Fixed-time M5 intraday momentum"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11029;
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
input int    strategy_entry_hour_server      = 10;
input int    strategy_entry_minute_server    = 36;
input int    strategy_entry_window_minutes   = 10;
input int    strategy_eod_hour_server        = 21;
input int    strategy_eod_minute_server      = 0;
input int    strategy_lookback_minutes       = 60;
input int    strategy_atr_period             = 14;
input double strategy_min_movement_atr       = 0.50;
input double strategy_strong_movement_atr    = 1.50;
input double strategy_sl_atr_mult            = 0.80;
input double strategy_tp_normal_atr_mult     = 1.20;
input double strategy_tp_strong_atr_mult     = 0.80;
input bool   strategy_use_stop_order         = false;
input double strategy_entry_buffer_atr       = 0.10;
input int    strategy_max_spread_points      = 0;
input bool   strategy_use_h1_ema_filter      = false;
input int    strategy_h1_ema_period          = 48;

int g_last_attempt_day_key = -1;

int Strategy_DayKey(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   return dt.year * 1000 + dt.day_of_year;
  }

int Strategy_MinuteOfDay(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   return dt.hour * 60 + dt.min;
  }

int Strategy_TargetMinute(const int hour_value, const int minute_value)
  {
   const int h = MathMax(0, MathMin(23, hour_value));
   const int m = MathMax(0, MathMin(59, minute_value));
   return h * 60 + m;
  }

bool Strategy_ReadCloseWindow(double &recent_close, double &past_close)
  {
   recent_close = 0.0;
   past_close = 0.0;

   const int period_seconds = PeriodSeconds(_Period);
   if(period_seconds <= 0)
      return false;

   const int lookback_bars = MathMax(1, (int)MathRound((double)strategy_lookback_minutes * 60.0 / (double)period_seconds));
   const int closes_needed = lookback_bars + 1;

   double closes[];
   ArraySetAsSeries(closes, true);
   const int copied = CopyClose(_Symbol, _Period, 1, closes_needed, closes); // perf-allowed: bounded close-to-close read, called only from framework QM_IsNewBar-gated Strategy_EntrySignal.
   if(copied < closes_needed)
      return false;

   recent_close = closes[0];
   past_close = closes[lookback_bars];
   return (recent_close > 0.0 && past_close > 0.0);
  }

bool Strategy_TrendFilterAllows(const QM_OrderType side)
  {
   if(!strategy_use_h1_ema_filter)
      return true;

   double h1_close[];
   ArraySetAsSeries(h1_close, true);
   const int copied = CopyClose(_Symbol, PERIOD_H1, 1, 1, h1_close); // perf-allowed: optional H1 closed-close filter, called only from framework QM_IsNewBar-gated Strategy_EntrySignal.
   if(copied < 1 || h1_close[0] <= 0.0)
      return false;

   const double ema = QM_EMA(_Symbol, PERIOD_H1, strategy_h1_ema_period, 1);
   if(ema <= 0.0)
      return false;

   if(side == QM_BUY)
      return (h1_close[0] > ema);
   return (h1_close[0] < ema);
  }

bool Strategy_SpreadAllows()
  {
   if(strategy_max_spread_points <= 0)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return true;

   const double spread = ask - bid;
   if(!(spread > 0.0))
      return true;

   return ((spread / point) <= (double)strategy_max_spread_points);
  }

int Strategy_SecondsUntilEod(const int minute_now)
  {
   const int eod_minute = Strategy_TargetMinute(strategy_eod_hour_server, strategy_eod_minute_server);
   if(minute_now >= eod_minute)
      return 0;
   return (eod_minute - minute_now) * 60;
  }

bool Strategy_NoTradeFilter()
  {
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

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const datetime broker_now = TimeCurrent();
   const int day_key = Strategy_DayKey(broker_now);
   if(day_key == g_last_attempt_day_key)
      return false;

   const int minute_now = Strategy_MinuteOfDay(broker_now);
   const int entry_minute = Strategy_TargetMinute(strategy_entry_hour_server, strategy_entry_minute_server);
   const int eod_minute = Strategy_TargetMinute(strategy_eod_hour_server, strategy_eod_minute_server);
   const int window_minutes = MathMax(1, strategy_entry_window_minutes);
   if(minute_now < entry_minute || minute_now >= entry_minute + window_minutes || minute_now >= eod_minute)
      return false;

   g_last_attempt_day_key = day_key;

   if(!Strategy_SpreadAllows())
      return false;

   double recent_close = 0.0;
   double past_close = 0.0;
   if(!Strategy_ReadCloseWindow(recent_close, past_close))
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double movement = recent_close - past_close;
   const double abs_movement = MathAbs(movement);
   if(abs_movement < strategy_min_movement_atr * atr_value)
      return false;

   const QM_OrderType side = (movement > 0.0) ? QM_BUY : QM_SELL;
   if(!Strategy_TrendFilterAllows(side))
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double market_entry = (side == QM_BUY) ? ask : bid;
   const double buffer = MathMax(0.0, strategy_entry_buffer_atr) * atr_value;
   QM_OrderType order_type = side;
   double order_price = 0.0;
   if(strategy_use_stop_order && buffer > 0.0)
     {
      order_type = (side == QM_BUY) ? QM_BUY_STOP : QM_SELL_STOP;
      order_price = (side == QM_BUY) ? market_entry + buffer : market_entry - buffer;
      order_price = QM_StopRulesNormalizePrice(_Symbol, order_price);
     }

   const double stop_entry = (order_price > 0.0) ? order_price : market_entry;
   const double sl = QM_StopATRFromValue(_Symbol, side, stop_entry, atr_value, strategy_sl_atr_mult);
   const double tp_mult = (abs_movement >= strategy_strong_movement_atr * atr_value)
                          ? strategy_tp_strong_atr_mult
                          : strategy_tp_normal_atr_mult;
   const double tp = QM_TakeATRFromValue(_Symbol, side, stop_entry, atr_value, tp_mult);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type = order_type;
   req.price = order_price;
   req.sl = sl;
   req.tp = tp;
   req.reason = (side == QM_BUY) ? "atc_time_momo_long" : "atc_time_momo_short";
   if(strategy_use_stop_order)
      req.expiration_seconds = Strategy_SecondsUntilEod(minute_now);
   return true;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   const int minute_now = Strategy_MinuteOfDay(TimeCurrent());
   const int eod_minute = Strategy_TargetMinute(strategy_eod_hour_server, strategy_eod_minute_server);
   return (minute_now >= eod_minute);
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
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
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
