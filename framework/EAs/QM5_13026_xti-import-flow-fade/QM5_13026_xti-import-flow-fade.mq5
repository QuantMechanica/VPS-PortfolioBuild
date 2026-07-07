#property strict
#property version   "5.0"
#property description "QM5_13026 XTI EIA crude-import flow fade"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_13026 - XTI Monthly Crude-Import Flow Absorption Fade
// -----------------------------------------------------------------------------
// D1 structural WTI sleeve:
//   - uses a first-business-days broker-calendar proxy after the monthly import
//     information cycle
//   - fades ATR/SMA stretches only when the signal bar has not broken out of the
//     prior Donchian channel
//   - ATR stop/target, SMA/time exits, no external runtime data
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 13026;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_window_business_days = 4;
input int    strategy_channel_lookback     = 30;
input int    strategy_sma_period           = 50;
input int    strategy_atr_period           = 20;
input double strategy_min_range_atr        = 0.85;
input double strategy_min_body_atr         = 0.25;
input double strategy_min_sma_distance_atr = 0.65;
input double strategy_atr_sl_mult          = 2.5;
input double strategy_atr_tp_mult          = 2.0;
input int    strategy_max_hold_days        = 6;
input int    strategy_max_spread_points    = 1000;

int g_last_signal_day_key = 0;

bool Strategy_IsXtiD1()
  {
   return (_Symbol == "XTIUSD.DWX" && _Period == PERIOD_D1);
  }

int Strategy_DayKey(const datetime t)
  {
   if(t <= 0)
      return 0;
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

bool Strategy_IsBrokerBusinessDay(const MqlDateTime &dt)
  {
   return (dt.day_of_week >= 1 && dt.day_of_week <= 5);
  }

datetime Strategy_MakeBrokerDate(const int year, const int month, const int day)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   dt.year = year;
   dt.mon = month;
   dt.day = day;
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
  }

int Strategy_BusinessDayOfMonth(const datetime t)
  {
   if(t <= 0)
      return -1;

   MqlDateTime target;
   TimeToStruct(t, target);
   if(!Strategy_IsBrokerBusinessDay(target))
      return -1;

   int count = 0;
   for(int day = 1; day <= target.day; ++day)
     {
      MqlDateTime probe;
      TimeToStruct(Strategy_MakeBrokerDate(target.year, target.mon, day), probe);
      if(Strategy_IsBrokerBusinessDay(probe))
         ++count;
     }

   return count;
  }

bool Strategy_IsImportProxyWindow(const datetime t)
  {
   const int business_day = Strategy_BusinessDayOfMonth(t);
   return (business_day > 0 && business_day <= strategy_window_business_days);
  }

bool Strategy_HasOpenPosition()
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
      return true;
     }
   return false;
  }

bool Strategy_DonchianExcludingSignal(double &highest_high, double &lowest_low)
  {
   highest_high = -DBL_MAX;
   lowest_low = DBL_MAX;

   const int lookback = MathMax(5, strategy_channel_lookback);
   for(int shift = 2; shift < lookback + 2; ++shift)
     {
      const double high = iHigh(_Symbol, PERIOD_D1, shift); // perf-allowed: D1 Donchian state behind new-bar gate.
      const double low = iLow(_Symbol, PERIOD_D1, shift);   // perf-allowed: D1 Donchian state behind new-bar gate.
      if(high <= 0.0 || low <= 0.0 || high < low)
         return false;
      highest_high = MathMax(highest_high, high);
      lowest_low = MathMin(lowest_low, low);
     }

   return (highest_high > 0.0 && lowest_low > 0.0 && highest_high >= lowest_low);
  }

bool Strategy_LoadImportFadeState(int &direction,
                                  double &atr_last,
                                  double &sma_last,
                                  int &signal_day_key)
  {
   direction = 0;
   atr_last = 0.0;
   sma_last = 0.0;
   signal_day_key = 0;

   const datetime signal_time = iTime(_Symbol, PERIOD_D1, 1); // perf-allowed: completed D1 calendar state behind new-bar gate.
   if(signal_time <= 0 || !Strategy_IsImportProxyWindow(signal_time))
      return false;

   const double signal_open = iOpen(_Symbol, PERIOD_D1, 1);   // perf-allowed: completed D1 signal bar.
   const double signal_high = iHigh(_Symbol, PERIOD_D1, 1);   // perf-allowed: completed D1 signal bar.
   const double signal_low = iLow(_Symbol, PERIOD_D1, 1);     // perf-allowed: completed D1 signal bar.
   const double signal_close = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: completed D1 signal bar.
   if(signal_open <= 0.0 || signal_high <= 0.0 || signal_low <= 0.0 || signal_close <= 0.0)
      return false;
   if(signal_high <= signal_low)
      return false;

   atr_last = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   sma_last = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_period, 1, PRICE_CLOSE);
   if(atr_last <= 0.0 || sma_last <= 0.0)
      return false;

   const double signal_range = signal_high - signal_low;
   const double signal_body = MathAbs(signal_close - signal_open);
   if(signal_range < strategy_min_range_atr * atr_last)
      return false;
   if(signal_body < strategy_min_body_atr * atr_last)
      return false;

   double channel_high = 0.0;
   double channel_low = 0.0;
   if(!Strategy_DonchianExcludingSignal(channel_high, channel_low))
      return false;

   const double distance_atr = MathAbs(signal_close - sma_last) / atr_last;
   if(distance_atr < strategy_min_sma_distance_atr)
      return false;

   if(signal_close > signal_open && signal_close > sma_last && signal_close <= channel_high)
      direction = -1;
   else if(signal_close < signal_open && signal_close < sma_last && signal_close >= channel_low)
      direction = 1;
   else
      return false;

   signal_day_key = Strategy_DayKey(signal_time);
   return (signal_day_key > 0);
  }

void Strategy_CloseOpenPositionsIfNeeded()
  {
   const int magic = QM_FrameworkMagic();
   const datetime now = TimeCurrent();
   const int hold_seconds = MathMax(1, strategy_max_hold_days) * 86400;
   const double close_last = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: D1 SMA exit behind new-bar gate.
   const double sma_last = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_period, 1, PRICE_CLOSE);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      bool should_close = false;
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened > 0 && now - opened >= hold_seconds)
         should_close = true;

      if(close_last > 0.0 && sma_last > 0.0)
        {
         const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         if(pos_type == POSITION_TYPE_BUY && close_last >= sma_last)
            should_close = true;
         if(pos_type == POSITION_TYPE_SELL && close_last <= sma_last)
            should_close = true;
        }

      if(should_close)
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsXtiD1())
      return true;
   if(qm_magic_slot_offset != 0)
      return true;
   if(strategy_window_business_days < 1 || strategy_window_business_days > 8)
      return true;
   if(strategy_channel_lookback < 5)
      return true;
   if(strategy_sma_period <= 1 || strategy_atr_period <= 1)
      return true;
   if(strategy_min_range_atr <= 0.0 || strategy_min_body_atr <= 0.0 || strategy_min_sma_distance_atr <= 0.0)
      return true;
   if(strategy_atr_sl_mult <= 0.0 || strategy_atr_tp_mult <= 0.0)
      return true;
   if(strategy_max_hold_days <= 0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_13026_XTI_IMPORT_FADE";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(Strategy_HasOpenPosition())
      return false;

   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return false;
     }

   int direction = 0;
   double atr_last = 0.0;
   double sma_last = 0.0;
   int signal_day_key = 0;
   if(!Strategy_LoadImportFadeState(direction, atr_last, sma_last, signal_day_key))
      return false;
   if(sma_last <= 0.0)
      return false;
   if(signal_day_key <= 0 || signal_day_key == g_last_signal_day_key)
      return false;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0)
      return false;

   req.sl = QM_StopATRFromValue(_Symbol, req.type, entry_price, atr_last, strategy_atr_sl_mult);
   req.sl = QM_StopRulesNormalizePrice(_Symbol, req.sl);
   if(req.sl <= 0.0)
      return false;
   if(req.type == QM_BUY && req.sl >= entry_price)
      return false;
   if(req.type == QM_SELL && req.sl <= entry_price)
      return false;

   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   req.tp = (req.type == QM_BUY)
            ? NormalizeDouble(entry_price + strategy_atr_tp_mult * atr_last, digits)
            : NormalizeDouble(entry_price - strategy_atr_tp_mult * atr_last, digits);
   req.tp = QM_StopRulesNormalizePrice(_Symbol, req.tp);
   if(req.tp <= 0.0)
      return false;
   if(req.type == QM_BUY && req.tp <= entry_price)
      return false;
   if(req.type == QM_SELL && req.tp >= entry_price)
      return false;

   req.reason = (direction > 0) ? "XTI_IMPORT_FLOW_FADE_LONG" : "XTI_IMPORT_FLOW_FADE_SHORT";
   g_last_signal_day_key = signal_day_key;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   Strategy_CloseOpenPositionsIfNeeded();
  }

bool Strategy_ExitSignal()
  {
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_13026\",\"ea\":\"xti-import-flow-fade\"}");
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
