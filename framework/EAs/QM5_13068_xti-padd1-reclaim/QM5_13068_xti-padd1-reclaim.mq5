#property strict
#property version   "5.0"
#property description "QM5_13068 EIA PADD1 WTI failed-breakdown reclaim"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_13068 - EIA PADD 1 WTI Failed-Breakdown Reclaim
// -----------------------------------------------------------------------------
// D1 structural WTI sleeve:
//   - official EIA East Coast PADD 1 crude-stock source lineage
//   - deterministic Jan-Mar and Oct-Dec post-WPSR proxy window
//   - long-only failed-breakdown D1 range reclaim with rising SMA trend filter
//   - ATR stop/target, max-hold exit, no external runtime data
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 13068;
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
input int    strategy_season_start_month_a = 1;
input int    strategy_season_end_month_a   = 3;
input int    strategy_season_start_month_b = 10;
input int    strategy_season_end_month_b   = 12;
input int    strategy_report_start_dow     = 4;
input int    strategy_report_end_dow       = 5;
input int    strategy_context_lookback     = 16;
input int    strategy_sma_period           = 34;
input int    strategy_slow_sma_period      = 100;
input int    strategy_sma_slope_shift      = 5;
input int    strategy_atr_period           = 20;
input double strategy_min_range_atr        = 0.45;
input double strategy_min_body_atr         = 0.10;
input double strategy_min_probe_atr        = 0.05;
input double strategy_min_close_location   = 0.55;
input double strategy_atr_sl_mult          = 2.20;
input double strategy_atr_tp_mult          = 2.80;
input int    strategy_max_hold_days        = 7;
input int    strategy_max_spread_points    = 1000;

int g_last_signal_month_key = 0;

bool Strategy_IsXtiD1()
  {
   return (_Symbol == "XTIUSD.DWX" && _Period == PERIOD_D1);
  }

int Strategy_MonthKey(const datetime t)
  {
   if(t <= 0)
      return 0;
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 100 + dt.mon;
  }

bool Strategy_MonthInRange(const int month,
                           const int start_month,
                           const int end_month)
  {
   if(month < 1 || month > 12 || start_month < 1 || start_month > 12 ||
      end_month < 1 || end_month > 12)
      return false;

   if(start_month <= end_month)
      return (month >= start_month && month <= end_month);
   return (month >= start_month || month <= end_month);
  }

bool Strategy_IsPadd1ReclaimSeason(const datetime t)
  {
   if(t <= 0)
      return false;

   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (Strategy_MonthInRange(dt.mon, strategy_season_start_month_a, strategy_season_end_month_a) ||
           Strategy_MonthInRange(dt.mon, strategy_season_start_month_b, strategy_season_end_month_b));
  }

bool Strategy_DowInRange(const int dow,
                         const int start_dow,
                         const int end_dow)
  {
   if(dow < 0 || dow > 6 || start_dow < 0 || start_dow > 6 ||
      end_dow < 0 || end_dow > 6)
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
   return Strategy_DowInRange(dt.day_of_week, strategy_report_start_dow, strategy_report_end_dow);
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

bool Strategy_ContextRange(double &context_high,
                           double &context_low)
  {
   context_high = -DBL_MAX;
   context_low = DBL_MAX;

   const int lookback = MathMax(5, strategy_context_lookback);
   for(int shift = 2; shift < lookback + 2; ++shift)
     {
      const double high = iHigh(_Symbol, PERIOD_D1, shift); // perf-allowed: compact D1 context loop behind new-bar gate.
      const double low = iLow(_Symbol, PERIOD_D1, shift);   // perf-allowed: compact D1 context loop behind new-bar gate.
      if(high <= 0.0 || low <= 0.0 || high < low)
         return false;
      context_high = MathMax(context_high, high);
      context_low = MathMin(context_low, low);
     }

   return (context_high > 0.0 && context_low > 0.0 && context_high >= context_low);
  }

bool Strategy_LoadReclaimState(double &atr_last,
                               int &signal_month_key)
  {
   atr_last = 0.0;
   signal_month_key = 0;

   const datetime event_time = iTime(_Symbol, PERIOD_D1, 1); // perf-allowed: completed D1 event calendar state behind new-bar gate.
   if(event_time <= 0 || !Strategy_IsPadd1ReclaimSeason(event_time) || !Strategy_IsReportProxyDay(event_time))
      return false;

   const double event_open = iOpen(_Symbol, PERIOD_D1, 1);   // perf-allowed: completed D1 event bar.
   const double event_high = iHigh(_Symbol, PERIOD_D1, 1);   // perf-allowed: completed D1 event bar.
   const double event_low = iLow(_Symbol, PERIOD_D1, 1);     // perf-allowed: completed D1 event bar.
   const double event_close = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: completed D1 event bar.
   if(event_open <= 0.0 || event_high <= 0.0 || event_low <= 0.0 || event_close <= 0.0)
      return false;
   if(event_high <= event_low)
      return false;
   if(event_close <= event_open)
      return false;

   atr_last = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   const double sma_fast = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_period, 1, PRICE_CLOSE);
   const double sma_fast_prior = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_period,
                                       1 + strategy_sma_slope_shift, PRICE_CLOSE);
   const double sma_slow = QM_SMA(_Symbol, PERIOD_D1, strategy_slow_sma_period, 1, PRICE_CLOSE);
   if(atr_last <= 0.0 || sma_fast <= 0.0 || sma_fast_prior <= 0.0 || sma_slow <= 0.0)
      return false;

   const double event_range = event_high - event_low;
   const double event_body = MathAbs(event_close - event_open);
   if(event_range < strategy_min_range_atr * atr_last)
      return false;
   if(event_body < strategy_min_body_atr * atr_last)
      return false;

   if(event_close <= sma_fast)
      return false;
   if(sma_fast <= sma_slow)
      return false;
   if(sma_fast <= sma_fast_prior)
      return false;

   double context_high = 0.0;
   double context_low = 0.0;
   if(!Strategy_ContextRange(context_high, context_low))
      return false;

   const double close_location = (event_close - event_low) / event_range;
   const double probe = strategy_min_probe_atr * atr_last;

   const bool failed_downside =
      event_low <= context_low - probe &&
      event_close >= context_low &&
      close_location >= strategy_min_close_location;
   if(!failed_downside)
      return false;

   signal_month_key = Strategy_MonthKey(event_time);
   return (signal_month_key > 0);
  }

void Strategy_CloseOpenPositionsIfNeeded()
  {
   const int magic = QM_FrameworkMagic();
   const datetime now = TimeCurrent();
   const int hold_seconds = MathMax(1, strategy_max_hold_days) * 86400;
   const bool in_season_now = Strategy_IsPadd1ReclaimSeason(now);
   const double close_last = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: completed D1 management bar.
   const double sma_fast = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_period, 1, PRICE_CLOSE);

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

      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY)
         should_close = true;

      if(!in_season_now)
         should_close = true;

      if(close_last > 0.0 && sma_fast > 0.0 && close_last < sma_fast)
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
   if(strategy_season_start_month_a < 1 || strategy_season_start_month_a > 12)
      return true;
   if(strategy_season_end_month_a < 1 || strategy_season_end_month_a > 12)
      return true;
   if(strategy_season_start_month_b < 1 || strategy_season_start_month_b > 12)
      return true;
   if(strategy_season_end_month_b < 1 || strategy_season_end_month_b > 12)
      return true;
   if(strategy_report_start_dow < 0 || strategy_report_start_dow > 6)
      return true;
   if(strategy_report_end_dow < 0 || strategy_report_end_dow > 6)
      return true;
   if(strategy_context_lookback < 5)
      return true;
   if(strategy_sma_period <= 1)
      return true;
   if(strategy_slow_sma_period <= strategy_sma_period)
      return true;
   if(strategy_sma_slope_shift <= 0)
      return true;
   if(strategy_atr_period <= 1)
      return true;
   if(strategy_min_range_atr <= 0.0 || strategy_min_body_atr < 0.0 || strategy_min_probe_atr < 0.0)
      return true;
   if(strategy_min_close_location < 0.0 || strategy_min_close_location > 1.0)
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
   req.reason = "QM5_13068_XTI_PADD1_RECLAIM";
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
   int signal_month_key = 0;
   if(!Strategy_LoadReclaimState(atr_last, signal_month_key))
      return false;
   if(signal_month_key <= 0 || signal_month_key == g_last_signal_month_key)
      return false;

   req.type = QM_BUY;
   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0)
      return false;

   req.sl = QM_StopATRFromValue(_Symbol, req.type, entry_price, atr_last, strategy_atr_sl_mult);
   req.sl = QM_StopRulesNormalizePrice(_Symbol, req.sl);
   if(req.sl >= entry_price)
      return false;

   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   req.tp = NormalizeDouble(entry_price + strategy_atr_tp_mult * atr_last, digits);
   req.tp = QM_StopRulesNormalizePrice(_Symbol, req.tp);
   if(req.tp <= entry_price)
      return false;

   req.reason = "XTI_PADD1_FAILED_BREAKDOWN_LONG";
   g_last_signal_month_key = signal_month_key;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_13068\",\"ea\":\"xti-padd1-reclaim\"}");
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
