#property strict
#property version   "5.0"
#property description "QM5_11432 carter-multitf-candle-color-h1 — Multi-TF candle-direction alignment (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11432 carter-multitf-candle-color-h1
// -----------------------------------------------------------------------------
// Source: John Carter, "20 Strategies Collection (H1)" (local PDF archive).
// Card: artifacts/cards_approved/QM5_11432_carter-multitf-candle-color-h1.md
//       (g0_status APPROVED).
//
// Mechanics (signal TF = H1, multi-timeframe same-symbol HTF reads, NO basket):
//   Candle-direction STATE : the last CLOSED bar on each of M5/M15/M30/H1 is
//                            bullish (close>open) or bearish (close<open). A
//                            doji (|close-open| < doji_pips) on ANY of the four
//                            TFs voids the signal. This running per-TF
//                            close-vs-open agreement is the STATE.
//   Alignment-completion EVENT : all four TFs share the SAME direction AND the
//                            current price has followed through past the last
//                            H1 CLOSE by confirm_pips. The follow-through
//                            confirmation is gapless-safe — it references the
//                            prior H1 CLOSE (not a range), so it fires on
//                            .DWX gapless CFDs. The completion of the aligned
//                            sequence is the single EVENT that opens a trade.
//   Direction              : all-bullish -> BUY, all-bearish -> SELL.
//   Stop                   : fixed sl_pips from entry (scale-correct pips).
//   Take profit            : fixed tp_pips from entry.
//   Defensive exit         : the higher-TF (M30 or H1) last closed bar flips
//                            against the open position's direction.
//   Spread guard           : skip only a genuinely wide spread (fail-open on
//                            .DWX zero modeled spread).
//
// .DWX invariants honoured: fail-open spread guard, no swap gate, gapless-safe
// prior-CLOSE confirmation (not range), no external feed, scale-correct pips.
// MQL5 != C++: the reserved word `color` is NEVER used as an identifier here;
// candle direction is carried as int `dir` (+1 bull / -1 bear / 0 doji).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11432;
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
input int    strategy_confirm_pips      = 3;     // follow-through buffer past prior H1 close (pips)
input int    strategy_doji_pips         = 1;     // |close-open| below this = doji -> void signal (pips)
input int    strategy_sl_pips           = 20;    // stop-loss distance (pips)
input int    strategy_tp_pips           = 35;    // take-profit distance (pips)
input double strategy_spread_pct_of_stop = 15.0; // skip if spread > this % of stop distance
input bool   strategy_use_m5            = true;  // include M5 in the alignment set
input bool   strategy_exit_on_htf_flip  = true;  // defensive exit when M30/H1 flips against the trade

// -----------------------------------------------------------------------------
// Helpers (EA-local; raw OHLC reads are perf-allowed for bespoke candle-
// direction structural logic per the Framework Corset — there is no QM_*
// reader for raw close-vs-open candle direction).
// -----------------------------------------------------------------------------

// Direction of the last CLOSED bar on `tf`: +1 bullish, -1 bearish, 0 doji.
// Doji = |close-open| < doji distance (scale-correct pips). Returns 0 on any
// unavailable data so the caller voids the signal rather than trading blind.
int CandleDirection(const ENUM_TIMEFRAMES tf)
  {
   const double bar_close = iClose(_Symbol, tf, 1); // perf-allowed: single closed-bar read
   const double bar_open  = iOpen(_Symbol, tf, 1);  // perf-allowed: single closed-bar read
   if(bar_close <= 0.0 || bar_open <= 0.0)
      return 0;

   const double body = bar_close - bar_open;
   const double doji_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_doji_pips);
   if(doji_dist > 0.0 && MathAbs(body) < doji_dist)
      return 0; // doji on this TF voids the alignment

   if(body > 0.0)
      return +1;
   if(body < 0.0)
      return -1;
   return 0;
  }

// Aggregate candle-direction STATE across the active TF set. Returns +1 if all
// active TFs are bullish, -1 if all bearish, 0 otherwise (mixed or any doji).
int AlignedDirection()
  {
   int dir_h1  = CandleDirection(PERIOD_H1);
   int dir_m30 = CandleDirection(PERIOD_M30);
   int dir_m15 = CandleDirection(PERIOD_M15);
   if(dir_h1 == 0 || dir_m30 == 0 || dir_m15 == 0)
      return 0;

   int dir_m5 = +1; // neutral-to-the-test default when M5 excluded
   if(strategy_use_m5)
     {
      dir_m5 = CandleDirection(PERIOD_M5);
      if(dir_m5 == 0)
         return 0;
     }

   if(strategy_use_m5)
     {
      if(dir_h1 == +1 && dir_m30 == +1 && dir_m15 == +1 && dir_m5 == +1)
         return +1;
      if(dir_h1 == -1 && dir_m30 == -1 && dir_m15 == -1 && dir_m5 == -1)
         return -1;
      return 0;
     }

   if(dir_h1 == +1 && dir_m30 == +1 && dir_m15 == +1)
      return +1;
   if(dir_h1 == -1 && dir_m30 == -1 && dir_m15 == -1)
      return -1;
   return 0;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — alignment/signal work is in
// Strategy_EntrySignal on the closed-bar path. Fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double stop_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_pips);
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Multi-TF candle-direction alignment entry. Caller guarantees
// QM_IsNewBar() == true on the H1 chart (closed-bar cadence).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Candle-direction STATE across the active TF set ---
   const int aligned = AlignedDirection();
   if(aligned == 0)
      return false; // not all-aligned, or a doji voided it

   // --- Alignment-completion EVENT: gapless-safe follow-through past the prior
   //     H1 CLOSE by the confirmation buffer. Prior CLOSE (not range) so it
   //     fires on .DWX gapless CFDs. ---
   const double h1_close = iClose(_Symbol, PERIOD_H1, 1); // perf-allowed: single closed-bar read
   if(h1_close <= 0.0)
      return false;

   const double confirm_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_confirm_pips);
   if(confirm_dist <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   QM_OrderType side;
   double entry;
   if(aligned == +1)
     {
      // long: current price 3 pips above the prior H1 close (upward follow-through)
      if(!(ask > h1_close + confirm_dist))
         return false;
      side  = QM_BUY;
      entry = ask;
     }
   else
     {
      // short: current price 3 pips below the prior H1 close (downward follow-through)
      if(!(bid < h1_close - confirm_dist))
         return false;
      side  = QM_SELL;
      entry = bid;
     }

   const double sl = QM_StopFixedPips(_Symbol, side, entry, strategy_sl_pips);
   const double tp = QM_TakeFixedPips(_Symbol, side, entry, strategy_tp_pips);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = (aligned == +1) ? "mtf_candle_align_long" : "mtf_candle_align_short";
   return true;
  }

// No active trade management beyond the fixed pip stop/target. The defensive
// HTF-flip exit lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Defensive exit: the higher-TF (M30 or H1) last closed bar flips AGAINST the
// open position's direction (early exit signal from the card).
bool Strategy_ExitSignal()
  {
   if(!strategy_exit_on_htf_flip)
      return false;

   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Determine the direction of the position held by this EA's magic.
   int pos_dir = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      pos_dir = (ptype == POSITION_TYPE_BUY) ? +1 : -1;
      break;
     }
   if(pos_dir == 0)
      return false;

   const int dir_h1  = CandleDirection(PERIOD_H1);
   const int dir_m30 = CandleDirection(PERIOD_M30);

   // A non-zero HTF direction opposite the position is the flip event.
   if(pos_dir == +1 && (dir_h1 == -1 || dir_m30 == -1))
      return true;
   if(pos_dir == -1 && (dir_h1 == +1 || dir_m30 == +1))
      return true;

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
