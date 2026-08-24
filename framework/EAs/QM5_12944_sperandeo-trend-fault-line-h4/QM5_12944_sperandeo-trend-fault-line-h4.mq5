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
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
// The framework enum has no 15/15 mode.  The card's fixed literal window is
// enforced inside Strategy_EntrySignal with QM_NewsInWindow(..., 15, 15, ...).
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
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

#define STRATEGY_MAX_PIVOTS 20
#define STRATEGY_RATE_WINDOW 160

struct StrategySignalState
{
   datetime bar_time;
   bool     evaluated;
   bool     structure_ready;
   bool     entry_ready;
   bool     long_breakout;
   bool     short_breakout;
   bool     long_failed_break;
   bool     short_failed_break;
   double   atr20;
   double   bar1_close;
};

StrategySignalState g_signal_state;
datetime g_spread_bar_time = 0;
double   g_mean_spread_points = 0.0;
bool     g_mean_spread_ready = false;

bool FitLinearRegression(const PivotPoint &points[],
                         const int start_index,
                         const int point_count,
                         double &out_slope,
                         double &out_intercept)
{
   const int available = ArraySize(points);
   if(start_index < 0 || point_count < 3 ||
      start_index + point_count > available)
      return false;

   double sum_x = 0.0;
   double sum_y = 0.0;
   for(int i = 0; i < point_count; ++i)
   {
      sum_x += (double)points[start_index + i].shift;
      sum_y += points[start_index + i].price;
   }

   const double mean_x = sum_x / (double)point_count;
   const double mean_y = sum_y / (double)point_count;
   double var_x = 0.0;
   double cov_xy = 0.0;
   for(int i = 0; i < point_count; ++i)
   {
      const double dx = (double)points[start_index + i].shift - mean_x;
      const double dy = points[start_index + i].price - mean_y;
      var_x += dx * dx;
      cov_xy += dx * dy;
   }

   if(var_x <= 1e-9)
      return false;

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
   const int rate_count = MathMin(count, ArraySize(rates));
   const int required_pivots = strategy_min_pivots;
   const int depth = MathMax(1, strategy_zigzag_depth);
   if(required_pivots < 3 || required_pivots > STRATEGY_MAX_PIVOTS ||
      rate_count <= (2 * depth + required_pivots))
      return false;

   PivotPoint highs[STRATEGY_MAX_PIVOTS];
   int high_count = 0;

   const int high_capacity = ArraySize(highs);
   for(int shift = depth; shift < rate_count - depth && high_count < high_capacity; ++shift)
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

   if(high_count < required_pivots)
      return false;

   // `highs` is newest-to-oldest.  A down fault-line therefore requires each
   // older pivot to be higher than its newer neighbour by the full deviation.
   for(int i = 0; i <= high_count - required_pivots; ++i)
   {
      bool descending_in_time = true;
      for(int j = 0; j < required_pivots - 1; ++j)
      {
         const double newer = highs[i + j].price;
         const double older = highs[i + j + 1].price;
         if(older <= newer)
         {
            descending_in_time = false;
            break;
         }
         const double deviation_pct = (older - newer) / older * 100.0;
         if(deviation_pct < strategy_zigzag_dev_pct)
         {
            descending_in_time = false;
            break;
         }
      }
      if(descending_in_time &&
         FitLinearRegression(highs, i, required_pivots, out_slope, out_intercept))
         return true;
   }

   return false;
}

bool FindUpFaultLine(const MqlRates &rates[], const int count, double &out_slope, double &out_intercept)
{
   const int rate_count = MathMin(count, ArraySize(rates));
   const int required_pivots = strategy_min_pivots;
   const int depth = MathMax(1, strategy_zigzag_depth);
   if(required_pivots < 3 || required_pivots > STRATEGY_MAX_PIVOTS ||
      rate_count <= (2 * depth + required_pivots))
      return false;

   PivotPoint lows[STRATEGY_MAX_PIVOTS];
   int low_count = 0;

   const int low_capacity = ArraySize(lows);
   for(int shift = depth; shift < rate_count - depth && low_count < low_capacity; ++shift)
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

   if(low_count < required_pivots)
      return false;

   // `lows` is newest-to-oldest.  An up fault-line requires each newer low to
   // be higher than its older neighbour by the full configured deviation.
   for(int i = 0; i <= low_count - required_pivots; ++i)
   {
      bool ascending_in_time = true;
      for(int j = 0; j < required_pivots - 1; ++j)
      {
         const double newer = lows[i + j].price;
         const double older = lows[i + j + 1].price;
         if(newer <= older)
         {
            ascending_in_time = false;
            break;
         }
         const double deviation_pct = (newer - older) / older * 100.0;
         if(deviation_pct < strategy_zigzag_dev_pct)
         {
            ascending_in_time = false;
            break;
         }
      }
      if(ascending_in_time &&
         FitLinearRegression(lows, i, required_pivots, out_slope, out_intercept))
         return true;
   }

   return false;
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool MeanSpreadPointsCached(const string sym, const int lookback, double &out_mean)
{
   out_mean = 0.0;
   MqlRates latest_closed;
   if(lookback <= 0 || !QM_ReadBar(sym, PERIOD_H4, 1, latest_closed))
      return false;

   if(g_mean_spread_ready && g_spread_bar_time == latest_closed.time)
   {
      out_mean = g_mean_spread_points;
      return (out_mean > 0.0);
   }

   double sum = 0.0;
   for(int i = 1; i <= lookback; i++)
   {
      MqlRates bar;
      if(!QM_ReadBar(sym, PERIOD_H4, i, bar) || bar.spread <= 0)
         return false;
      sum += (double)bar.spread;
   }

   g_spread_bar_time = latest_closed.time;
   g_mean_spread_points = sum / (double)lookback;
   g_mean_spread_ready = (g_mean_spread_points > 0.0);
   out_mean = g_mean_spread_points;
   return g_mean_spread_ready;
}

bool RefreshSignalState()
{
   MqlRates latest_closed;
   if(!QM_ReadBar(_Symbol, PERIOD_H4, 1, latest_closed))
      return false;

   if(g_signal_state.evaluated && g_signal_state.bar_time == latest_closed.time)
      return g_signal_state.structure_ready;

   ZeroMemory(g_signal_state);
   g_signal_state.bar_time = latest_closed.time;
   g_signal_state.evaluated = true;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   // perf-allowed: bounded bespoke pivot/fault-line scan, cached once per
   // closed H4 bar and shared by the exit and entry hooks.
   const int copied = CopyRates(_Symbol, PERIOD_H4, 1, STRATEGY_RATE_WINDOW, rates);
   const int rate_count = MathMin(copied, ArraySize(rates));
   if(rate_count < 60)
      return false;

   double down_slope = 0.0;
   double down_intercept = 0.0;
   const bool have_down = FindDownFaultLine(rates, rate_count, down_slope, down_intercept);
   double up_slope = 0.0;
   double up_intercept = 0.0;
   const bool have_up = FindUpFaultLine(rates, rate_count, up_slope, up_intercept);

   if(have_down)
   {
      const double down_line_bar1 = FaultLinePriceAtShift(down_slope, down_intercept, 0);
      g_signal_state.long_failed_break = (rates[0].close < down_line_bar1);
   }
   if(have_up)
   {
      const double up_line_bar1 = FaultLinePriceAtShift(up_slope, up_intercept, 0);
      g_signal_state.short_failed_break = (rates[0].close > up_line_bar1);
   }
   g_signal_state.structure_ready = (have_down || have_up);
   g_signal_state.bar1_close = rates[0].close;

   const double atr1 = QM_ATR(_Symbol, PERIOD_H4, 1, 1);
   const double atr20 = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   MqlRates d1_bar;
   const double d1_sma = QM_SMA(_Symbol, PERIOD_D1, strategy_regime_sma_period, 1, PRICE_CLOSE);
   if(atr1 <= 0.0 || atr20 <= 0.0 || d1_sma <= 0.0 ||
      !QM_ReadBar(_Symbol, PERIOD_D1, 1, d1_bar))
      return g_signal_state.structure_ready;

   g_signal_state.atr20 = atr20;
   const bool vol_expansion = (atr1 > strategy_vol_expansion_mult * atr20);
   if(!vol_expansion)
      return g_signal_state.structure_ready;

   if(have_down)
   {
      const double line_bar1 = FaultLinePriceAtShift(down_slope, down_intercept, 0);
      const double line_bar2 = FaultLinePriceAtShift(down_slope, down_intercept, 1);
      g_signal_state.long_breakout =
         (rates[0].close > line_bar1 + strategy_break_buffer_mult * atr20 &&
          rates[1].close <= line_bar2 + strategy_break_buffer_mult * atr20 &&
          d1_bar.close > d1_sma);
   }
   if(have_up)
   {
      const double line_bar1 = FaultLinePriceAtShift(up_slope, up_intercept, 0);
      const double line_bar2 = FaultLinePriceAtShift(up_slope, up_intercept, 1);
      g_signal_state.short_breakout =
         (rates[0].close < line_bar1 - strategy_break_buffer_mult * atr20 &&
          rates[1].close >= line_bar2 - strategy_break_buffer_mult * atr20 &&
          d1_bar.close < d1_sma);
   }

   g_signal_state.entry_ready = true;
   return g_signal_state.structure_ready;
}

bool Strategy_NoTradeFilter()
{
   if(_Period != PERIOD_H4)
      return true;
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

   // The approved card fixes an entry-only high-impact blackout at ±15 min.
   // Temporal enum mode stays OFF because the framework has no 15/15 enum.
   datetime utc_now = QM_BrokerToUTC(TimeCurrent());
   if(utc_now <= 0)
      utc_now = TimeGMT();
   if(utc_now <= 0 || QM_NewsInWindow(utc_now, _Symbol, 15, 15, "high"))
      return false;

   // Entry-only spread gate: current spread must be no more than two times the
   // complete rolling mean of the preceding 100 closed H4 bars.
   double mean_spread = 0.0;
   if(!MeanSpreadPointsCached(_Symbol, 100, mean_spread))
      return false;
   const double current_spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(current_spread <= 0.0 ||
      current_spread > strategy_spread_filter_mult * mean_spread)
      return false;

   RefreshSignalState();
   if(!g_signal_state.entry_ready || g_signal_state.atr20 <= 0.0)
      return false;

   if(g_signal_state.long_breakout)
   {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double entry_price = (ask > 0.0) ? ask : g_signal_state.bar1_close;
      req.type = QM_BUY;
      req.sl = QM_StopRulesNormalizePrice(
         _Symbol, entry_price - strategy_sl_atr_mult * g_signal_state.atr20);
      req.tp = QM_StopRulesNormalizePrice(
         _Symbol, entry_price + strategy_tp_atr_mult * g_signal_state.atr20);
      req.reason = "sperandeo_fault_break_long";
      return true;
   }

   if(g_signal_state.short_breakout)
   {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double entry_price = (bid > 0.0) ? bid : g_signal_state.bar1_close;
      req.type = QM_SELL;
      req.sl = QM_StopRulesNormalizePrice(
         _Symbol, entry_price + strategy_sl_atr_mult * g_signal_state.atr20);
      req.tp = QM_StopRulesNormalizePrice(
         _Symbol, entry_price - strategy_tp_atr_mult * g_signal_state.atr20);
      req.reason = "sperandeo_fault_break_short";
      return true;
   }

   return false;
}

void Strategy_ManageOpenPosition() {}

bool Strategy_ExitSignal()
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) == 0)
      return false;

   RefreshSignalState();
   if(!g_signal_state.structure_ready)
      return false;

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
      // Failed-break exits and fully qualifying opposite breakouts both close
      // through the framework.  OnTick then evaluates a possible opposite
      // entry after all entry-only news/spread guards have cleared.
      if(pos_type == POSITION_TYPE_BUY &&
         (g_signal_state.long_failed_break || g_signal_state.short_breakout))
         return true;
      if(pos_type == POSITION_TYPE_SELL &&
         (g_signal_state.short_failed_break || g_signal_state.long_breakout))
         return true;
   }

   return false;
}

bool Strategy_NewsFilterHook(const datetime broker_time) { return false; }

// -----------------------------------------------------------------------------
// Framework wiring
// -----------------------------------------------------------------------------

int OnInit()
{
   if(strategy_zigzag_depth < 1 ||
      strategy_zigzag_dev_pct <= 0.0 ||
      strategy_min_pivots < 3 || strategy_min_pivots > STRATEGY_MAX_PIVOTS ||
      strategy_vol_expansion_mult <= 0.0 ||
      strategy_break_buffer_mult < 0.0 ||
      strategy_tp_atr_mult <= 0.0 ||
      strategy_sl_atr_mult <= 0.0 ||
      strategy_atr_period < 1 ||
      strategy_regime_sma_period < 1 ||
      strategy_spread_filter_mult <= 0.0)
      return INIT_PARAMETERS_INCORRECT;

   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        15,
                        15,
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

   QM_EntryRequest req = {};
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
