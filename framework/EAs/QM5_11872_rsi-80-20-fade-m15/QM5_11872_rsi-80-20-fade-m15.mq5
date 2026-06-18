#property strict
#property version   "5.0"
#property description "QM5_11872 rsi-80-20-fade-m15 — RSI(80/20) overbought/oversold fade (M15)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11872 rsi-80-20-fade-m15
// -----------------------------------------------------------------------------
// Source: Unknown author, "My Top Three Scalping Trading Strategies", ~2020
//   (source_id 182e6755-015a-50ff-a0c9-b5507c5308b4, local PDF archive).
// Card: artifacts/cards_approved/QM5_11872_rsi-80-20-fade-m15.md
//   (g0_status APPROVED).
//
// Mechanics (counter-trend mean-reversion fade, closed-bar reads at shift 1; M15):
//   Concept     : Fade RSI(14) extremes at the 80/20 levels. Tighter than the
//                 standard 70/30 to cut false signals at the cost of frequency.
//   Short EVENT : RSI was overbought (>= rsi_upper) and crosses back DOWN below
//                 rsi_upper on the trigger bar -> SELL at next bar open.
//   Long  EVENT : RSI was oversold (<= rsi_lower) and crosses back UP above
//                 rsi_lower on the trigger bar -> BUY at next bar open.
//   Stop        : fixed strategy_sl_pips from entry.
//   Take profit : fixed strategy_tp_pips from entry (1:1 RR by default).
//
// Two-cross trap: only ONE cross EVENT triggers each side (the cross BACK across
// the extreme level). The "was at the extreme" condition is read from the
// immediately-prior closed bar (shift 2), the cross-back from the trigger bar
// (shift 1) — a single fresh event per bar. The upper-fade and lower-fade
// conditions are mutually exclusive, so long and short can never fire together.
//
// .DWX invariants honoured:
//   - Spread guard fails OPEN on zero modeled spread (only a genuinely wide
//     spread blocks). No swap gate. RISK_FIXED in tester.
//   - Pip-correct SL/TP via QM_StopFixedPips / QM_TakeRR (no raw points).
//   - QM_IsNewBar consumed once by the framework OnTick path; hooks do not call
//     it again.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11872;
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
input int    strategy_rsi_period        = 14;     // RSI lookback period
input double strategy_rsi_upper         = 80.0;   // overbought extreme (fade short)
input double strategy_rsi_lower         = 20.0;   // oversold extreme (fade long)
input double strategy_sl_pips           = 5.0;    // fixed stop in pips
input double strategy_tp_pips           = 5.0;    // fixed take profit in pips (1:1)
input double strategy_spread_pct_of_stop = 30.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only. Fail-OPEN on .DWX zero spread:
// only a genuinely wide spread (> pct of the fixed stop distance) blocks.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double stop_distance = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_sl_pips);
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Counter-trend entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double rsi_now  = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1); // trigger bar (closed)
   const double rsi_prev = QM_RSI(_Symbol, _Period, strategy_rsi_period, 2); // bar before trigger
   if(rsi_now <= 0.0 || rsi_prev <= 0.0)
      return false;

   // --- Short EVENT: was overbought, crossed back DOWN below the upper level ---
   const bool fade_short = (rsi_prev >= strategy_rsi_upper &&
                            rsi_now  <  strategy_rsi_upper);

   // --- Long EVENT: was oversold, crossed back UP above the lower level ---
   const bool fade_long  = (rsi_prev <= strategy_rsi_lower &&
                            rsi_now  >  strategy_rsi_lower);

   // Mutually exclusive by construction — never both on one bar.
   if(!fade_short && !fade_long)
      return false;

   const QM_OrderType otype = fade_short ? QM_SELL : QM_BUY;

   const double entry = (otype == QM_SELL) ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                           : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopFixedPips(_Symbol, otype, entry, (int)strategy_sl_pips);
   if(sl <= 0.0)
      return false;

   const double rr = (strategy_sl_pips > 0.0) ? (strategy_tp_pips / strategy_sl_pips) : 1.0;
   const double tp = QM_TakeRR(_Symbol, otype, entry, sl, rr);
   if(tp <= 0.0)
      return false;

   req.type   = otype;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = fade_short ? "rsi8020_fade_short" : "rsi8020_fade_long";
   return true;
  }

// Fixed SL/TP only — no active management, no trailing.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit — positions exit at the fixed SL or TP.
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
