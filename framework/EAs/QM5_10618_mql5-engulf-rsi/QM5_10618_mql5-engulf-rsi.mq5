#property strict
#property version   "5.0"
#property description "QM5_10618 MQL5 Engulfing + RSI Reversal"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails). The framework provides:
//
//   - QM_IsNewBar(sym="", tf=PERIOD_CURRENT)  — closed-bar gate
//   - QM_ATR / QM_EMA / QM_SMA / QM_RSI / QM_MACD_Main / QM_MACD_Signal /
//     QM_ADX / QM_ADX_PlusDI / QM_ADX_MinusDI /
//     QM_BB_Upper / QM_BB_Middle / QM_BB_Lower    (from QM_Indicators.mqh)
//   - QM_TM_OpenPosition(req, ticket) / QM_TM_ClosePosition(ticket, reason)
//   - QM_TM_MoveToBreakEven / QM_TM_TrailATR / QM_TM_TrailStep / QM_TM_PartialClose
//   - QM_LotsForRisk(symbol, sl_points)        — risk model lot sizing
//   - QM_StopFixedPips / QM_StopATR / QM_StopStructure / QM_StopVolatility
//   - QM_FrameworkHandleFridayClose / QM_KillSwitchCheck / QM_NewsAllowsTrade
//
// DO NOT
//   - Write per-EA IsNewBar() — use QM_IsNewBar()
//   - Call iATR / iMA / iRSI / iMACD / iADX / iBands or CopyBuffer directly —
//     use the QM_* readers above. The framework pools handles and releases them
//     on shutdown.
//   - CopyRates over warmup windows on every tick. If you genuinely need raw
//     bar arrays, gate by QM_IsNewBar so the work runs once per closed bar.
//   - Hand-edit framework/include/QM/QM_MagicResolver.mqh. After adding rows
//     to magic_numbers.csv, run:
//         python framework/scripts/update_magic_resolver.py
//     This is idempotent and preserves all rows.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10618;
input int    qm_magic_slot_offset       = 0;
// FW3: Q07 Multi-Seed uses one of the canonical seeds (42, 17, 99, 7, 2026).
// All other phases use 42 by default. Stress / noise dimensions read from
// this single seed so reproducibility is guaranteed across re-runs.
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
// FW1 2026-05-23 — Two-axis news filter per Vault Q09.
//   AXIS A (temporal): per-event behaviour. Default mode 3 = pause 30min pre+post.
//   AXIS B (compliance): prop-firm blackout overlay. Default DXZ = no extra rules.
// A trade is allowed only if BOTH axes allow. See Vault `Q09 News Impact Mode`.
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
// Legacy single-mode input kept for back-compat with pre-FW1 setfiles.
// New EAs use qm_news_temporal + qm_news_compliance above and leave this OFF.
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
// FW2 2026-05-23 — only populated by Q05 MED / Q06 HARSH stress setfiles.
// Default 0.0 = no rejection (Q02/Q03/Q04/Q07/Q08/Q09/Q10/Q13 backtests).
// Q06 HARSH sets to 0.10 (10% of entries randomly dropped before broker send,
// deterministic per qm_rng_seed). MED slip/spread/commission live in the
// tester groups file, not as EA inputs.
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
// Card QM5_10618 — MQL5 Engulfing + RSI Reversal (H1).
//   Entry long : Bullish Engulfing + RSI(1) below strategy_rsi_entry_low (40).
//   Entry short: Bearish Engulfing + RSI(1) above strategy_rsi_entry_high (60).
//   Exit       : RSI crosses through 30 or 70 against the open position.
//   Stop       : beyond engulfing extreme, capped at 1.75 x ATR(14).
//   Take       : 1.5R.
input int    strategy_rsi_period          = 14;     // RSI for entry confirmation + exit cross
input double strategy_rsi_entry_low       = 40.0;   // long confirm: RSI(1) below this
input double strategy_rsi_entry_high      = 60.0;   // short confirm: RSI(1) above this
input double strategy_rsi_exit_low        = 30.0;   // RSI exit cross level (lower)
input double strategy_rsi_exit_high       = 70.0;   // RSI exit cross level (upper)
input int    strategy_atr_period          = 14;     // ATR for the stop cap
input double strategy_atr_sl_cap_mult     = 1.75;   // SL capped at this x ATR
input double strategy_tp_rr               = 1.50;   // take-profit R multiple
input int    strategy_max_spread_points   = 0;      // 0 = no spread cap (fail-open on .DWX)

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // .DWX BACKTEST INVARIANT #1: never fail-closed on zero modeled spread.
   // Only block a genuinely wide spread when a positive cap is configured.
   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > 0 && spread_points > strategy_max_spread_points)
         return true;
     }

   return false;
  }

bool HasOurOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
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
      return true;
     }

   return false;
  }

// Engulfing detection on the last completed bar (shift 1) vs the prior bar
// (shift 2). Returns +1 bullish, -1 bearish, 0 none. Reports the pattern
// extreme prices for structure-based stop placement.
//   .DWX gapless CFDs: open[1] == close[2], so body-engulfing is the correct
//   trigger (no real-gap dependency). The pattern is the SOLE trigger; the RSI
//   threshold is a confirming STATE checked separately, not a second cross.
int EngulfingSignal(double &pattern_low, double &pattern_high)
  {
   pattern_low = 0.0;
   pattern_high = 0.0;

   const double prev_open  = iOpen(_Symbol, _Period, 2);
   const double prev_close = iClose(_Symbol, _Period, 2);
   const double prev_low   = iLow(_Symbol, _Period, 2);
   const double prev_high  = iHigh(_Symbol, _Period, 2);
   const double last_open  = iOpen(_Symbol, _Period, 1);
   const double last_close = iClose(_Symbol, _Period, 1);
   const double last_low   = iLow(_Symbol, _Period, 1);
   const double last_high  = iHigh(_Symbol, _Period, 1);
   if(prev_open <= 0.0 || prev_close <= 0.0 || prev_low <= 0.0 || prev_high <= 0.0 ||
      last_open <= 0.0 || last_close <= 0.0 || last_low <= 0.0 || last_high <= 0.0)
      return 0;

   const double prev_body = MathAbs(prev_close - prev_open);
   const double last_body = MathAbs(last_close - last_open);
   if(prev_body <= 0.0 || last_body <= 0.0)
      return 0;

   pattern_low  = MathMin(prev_low, last_low);
   pattern_high = MathMax(prev_high, last_high);

   const double prev_body_low  = MathMin(prev_open, prev_close);
   const double prev_body_high = MathMax(prev_open, prev_close);
   const double last_body_low  = MathMin(last_open, last_close);
   const double last_body_high = MathMax(last_open, last_close);
   const bool engulfs_body = (last_body_low <= prev_body_low && last_body_high >= prev_body_high);
   if(!engulfs_body)
      return 0;

   // Bullish engulfing: prior bar bearish, last bar bullish.
   if(prev_close < prev_open && last_close > last_open)
      return 1;

   // Bearish engulfing: prior bar bullish, last bar bearish.
   if(prev_close > prev_open && last_close < last_open)
      return -1;

   return 0;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_10618_ENGULF_RSI";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(HasOurOpenPosition())
      return false;

   double pattern_low = 0.0;
   double pattern_high = 0.0;
   const int signal = EngulfingSignal(pattern_low, pattern_high);
   if(signal == 0)
      return false;

   // RSI confirmation on the last completed bar — a STATE, not a second cross.
   const double rsi = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   if(rsi <= 0.0)
      return false;

   if(signal > 0 && rsi >= strategy_rsi_entry_low)
      return false;   // bullish engulf needs RSI below the oversold threshold
   if(signal < 0 && rsi <= strategy_rsi_entry_high)
      return false;   // bearish engulf needs RSI above the overbought threshold

   const QM_OrderType side = (signal > 0) ? QM_BUY : QM_SELL;
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(entry <= 0.0 || point <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr <= 0.0 || strategy_atr_sl_cap_mult <= 0.0 || strategy_tp_rr <= 0.0)
      return false;

   // Stop beyond the engulfing extreme, capped at 1.75 x ATR distance.
   // "Capped" = the stop is never farther than the ATR cap; if the structure
   // extreme is wider than the cap, clamp the stop distance to the cap.
   const double spread_buffer = MathMax((double)spread_points * point, point);
   const double atr_cap_dist = atr * strategy_atr_sl_cap_mult;
   double stop_price = 0.0;
   if(side == QM_BUY)
     {
      const double structure_stop = pattern_low - spread_buffer;
      const double cap_stop = entry - atr_cap_dist;
      // Take the tighter (higher) of the two so distance <= cap.
      stop_price = QM_StopRulesNormalizePrice(_Symbol, MathMax(structure_stop, cap_stop));
      if(stop_price <= 0.0 || stop_price >= entry)
         return false;
      req.reason = "QM5_10618_BULL_ENGULF_RSI";
     }
   else
     {
      const double structure_stop = pattern_high + spread_buffer;
      const double cap_stop = entry + atr_cap_dist;
      // Take the tighter (lower) of the two so distance <= cap.
      stop_price = QM_StopRulesNormalizePrice(_Symbol, MathMin(structure_stop, cap_stop));
      if(stop_price <= entry)
         return false;
      req.reason = "QM5_10618_BEAR_ENGULF_RSI";
     }

   const double take_price = QM_TakeRR(_Symbol, side, entry, stop_price, strategy_tp_rr);
   if(take_price <= 0.0)
      return false;
   if(side == QM_BUY && take_price <= entry)
      return false;
   if(side == QM_SELL && take_price >= entry)
      return false;

   req.type = side;
   req.sl = stop_price;
   req.tp = take_price;
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card baseline has no trailing, break-even, partial close, or add-on logic.
   // V5 hard SL/TP remain active; RSI-cross exit handled in Strategy_ExitSignal.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
//   Card exit: close long when RSI crosses DOWN through 70 or 30; close short
//   when RSI crosses UP through 30 or 70. A cross uses RSI(2) -> RSI(1).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   if(!HasOurOpenPosition())
      return false;

   const double rsi_prev = QM_RSI(_Symbol, _Period, strategy_rsi_period, 2);
   const double rsi_last = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   if(rsi_prev <= 0.0 || rsi_last <= 0.0)
      return false;

   // Downward cross through a level: prev above/at, last strictly below.
   const bool crossed_down_high = (rsi_prev >= strategy_rsi_exit_high && rsi_last < strategy_rsi_exit_high);
   const bool crossed_down_low  = (rsi_prev >= strategy_rsi_exit_low  && rsi_last < strategy_rsi_exit_low);
   // Upward cross through a level: prev below/at, last strictly above.
   const bool crossed_up_low    = (rsi_prev <= strategy_rsi_exit_low  && rsi_last > strategy_rsi_exit_low);
   const bool crossed_up_high   = (rsi_prev <= strategy_rsi_exit_high && rsi_last > strategy_rsi_exit_high);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const long position_type = PositionGetInteger(POSITION_TYPE);
      // Close long if RSI crosses downward through 70 or 30.
      if(position_type == POSITION_TYPE_BUY && (crossed_down_high || crossed_down_low))
         return true;
      // Close short if RSI crosses upward through 30 or 70.
      if(position_type == POSITION_TYPE_SELL && (crossed_up_low || crossed_up_high))
         return true;
     }

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade(...)
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
   // FW1 — 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults.
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

   // Per-tick: trade management can adjust SL/TP on open positions.
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit (e.g. time stop). Separate from SL/TP.
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

   // Per-closed-bar: entry-signal evaluation. Gating here avoids 99% of
   // per-tick recompute mistakes — EntrySignal sees one new closed bar per
   // call, not every incoming tick.
   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
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
   // FW4: feeds closing-deal net-profits to the KS kill-switch.
   // No-op outside Q13 (when no baseline.json exists).
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
