#property strict
#property version   "5.0"
#property description "QM5_13048 WTI ETF-roll compression breakout"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_13048 - WTI ETF Roll-Window Squeeze Breakout
// -----------------------------------------------------------------------------
// D1 structural WTI sleeve:
//   - uses the CFTC crude-oil ETF-roll source as a fixed early-month flow clock
//   - requires pre-signal D1 compression before a closed-bar channel breakout
//   - ATR stop/target, SMA/window/time exits, no external runtime data
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 13048;
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
input int    strategy_roll_start_trading_day = 5;
input int    strategy_roll_end_trading_day   = 9;
input int    strategy_exit_last_trading_day  = 12;
input int    strategy_compression_lookback   = 8;
input int    strategy_atr_period             = 20;
input double strategy_max_compression_atr    = 1.05;
input double strategy_min_signal_range_atr   = 0.45;
input double strategy_min_body_ratio         = 0.25;
input double strategy_min_break_atr          = 0.05;
input double strategy_long_min_close_location = 0.62;
input double strategy_short_max_close_location = 0.38;
input int    strategy_exit_sma_period        = 20;
input double strategy_atr_sl_mult            = 2.75;
input double strategy_atr_tp_mult            = 3.25;
input int    strategy_max_hold_days          = 6;
input int    strategy_max_spread_points      = 1000;

int g_last_entry_month_key = 0;
int g_last_signal_day_key = 0;

bool Strategy_IsXtiD1()
  {
   return (_Symbol == "XTIUSD.DWX" && _Period == PERIOD_D1);
  }

int Strategy_MonthKeyFromTime(const datetime t)
  {
   if(t <= 0)
      return 0;
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 100 + dt.mon;
  }

int Strategy_TradingDayOfMonth(const int target_shift)
  {
   const int target_month_key = QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, target_shift);
   const int target_day_key = QM_CalendarPeriodKey(PERIOD_D1, _Symbol, target_shift);
   if(target_month_key <= 0 || target_day_key <= 0)
      return 0;

   int count = 0;
   for(int shift = 0; shift < 80; ++shift)
     {
      const int month_key = QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, shift);
      if(month_key <= 0 || month_key < target_month_key)
         break;
      if(month_key != target_month_key)
         continue;

      const int day_key = QM_CalendarPeriodKey(PERIOD_D1, _Symbol, shift);
      if(day_key > 0 && day_key <= target_day_key)
         ++count;
     }

   return count;
  }

bool Strategy_InRollWindow(const int shift)
  {
   const int td = Strategy_TradingDayOfMonth(shift);
   return (td >= strategy_roll_start_trading_day && td <= strategy_roll_end_trading_day);
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

bool Strategy_PreSignalRange(const int signal_shift,
                             double &range_high,
                             double &range_low)
  {
   range_high = -DBL_MAX;
   range_low = DBL_MAX;

   const int lookback = MathMax(3, strategy_compression_lookback);
   for(int shift = signal_shift + 1; shift <= signal_shift + lookback; ++shift)
     {
      const double high = iHigh(_Symbol, PERIOD_D1, shift); // perf-allowed: compact D1 pre-roll compression loop, new-bar gated.
      const double low = iLow(_Symbol, PERIOD_D1, shift);   // perf-allowed: compact D1 pre-roll compression loop, new-bar gated.
      if(high <= 0.0 || low <= 0.0 || high < low)
         return false;
      range_high = MathMax(range_high, high);
      range_low = MathMin(range_low, low);
     }

   return (range_high > 0.0 && range_low > 0.0 && range_high >= range_low);
  }

bool Strategy_LoadSqueezeState(int &direction,
                               double &atr_last,
                               int &signal_day_key)
  {
   direction = 0;
   atr_last = 0.0;
   signal_day_key = 0;

   if(!Strategy_InRollWindow(1))
      return false;

   signal_day_key = QM_CalendarPeriodKey(PERIOD_D1, _Symbol, 1);
   if(signal_day_key <= 0)
      return false;

   const double signal_open = iOpen(_Symbol, PERIOD_D1, 1);   // perf-allowed: completed D1 roll-window signal bar.
   const double signal_high = iHigh(_Symbol, PERIOD_D1, 1);   // perf-allowed: completed D1 roll-window signal bar.
   const double signal_low = iLow(_Symbol, PERIOD_D1, 1);     // perf-allowed: completed D1 roll-window signal bar.
   const double signal_close = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: completed D1 roll-window signal bar.
   if(signal_open <= 0.0 || signal_high <= 0.0 || signal_low <= 0.0 || signal_close <= 0.0)
      return false;
   if(signal_high <= signal_low)
      return false;

   atr_last = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr_last <= 0.0)
      return false;

   const double signal_range = signal_high - signal_low;
   const double signal_body = MathAbs(signal_close - signal_open);
   if(signal_range < strategy_min_signal_range_atr * atr_last)
      return false;
   if(signal_body < strategy_min_body_ratio * signal_range)
      return false;

   double pre_high = 0.0;
   double pre_low = 0.0;
   if(!Strategy_PreSignalRange(1, pre_high, pre_low))
      return false;

   const int lookback = MathMax(3, strategy_compression_lookback);
   const double pre_width = pre_high - pre_low;
   const double max_width = strategy_max_compression_atr * atr_last * MathSqrt((double)lookback);
   if(pre_width <= 0.0 || pre_width > max_width)
      return false;

   const double close_location = (signal_close - signal_low) / signal_range;
   const double min_break = strategy_min_break_atr * atr_last;

   const bool upside_break =
      signal_close >= pre_high + min_break &&
      close_location >= strategy_long_min_close_location;

   const bool downside_break =
      signal_close <= pre_low - min_break &&
      close_location <= strategy_short_max_close_location;

   if(upside_break && !downside_break)
      direction = 1;
   else if(downside_break && !upside_break)
      direction = -1;
   else
      return false;

   return true;
  }

void Strategy_CloseOpenPositionsIfNeeded()
  {
   const int current_td = Strategy_TradingDayOfMonth(0);
   const int current_month_key = QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 0);
   const double close_last = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: completed D1 SMA failure exit state.
   const double sma_last = QM_SMA(_Symbol, PERIOD_D1, strategy_exit_sma_period, 1, PRICE_CLOSE);

   const int magic = QM_FrameworkMagic();
   const datetime now = TimeCurrent();
   const int hold_seconds = MathMax(1, strategy_max_hold_days) * 86400;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      const int opened_month_key = Strategy_MonthKeyFromTime(opened);
      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      bool should_close = false;

      if(current_td > strategy_exit_last_trading_day)
         should_close = true;
      if(opened_month_key > 0 && current_month_key > 0 && opened_month_key != current_month_key)
         should_close = true;
      if(opened > 0 && now - opened >= hold_seconds)
         should_close = true;
      if(pos_type != POSITION_TYPE_BUY && pos_type != POSITION_TYPE_SELL)
         should_close = true;
      if(close_last > 0.0 && sma_last > 0.0 && pos_type == POSITION_TYPE_BUY && close_last < sma_last)
         should_close = true;
      if(close_last > 0.0 && sma_last > 0.0 && pos_type == POSITION_TYPE_SELL && close_last > sma_last)
         should_close = true;

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
   if(strategy_roll_start_trading_day < 1 || strategy_roll_end_trading_day < strategy_roll_start_trading_day)
      return true;
   if(strategy_roll_end_trading_day > 23)
      return true;
   if(strategy_exit_last_trading_day < strategy_roll_end_trading_day)
      return true;
   if(strategy_exit_last_trading_day > 23)
      return true;
   if(strategy_compression_lookback < 3 || strategy_compression_lookback > 60)
      return true;
   if(strategy_atr_period <= 1 || strategy_exit_sma_period <= 1)
      return true;
   if(strategy_max_compression_atr <= 0.0 || strategy_min_signal_range_atr <= 0.0)
      return true;
   if(strategy_min_body_ratio < 0.0 || strategy_min_body_ratio > 1.0)
      return true;
   if(strategy_min_break_atr < 0.0)
      return true;
   if(strategy_long_min_close_location < 0.0 || strategy_long_min_close_location > 1.0)
      return true;
   if(strategy_short_max_close_location < 0.0 || strategy_short_max_close_location > 1.0)
      return true;
   if(strategy_short_max_close_location > strategy_long_min_close_location)
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
   req.reason = "QM5_13048_WTI_ROLL_SQUEEZE";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   Strategy_CloseOpenPositionsIfNeeded();

   if(Strategy_HasOpenPosition())
      return false;

   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return false;
     }

   const int current_month_key = QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 0);
   if(current_month_key <= 0 || current_month_key == g_last_entry_month_key)
      return false;

   int direction = 0;
   double atr_last = 0.0;
   int signal_day_key = 0;
   if(!Strategy_LoadSqueezeState(direction, atr_last, signal_day_key))
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

   req.reason = (direction > 0) ? "XTI_ROLL_SQUEEZE_BREAKOUT_LONG" : "XTI_ROLL_SQUEEZE_BREAKDOWN_SHORT";
   g_last_signal_day_key = signal_day_key;
   g_last_entry_month_key = current_month_key;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_13048\",\"ea\":\"wti-roll-squeeze\"}");
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

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

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
