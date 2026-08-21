#property strict
#property version   "5.0"
#property description "QM5_39004 forexfactory-thv-cobra-trix-scalper — THV Cobra Trix Scalper (M5)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_39004 forexfactory-thv-cobra-trix-scalper
// -----------------------------------------------------------------------------
// Source: Cobraforex & TAH (2009-2024). THV System V3/V4. Forex Factory (>8M Views).
// Card: artifacts/cards_approved/QM5_39004_forexfactory-thv-cobra-trix-scalper.md (g0_status APPROVED).
//
// Mechanics (closed-bar, M5):
//   - Coral: SMMA(20) on M5.
//   - Fast Trix: TRIX(9) triple-EMA on M5 close.
//   - Slow Trix: TRIX(18) triple-EMA on M5 close.
//   - Long: Close[1] > Coral[1] AND FastTrix[1] > SlowTrix[1] AND FastTrix[1] > 0
//   - Short: Close[1] < Coral[1] AND FastTrix[1] < SlowTrix[1] AND FastTrix[1] < 0
//   - SL: Placed beyond Coral band +/- 2 pips.
//   - TP: 1:2.0 R:R target.
//   - Exit: Fast Trix slope reversal.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 39004;
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
input int    InpCoralPeriod             = 20;     // THV Coral SMMA period
input int    InpFastTrix                = 9;      // Fast Trix period
input int    InpSlowTrix                = 18;     // Slow Trix period
input int    strategy_atr_period        = 14;     // ATR period (M5)
input double strategy_sl_buffer_pips    = 2.0;    // SL buffer beyond Coral in pips
input double strategy_tp_rr             = 2.0;    // Take profit R:R multiple

// -----------------------------------------------------------------------------
// File-scope cached state (updated once per new closed bar)
// -----------------------------------------------------------------------------
double g_cached_fast_trix_1 = 0.0;
double g_cached_fast_trix_2 = 0.0;
double g_cached_slow_trix_1 = 0.0;
double g_cached_coral_1     = 0.0;
double g_cached_atr_1       = 0.0;
int    g_pos_direction      = 0;

// -----------------------------------------------------------------------------
// TRIX calculation helper
// -----------------------------------------------------------------------------
bool CalculateTrix(const int period, const int shift, double &trix_val)
{
   trix_val = 0.0;
   if(period <= 1) return false;
   const int warmup = period * 8 + 10;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_M5, shift, warmup, rates); // perf-allowed: exact TRIX triple-EMA close window
   if(copied < period * 3 + 2) return false;

   const double alpha = 2.0 / ((double)period + 1.0);
   const double one_minus_alpha = 1.0 - alpha;
   const int oldest = copied;
   const double seed_close = rates[oldest - 1].close;
   if(seed_close <= 0.0) return false;

   double ema1 = seed_close;
   double ema2 = seed_close;
   double ema3 = seed_close;
   double prev_ema3 = 0.0;

   for(int s = oldest - 1; s >= 0; --s)
   {
      const double cl = rates[s].close;
      if(cl <= 0.0) return false;
      ema1 = alpha * cl + one_minus_alpha * ema1;
      ema2 = alpha * ema1 + one_minus_alpha * ema2;
      ema3 = alpha * ema2 + one_minus_alpha * ema3;

      if(s == 0)
      {
         if(prev_ema3 <= 0.0) return false;
         trix_val = (ema3 - prev_ema3) / prev_ema3;
         return true;
      }
      prev_ema3 = ema3;
   }
   return false;
}

void AdvanceState_OnNewBar()
{
   CalculateTrix(InpFastTrix, 1, g_cached_fast_trix_1);
   CalculateTrix(InpFastTrix, 2, g_cached_fast_trix_2);
   CalculateTrix(InpSlowTrix, 1, g_cached_slow_trix_1);
   g_cached_coral_1 = QM_SMMA(_Symbol, PERIOD_M5, InpCoralPeriod, 1);
   g_cached_atr_1   = QM_ATR(_Symbol, PERIOD_M5, strategy_atr_period, 1);
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   return false;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(g_cached_atr_1 <= 0.0 || g_cached_coral_1 <= 0.0)
      return false;

   const double c1 = iClose(_Symbol, PERIOD_M5, 1); // perf-allowed: single closed bar
   if(c1 <= 0.0) return false;

   const double buf = QM_StopRulesPipsToPriceDistance(_Symbol, (int)MathRound(strategy_sl_buffer_pips * 10.0));

   // Long Entry
   if(c1 > g_cached_coral_1 && g_cached_fast_trix_1 > g_cached_slow_trix_1 && g_cached_fast_trix_1 > 0.0)
   {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(ask <= 0.0) return false;
      double sl = g_cached_coral_1 - buf;
      if(sl >= ask) sl = ask - 1.5 * g_cached_atr_1;
      if(sl <= 0.0 || sl >= ask) return false;
      const double tp = QM_TakeRR(_Symbol, QM_BUY, ask, sl, strategy_tp_rr);
      if(tp <= 0.0) return false;

      req.type               = QM_BUY;
      req.price              = 0.0;
      req.sl                 = QM_StopRulesNormalizePrice(_Symbol, sl);
      req.tp                 = QM_StopRulesNormalizePrice(_Symbol, tp);
      req.reason             = "THV_COBRA_TRIX_LONG";
      req.symbol_slot        = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      g_pos_direction        = +1;
      return true;
   }

   // Short Entry
   if(c1 < g_cached_coral_1 && g_cached_fast_trix_1 < g_cached_slow_trix_1 && g_cached_fast_trix_1 < 0.0)
   {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid <= 0.0) return false;
      double sl = g_cached_coral_1 + buf;
      if(sl <= bid) sl = bid + 1.5 * g_cached_atr_1;
      if(sl <= 0.0 || sl <= bid) return false;
      const double tp = QM_TakeRR(_Symbol, QM_SELL, bid, sl, strategy_tp_rr);
      if(tp <= 0.0) return false;

      req.type               = QM_SELL;
      req.price              = 0.0;
      req.sl                 = QM_StopRulesNormalizePrice(_Symbol, sl);
      req.tp                 = QM_StopRulesNormalizePrice(_Symbol, tp);
      req.reason             = "THV_COBRA_TRIX_SHORT";
      req.symbol_slot        = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      g_pos_direction        = -1;
      return true;
   }

   return false;
}

void Strategy_ManageOpenPosition()
{
}

bool Strategy_ExitSignal()
{
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   if(g_pos_direction > 0 && g_cached_fast_trix_1 < g_cached_fast_trix_2)
   {
      g_pos_direction = 0;
      return true;
   }
   if(g_pos_direction < 0 && g_cached_fast_trix_1 > g_cached_fast_trix_2)
   {
      g_pos_direction = 0;
      return true;
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

   if(!QM_FrameworkDeclareExecutionContract(PERIOD_M5,
                                            QM_FRIDAY_CLOSE_FRAMEWORK_OVERRIDE,
                                            "V5_WEEKEND_RISK_POLICY"))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_39004_forexfactory-thv-cobra-trix-scalper\"}");
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

   if(!QM_IsNewBar(_Symbol, PERIOD_M5))
      return;

   QM_EquityStreamOnNewBar();

   AdvanceState_OnNewBar();

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
