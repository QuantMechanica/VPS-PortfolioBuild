#property strict
#property version   "5.0"
#property description "QM5_13037 XNG EIA dry-production compression breakout"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_13037 - XNG EIA Dry-Production Compression Breakout
// -----------------------------------------------------------------------------
// D1 structural natural gas sleeve:
//   - uses the late-month EIA Natural Gas Monthly dry-production update window
//   - requires pre-signal D1 compression before a trend-aligned Donchian break
//   - ATR stop/target, channel/trend/time exits, no external runtime data
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 13037;
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
input int    strategy_event_day_min         = 25;
input int    strategy_event_day_max         = 31;
input int    strategy_compression_lookback  = 12;
input int    strategy_entry_channel         = 34;
input int    strategy_exit_channel          = 13;
input int    strategy_trend_period          = 80;
input int    strategy_sma_slope_shift       = 5;
input int    strategy_atr_period            = 20;
input double strategy_max_compression_atr   = 1.05;
input double strategy_min_signal_range_atr  = 0.80;
input double strategy_min_body_ratio        = 0.30;
input double strategy_atr_sl_mult           = 3.25;
input double strategy_atr_tp_mult           = 4.00;
input int    strategy_max_hold_days         = 10;
input int    strategy_max_spread_points     = 2500;

int g_last_entry_month_key = 0;
int g_entry_candidate_month_key = 0;

bool Strategy_IsXngD1()
  {
   return (_Symbol == "XNGUSD.DWX" && _Period == PERIOD_D1);
  }

int Strategy_MonthKey(const datetime t)
  {
   if(t <= 0)
      return 0;

   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 100 + dt.mon;
  }

bool Strategy_IsProductionWindowDay(const datetime t)
  {
   if(t <= 0)
      return false;

   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (dt.day >= strategy_event_day_min && dt.day <= strategy_event_day_max);
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

bool Strategy_ChannelRange(const int lookback,
                           const int start_shift,
                           double &highest_high,
                           double &lowest_low)
  {
   highest_high = -DBL_MAX;
   lowest_low = DBL_MAX;

   const int bars = MathMax(2, lookback);
   for(int shift = start_shift; shift < start_shift + bars; ++shift)
     {
      const double high = iHigh(_Symbol, PERIOD_D1, shift); // perf-allowed: bounded D1 structural channel read behind single new-bar gate.
      const double low = iLow(_Symbol, PERIOD_D1, shift);   // perf-allowed: bounded D1 structural channel read behind single new-bar gate.
      if(high <= 0.0 || low <= 0.0 || high < low)
         return false;
      highest_high = MathMax(highest_high, high);
      lowest_low = MathMin(lowest_low, low);
     }

   return (highest_high > 0.0 && lowest_low > 0.0 && highest_high >= lowest_low);
  }

bool Strategy_CompressionOK(const double atr_last)
  {
   if(atr_last <= 0.0)
      return false;

   double compression_high = 0.0;
   double compression_low = 0.0;
   if(!Strategy_ChannelRange(strategy_compression_lookback, 2, compression_high, compression_low))
      return false;

   const double compression_range = compression_high - compression_low;
   const double scaled_atr = atr_last * MathSqrt((double)MathMax(2, strategy_compression_lookback));
   return (compression_range <= strategy_max_compression_atr * scaled_atr);
  }

bool Strategy_LoadDryProductionBreakoutState(int &direction,
                                             double &atr_last,
                                             int &signal_month_key)
  {
   direction = 0;
   atr_last = 0.0;
   signal_month_key = 0;

   const datetime signal_time = iTime(_Symbol, PERIOD_D1, 1); // perf-allowed: completed D1 dry-production calendar state behind single new-bar gate.
   if(signal_time <= 0 || !Strategy_IsProductionWindowDay(signal_time))
      return false;

   signal_month_key = Strategy_MonthKey(signal_time);
   if(signal_month_key <= 0 || signal_month_key == g_last_entry_month_key)
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
   const double sma_last = QM_SMA(_Symbol, PERIOD_D1, strategy_trend_period, 1, PRICE_CLOSE);
   const double sma_prior = QM_SMA(_Symbol, PERIOD_D1, strategy_trend_period, 1 + strategy_sma_slope_shift, PRICE_CLOSE);
   if(atr_last <= 0.0 || sma_last <= 0.0 || sma_prior <= 0.0)
      return false;

   if(!Strategy_CompressionOK(atr_last))
      return false;

   const double signal_range = signal_high - signal_low;
   const double signal_body = MathAbs(signal_close - signal_open);
   if(signal_range < strategy_min_signal_range_atr * atr_last)
      return false;
   if(signal_body < strategy_min_body_ratio * signal_range)
      return false;

   double channel_high = 0.0;
   double channel_low = 0.0;
   if(!Strategy_ChannelRange(strategy_entry_channel, 2, channel_high, channel_low))
      return false;

   if(signal_close > signal_open &&
      signal_close > channel_high &&
      signal_close > sma_last &&
      sma_last > sma_prior)
      direction = 1;
   else if(signal_close < signal_open &&
           signal_close < channel_low &&
           signal_close < sma_last &&
           sma_last < sma_prior)
      direction = -1;
   else
      return false;

   return true;
  }

void Strategy_CloseOpenPositionsIfNeeded()
  {
   const int magic = QM_FrameworkMagic();
   const datetime now = TimeCurrent();
   const int hold_seconds = MathMax(1, strategy_max_hold_days) * 86400;
   const double close_last = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: D1 channel/trend exit behind single new-bar gate.
   const double sma_last = QM_SMA(_Symbol, PERIOD_D1, strategy_trend_period, 1, PRICE_CLOSE);

   double exit_high = 0.0;
   double exit_low = 0.0;
   const bool has_exit_channel = Strategy_ChannelRange(strategy_exit_channel, 2, exit_high, exit_low);

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
         if(pos_type == POSITION_TYPE_BUY)
           {
            if(close_last < sma_last)
               should_close = true;
            if(has_exit_channel && close_last < exit_low)
               should_close = true;
           }
         if(pos_type == POSITION_TYPE_SELL)
           {
            if(close_last > sma_last)
               should_close = true;
            if(has_exit_channel && close_last > exit_high)
               should_close = true;
           }
        }

      if(should_close)
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsXngD1())
      return true;
   if(qm_magic_slot_offset != 0)
      return true;
   if(strategy_event_day_min < 1 || strategy_event_day_min > 31)
      return true;
   if(strategy_event_day_max < 1 || strategy_event_day_max > 31)
      return true;
   if(strategy_event_day_min > strategy_event_day_max)
      return true;
   if(strategy_compression_lookback < 2 || strategy_entry_channel < 5 || strategy_exit_channel < 2)
      return true;
   if(strategy_trend_period <= 1 || strategy_sma_slope_shift <= 0 || strategy_atr_period <= 1)
      return true;
   if(strategy_max_compression_atr <= 0.0 || strategy_min_signal_range_atr <= 0.0 || strategy_min_body_ratio <= 0.0)
      return true;
   if(strategy_min_body_ratio > 1.0)
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
   req.reason = "QM5_13037_XNG_PROD_BRK";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   g_entry_candidate_month_key = 0;

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
   int signal_month_key = 0;
   if(!Strategy_LoadDryProductionBreakoutState(direction, atr_last, signal_month_key))
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

   req.reason = (direction > 0) ? "XNG_DRYPROD_BRK_LONG" : "XNG_DRYPROD_BRK_SHORT";
   g_entry_candidate_month_key = signal_month_key;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_13037\",\"ea\":\"xng-prod-brk\"}");
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
      if(QM_TM_OpenPosition(req, out_ticket))
         g_last_entry_month_key = g_entry_candidate_month_key;
      g_entry_candidate_month_key = 0;
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
