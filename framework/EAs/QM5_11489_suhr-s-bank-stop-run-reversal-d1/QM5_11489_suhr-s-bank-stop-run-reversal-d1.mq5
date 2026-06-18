#property strict
#property version   "5.0"
#property description "QM5_11489 suhr-s-bank-stop-run-reversal-d1 — Bank Stop-Run Reversal (liquidity sweep, D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11489 suhr-s-bank-stop-run-reversal-d1
// -----------------------------------------------------------------------------
// Source: Sterling Suhr, "The Bank Trading Forex Strategy" in TradingPub
//   "6 Simple Strategies for Trading Forex" (2014).
// Card: artifacts/cards_approved/QM5_11489_suhr-s-bank-stop-run-reversal-d1.md
//   (g0_status APPROVED).
//
// Concept — "Bank stop-run reversal" / liquidity grab / stop hunt:
//   Banks push price beyond a prior swing extreme to trigger retail stops
//   clustered there (the liquidity pool), fill against them, then reverse.
//   Mechanically this is the same family as a liquidity-sweep bar / Wyckoff
//   spring: price SWEEPS beyond a prior swing high/low (runs the stops) and
//   then CLOSES back inside the prior range on the SAME closed bar = the
//   reversal trigger.
//
// D1-NATIVE realization (card framing was H1-intraday with D1 levels; the
//   build brief specifies a D1-native realization of the same mechanical
//   family). Swing levels are computed in-EA from closed-bar D1 OHLC, bounded
//   to swing_lookback bars (perf-allowed: a single closed-bar-gated scan).
//
//   Prior swing extremes (STATE): over the swing_lookback closed bars that
//     PRECEDE the candidate sweep bar (shift 2 .. swing_lookback+1), take the
//     highest high (swing_high) and the lowest low (swing_low). Measuring the
//     level over bars before the sweep bar means the sweep bar never defines
//     its own level.
//
//   SHORT trigger EVENT (stop run above the swing high): the last closed bar
//     (shift 1) pierced ABOVE swing_high by >= sweep_pips (high[1] >=
//     swing_high + sweep) AND CLOSED back BELOW swing_high (close[1] <
//     swing_high). One bar both sweeps and rejects = a SINGLE event, so the
//     two-cross-same-bar zero-trade trap does not apply.
//
//   LONG trigger EVENT (stop run below the swing low): low[1] <= swing_low -
//     sweep AND close[1] > swing_low.
//
//   Stop : beyond the sweep bar's extreme by sl_buffer_pips (clears the
//          stop-run candle, per the card's "stop just beyond the stop-run
//          candle extreme").
//   Take : reward_rr multiple of the stop distance (card P2 = 3R asymmetric).
//
// Gapless-safe: every comparison uses prior-bar high/low/close, never a gap
//   open (.DWX CFDs are gapless: open[0]==close[1]). Spread guard fails OPEN on
//   .DWX zero modeled spread.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11489;
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
input int    strategy_swing_lookback    = 10;    // prior closed D1 bars defining the swing extreme
input int    strategy_sweep_pips        = 3;     // min penetration beyond the swing extreme (the stop run)
input int    strategy_sl_buffer_pips    = 5;     // SL placed this many pips beyond the sweep bar extreme
input double strategy_reward_rr         = 3.0;   // take-profit = reward_rr * stop distance (card 3R)
input double strategy_spread_pct_of_stop = 15.0; // skip if spread > this % of stop distance
input bool   strategy_block_friday      = true;  // card: no Friday entry

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — sweep/reversal work is in
// Strategy_EntrySignal on the closed-bar path. Fail-OPEN on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   // Reference stop distance for the spread cap: the SL buffer scaled to price.
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   const double stop_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_buffer_pips);
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Stop-run reversal entry. Caller guarantees QM_IsNewBar() == true (closed bar).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Card filter: no Friday entry (last closed bar's open day == Friday).
   if(strategy_block_friday)
     {
      MqlDateTime dt;
      TimeToStruct(iTime(_Symbol, _Period, 1), dt); // perf-allowed: single closed-bar time read
      if(dt.day_of_week == 5)
         return false;
     }

   if(strategy_swing_lookback < 1 || strategy_sweep_pips < 0)
      return false;

   const double pip = QM_StopRulesPipsToPriceDistance(_Symbol, 1); // one pip in price terms
   if(pip <= 0.0)
      return false;
   const double sweep = strategy_sweep_pips * pip;

   // --- Prior swing extremes (STATE): bounded scan over the closed bars that
   //     PRECEDE the candidate sweep bar (shift 2 .. swing_lookback+1). The
   //     sweep bar (shift 1) is excluded so it never defines its own level. ---
   double swing_high = -1.0;
   double swing_low  = -1.0;
   const int first_shift = 2;
   const int last_shift  = strategy_swing_lookback + 1;
   for(int s = first_shift; s <= last_shift; ++s)
     {
      const double h = iHigh(_Symbol, _Period, s); // perf-allowed: bounded closed-bar structural scan
      const double l = iLow(_Symbol, _Period, s);
      if(h <= 0.0 || l <= 0.0)
         return false; // insufficient history for the swing window
      if(swing_high < 0.0 || h > swing_high)
         swing_high = h;
      if(swing_low < 0.0 || l < swing_low)
         swing_low = l;
     }
   if(swing_high <= 0.0 || swing_low <= 0.0)
      return false;

   // --- Candidate sweep bar (the last closed bar, shift 1). ---
   const double sweep_high  = iHigh(_Symbol, _Period, 1);  // perf-allowed: single closed-bar read
   const double sweep_low   = iLow(_Symbol, _Period, 1);
   const double sweep_close = iClose(_Symbol, _Period, 1);
   if(sweep_high <= 0.0 || sweep_low <= 0.0 || sweep_close <= 0.0)
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0 || bid <= 0.0)
      return false;

   // --- SHORT trigger EVENT: swept above swing_high then closed back below. ---
   const bool short_sweep  = (sweep_high  >= swing_high + sweep);
   const bool short_reject = (sweep_close <  swing_high);
   if(short_sweep && short_reject)
     {
      const double s_entry = bid; // sell at market (framework fills at send)
      // SL beyond the sweep bar's high (clears the stop-run candle extreme).
      const double sl = QM_StopRulesNormalizePrice(_Symbol, sweep_high + strategy_sl_buffer_pips * pip);
      if(sl <= s_entry)
         return false; // degenerate geometry — skip
      const double tp = QM_TakeRR(_Symbol, QM_SELL, s_entry, sl, strategy_reward_rr);
      if(tp <= 0.0)
         return false;

      req.type   = QM_SELL;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "stop_run_reversal_short";
      return true;
     }

   // --- LONG trigger EVENT: swept below swing_low then closed back above. ---
   const bool long_sweep  = (sweep_low   <= swing_low - sweep);
   const bool long_reject = (sweep_close >  swing_low);
   if(long_sweep && long_reject)
     {
      const double l_entry = entry; // buy at market
      // SL beyond the sweep bar's low (clears the stop-run candle extreme).
      const double sl = QM_StopRulesNormalizePrice(_Symbol, sweep_low - strategy_sl_buffer_pips * pip);
      if(sl >= l_entry)
         return false; // degenerate geometry — skip
      const double tp = QM_TakeRR(_Symbol, QM_BUY, l_entry, sl, strategy_reward_rr);
      if(tp <= 0.0)
         return false;

      req.type   = QM_BUY;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "stop_run_reversal_long";
      return true;
     }

   return false;
  }

// Fixed SL/TP only — no active trade management.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit; the fixed SL/TP handle the trade.
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
