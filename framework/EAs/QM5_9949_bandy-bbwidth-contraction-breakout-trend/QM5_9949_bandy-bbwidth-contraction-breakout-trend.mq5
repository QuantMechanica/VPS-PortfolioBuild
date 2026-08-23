#property strict
#property version   "5.0"
#property description "QM5_9949 Bandy BB-Width Contraction Breakout D1 Trend"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_9949
// Strategy Card: C:/QM/repo/framework/EAs/QM5_9949_bandy-bbwidth-contraction-breakout-trend/docs/strategy_card.md
// Source: Howard Bandy, Quantitative Technical Analysis 2015 (9ef19e06-5ca6-5b35-aa06-b8187aa0e016)
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9949;
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
input int    strategy_bb_period              = 20;
input double strategy_bb_deviation           = 2.0;
input int    strategy_compression_lookback   = 120;
input double strategy_compression_pct        = 10.0;
input double strategy_rearm_pct              = 60.0;
input int    strategy_regime_sma_period      = 200;
input int    strategy_atr_period             = 14;
input double strategy_stop_atr_mult          = 2.5;
input double strategy_extreme_range_atr_mult = 4.0;
input int    strategy_max_hold_bars          = 30;
input int    strategy_warmup_bars            = 250;
input int    strategy_max_spread_points      = 0;

// -----------------------------------------------------------------------------
// Strategy calculation helpers
// -----------------------------------------------------------------------------

bool Strategy_SymbolAllowed(const string sym)
{
   return (sym == "SP500.DWX" ||
           sym == "NDX.DWX" ||
           sym == "WS30.DWX" ||
           sym == "GDAXI.DWX" ||
           sym == "UK100.DWX" ||
           sym == "EURUSD.DWX" ||
           sym == "GBPUSD.DWX" ||
           sym == "USDJPY.DWX" ||
           sym == "USDCHF.DWX" ||
           sym == "USDCAD.DWX" ||
           sym == "AUDUSD.DWX" ||
           sym == "NZDUSD.DWX" ||
           sym == "XAUUSD.DWX");
}

bool Strategy_ParamsValid()
{
   return (strategy_bb_period >= 5 &&
           strategy_bb_deviation > 0.0 &&
           strategy_compression_lookback >= 20 &&
           strategy_compression_pct > 0.0 &&
           strategy_compression_pct < 50.0 &&
           strategy_rearm_pct > strategy_compression_pct &&
           strategy_rearm_pct <= 95.0 &&
           strategy_regime_sma_period >= 20 &&
           strategy_atr_period >= 1 &&
           strategy_stop_atr_mult > 0.0 &&
           strategy_max_hold_bars >= 1 &&
           strategy_warmup_bars >= strategy_compression_lookback + strategy_bb_period + 20);
}

double Strategy_CalculateBBWidth(const int shift)
{
   const double mid = QM_SMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_bb_period, shift, PRICE_CLOSE);
   if(mid <= 0.0)
      return 0.0;

   // Standard deviation calculation
   double sum_sq = 0.0;
   for(int i = 0; i < strategy_bb_period; ++i)
   {
      const double c = iClose(_Symbol, (ENUM_TIMEFRAMES)_Period, shift + i);
      if(c <= 0.0)
         return 0.0;
      const double diff = c - mid;
      sum_sq += diff * diff;
   }
   const double stdev = MathSqrt(sum_sq / strategy_bb_period);
   const double ub = mid + strategy_bb_deviation * stdev;
   const double lb = mid - strategy_bb_deviation * stdev;
   if(ub <= lb || mid <= 0.0)
      return 0.0;

   return (ub - lb) / mid;
}

bool Strategy_GetBBLevels(const int shift, double &mid, double &ub, double &lb)
{
   mid = QM_SMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_bb_period, shift, PRICE_CLOSE);
   if(mid <= 0.0)
      return false;

   double sum_sq = 0.0;
   for(int i = 0; i < strategy_bb_period; ++i)
   {
      const double c = iClose(_Symbol, (ENUM_TIMEFRAMES)_Period, shift + i);
      if(c <= 0.0)
         return false;
      const double diff = c - mid;
      sum_sq += diff * diff;
   }
   const double stdev = MathSqrt(sum_sq / strategy_bb_period);
   ub = mid + strategy_bb_deviation * stdev;
   lb = mid - strategy_bb_deviation * stdev;
   return (ub > lb && mid > 0.0);
}

double Strategy_GetPercentile(const double &arr[], const int count, const double pct)
{
   if(count <= 0)
      return 0.0;

   double temp[];
   ArrayResize(temp, count);
   ArrayCopy(temp, arr, 0, 0, count);
   ArraySort(temp);

   int idx = (int)MathFloor((pct / 100.0) * (double)count);
   if(idx < 0)
      idx = 0;
   if(idx >= count)
      idx = count - 1;

   if(idx < 0 || idx >= ArraySize(temp))
      return 0.0;

   return temp[idx];
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   if(!Strategy_ParamsValid())
      return true;
   if((ENUM_TIMEFRAMES)_Period != PERIOD_D1)
      return true;
   if(!Strategy_SymbolAllowed(_Symbol))
      return true;
   if(iBars(_Symbol, PERIOD_D1) < strategy_warmup_bars)
      return true;

   if(strategy_max_spread_points <= 0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return true;

   if(ask > bid && ((ask - bid) / point) > strategy_max_spread_points)
      return true;
   return false;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   req.type               = QM_BUY;
   req.price              = 0.0;
   req.sl                 = 0.0;
   req.tp                 = 0.0;
   req.reason             = "";
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) > 0)
      return false;

   // Gather prior 120 BB width values for bar shift 2 (window = shift 3 to 122)
   const int lookback = strategy_compression_lookback;
   double widths_prev[];
   ArrayResize(widths_prev, lookback);
   for(int i = 0; i < lookback; ++i)
   {
      const double w = Strategy_CalculateBBWidth(3 + i);
      if(w <= 0.0)
         return false;
      widths_prev[i] = w;
   }

   const double width_at_prev = Strategy_CalculateBBWidth(2);
   if(width_at_prev <= 0.0)
      return false;

   const double p10_prev = Strategy_GetPercentile(widths_prev, lookback, strategy_compression_pct);
   const bool was_compressed_at_prev = (width_at_prev <= p10_prev);
   if(!was_compressed_at_prev)
      return false;

   // Check current bar (shift 1 close) breakout
   double mid1 = 0.0, ub1 = 0.0, lb1 = 0.0;
   if(!Strategy_GetBBLevels(1, mid1, ub1, lb1))
      return false;

   const double close1 = iClose(_Symbol, PERIOD_D1, 1);
   const double high1  = iHigh(_Symbol, PERIOD_D1, 1);
   const double low1   = iLow(_Symbol, PERIOD_D1, 1);
   const double regime = QM_SMA(_Symbol, PERIOD_D1, strategy_regime_sma_period, 1, PRICE_CLOSE);
   const double atr14  = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);

   if(close1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0 || regime <= 0.0 || atr14 <= 0.0)
      return false;

   // Extreme range filter (skip news flashes)
   if(high1 - low1 > strategy_extreme_range_atr_mult * atr14)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;

   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(digits < 0)
      digits = 8;

   const int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const double min_stop_distance = MathMax((double)stops_level * point, point);

   // Long breakout: close1 > ub1 AND close1 > regime
   if(close1 > ub1 && close1 > regime)
   {
      double sl_raw = ask - strategy_stop_atr_mult * atr14;
      if(ask - sl_raw < min_stop_distance)
         sl_raw = ask - min_stop_distance - point;
      if(sl_raw <= 0.0)
         return false;

      req.type               = QM_BUY;
      req.price              = 0.0;
      req.sl                 = NormalizeDouble(sl_raw, digits);
      req.tp                 = 0.0;
      req.reason             = "bandy_bbwidth_contraction_long_breakout";
      req.symbol_slot        = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
   }

   // Short breakout: close1 < lb1 AND close1 < regime
   if(close1 < lb1 && close1 < regime)
   {
      double sl_raw = bid + strategy_stop_atr_mult * atr14;
      if(sl_raw - bid < min_stop_distance)
         sl_raw = bid + min_stop_distance + point;

      req.type               = QM_SELL;
      req.price              = 0.0;
      req.sl                 = NormalizeDouble(sl_raw, digits);
      req.tp                 = 0.0;
      req.reason             = "bandy_bbwidth_contraction_short_breakout";
      req.symbol_slot        = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
   }

   return false;
}

void Strategy_ManageOpenPosition()
{
}

bool Strategy_ExitSignal()
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const int period_seconds = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   if(period_seconds <= 0)
      return false;

   double mid1 = 0.0, ub1 = 0.0, lb1 = 0.0;
   const bool bb_ok = Strategy_GetBBLevels(1, mid1, ub1, lb1);
   const double close1 = iClose(_Symbol, PERIOD_D1, 1);
   const double low1   = iLow(_Symbol, PERIOD_D1, 1);
   const double high1  = iHigh(_Symbol, PERIOD_D1, 1);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      // Time stop
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened > 0 && TimeCurrent() - opened >= strategy_max_hold_bars * period_seconds)
         return true;

      // BB midband touch trail-exit
      if(bb_ok && close1 > 0.0 && low1 > 0.0 && high1 > 0.0)
      {
         const long pos_type = PositionGetInteger(POSITION_TYPE);
         // Midband touched during bar
         if(low1 <= mid1 && mid1 <= high1)
         {
            if(pos_type == POSITION_TYPE_BUY && close1 < mid1)
               return true;
            if(pos_type == POSITION_TYPE_SELL && close1 > mid1)
               return true;
         }
      }
   }
   return false;
}

bool Strategy_NewsFilterHook(const datetime broker_time)
{
   return false;
}

// -----------------------------------------------------------------------------
// Framework wiring
// -----------------------------------------------------------------------------

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
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
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
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
      }
   }

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
