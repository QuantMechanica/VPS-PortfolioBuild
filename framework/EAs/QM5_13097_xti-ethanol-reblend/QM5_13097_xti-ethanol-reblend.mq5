#property strict
#property version   "5.0"
#property description "QM5_13097 XTI ethanol reblend pullback-reclaim"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_13097 - XTI Ethanol Reblend Pullback-Reclaim
// -----------------------------------------------------------------------------
// D1 structural WTI sleeve:
//   - trades only in the late-April to mid-June ethanol/gasoline reblend window
//   - requires a pullback below SMA followed by a bullish SMA reclaim
//   - ATR stop/target, SMA/window/time exits, no external runtime data
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 13097;
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
input int    strategy_window_start_month  = 4;
input int    strategy_window_start_day    = 20;
input int    strategy_window_end_month    = 6;
input int    strategy_window_end_day      = 15;
input int    strategy_pullback_lookback   = 12;
input double strategy_min_pullback_atr    = 0.60;
input int    strategy_sma_period          = 40;
input int    strategy_sma_slope_lag_days  = 5;
input double strategy_max_sma_fall_atr    = 0.10;
input int    strategy_atr_period          = 20;
input double strategy_min_range_atr       = 0.55;
input double strategy_min_body_atr        = 0.22;
input double strategy_min_close_location  = 0.62;
input double strategy_exit_sma_buffer_atr = 0.10;
input double strategy_atr_sl_mult         = 2.4;
input double strategy_atr_tp_mult         = 3.0;
input int    strategy_max_hold_days       = 12;
input int    strategy_max_spread_points   = 1000;

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

bool Strategy_ValidMonthDay(const int month, const int day)
  {
   if(month < 1 || month > 12 || day < 1 || day > 31)
      return false;
   return true;
  }

bool Strategy_DateInWindow(const datetime t)
  {
   if(t <= 0)
      return false;
   if(!Strategy_ValidMonthDay(strategy_window_start_month, strategy_window_start_day))
      return false;
   if(!Strategy_ValidMonthDay(strategy_window_end_month, strategy_window_end_day))
      return false;

   MqlDateTime dt;
   TimeToStruct(t, dt);
   const int md = dt.mon * 100 + dt.day;
   const int start_md = strategy_window_start_month * 100 + strategy_window_start_day;
   const int end_md = strategy_window_end_month * 100 + strategy_window_end_day;

   if(start_md <= end_md)
      return (md >= start_md && md <= end_md);
   return (md >= start_md || md <= end_md);
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

bool Strategy_LoadReblendState(double &atr_last, int &signal_day_key)
  {
   atr_last = 0.0;
   signal_day_key = 0;

   const datetime signal_time = iTime(_Symbol, PERIOD_D1, 1); // perf-allowed: completed D1 calendar state behind new-bar gate.
   if(signal_time <= 0 || !Strategy_DateInWindow(signal_time))
      return false;
   if(!Strategy_DateInWindow(TimeCurrent()))
      return false;

   const double signal_open = iOpen(_Symbol, PERIOD_D1, 1);   // perf-allowed: completed D1 signal bar.
   const double signal_high = iHigh(_Symbol, PERIOD_D1, 1);   // perf-allowed: completed D1 signal bar.
   const double signal_low = iLow(_Symbol, PERIOD_D1, 1);     // perf-allowed: completed D1 signal bar.
   const double signal_close = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: completed D1 signal bar.
   const double prior_close = iClose(_Symbol, PERIOD_D1, 2);  // perf-allowed: completed D1 reclaim context.
   if(signal_open <= 0.0 || signal_high <= 0.0 || signal_low <= 0.0 || signal_close <= 0.0 || prior_close <= 0.0)
      return false;
   if(signal_high <= signal_low || signal_close <= signal_open)
      return false;

   atr_last = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   const double sma_last = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_period, 1, PRICE_CLOSE);
   const double sma_prior = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_period, 2, PRICE_CLOSE);
   const double sma_past = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_period, 1 + strategy_sma_slope_lag_days, PRICE_CLOSE);
   if(atr_last <= 0.0 || sma_last <= 0.0 || sma_prior <= 0.0 || sma_past <= 0.0)
      return false;

   if(prior_close > sma_prior)
      return false;
   if(signal_close <= sma_last)
      return false;
   if((sma_past - sma_last) > strategy_max_sma_fall_atr * atr_last)
      return false;

   const double signal_range = signal_high - signal_low;
   const double signal_body = MathAbs(signal_close - signal_open);
   const double close_location = (signal_close - signal_low) / signal_range;
   if(signal_range < strategy_min_range_atr * atr_last)
      return false;
   if(signal_body < strategy_min_body_atr * atr_last)
      return false;
   if(close_location < strategy_min_close_location)
      return false;

   const int pullback_lookback = MathMax(2, strategy_pullback_lookback);
   double pullback_low = DBL_MAX;
   for(int shift = 2; shift <= 1 + pullback_lookback; ++shift)
     {
      const double bar_low = iLow(_Symbol, PERIOD_D1, shift); // perf-allowed: compact D1 pullback state.
      if(bar_low <= 0.0)
         return false;
      if(bar_low < pullback_low)
         pullback_low = bar_low;
     }
   if(pullback_low == DBL_MAX)
      return false;
   if((sma_last - pullback_low) < strategy_min_pullback_atr * atr_last)
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
   const double atr_last = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
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

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(pos_type != POSITION_TYPE_BUY)
         should_close = true;
      if(!Strategy_DateInWindow(now))
         should_close = true;
      if(close_last > 0.0 && sma_last > 0.0 && atr_last > 0.0)
        {
         const double exit_level = sma_last - strategy_exit_sma_buffer_atr * atr_last;
         if(close_last < exit_level)
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
   if(!Strategy_ValidMonthDay(strategy_window_start_month, strategy_window_start_day))
      return true;
   if(!Strategy_ValidMonthDay(strategy_window_end_month, strategy_window_end_day))
      return true;
   if(strategy_pullback_lookback < 2)
      return true;
   if(strategy_sma_period <= 1 || strategy_sma_slope_lag_days <= 0 || strategy_atr_period <= 1)
      return true;
   if(strategy_min_pullback_atr <= 0.0 || strategy_min_range_atr <= 0.0 || strategy_min_body_atr <= 0.0)
      return true;
   if(strategy_min_close_location <= 0.0 || strategy_min_close_location >= 1.0)
      return true;
   if(strategy_max_sma_fall_atr < 0.0 || strategy_exit_sma_buffer_atr < 0.0)
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
   req.reason = "QM5_13097_XTI_ETHANOL_REBLEND";
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

   double atr_last = 0.0;
   int signal_day_key = 0;
   if(!Strategy_LoadReblendState(atr_last, signal_day_key))
      return false;
   if(signal_day_key <= 0 || signal_day_key == g_last_signal_day_key)
      return false;

   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0)
      return false;

   req.sl = QM_StopATRFromValue(_Symbol, req.type, entry_price, atr_last, strategy_atr_sl_mult);
   req.sl = QM_StopRulesNormalizePrice(_Symbol, req.sl);
   if(req.sl <= 0.0 || req.sl >= entry_price)
      return false;

   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   req.tp = NormalizeDouble(entry_price + strategy_atr_tp_mult * atr_last, digits);
   req.tp = QM_StopRulesNormalizePrice(_Symbol, req.tp);
   if(req.tp <= 0.0 || req.tp <= entry_price)
      return false;

   req.reason = "XTI_ETHANOL_REBLEND_LONG";
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_13097\",\"ea\":\"xti-ethanol-reblend\"}");
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

   if(!QM_IsNewBar())
      return;

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
