#property strict
#property version   "5.0"
#property description "QM5_37006 Marcos Lopez de Prado CUSUM Structural Breakout"
// Strategy Card: QM5_37006 (cusum-filter-structural-breakout), G0 APPROVED.
// Source: Lopez de Prado, M. (2018). Advances in Financial Machine Learning. Symmetric CUSUM Filter.

#include <QM/QM_Common.mqh>
#include <QM/QM_Signals.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_37006 — CUSUM Structural Breakout
// -----------------------------------------------------------------------------
// Quality control Cumulative Sum (CUSUM) filter on M15 closed bars:
//   - S_pos = max(0, S_pos + delta_P)
//   - S_neg = min(0, S_neg + delta_P)
//   - Threshold h = 1.50 * std(delta_P, 50)
//   - Long Entry:  S_pos >= h -> BUY,  SL = 1.5*ATR(14), TP = 2.0*SL_dist (1:2 RR)
//   - Short Entry: S_neg <= -h -> SELL, SL = 1.5*ATR(14), TP = 2.0*SL_dist (1:2 RR)
//   - CUSUM Reset: S_pos = 0, S_neg = 0 on entry execution
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 37006;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_vol_window          = 50;     // Rolling return volatility window in M15 bars
input double strategy_threshold_h         = 1.50;   // Standard deviation multiplier for CUSUM threshold
input int    strategy_atr_period          = 14;     // ATR period for stop loss and spread filter
input double strategy_sl_atr_mult         = 1.50;   // Stop loss ATR multiplier
input double strategy_tp_rr               = 2.00;   // Take profit risk-reward multiplier (1:2.0)
input double strategy_spread_atr_mult     = 1.80;   // Spread filter ATR multiplier
input int    strategy_max_spread_points   = 300;    // Absolute spread cap in points

// -----------------------------------------------------------------------------
// Cached State
// -----------------------------------------------------------------------------

double g_cusum_pos    = 0.0;
double g_cusum_neg    = 0.0;
double g_cached_atr1  = 0.0;
double g_cached_h     = 0.0;
bool   g_cached_valid = false;

//+------------------------------------------------------------------+
//| Rolling Standard Deviation of Return Differences                 |
//+------------------------------------------------------------------+
double CalculateReturnStdDev(const string sym, const ENUM_TIMEFRAMES tf, const int lookback, const int shift=1)
{
   if(lookback < 5) return 0.0;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(sym, tf, shift, lookback + 1, rates) < lookback + 1)
      return 0.0;

   double sum = 0.0;
   double diffs[];
   ArrayResize(diffs, lookback);
   for(int i = 0; i < lookback; ++i)
   {
      diffs[i] = rates[i].close - rates[i+1].close;
      sum += diffs[i];
   }
   double mean = sum / (double)lookback;

   double var = 0.0;
   for(int i = 0; i < lookback; ++i)
   {
      double d = diffs[i] - mean;
      var += d * d;
   }
   return MathSqrt(var / (double)lookback);
}

void AdvanceState_OnNewBar()
{
   g_cached_atr1 = QM_ATR(_Symbol, PERIOD_M15, strategy_atr_period, 1);

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_M15, 1, 2, rates) >= 2)
   {
      double diff = rates[0].close - rates[1].close;
      g_cusum_pos = MathMax(0.0, g_cusum_pos + diff);
      g_cusum_neg = MathMin(0.0, g_cusum_neg + diff);

      double std_dev = CalculateReturnStdDev(_Symbol, PERIOD_M15, strategy_vol_window, 1);
      g_cached_h = strategy_threshold_h * std_dev;
      g_cached_valid = (g_cached_h > 0.0);
   }
   else
   {
      g_cached_valid = false;
   }
}

bool IsRolloverBlackout()
{
   MqlDateTime dt;
   TimeToStruct(TimeGMT(), dt);
   int minute_of_day = dt.hour * 60 + dt.min;
   if(minute_of_day >= 1435 || minute_of_day <= 5)
      return true;
   return false;
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   if(IsRolloverBlackout())
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask > 0.0 && bid > 0.0 && ask > bid)
   {
      if(g_cached_atr1 > 0.0 && (ask - bid) > (strategy_spread_atr_mult * g_cached_atr1))
         return true;
      if(point > 0.0 && strategy_max_spread_points > 0 && (ask - bid) > (strategy_max_spread_points * point))
         return true;
   }
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

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(!g_cached_valid || g_cached_atr1 <= 0.0 || g_cached_h <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   double sl_dist = strategy_sl_atr_mult * g_cached_atr1;
   if(sl_dist <= 0.0)
      return false;

   // Long: S_pos >= h
   if(g_cusum_pos >= g_cached_h)
   {
      req.type   = QM_BUY;
      req.reason = "QM5_37006_CUSUM_BUY";
      req.sl     = ask - sl_dist;
      req.tp     = ask + (sl_dist * strategy_tp_rr);
      g_cusum_pos = 0.0;
      g_cusum_neg = 0.0;
      return true;
   }
   // Short: S_neg <= -h
   else if(g_cusum_neg <= -g_cached_h)
   {
      req.type   = QM_SELL;
      req.reason = "QM5_37006_CUSUM_SELL";
      req.sl     = bid + sl_dist;
      req.tp     = bid - (sl_dist * strategy_tp_rr);
      g_cusum_pos = 0.0;
      g_cusum_neg = 0.0;
      return true;
   }

   return false;
}

void Strategy_ManageOpenPosition()
{
}

bool Strategy_ExitSignal()
{
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

   AdvanceState_OnNewBar();

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
         if(PositionGetInteger(POSITION_MAGIC) != magic)
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

   AdvanceState_OnNewBar();

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
