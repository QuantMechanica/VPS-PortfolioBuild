#property strict
#property version   "5.0"
#property description "QM5_9640 Colby Disparity Index H4 — mean-reversion on DI z-score"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_9640  colby-disparity-index-h4
// Entry when price/SMA(20) disparity z-score (252-bar window) is extreme and
// turning back toward zero, with SMA(200) trend bias and slope filter.
// Exit at DI_z zero-cross, 1.5R TP, or 12-bar time stop.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9640;
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
input int    strategy_di_period         = 20;    // SMA period for Disparity Index
input int    strategy_di_zscore_window  = 252;   // rolling z-score lookback (bars)
input double strategy_entry_zscore      = 1.75;  // |DI_z| threshold to enter
input double strategy_momentum_min      = 0.25;  // DI_z must shift this much toward 0
input int    strategy_sma200_period     = 200;   // trend bias SMA period
input int    strategy_sma200_slope_bars = 10;    // bars over which slope is measured
input double strategy_sma200_slope_atr  = 0.05; // slope < X*ATR(14) → skip entry
input double strategy_sl_atr_mult       = 0.35;  // SL = setup bar extreme + X*ATR
input double strategy_tp_r_mult         = 1.5;   // TP in R multiples
input int    strategy_time_stop_bars    = 12;    // max hold in H4 bars
input int    strategy_atr_period        = 14;    // ATR period for SL and filters

// ---- File-scope cached state (advanced once per closed H4 bar) ----
bool   g_state_valid  = false;
double g_di_z_current = 0.0;   // DI z-score at shift=1
double g_di_z_prev    = 0.0;   // DI z-score at shift=2
double g_bar_low      = 0.0;   // setup bar low  (rates[0].low)
double g_bar_high     = 0.0;   // setup bar high (rates[0].high)
double g_close1       = 0.0;   // close at shift=1
bool   g_slope_ok     = false; // SMA(200) slope filter passes
double g_sma200_val   = 0.0;   // SMA(200) at shift=1

// Called once per new H4 bar inside Strategy_EntrySignal (gated by QM_IsNewBar).
void AdvanceState_OnNewBar()
{
   g_state_valid = false;

   // ZWINDOW DI values, each needing di_period bars for SMA → total + 2 buffer
   const int NEEDED = strategy_di_zscore_window + strategy_di_period + 2;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   // perf-allowed: bespoke 252-bar z-score requires raw close history; called once per H4 bar
   if(CopyRates(_Symbol, PERIOD_H4, 1, NEEDED, rates) < NEEDED)
      return;

   // DI = 100 * (close - SMA(di_period)) / SMA(di_period) for each of ZWINDOW bars
   double di[];
   ArrayResize(di, strategy_di_zscore_window);

   for(int i = 0; i < strategy_di_zscore_window; i++)
   {
      double sma_sum = 0.0;
      for(int j = 0; j < strategy_di_period; j++)
         sma_sum += rates[i + j].close;
      const double sma_val = sma_sum / strategy_di_period;
      if(sma_val < 1e-10) return;
      di[i] = 100.0 * (rates[i].close - sma_val) / sma_val;
   }

   // Rolling z-score: mean + std over ZWINDOW
   double mean_di = 0.0;
   for(int i = 0; i < strategy_di_zscore_window; i++)
      mean_di += di[i];
   mean_di /= strategy_di_zscore_window;

   double var_di = 0.0;
   for(int i = 0; i < strategy_di_zscore_window; i++)
      var_di += (di[i] - mean_di) * (di[i] - mean_di);
   var_di /= strategy_di_zscore_window;
   const double std_di = MathSqrt(var_di);

   if(std_di < 1e-10) return;

   g_di_z_current = (di[0] - mean_di) / std_di;   // z-score at shift=1
   g_di_z_prev    = (di[1] - mean_di) / std_di;   // z-score at shift=2

   g_bar_low  = rates[0].low;
   g_bar_high = rates[0].high;
   g_close1   = rates[0].close;

   // SMA(200) for trend bias + slope filter (framework pooled handles)
   const double sma200_now  = QM_SMA(_Symbol, PERIOD_H4, strategy_sma200_period, 1);
   const double sma200_then = QM_SMA(_Symbol, PERIOD_H4, strategy_sma200_period,
                                     strategy_sma200_slope_bars + 1);
   const double atr14       = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);

   if(sma200_now <= 0.0 || sma200_then <= 0.0 || atr14 <= 0.0) return;

   g_sma200_val = sma200_now;
   const double slope_mag = MathAbs(sma200_now - sma200_then) / strategy_sma200_slope_bars;
   g_slope_ok   = (slope_mag >= strategy_sma200_slope_atr * atr14);

   g_state_valid = true;
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// No Trade Filter
bool Strategy_NoTradeFilter()
{
   return false;
}

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   // Advance bar state (QM_IsNewBar gate in OnTick ensures this runs once per bar)
   AdvanceState_OnNewBar();
   if(!g_state_valid || !g_slope_ok) return false;

   // One active position per magic-symbol
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) == magic &&
         PositionGetString(POSITION_SYMBOL) == _Symbol)
         return false;
   }

   const double atr14 = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(atr14 <= 0.0) return false;

   // Long mean-reversion: DI_z very negative, above SMA(200), momentum rising toward 0
   if(g_di_z_current <= -strategy_entry_zscore &&
      g_close1 > g_sma200_val &&
      (g_di_z_current - g_di_z_prev) >= strategy_momentum_min)
   {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double sl  = g_bar_low - strategy_sl_atr_mult * atr14;
      if((ask - sl) <= 0.0) return false;
      req.type   = QM_BUY;
      req.price  = ask;
      req.sl     = sl;
      req.tp     = ask + strategy_tp_r_mult * (ask - sl);
      req.reason = "DI_LONG";
      return true;
   }

   // Short mean-reversion: DI_z very positive, below SMA(200), momentum falling toward 0
   if(g_di_z_current >= strategy_entry_zscore &&
      g_close1 < g_sma200_val &&
      (g_di_z_current - g_di_z_prev) <= -strategy_momentum_min)
   {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double sl  = g_bar_high + strategy_sl_atr_mult * atr14;
      if((sl - bid) <= 0.0) return false;
      req.type   = QM_SELL;
      req.price  = bid;
      req.sl     = sl;
      req.tp     = bid - strategy_tp_r_mult * (sl - bid);
      req.reason = "DI_SHORT";
      return true;
   }

   return false;
}

// Trade Management
void Strategy_ManageOpenPosition()
{
   // Mean-reversion strategy: no trailing stop or break-even.
   // All management via TP/SL and the discretionary exits in ExitSignal.
}

// Trade Close
bool Strategy_ExitSignal()
{
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      // Time stop: 12 H4 bars = 172800 seconds
      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      if((TimeCurrent() - open_time) >= (long)strategy_time_stop_bars * 4 * 3600)
         return true;

      // DI_z zero-cross exit: exit long when z-score reaches 0, exit short when it reaches 0
      if(g_state_valid)
      {
         const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         if(ptype == POSITION_TYPE_BUY  && g_di_z_current >= 0.0) return true;
         if(ptype == POSITION_TYPE_SELL && g_di_z_current <= 0.0) return true;
      }
   }
   return false;
}

// News Filter Hook
bool Strategy_NewsFilterHook(const datetime broker_time)
{
   return false; // defer to QM_NewsAllowsTrade
}

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line unless you know why.
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

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

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
                        const MqlTradeRequest     &request,
                        const MqlTradeResult      &result)
{
   QM_FrameworkOnTradeTransaction(trans, request, result);
}

double OnTester()
{
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
}
