#property strict
#property version   "5.0"
#property description "QM5_13088 XTI export-flow month-end failed-probe fade"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_13088 - XTI Export-Flow Failed-Probe Fade
// -----------------------------------------------------------------------------
// D1 structural WTI sleeve:
//   - last-business-days-of-month export-flow information window
//   - fades failed Donchian probes after ATR/SMA stretch and rejection tail
//   - ATR stop/target, SMA/channel/time exits, no external runtime data
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 13088;
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
input int    strategy_channel_lookback     = 63;
input int    strategy_exit_channel         = 21;
input int    strategy_sma_period           = 80;
input int    strategy_atr_period           = 20;
input double strategy_min_probe_atr        = 0.18;
input double strategy_min_signal_range_atr = 0.70;
input double strategy_min_tail_ratio       = 0.25;
input double strategy_min_sma_stretch_atr  = 0.45;
input double strategy_atr_sl_mult          = 2.50;
input double strategy_atr_tp_mult          = 2.00;
input int    strategy_max_hold_days        = 7;
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

bool Strategy_IsLeapYear(const int year)
  {
   if((year % 400) == 0)
      return true;
   if((year % 100) == 0)
      return false;
   return ((year % 4) == 0);
  }

int Strategy_DaysInMonth(const int year, const int month)
  {
   if(month == 2)
      return Strategy_IsLeapYear(year) ? 29 : 28;
   if(month == 4 || month == 6 || month == 9 || month == 11)
      return 30;
   return 31;
  }

bool Strategy_IsBusinessDay(const datetime t)
  {
   if(t <= 0)
      return false;
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (dt.day_of_week >= 1 && dt.day_of_week <= 5);
  }

bool Strategy_IsMonthEndExportWindow(const datetime bar_time)
  {
   if(!Strategy_IsBusinessDay(bar_time))
      return false;

   MqlDateTime dt;
   TimeToStruct(bar_time, dt);
   const int days_in_month = Strategy_DaysInMonth(dt.year, dt.mon);
   int business_days_remaining = 0;

   for(int day = dt.day + 1; day <= days_in_month; ++day)
     {
      MqlDateTime candidate = dt;
      candidate.day = day;
      candidate.hour = 12;
      candidate.min = 0;
      candidate.sec = 0;
      const datetime candidate_time = StructToTime(candidate);
      if(Strategy_IsBusinessDay(candidate_time))
         ++business_days_remaining;
     }

   return (business_days_remaining < MathMax(1, strategy_window_business_days));
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

bool Strategy_Channel(const int lookback,
                      const int start_shift,
                      double &highest_high,
                      double &lowest_low)
  {
   highest_high = -DBL_MAX;
   lowest_low = DBL_MAX;

   const int bars = MathMax(2, lookback);
   for(int shift = start_shift; shift < start_shift + bars; ++shift)
     {
      const double high = iHigh(_Symbol, PERIOD_D1, shift); // perf-allowed: bounded D1 channel state behind single new-bar gate.
      const double low = iLow(_Symbol, PERIOD_D1, shift);   // perf-allowed: bounded D1 channel state behind single new-bar gate.
      if(high <= 0.0 || low <= 0.0 || high < low)
         return false;
      highest_high = MathMax(highest_high, high);
      lowest_low = MathMin(lowest_low, low);
     }

   return (highest_high > 0.0 && lowest_low > 0.0 && highest_high >= lowest_low);
  }

bool Strategy_LoadFadeState(int &direction,
                            double &atr_last,
                            int &signal_day_key)
  {
   direction = 0;
   atr_last = 0.0;
   signal_day_key = 0;

   const datetime signal_time = iTime(_Symbol, PERIOD_D1, 1); // perf-allowed: completed D1 export-window calendar state behind new-bar gate.
   if(signal_time <= 0 || !Strategy_IsMonthEndExportWindow(signal_time))
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
   const double sma_last = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_period, 1, PRICE_CLOSE);
   if(atr_last <= 0.0 || sma_last <= 0.0)
      return false;

   const double signal_range = signal_high - signal_low;
   if(signal_range < strategy_min_signal_range_atr * atr_last)
      return false;

   double channel_high = 0.0;
   double channel_low = 0.0;
   if(!Strategy_Channel(strategy_channel_lookback, 2, channel_high, channel_low))
      return false;
   if(channel_high <= channel_low)
      return false;

   const double min_probe = strategy_min_probe_atr * atr_last;
   const double min_tail = strategy_min_tail_ratio * signal_range;
   const double min_stretch = strategy_min_sma_stretch_atr * atr_last;
   const double upper_tail = signal_high - MathMax(signal_open, signal_close);
   const double lower_tail = MathMin(signal_open, signal_close) - signal_low;

   const bool failed_up_probe =
      signal_high > channel_high + min_probe &&
      signal_close < channel_high &&
      signal_close > channel_low &&
      upper_tail >= min_tail &&
      signal_high > sma_last + min_stretch;

   if(failed_up_probe)
     {
      direction = -1;
      signal_day_key = Strategy_DayKey(signal_time);
      return (signal_day_key > 0);
     }

   const bool failed_down_probe =
      signal_low < channel_low - min_probe &&
      signal_close > channel_low &&
      signal_close < channel_high &&
      lower_tail >= min_tail &&
      signal_low < sma_last - min_stretch;

   if(failed_down_probe)
     {
      direction = 1;
      signal_day_key = Strategy_DayKey(signal_time);
      return (signal_day_key > 0);
     }

   return false;
  }

void Strategy_CloseOpenPositionsIfNeeded()
  {
   const int magic = QM_FrameworkMagic();
   const datetime now = TimeCurrent();
   const int hold_seconds = MathMax(1, strategy_max_hold_days) * 86400;
   const double close_last = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: completed D1 exit state behind single new-bar gate.
   const double sma_last = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_period, 1, PRICE_CLOSE);

   double exit_high = 0.0;
   double exit_low = 0.0;
   const bool have_exit_channel = Strategy_Channel(strategy_exit_channel, 2, exit_high, exit_low);

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

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(close_last > 0.0 && sma_last > 0.0)
        {
         if(pos_type == POSITION_TYPE_BUY && close_last >= sma_last)
            should_close = true;
         if(pos_type == POSITION_TYPE_SELL && close_last <= sma_last)
            should_close = true;
        }

      if(have_exit_channel && close_last > 0.0)
        {
         if(pos_type == POSITION_TYPE_BUY && close_last < exit_low)
            should_close = true;
         if(pos_type == POSITION_TYPE_SELL && close_last > exit_high)
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
   if(strategy_window_business_days <= 0 || strategy_window_business_days > 7)
      return true;
   if(strategy_channel_lookback < 10 || strategy_exit_channel < 2)
      return true;
   if(strategy_sma_period <= 1 || strategy_atr_period <= 0)
      return true;
   if(strategy_min_probe_atr <= 0.0 || strategy_min_signal_range_atr <= 0.0)
      return true;
   if(strategy_min_tail_ratio <= 0.0 || strategy_min_tail_ratio >= 1.0)
      return true;
   if(strategy_min_sma_stretch_atr < 0.0)
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
   req.reason = "QM5_13088_XTI_EXPORT_FADE";
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
   int signal_day_key = 0;
   if(!Strategy_LoadFadeState(direction, atr_last, signal_day_key))
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

   req.reason = (direction > 0) ? "XTI_EXPORT_FADE_LONG" : "XTI_EXPORT_FADE_SHORT";
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_13088\",\"ea\":\"xti-export-fade\"}");
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
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   const bool is_new_bar = QM_IsNewBar();
   if(is_new_bar)
     {
      QM_EquityStreamOnNewBar();
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
     }

   if(Strategy_NewsFilterHook(broker_now))
      return;

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!is_new_bar)
      return;

   QM_EntryRequest req;
   ZeroMemory(req);
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
