#property strict
#property version   "5.0"
#property description "QM5_13042 XTI distillate draw pressure momentum"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_13042 - XTI Distillate Draw Pressure Momentum
// -----------------------------------------------------------------------------
// D1 structural WTI sleeve:
//   - uses Wednesday/Thursday as the weekly EIA distillate-stock WPSR proxy
//   - requires a short pullback, bullish winter reaction, and rising SMA
//   - ATR stop/target, SMA/season/time exits, no external runtime data
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 13042;
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
input int    strategy_season_start_month   = 10;
input int    strategy_season_end_month     = 3;
input int    strategy_report_start_dow     = 3;
input int    strategy_report_end_dow       = 4;
input int    strategy_pullback_lookback    = 4;
input double strategy_min_pullback_atr     = 0.30;
input int    strategy_sma_period           = 60;
input int    strategy_sma_slope_shift      = 5;
input int    strategy_atr_period           = 20;
input double strategy_min_range_atr        = 0.60;
input double strategy_min_body_atr         = 0.18;
input double strategy_min_close_location   = 0.66;
input double strategy_atr_sl_mult          = 2.75;
input double strategy_atr_tp_mult          = 2.50;
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

bool Strategy_MonthInWindow(const int month, const int start_month, const int end_month)
  {
   if(month < 1 || month > 12 || start_month < 1 || start_month > 12 || end_month < 1 || end_month > 12)
      return false;
   if(start_month <= end_month)
      return (month >= start_month && month <= end_month);
   return (month >= start_month || month <= end_month);
  }

bool Strategy_IsHeatingSeason(const datetime t)
  {
   if(t <= 0)
      return false;
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return Strategy_MonthInWindow(dt.mon, strategy_season_start_month, strategy_season_end_month);
  }

bool Strategy_DowInWindow(const int dow, const int start_dow, const int end_dow)
  {
   if(dow < 0 || dow > 6 || start_dow < 0 || start_dow > 6 || end_dow < 0 || end_dow > 6)
      return false;
   if(start_dow <= end_dow)
      return (dow >= start_dow && dow <= end_dow);
   return (dow >= start_dow || dow <= end_dow);
  }

bool Strategy_IsReportProxyDay(const datetime t)
  {
   if(t <= 0)
      return false;
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return Strategy_DowInWindow(dt.day_of_week, strategy_report_start_dow, strategy_report_end_dow);
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

bool Strategy_LoadDistillatePressureState(double &atr_last, int &signal_day_key)
  {
   atr_last = 0.0;
   signal_day_key = 0;

   const datetime signal_time = iTime(_Symbol, PERIOD_D1, 1); // perf-allowed: completed D1 calendar state behind new-bar gate.
   if(signal_time <= 0 || !Strategy_IsReportProxyDay(signal_time))
      return false;
   if(!Strategy_IsHeatingSeason(signal_time) || !Strategy_IsHeatingSeason(TimeCurrent()))
      return false;

   const double signal_open = iOpen(_Symbol, PERIOD_D1, 1);   // perf-allowed: completed D1 signal bar.
   const double signal_high = iHigh(_Symbol, PERIOD_D1, 1);   // perf-allowed: completed D1 signal bar.
   const double signal_low = iLow(_Symbol, PERIOD_D1, 1);     // perf-allowed: completed D1 signal bar.
   const double signal_close = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: completed D1 signal bar.
   if(signal_open <= 0.0 || signal_high <= 0.0 || signal_low <= 0.0 || signal_close <= 0.0)
      return false;
   if(signal_high <= signal_low || signal_close <= signal_open)
      return false;

   atr_last = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   const double sma_last = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_period, 1, PRICE_CLOSE);
   const double sma_past = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_period, 1 + strategy_sma_slope_shift, PRICE_CLOSE);
   if(atr_last <= 0.0 || sma_last <= 0.0 || sma_past <= 0.0)
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
   if(signal_close <= sma_last || sma_last <= sma_past)
      return false;

   const int pre_start_shift = 1 + MathMax(2, strategy_pullback_lookback);
   const double pre_start_close = iClose(_Symbol, PERIOD_D1, pre_start_shift); // perf-allowed: compact D1 pullback state.
   const double pre_end_close = iClose(_Symbol, PERIOD_D1, 2);                 // perf-allowed: compact D1 pullback state.
   if(pre_start_close <= 0.0 || pre_end_close <= 0.0)
      return false;
   const double pullback = pre_start_close - pre_end_close;
   if(pullback < strategy_min_pullback_atr * atr_last)
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

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(pos_type != POSITION_TYPE_BUY)
         should_close = true;
      if(!Strategy_IsHeatingSeason(now))
         should_close = true;
      if(close_last > 0.0 && sma_last > 0.0 && close_last < sma_last)
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
   if(strategy_season_start_month < 1 || strategy_season_start_month > 12 || strategy_season_end_month < 1 || strategy_season_end_month > 12)
      return true;
   if(strategy_report_start_dow < 0 || strategy_report_start_dow > 6 || strategy_report_end_dow < 0 || strategy_report_end_dow > 6)
      return true;
   if(strategy_pullback_lookback < 2)
      return true;
   if(strategy_sma_period <= 1 || strategy_sma_slope_shift <= 0 || strategy_atr_period <= 1)
      return true;
   if(strategy_min_pullback_atr <= 0.0 || strategy_min_range_atr <= 0.0 || strategy_min_body_atr <= 0.0)
      return true;
   if(strategy_min_close_location <= 0.0 || strategy_min_close_location >= 1.0)
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
   req.reason = "QM5_13042_XTI_DISTDRAW_MOM";
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
   if(!Strategy_LoadDistillatePressureState(atr_last, signal_day_key))
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

   req.reason = "XTI_DISTDRAW_MOM_LONG";
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_13042\",\"ea\":\"xti-distdraw-mom\"}");
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
