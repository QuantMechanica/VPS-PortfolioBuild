#property strict
#property version   "5.0"
#property description "QM5_11670 suhr-bank-stop-run-m5 — Bank Stop-Run Reversal (liquidity grab, M5)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11670 suhr-bank-stop-run-m5
// -----------------------------------------------------------------------------
// Source: Sterling Suhr (Day Trading Forex Live), "The Bank Trading Forex
//   Strategy" in TradingPub "6 Simple Strategies for Trading Forex" (~2015).
// Card: artifacts/cards_approved/QM5_11670_suhr-bank-stop-run-m5.md
//   (g0_status APPROVED).
//
// Concept — "Bank stop-run reversal" / liquidity grab / stop hunt, on M5:
//   Banks push price beyond a pre-defined manipulation point (a liquidity pool
//   where retail stops cluster), fill against the triggered stops, then reverse
//   price back through the level. The reversal back INSIDE the level is the
//   entry. Sibling of QM5_11489 (D1 realization, same author/strategy); this is
//   the card's M5 realization with intraday confirmation + pullback.
//
// Manipulation points (STATE): the PRIOR DAY's high and low — read from the
//   last CLOSED D1 bar (shift 1). PrevDayHigh is the resistance pool (short
//   setups), PrevDayLow is the support pool (long setups). These are fixed
//   reference levels for the whole current day; computed once per closed M5
//   bar from a single D1 OHLC read (perf-allowed).
//
// Three-step confirmation on M5 (card mechanic), reframed as ONE closed-bar
//   trigger EVENT gated by preceding STATEs so the two-cross-same-bar trap
//   never applies:
//     1. Stop-run STATE  : within the confirm_window closed M5 bars that
//          PRECEDE the confirmation bar, at least one bar pierced BEYOND the
//          level by >= sweep_pips (the stop run). Its extreme = the stop-run
//          extreme (used for SL + the pullback proximity gate).
//     2. Confirmation EVENT (the single trigger): the just-closed M5 bar
//          (shift 1) CLOSED back INSIDE the level (close[1] above PrevDayLow
//          for longs / below PrevDayHigh for shorts) — the stop run is
//          confirmed false. One bar = one event.
//     3. Pullback proximity gate: the confirmation close (the market-fill
//          reference) must be within pullback_pips of the stop-run extreme, so
//          we enter near the manipulation level, not chasing an extended move.
//
//   Invalidation (card): if two consecutive recent closed bars BOTH opened AND
//     closed beyond the level, the level is broken (a real breakout, not a stop
//     run) — cancel the setup, no entry.
//
//   Stop : sl_pips beyond the stop-run candle extreme (clears the stop-run
//          candle, per the card's "stop placed beyond the stop-run candle
//          extreme"). Take : the OPPOSITE prior-day level in the trade
//          direction (the next manipulation point); falls back to
//          tp_fallback_pips if that geometry is degenerate / too close.
//
// Gapless-safe: every comparison uses closed-bar high/low/close, never a gap
//   open (.DWX CFDs are gapless: open[0]==close[1]). Spread guard fails OPEN on
//   .DWX zero modeled spread.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11670;
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
input int    strategy_sweep_pips         = 3;     // min penetration beyond the manip point (the stop run)
input int    strategy_confirm_window     = 5;     // closed M5 bars before the confirmation bar to find the stop run
input int    strategy_pullback_pips      = 15;    // confirmation close must be within this of the stop-run extreme
input int    strategy_sl_pips            = 20;    // SL placed this many pips beyond the stop-run candle extreme
input int    strategy_tp_fallback_pips   = 40;    // TP fallback when the opposite D1 level is degenerate
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

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

   // Reference stop distance for the spread cap: the SL pips scaled to price.
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   const double stop_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_pips);
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Stop-run reversal entry. Caller guarantees QM_IsNewBar() == true (closed M5 bar).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(strategy_confirm_window < 1 || strategy_sweep_pips < 0)
      return false;

   const double pip = QM_StopRulesPipsToPriceDistance(_Symbol, 1); // one pip in price terms
   if(pip <= 0.0)
      return false;
   const double sweep    = strategy_sweep_pips    * pip;
   const double pullback = strategy_pullback_pips * pip;

   // --- Manipulation points (STATE): prior-day high/low, last CLOSED D1 bar.
   //     Single closed-bar D1 read; recomputed once per closed M5 bar. ---
   const double prev_day_high = iHigh(_Symbol, PERIOD_D1, 1); // perf-allowed: single closed-bar D1 read
   const double prev_day_low  = iLow(_Symbol, PERIOD_D1, 1);
   if(prev_day_high <= 0.0 || prev_day_low <= 0.0 || prev_day_high <= prev_day_low)
      return false;

   // --- Confirmation bar (the single trigger): the last closed M5 bar (shift 1). ---
   const double conf_close = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double conf_open  = iOpen(_Symbol, _Period, 1);
   const double conf_high  = iHigh(_Symbol, _Period, 1);
   const double conf_low   = iLow(_Symbol, _Period, 1);
   if(conf_close <= 0.0 || conf_open <= 0.0 || conf_high <= 0.0 || conf_low <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   // =========================================================================
   // SHORT setup — manipulation point = prior-day HIGH (resistance pool).
   //   Stop run STATE : a recent bar pierced ABOVE prev_day_high by >= sweep.
   //   Trigger EVENT  : confirmation bar CLOSED back BELOW prev_day_high.
   // =========================================================================
   if(conf_close < prev_day_high)
     {
      // Stop-run STATE: scan the confirm_window bars that PRECEDE the
      // confirmation bar (shift 2 .. confirm_window+1) for a pierce above the
      // level by >= sweep. Track the highest such pierce (the stop-run extreme).
      double sweep_high      = -1.0;
      bool   found_stop_run  = false;
      int    beyond_run      = 0;     // consecutive open&close-beyond bars => real breakout
      const int first_shift  = 2;
      const int last_shift   = strategy_confirm_window + 1;
      for(int s = first_shift; s <= last_shift; ++s)
        {
         const double h = iHigh(_Symbol, _Period, s);  // perf-allowed: bounded closed-bar structural scan
         const double o = iOpen(_Symbol, _Period, s);
         const double c = iClose(_Symbol, _Period, s);
         if(h <= 0.0 || o <= 0.0 || c <= 0.0)
            break; // insufficient history

         if(h >= prev_day_high + sweep)
           {
            found_stop_run = true;
            if(h > sweep_high)
               sweep_high = h;
           }

         // Invalidation: two CONSECUTIVE bars that open AND close beyond the
         // level => the level genuinely broke (not a stop run).
         if(o > prev_day_high && c > prev_day_high)
           {
            beyond_run++;
            if(beyond_run >= 2)
              { found_stop_run = false; break; }
           }
         else
            beyond_run = 0;
        }

      if(found_stop_run && sweep_high > 0.0)
        {
         const double s_entry = bid; // sell at market (framework fills at send)
         // Pullback proximity gate: enter near the level, not chasing.
         if((sweep_high - s_entry) <= pullback)
           {
            const double sl = QM_StopRulesNormalizePrice(_Symbol, sweep_high + strategy_sl_pips * pip);
            if(sl > s_entry)
              {
               // TP = opposite manipulation point (prior-day low); fallback if degenerate.
               double tp = prev_day_low;
               const double min_tp_dist = strategy_tp_fallback_pips * pip;
               if((s_entry - tp) < min_tp_dist)
                  tp = s_entry - min_tp_dist;
               tp = QM_StopRulesNormalizePrice(_Symbol, tp);
               if(tp > 0.0 && tp < s_entry)
                 {
                  req.type   = QM_SELL;
                  req.price  = 0.0;   // framework fills market price at send
                  req.sl     = sl;
                  req.tp     = tp;
                  req.reason = "bank_stop_run_short";
                  return true;
                 }
              }
           }
        }
     }

   // =========================================================================
   // LONG setup — manipulation point = prior-day LOW (support pool).
   //   Stop run STATE : a recent bar pierced BELOW prev_day_low by >= sweep.
   //   Trigger EVENT  : confirmation bar CLOSED back ABOVE prev_day_low.
   // =========================================================================
   if(conf_close > prev_day_low)
     {
      double sweep_low      = -1.0;
      bool   found_stop_run = false;
      int    beyond_run     = 0;
      const int first_shift = 2;
      const int last_shift  = strategy_confirm_window + 1;
      for(int s = first_shift; s <= last_shift; ++s)
        {
         const double l = iLow(_Symbol, _Period, s);   // perf-allowed: bounded closed-bar structural scan
         const double o = iOpen(_Symbol, _Period, s);
         const double c = iClose(_Symbol, _Period, s);
         if(l <= 0.0 || o <= 0.0 || c <= 0.0)
            break;

         if(l <= prev_day_low - sweep)
           {
            found_stop_run = true;
            if(sweep_low < 0.0 || l < sweep_low)
               sweep_low = l;
           }

         if(o < prev_day_low && c < prev_day_low)
           {
            beyond_run++;
            if(beyond_run >= 2)
              { found_stop_run = false; break; }
           }
         else
            beyond_run = 0;
        }

      if(found_stop_run && sweep_low > 0.0)
        {
         const double l_entry = ask; // buy at market
         if((l_entry - sweep_low) <= pullback)
           {
            const double sl = QM_StopRulesNormalizePrice(_Symbol, sweep_low - strategy_sl_pips * pip);
            if(sl < l_entry && sl > 0.0)
              {
               double tp = prev_day_high;
               const double min_tp_dist = strategy_tp_fallback_pips * pip;
               if((tp - l_entry) < min_tp_dist)
                  tp = l_entry + min_tp_dist;
               tp = QM_StopRulesNormalizePrice(_Symbol, tp);
               if(tp > l_entry)
                 {
                  req.type   = QM_BUY;
                  req.price  = 0.0;
                  req.sl     = sl;
                  req.tp     = tp;
                  req.reason = "bank_stop_run_long";
                  return true;
                 }
              }
           }
        }
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
