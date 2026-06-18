#property strict
#property version   "5.0"
#property description "QM5_11540 carter-t-h1-ema5-13-62-macd3060-sep — Triple EMA stack + MACD zero-cross + EMA separation (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11540 carter-t-h1-ema5-13-62-macd3060-sep
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Forex Trading Strategies (1 Hour Time Frame)",
//         System #14, self-published 2014.
// Card: artifacts/cards_approved/QM5_11540_carter-t-h1-ema5-13-62-macd3060-sep.md
//       (g0_status APPROVED). source_id 3001a121-97a0-5db0-b6ff-69b89a0fc07d.
//
// Mechanics (closed-bar reads at shift 1/2; H1):
//   Trend STATE  : EMA(5) > EMA(13) > EMA(62)         (long)
//                  EMA(5) < EMA(13) < EMA(62)         (short)
//   Separation STATE: MathAbs(EMA13 - EMA62) >= sep_pips * pip   (trend strength)
//   Trigger EVENT (single): MACD(30,60,30) main line crosses zero in the trend
//                  direction (one fresh cross / bar). The EMA stack + separation
//                  are STATE filters — only the MACD zero-cross is the trigger,
//                  which avoids the two-cross-same-bar zero-trade trap.
//   Stop         : fixed sl_pips (30, P2 cap 35).
//   Take profit  : fixed tp_pips (50).
//   No-trade     : genuinely-wide spread cap (fail-open on .DWX zero spread);
//                  optional no-Friday-entry filter.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11540;
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
input int    strategy_ema_fast_period   = 5;      // fastest EMA (stack top)
input int    strategy_ema_mid_period    = 13;     // middle EMA
input int    strategy_ema_slow_period   = 62;     // slowest EMA (stack base)
input int    strategy_macd_fast_period  = 30;     // MACD fast EMA
input int    strategy_macd_slow_period  = 60;     // MACD slow EMA
input int    strategy_macd_signal_period = 30;    // MACD signal EMA (unused by zero-cross; param of the indicator)
input double strategy_separation_pips   = 30.0;   // min |EMA13 - EMA62| in pips (trend-strength filter)
input double strategy_sl_pips           = 30.0;   // stop-loss distance in pips (P2 cap 35)
input double strategy_tp_pips           = 50.0;   // take-profit distance in pips
input double strategy_spread_cap_pips   = 15.0;   // skip if genuine spread exceeds this (pips)
input bool   strategy_no_friday_entry   = true;   // block new entries on Friday (broker time)

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

// Triple-EMA-stack + MACD-zero-cross + separation entry. Caller guarantees
// QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Optional no-Friday-entry filter (broker time).
   if(strategy_no_friday_entry)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.day_of_week == 5) // Friday
         return false;
     }

   // --- Trend STATE: triple-EMA stack at the closed bar (shift 1) ---
   const double ema_fast = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_mid  = QM_EMA(_Symbol, _Period, strategy_ema_mid_period,  1);
   const double ema_slow = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   if(ema_fast <= 0.0 || ema_mid <= 0.0 || ema_slow <= 0.0)
      return false;

   const bool stack_long  = (ema_fast > ema_mid && ema_mid > ema_slow);
   const bool stack_short = (ema_fast < ema_mid && ema_mid < ema_slow);
   if(!stack_long && !stack_short)
      return false;

   // --- Separation STATE: |EMA13 - EMA62| >= separation threshold (pips) ---
   const double sep_distance = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_separation_pips);
   if(sep_distance <= 0.0)
      return false;
   const double sep = MathAbs(ema_mid - ema_slow);
   if(sep < sep_distance)
      return false;

   // --- Trigger EVENT (single): MACD(30,60,30) main crosses zero in the
   //     trend direction. shift 2 = prior closed bar, shift 1 = trigger bar. ---
   const double macd_now  = QM_MACD_Main(_Symbol, _Period,
                                         strategy_macd_fast_period,
                                         strategy_macd_slow_period,
                                         strategy_macd_signal_period, 1);
   const double macd_prev = QM_MACD_Main(_Symbol, _Period,
                                         strategy_macd_fast_period,
                                         strategy_macd_slow_period,
                                         strategy_macd_signal_period, 2);

   const bool macd_cross_up   = (macd_prev <= 0.0 && macd_now > 0.0);
   const bool macd_cross_down = (macd_prev >= 0.0 && macd_now < 0.0);

   const double entry = SymbolInfoDouble(_Symbol, (stack_long ? SYMBOL_ASK : SYMBOL_BID));
   if(entry <= 0.0)
      return false;

   if(stack_long && macd_cross_up)
     {
      const double sl = QM_StopFixedPips(_Symbol, QM_BUY, entry, (int)strategy_sl_pips);
      const double tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, strategy_tp_pips / strategy_sl_pips);
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "carter_emastack_macd_sep_long";
      return true;
     }

   if(stack_short && macd_cross_down)
     {
      const double sl = QM_StopFixedPips(_Symbol, QM_SELL, entry, (int)strategy_sl_pips);
      const double tp = QM_TakeRR(_Symbol, QM_SELL, entry, sl, strategy_tp_pips / strategy_sl_pips);
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "carter_emastack_macd_sep_short";
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
