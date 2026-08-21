#property strict
#property version   "5.0"
#property description "QM5_12944 Sperandeo Trend Fault-Line Break (H4)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_12944 — Sperandeo Trend Fault-Line Break (H4)
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12944;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.5;
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
input int    strategy_zigzag_depth      = 12;
input double strategy_zigzag_dev_pct    = 0.5;
input int    strategy_min_pivots        = 3;
input double strategy_vol_expansion_mult = 1.5;
input double strategy_break_buffer_mult  = 0.5;
input double strategy_tp_atr_mult       = 2.0;
input double strategy_sl_atr_mult       = 1.5;
input int    strategy_atr_period        = 20;
input int    strategy_regime_sma_period = 200;
input double strategy_spread_filter_mult = 2.0;

// -----------------------------------------------------------------------------
// Structural Types and Helpers
// -----------------------------------------------------------------------------

struct PivotPoint
{
   int      shift;
   double   price;
   datetime time;
};

bool FitLinearRegression3(const PivotPoint &p0, const PivotPoint &p1, const PivotPoint &p2,
                          double &out_slope, double &out_intercept)
{
   const double x0 = (double)p0.shift;
   const double x1 = (double)p1.shift;
   const double x2 = (double)p2.shift;
   const double y0 = p0.price;
   const double y1 = p1.price;
   const double y2 = p2.price;

   const double mean_x = (x0 + x1 + x2) / 3.0;
   const double mean_y = (y0 + y1 + y2) / 3.0;

   const double var_x = (x0 - mean_x) * (x0 - mean_x) +
                        (x1 - mean_x) * (x1 - mean_x) +
                        (x2 - mean_x) * (x2 - mean_x);

   if(var_x <= 1e-9)
      return false;

   const double cov_xy = (x0 - mean_x) * (y0 - mean_y) +
                         (x1 - mean_x) * (y1 - mean_y) +
                         (x2 - mean_x) * (y2 - mean_y);

   out_slope = cov_xy / var_x;
   out_intercept = mean_y - out_slope * mean_x;
   return true;
}

double FaultLinePriceAtShift(const double slope, const double intercept, const int shift)
{
   return intercept + slope * (double)shift;
}

bool FindDownFaultLine(const MqlRates &rates[], const int count, double &out_slope, double &out_intercept)
{
   const int depth = MathMax(3, strategy_zigzag_depth);
   PivotPoint highs[20];
   int high_count = 0;

   for(int shift = depth; shift < count - depth && high_count < 20; ++shift)
   {
      const double h = rates[shift].high;
      bool is_peak = true;
      for(int k = 1; k <= depth; ++k)
      {
         if(rates[shift - k].high > h || rates[shift + k].high >= h)
         {
            is_peak = false;
            break;
         }
      }
      if(is_peak)
      {
         highs[high_count].shift = shift;
         highs[high_count].price = h;
         highs[high_count].time = rates[shift].time;
         high_count++;
      }
   }

   if(high_count < 3)
      return false;

   for(int i = 0; i <= high_count - 3; ++i)
   {
      if(highs[i + 2].price > highs[i + 1].price && highs[i + 1].price > highs[i].price)
      {
         const double pct_diff1 = (highs[i + 2].price - highs[i + 1].price) / highs[i + 2].price * 100.0;
         const double pct_diff2 = (highs[i + 1].price - highs[i].price) / highs[i + 1].price * 100.0;
         if(pct_diff1 >= strategy_zigzag_dev_pct * 0.5 && pct_diff2 >= strategy_zigzag_dev_pct * 0.5)
         {
            return FitLinearRegression3(highs[i], highs[i + 1], highs[i + 2], out_slope, out_intercept);
         }
      }
   }

   return false;
}

bool FindUpFaultLine(const MqlRates &rates[], const int count, double &out_slope, double &out_intercept)
{
   const int depth = MathMax(3, strategy_zigzag_depth);
   PivotPoint lows[20];
   int low_count = 0;

   for(int shift = depth; shift < count - depth && low_count < 20; ++shift)
   {
      const double l = rates[shift].low;
      bool is_trough = true;
      for(int k = 1; k <= depth; ++k)
      {
         if(rates[shift - k].low < l || rates[shift + k].low <= l)
         {
            is_trough = false;
            break;
         }
      }
      if(is_trough)
      {
         lows[low_count].shift = shift;
         lows[low_count].price = l;
         lows[low_count].time = rates[shift].time;
         low_count++;
      }
   }

   if(low_count < 3)
      return false;

   for(int i = 0; i <= low_count - 3; ++i)
   {
      if(lows[i + 2].price < lows[i + 1].price && lows[i + 1].price < lows[i].price)
      {
         const double pct_diff1 = (lows[i + 1].price - lows[i + 2].price) / lows[i + 2].price * 100.0;
         const double pct_diff2 = (lows[i].price - lows[i + 1].price) / lows[i + 1].price * 100.0;
         if(pct_diff1 >= strategy_zigzag_dev_pct * 0.5 && pct_diff2 >= strategy_zigzag_dev_pct * 0.5)
         {
            return FitLinearRegression3(lows[i], lows[i + 1], lows[i + 2], out_slope, out_intercept);
         }
      }
   }

   return false;
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   if(_Period != PERIOD_H4)
      return true;

   const double atr_val = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(atr_val > 0.0 && bid > 0.0 && ask > bid)
   {
      const double spread = ask - bid;
      if(spread > atr_val * strategy_spread_filter_mult * 0.5)
         return true;
   }

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

   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) > 0)
      return false;

   const double atr20 = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(atr20 <= 0.0)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_H4, 1, 160, rates); // perf-allowed: bespoke ZigZag/fault-line scan, called only after framework QM_IsNewBar().
   if(copied < 60)
      return false;

   // Volatility expansion on breaking bar (rates[0] corresponds to shift 1)
   const double bar1_range = rates[0].high - rates[0].low;
   const bool vol_expansion = (bar1_range > strategy_vol_expansion_mult * atr20);
   if(!vol_expansion)
      return false;

   const double d1_close1 = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: D1 regime close paired with QM_SMA.
   const double d1_sma200 = QM_SMA(_Symbol, PERIOD_D1, strategy_regime_sma_period, 1, PRICE_CLOSE);
   if(d1_close1 <= 0.0 || d1_sma200 <= 0.0)
      return false;

   // Test Bullish Entry (breakout of downtrend fault line)
   double down_slope = 0.0, down_intercept = 0.0;
   if(FindDownFaultLine(rates, copied, down_slope, down_intercept))
   {
      const double line_price_bar1 = FaultLinePriceAtShift(down_slope, down_intercept, 0); // rates[0] is shift 1
      if(rates[0].close > line_price_bar1 + strategy_break_buffer_mult * atr20)
      {
         if(d1_close1 > d1_sma200)
         {
            const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            const double entry_p = (ask > 0.0) ? ask : rates[0].close;
            const double sl = entry_p - strategy_sl_atr_mult * atr20;
            const double tp = entry_p + strategy_tp_atr_mult * atr20;

            req.type = QM_BUY;
            req.price = 0.0;
            req.sl = QM_StopRulesNormalizePrice(_Symbol, sl);
            req.tp = QM_StopRulesNormalizePrice(_Symbol, tp);
            req.reason = "sperandeo_fault_break_long";
            return true;
         }
      }
   }

   // Test Bearish Entry (breakout of uptrend fault line)
   double up_slope = 0.0, up_intercept = 0.0;
   if(FindUpFaultLine(rates, copied, up_slope, up_intercept))
   {
      const double line_price_bar1 = FaultLinePriceAtShift(up_slope, up_intercept, 0); // rates[0] is shift 1
      if(rates[0].close < line_price_bar1 - strategy_break_buffer_mult * atr20)
      {
         if(d1_close1 < d1_sma200)
         {
            const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            const double entry_p = (bid > 0.0) ? bid : rates[0].close;
            const double sl = entry_p + strategy_sl_atr_mult * atr20;
            const double tp = entry_p - strategy_tp_atr_mult * atr20;

            req.type = QM_SELL;
            req.price = 0.0;
            req.sl = QM_StopRulesNormalizePrice(_Symbol, sl);
            req.tp = QM_StopRulesNormalizePrice(_Symbol, tp);
            req.reason = "sperandeo_fault_break_short";
            return true;
         }
      }
   }

   return false;
}

void Strategy_ManageOpenPosition() {}

bool Strategy_ExitSignal()
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) == 0)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_H4, 1, 160, rates); // perf-allowed: bespoke ZigZag/fault-line scan.
   if(copied < 60)
      return false;

   double down_slope = 0.0, down_intercept = 0.0;
   const bool have_down = FindDownFaultLine(rates, copied, down_slope, down_intercept);

   double up_slope = 0.0, up_intercept = 0.0;
   const bool have_up = FindUpFaultLine(rates, copied, up_slope, up_intercept);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(pos_type == POSITION_TYPE_BUY && have_down)
      {
         const double line_p = FaultLinePriceAtShift(down_slope, down_intercept, 0);
         if(rates[0].close < line_p)
         {
            QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
            continue;
         }
      }
      else if(pos_type == POSITION_TYPE_SELL && have_up)
      {
         const double line_p = FaultLinePriceAtShift(up_slope, up_intercept, 0);
         if(rates[0].close > line_p)
         {
            QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
            continue;
         }
      }
   }

   return false;
}

bool Strategy_NewsFilterHook(const datetime broker_time) { return false; }

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
   if(!QM_KillSwitchCheck()) return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now)) return;
   if(QM_FrameworkHandleFridayClose()) return;

   if(Strategy_NoTradeFilter()) return;

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
   {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
      {
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
      }
   }

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows) return;

   if(!QM_IsNewBar()) return;

   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req);
   if(Strategy_EntrySignal(req))
   {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
   }
}

void OnTimer() { QM_FrameworkOnTimer(); }
void OnTradeTransaction(const MqlTradeTransaction &t, const MqlTradeRequest &r, const MqlTradeResult &res)
{
   QM_FrameworkOnTradeTransaction(t, r, res);
}

double OnTester()
{
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
}
