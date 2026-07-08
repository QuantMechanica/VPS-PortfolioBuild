#property strict
#property version   "5.0"
#property description "QM5_13051 XNG realized-volatility VRP proxy"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_13051 - XNG VRP Proxy
// -----------------------------------------------------------------------------
// D1 structural natural-gas sleeve:
//   - uses top-quartile realized volatility as an OHLC-only energy VRP proxy
//   - fades short-horizon return stretches back toward a slow D1 mean
//   - ATR stop, SMA/vol/time exits, no external runtime data
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 13051;
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
input int    strategy_rv_period             = 20;
input int    strategy_rv_rank_lookback      = 252;
input double strategy_entry_rv_percentile   = 0.75;
input double strategy_exit_rv_percentile    = 0.50;
input int    strategy_return_lookback       = 5;
input double strategy_min_return_atr        = 1.20;
input int    strategy_mean_period           = 50;
input double strategy_min_stretch_atr       = 0.40;
input int    strategy_atr_period            = 20;
input double strategy_atr_sl_mult           = 3.25;
input int    strategy_max_hold_days         = 10;
input int    strategy_max_spread_points     = 2500;

int g_last_signal_day_key = 0;

bool Strategy_IsXngD1()
  {
   return (_Symbol == "XNGUSD.DWX" && _Period == PERIOD_D1);
  }

int Strategy_DayKey(const datetime t)
  {
   if(t <= 0)
      return 0;
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
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

bool Strategy_RealizedVol(const int start_shift,
                          const int period,
                          double &rv)
  {
   rv = 0.0;
   const int n = MathMax(5, period);
   double sum = 0.0;
   double sum_sq = 0.0;

   for(int i = 0; i < n; ++i)
     {
      const double c0 = iClose(_Symbol, PERIOD_D1, start_shift + i);     // perf-allowed: compact D1 RV loop behind new-bar gate.
      const double c1 = iClose(_Symbol, PERIOD_D1, start_shift + i + 1); // perf-allowed: compact D1 RV loop behind new-bar gate.
      if(c0 <= 0.0 || c1 <= 0.0)
         return false;
      const double r = MathLog(c0 / c1);
      if(!MathIsValidNumber(r))
         return false;
      sum += r;
      sum_sq += r * r;
     }

   const double mean = sum / (double)n;
   const double variance = MathMax(0.0, (sum_sq / (double)n) - mean * mean);
   rv = MathSqrt(variance) * MathSqrt(252.0);
   return (rv > 0.0 && MathIsValidNumber(rv));
  }

bool Strategy_RvPercentile(const int start_shift,
                           double &current_rv,
                           double &percentile)
  {
   current_rv = 0.0;
   percentile = 0.0;
   if(!Strategy_RealizedVol(start_shift, strategy_rv_period, current_rv))
      return false;

   const int lookback = MathMax(30, strategy_rv_rank_lookback);
   int valid = 0;
   int below_or_equal = 0;
   for(int i = 1; i <= lookback; ++i)
     {
      double sample_rv = 0.0;
      if(!Strategy_RealizedVol(start_shift + i, strategy_rv_period, sample_rv))
         continue;
      ++valid;
      if(sample_rv <= current_rv)
         ++below_or_equal;
     }

   if(valid < MathMin(60, lookback / 2))
      return false;
   percentile = (double)below_or_equal / (double)valid;
   return MathIsValidNumber(percentile);
  }

bool Strategy_LoadVrpProxyState(int &direction,
                                double &atr_last,
                                double &sma_last,
                                double &rv_percentile,
                                int &signal_day_key)
  {
   direction = 0;
   atr_last = 0.0;
   sma_last = 0.0;
   rv_percentile = 0.0;
   signal_day_key = 0;

   const datetime signal_time = iTime(_Symbol, PERIOD_D1, 1); // perf-allowed: completed D1 signal calendar state behind new-bar gate.
   if(signal_time <= 0)
      return false;

   const double signal_open = iOpen(_Symbol, PERIOD_D1, 1);   // perf-allowed: completed D1 signal bar.
   const double signal_high = iHigh(_Symbol, PERIOD_D1, 1);   // perf-allowed: completed D1 signal bar.
   const double signal_low = iLow(_Symbol, PERIOD_D1, 1);     // perf-allowed: completed D1 signal bar.
   const double signal_close = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: completed D1 signal bar.
   if(signal_open <= 0.0 || signal_high <= 0.0 || signal_low <= 0.0 || signal_close <= 0.0)
      return false;
   if(signal_high <= signal_low)
      return false;

   double current_rv = 0.0;
   if(!Strategy_RvPercentile(1, current_rv, rv_percentile))
      return false;
   if(rv_percentile < strategy_entry_rv_percentile)
      return false;

   atr_last = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   sma_last = QM_SMA(_Symbol, PERIOD_D1, strategy_mean_period, 1, PRICE_CLOSE);
   if(atr_last <= 0.0 || sma_last <= 0.0)
      return false;

   const int ret_shift = 1 + MathMax(1, strategy_return_lookback);
   const double past_close = iClose(_Symbol, PERIOD_D1, ret_shift); // perf-allowed: D1 return-stretch state behind new-bar gate.
   if(past_close <= 0.0)
      return false;

   const double return_price = signal_close - past_close;
   const double signal_range = signal_high - signal_low;
   const double close_location = (signal_close - signal_low) / signal_range;
   const bool bullish_reversal = (signal_close > signal_open && close_location >= 0.55);
   const bool bearish_reversal = (signal_close < signal_open && close_location <= 0.45);

   const bool long_setup =
      return_price <= -strategy_min_return_atr * atr_last &&
      signal_close <= sma_last - strategy_min_stretch_atr * atr_last &&
      bullish_reversal;

   const bool short_setup =
      return_price >= strategy_min_return_atr * atr_last &&
      signal_close >= sma_last + strategy_min_stretch_atr * atr_last &&
      bearish_reversal;

   if(long_setup)
      direction = 1;
   else if(short_setup)
      direction = -1;
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
   const double close_last = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: D1 mean/vol exit behind new-bar gate.
   const double sma_last = QM_SMA(_Symbol, PERIOD_D1, strategy_mean_period, 1, PRICE_CLOSE);
   double current_rv = 0.0;
   double rv_percentile = 0.0;
   const bool rv_ready = Strategy_RvPercentile(1, current_rv, rv_percentile);

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

      if(rv_ready && rv_percentile <= strategy_exit_rv_percentile)
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
   if(!Strategy_IsXngD1())
      return true;
   if(qm_magic_slot_offset != 0)
      return true;
   if(strategy_rv_period < 5 || strategy_rv_rank_lookback < 60)
      return true;
   if(strategy_entry_rv_percentile <= 0.0 || strategy_entry_rv_percentile > 1.0)
      return true;
   if(strategy_exit_rv_percentile < 0.0 || strategy_exit_rv_percentile > strategy_entry_rv_percentile)
      return true;
   if(strategy_return_lookback <= 0 || strategy_min_return_atr <= 0.0)
      return true;
   if(strategy_mean_period <= 1 || strategy_min_stretch_atr < 0.0)
      return true;
   if(strategy_atr_period <= 1 || strategy_atr_sl_mult <= 0.0 || strategy_max_hold_days <= 0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_13051_XNG_VRP_PROXY";
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
   double rv_percentile = 0.0;
   int signal_day_key = 0;
   if(!Strategy_LoadVrpProxyState(direction, atr_last, sma_last, rv_percentile, signal_day_key))
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

   req.reason = (direction > 0) ? "XNG_VRP_PROXY_LONG" : "XNG_VRP_PROXY_SHORT";
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_13051\",\"ea\":\"xng-vrp-proxy\"}");
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
