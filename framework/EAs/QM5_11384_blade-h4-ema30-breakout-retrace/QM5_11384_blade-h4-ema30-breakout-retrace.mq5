#property strict
#property version   "5.0"
#property description "QM5_11384 blade-h4-ema30-breakout-retrace — EMA30 trend S/R breakout-then-retrace entry (H4)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11384 blade-h4-ema30-breakout-retrace
// -----------------------------------------------------------------------------
// Source: "The Blade Forex Strategies" — 4H Breakout System (anonymous,
//         ForexSuccessSecrets.com). Card:
//         artifacts/cards_approved/QM5_11384_blade-h4-ema30-breakout-retrace.md
//         (g0_status APPROVED).
//
// Mechanics (H4, all reads on CLOSED bars at shift >= 1):
//   Trend STATE  : EMA(30) rising over slope_lookback AND close above EMA(30)
//                  => LONG bias.  Falling EMA(30) AND close below => SHORT bias.
//   S/R level    : LONG  -> resistance = highest High over sr_lookback bars
//                           ending at shift 2 (the band that price must break).
//                  SHORT -> support    = lowest  Low  over the same window.
//   Breakout EVENT (latched): a closed bar closes BEYOND the S/R level in the
//                  trend direction. We latch the broken level + direction and
//                  start a retrace-wait window. This is a STATE we remember,
//                  not the firing trigger.
//   Retrace ENTRY EVENT (single trigger): on a LATER closed bar price pulls
//                  back to within retrace_tol_pips of the broken level (now the
//                  opposite-side S/R) while close is still on the breakout side.
//                  Enter at market. Because the breakout and the retrace touch
//                  occur on different bars, there is no two-events-same-bar
//                  zero-trade trap.
//   Stop         : behind the broken level by sl_pips (P2 cap 40 pips).
//   Take profit  : RR multiple of the risk distance (tp_rr).
//   Cancel latch : close pushes cancel_pips beyond the level against the trade,
//                  or the retrace does not arrive within max_wait_bars.
//   Spread guard : block only a genuinely wide spread (fail-open on .DWX zero
//                  modeled spread).
//
// State (broken level, direction, wait counter) is advanced ONCE per closed bar
// in AdvanceState_OnNewBar(); the per-tick path is O(1). Only the 5 Strategy_*
// hooks + Strategy inputs are EA-specific; framework wiring stays intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11384;
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
input int    strategy_ema_period        = 30;     // trend EMA period (Blade EMA30)
input int    strategy_slope_lookback    = 20;     // bars back to measure EMA slope
input int    strategy_sr_lookback       = 20;     // bars to define the S/R swing level
input int    strategy_retrace_tol_pips  = 10;     // retrace touch tolerance to broken level
input int    strategy_sl_pips           = 25;     // stop behind broken level (card 20-25)
input int    strategy_sl_cap_pips       = 40;     // P2 hard cap on stop distance
input double strategy_tp_rr             = 2.0;    // take-profit as RR multiple (card 2-3x)
input int    strategy_max_wait_bars     = 12;     // bars to wait for retrace after breakout
input int    strategy_cancel_pips       = 30;     // adverse move past level cancels the latch
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// File-scope cached breakout state (advanced once per closed bar).
//   g_break_dir : +1 long breakout latched, -1 short, 0 none.
// -----------------------------------------------------------------------------
int      g_break_dir        = 0;
double   g_broken_level      = 0.0;
int      g_bars_since_break  = 0;
bool     g_entry_armed       = false;   // set true on the bar a retrace touch fires

// Helper: pip size for the active symbol (5-digit / JPY aware via StopRules).
double PipDistance(const int pips)
  {
   return QM_StopRulesPipsToPriceDistance(_Symbol, pips);
  }

// Advance the latched breakout state by ONE closed bar. Called once per new bar.
void AdvanceState_OnNewBar()
  {
   g_entry_armed = false;

   // --- Trend STATE on closed bars (shift 1) ---
   const double ema_now  = QM_EMA(_Symbol, _Period, strategy_ema_period, 1);
   const double ema_past = QM_EMA(_Symbol, _Period, strategy_ema_period,
                                  1 + strategy_slope_lookback);
   const double close1   = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(ema_now <= 0.0 || ema_past <= 0.0 || close1 <= 0.0)
      return;

   const bool up_state   = (ema_now > ema_past) && (close1 > ema_now);
   const bool down_state = (ema_now < ema_past) && (close1 < ema_now);

   // --- If a breakout is latched, age it / cancel / arm the retrace entry ---
   if(g_break_dir != 0)
     {
      g_bars_since_break++;

      // Cancel if the trade-direction state is no longer valid.
      if((g_break_dir > 0 && !up_state) || (g_break_dir < 0 && !down_state))
        {
         g_break_dir = 0;
         g_broken_level = 0.0;
         g_bars_since_break = 0;
         return;
        }

      // Cancel if price has moved cancel_pips against the breakout (closed back
      // through the level), or the wait window expired.
      const double cancel_dist = PipDistance(strategy_cancel_pips);
      if(g_break_dir > 0)
        {
         if(close1 < g_broken_level - cancel_dist ||
            g_bars_since_break > strategy_max_wait_bars)
           { g_break_dir = 0; g_broken_level = 0.0; g_bars_since_break = 0; return; }

         // Retrace touch: this closed bar's Low dipped to within tol of the
         // broken level (now support) while the close held above it.
         const double low1 = iLow(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
         const double tol  = PipDistance(strategy_retrace_tol_pips);
         if(low1 <= g_broken_level + tol && close1 >= g_broken_level)
            g_entry_armed = true;
        }
      else // g_break_dir < 0
        {
         if(close1 > g_broken_level + cancel_dist ||
            g_bars_since_break > strategy_max_wait_bars)
           { g_break_dir = 0; g_broken_level = 0.0; g_bars_since_break = 0; return; }

         const double high1 = iHigh(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
         const double tol   = PipDistance(strategy_retrace_tol_pips);
         if(high1 >= g_broken_level - tol && close1 <= g_broken_level)
            g_entry_armed = true;
        }
      return; // already latched — do not re-detect a fresh breakout this bar
     }

   // --- No latch yet: look for a fresh breakout EVENT on the last closed bar ---
   // S/R band = extreme over sr_lookback bars ending at shift 2, so the shift-1
   // breakout bar can exceed it (excludes the breakout bar itself).
   double level = 0.0;
   if(up_state)
     {
      double hi = 0.0;
      for(int s = 2; s <= 1 + strategy_sr_lookback; ++s) // perf-allowed: per-closed-bar swing scan
        {
         const double h = iHigh(_Symbol, _Period, s);
         if(h > hi) hi = h;
        }
      level = hi;
      if(level > 0.0 && close1 > level) // closed above resistance => breakout up
        {
         g_break_dir = 1;
         g_broken_level = level;
         g_bars_since_break = 0;
        }
     }
   else if(down_state)
     {
      double lo = 0.0;
      for(int s = 2; s <= 1 + strategy_sr_lookback; ++s) // perf-allowed: per-closed-bar swing scan
        {
         const double l = iLow(_Symbol, _Period, s);
         if(lo == 0.0 || l < lo) lo = l;
        }
      level = lo;
      if(level > 0.0 && close1 < level) // closed below support => breakout down
        {
         g_break_dir = -1;
         g_broken_level = level;
         g_bars_since_break = 0;
        }
     }
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only; fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double stop_distance = PipDistance(strategy_sl_pips);
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Entry fires when a retrace touch was armed on this closed bar. Caller
// guarantees QM_IsNewBar() == true and AdvanceState_OnNewBar() already ran.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;
   if(!g_entry_armed || g_break_dir == 0 || g_broken_level <= 0.0)
      return false;

   const double sl_dist  = PipDistance(strategy_sl_pips);
   const double cap_dist = PipDistance(strategy_sl_cap_pips);
   if(sl_dist <= 0.0)
      return false;
   // Honour the P2 stop cap.
   const double use_dist = (cap_dist > 0.0 && sl_dist > cap_dist) ? cap_dist : sl_dist;

   if(g_break_dir > 0)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopRulesNormalizePrice(_Symbol, g_broken_level - use_dist);
      if(sl <= 0.0 || sl >= entry)
         return false;
      const double tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, strategy_tp_rr);
      if(tp <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "blade_breakout_retrace_long";
      g_entry_armed = false;
      return true;
     }
   else // short
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopRulesNormalizePrice(_Symbol, g_broken_level + use_dist);
      if(sl <= 0.0 || sl <= entry)
         return false;
      const double tp = QM_TakeRR(_Symbol, QM_SELL, entry, sl, strategy_tp_rr);
      if(tp <= 0.0)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "blade_breakout_retrace_short";
      g_entry_armed = false;
      return true;
     }
  }

// Fixed SL/TP only; no active trade management. Breakeven/trailing are out of
// scope for the mechanical baseline (card lists them as discretionary options).
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit beyond SL/TP. Once filled, the latch is cleared on the
// next AdvanceState pass via the open-position guard in Strategy_EntrySignal.
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

   // Advance the latched breakout/retrace state once per closed bar.
   AdvanceState_OnNewBar();

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
