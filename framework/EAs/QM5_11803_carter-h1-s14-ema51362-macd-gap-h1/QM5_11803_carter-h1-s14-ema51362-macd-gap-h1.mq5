#property strict
#property version   "5.0"
#property description "QM5_11803 carter-h1-s14-ema51362-macd-gap-h1 — EMA5/13 cross trigger + EMA13>EMA62 gap + MACD(30,60,30) zero-sign filter (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11803 carter-h1-s14-ema51362-macd-gap-h1
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Forex Trading Strategies (1 Hour Time Frame)",
//         Strategy #14, 2014 (376863900 collection PDF, pp. 26-27).
// Card: artifacts/cards_approved/QM5_11803_carter-h1-s14-ema51362-macd-gap-h1.md
//       (g0_status APPROVED). source_id 529382f8-fbd1-5c17-ba62-fbe56990ebcd.
//
// Mechanics (closed-bar reads at shift 1/2; H1):
//   Trigger EVENT (single): EMA(5) crosses EMA(13).
//                  Long : ema5[2] <= ema13[2] AND ema5[1] > ema13[1]
//                  Short: ema5[2] >= ema13[2] AND ema5[1] < ema13[1]
//   Trend STATE  : EMA(13) above/below EMA(62) in the cross direction.
//   Gap   STATE  : |EMA13 - EMA62| >= gap_pips (default 30) — the trend must be
//                  well-developed, not a consolidation. Pip-normalized so it is
//                  scale-correct on 5-digit and JPY symbols.
//   Momentum STATE: MACD(30,60,30) MAIN line sign (>0 long / <0 short). The card
//                  uses MACD as a trend-DIRECTION filter (above/below zero), NOT
//                  as a crossover signal. The EMA5/13 cross is the only EVENT —
//                  this avoids the two-cross-same-bar zero-trade trap.
//   Stop         : fixed sl_pips (30, per source).
//   Take profit  : fixed tp_pips (50, per source).
//   No-trade     : genuinely-wide spread cap (fail-open on .DWX zero spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11803;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_ema_fast_period   = 5;      // fastest EMA (cross signal line)
input int    strategy_ema_mid_period    = 13;     // middle EMA (cross signal + gap leg)
input int    strategy_ema_slow_period   = 62;     // slowest EMA (trend base + gap leg)
input int    strategy_macd_fast_period  = 30;     // MACD fast EMA
input int    strategy_macd_slow_period  = 60;     // MACD slow EMA
input int    strategy_macd_signal_period = 30;    // MACD signal EMA (param of indicator; zero-sign uses MAIN only)
input double strategy_gap_pips          = 30.0;   // min |EMA13 - EMA62| in pips (trend-developed filter)
input double strategy_sl_pips           = 30.0;   // stop-loss distance in pips
input double strategy_tp_pips           = 50.0;   // take-profit distance in pips
input double strategy_spread_cap_pips   = 15.0;   // skip if genuine spread exceeds this (pips)

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Genuine-wide-spread guard only (fail-open on .DWX
// zero modeled spread). Regime / signal work is on the closed-bar path.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   // Convert the pip-based spread cap to a price distance (scale-correct).
   const double spread_cap = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_spread_cap_pips);
   if(spread_cap <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > spread_cap)
      return true;

   return false;
  }

// EMA5/13-cross trigger + EMA13>EMA62 ordering + gap + MACD-zero-sign entry.
// Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Trigger EVENT (single): EMA(5) crosses EMA(13).
   //     shift 2 = prior closed bar, shift 1 = trigger (just-closed) bar. ---
   const double ema5_prev  = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 2);
   const double ema5_now   = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema13_prev = QM_EMA(_Symbol, _Period, strategy_ema_mid_period,  2);
   const double ema13_now  = QM_EMA(_Symbol, _Period, strategy_ema_mid_period,  1);
   const double ema62_now  = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   if(ema5_prev <= 0.0 || ema5_now <= 0.0 || ema13_prev <= 0.0 ||
      ema13_now <= 0.0 || ema62_now <= 0.0)
      return false;

   const bool cross_up   = (ema5_prev <= ema13_prev && ema5_now > ema13_now);
   const bool cross_down = (ema5_prev >= ema13_prev && ema5_now < ema13_now);
   if(!cross_up && !cross_down)
      return false;

   // --- Gap STATE: |EMA13 - EMA62| >= gap threshold (pips), scale-correct. ---
   const double gap_distance = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_gap_pips);
   if(gap_distance <= 0.0)
      return false;
   const double gap = MathAbs(ema13_now - ema62_now);
   if(gap < gap_distance)
      return false;

   // --- Momentum STATE: MACD(30,60,30) main line sign (above/below zero). ---
   const double macd_main = QM_MACD_Main(_Symbol, _Period,
                                         strategy_macd_fast_period,
                                         strategy_macd_slow_period,
                                         strategy_macd_signal_period, 1);

   // --- Long: EMA5/13 cross up + EMA13 above EMA62 + MACD main > 0. ---
   if(cross_up && ema13_now > ema62_now && macd_main > 0.0)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopFixedPips(_Symbol, QM_BUY, entry, (int)strategy_sl_pips);
      const double tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, strategy_tp_pips / strategy_sl_pips);
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "carter_ema513cross_gap_macd_long";
      return true;
     }

   // --- Short: EMA5/13 cross down + EMA13 below EMA62 + MACD main < 0. ---
   if(cross_down && ema13_now < ema62_now && macd_main < 0.0)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopFixedPips(_Symbol, QM_SELL, entry, (int)strategy_sl_pips);
      const double tp = QM_TakeRR(_Symbol, QM_SELL, entry, sl, strategy_tp_pips / strategy_sl_pips);
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "carter_ema513cross_gap_macd_short";
      return true;
     }

   return false;
  }

// Fixed SL/TP only — no active trade management.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit beyond the fixed SL/TP.
bool Strategy_ExitSignal()
  {
   return false;
  }

// Defer to the central news filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
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
                        qm_news_mode_legacy,           // legacy back-compat
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,                            // pause-before (legacy hint)
                        30,                            // pause-after (legacy hint)
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,              // FW1 Axis A
                        qm_news_compliance))           // FW1 Axis B
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
