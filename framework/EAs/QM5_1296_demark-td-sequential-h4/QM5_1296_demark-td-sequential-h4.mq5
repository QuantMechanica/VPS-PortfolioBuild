#property strict
#property version   "5.0"
#property description "QM5_1296 demark-td-sequential-h4 — DeMark TD Sequential 9-13 exhaustion (H4)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_1296 demark-td-sequential-h4
// -----------------------------------------------------------------------------
// Source: DeMark — The New Science of Technical Analysis (Wiley 1994) +
//         DeMark Indicators (Bloomberg/Wiley 2008); FF "TD Sequential" cluster.
// Card: artifacts/cards_approved/QM5_1296_demark-td-sequential-h4.md
//       (g0_status APPROVED).
//
// Mechanics — literal TD Sequential, evaluated on closed bars (shift 1 = the
// just-closed bar). The 9-count completion is a single EVENT; the countdown
// progression and TDST level are STATE; the confirmation bar is a separate
// bar. They are sequential by construction, so the two-cross same-bar
// zero-trade trap cannot occur.
//
//   TD Setup (count of 9):
//     BUY-Setup  bar : close[i] < close[i+4]   (bearish exhaustion, buy)
//     SELL-Setup bar : close[i] > close[i+4]   (bullish exhaustion, sell)
//     9 consecutive qualifying bars complete the setup. On completion we latch
//     the TDST level (lowest-low / highest-high across the 9 setup bars) and
//     arm a countdown for that direction.
//
//   TD Countdown (count of 13, after a completed setup, NOT consecutive):
//     BUY-Countdown  bar : close <= low[2]     (close at/below low 2 bars ago)
//     SELL-Countdown bar : close >= high[2]    (close at/above high 2 bars ago)
//     The 13th qualifying bar = exhaustion latch.
//
//   Confirmation bar (the bar AFTER countdown-13 latches):
//     BUY  : close > open  (bullish reversal candle)
//     SELL : close < open  (bearish reversal candle)
//     Enter at the open of the next bar -> we fire the market entry on the
//     closed-bar tick immediately after the confirmation bar closes.
//
//   Trend filter (avoid falling-knife / parabola):
//     BUY  : close > SMA(50,H4) - filter_atr_mult * ATR(14)
//     SELL : close < SMA(50,H4) + filter_atr_mult * ATR(14)
//
//   Stop : BUY  = TDST_support  - sl_atr_buffer_mult * ATR(14)
//          SELL = TDST_resist    + sl_atr_buffer_mult * ATR(14)
//   Take : tp_atr_mult * ATR(14) from entry (single TP; framework is
//          single-position-per-magic, so the card's 50/50 TP1/TP2 split is
//          collapsed to one ATR target at the mid of 1.5x/3.0x by default).
//   Time stop : close at market after time_stop_bars closed bars.
//   Invalidation : an opposite-direction Setup-9 completes while in a trade
//                  -> close at market.
//
// Only the 5 Strategy_* hooks + cached-state advance + Strategy inputs are
// EA-specific. Everything below the wiring line MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1296;
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
input int    strategy_setup_length      = 9;     // TD Setup count to complete
input int    strategy_setup_lookback    = 4;     // close[i] vs close[i+lookback]
input int    strategy_countdown_length  = 13;    // TD Countdown count to complete
input int    strategy_countdown_ref     = 2;     // close vs low/high [ref] bars ago
input int    strategy_max_countdown_bars = 200;  // abort an un-completed countdown after N bars
input int    strategy_sma_period        = 50;    // trend-filter SMA period
input int    strategy_atr_period        = 14;    // ATR period (filter / stop / target)
input double strategy_filter_atr_mult   = 1.5;   // trend-filter ATR band
input double strategy_sl_atr_buffer_mult = 0.3;  // TDST stop buffer in ATR
input double strategy_tp_atr_mult       = 2.25;  // TP distance in ATR (mid of 1.5x/3.0x)
input int    strategy_time_stop_bars    = 24;    // close at market after N closed bars
input double strategy_spread_pct_of_stop = 15.0; // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// File-scope cached state — advanced once per closed bar by AdvanceState().
// -----------------------------------------------------------------------------
// Setup running counts (consecutive qualifying closed bars).
int      g_buy_setup_count    = 0;
int      g_sell_setup_count   = 0;

// A completed setup arms a countdown for that direction.
bool     g_buy_cd_armed       = false;   // BUY countdown in progress
bool     g_sell_cd_armed      = false;   // SELL countdown in progress
int      g_buy_cd_count       = 0;
int      g_sell_cd_count      = 0;
int      g_buy_cd_age         = 0;       // bars since BUY countdown armed
int      g_sell_cd_age        = 0;       // bars since SELL countdown armed
double   g_buy_tdst_support   = 0.0;     // lowest low across the 9 BUY-setup bars
double   g_sell_tdst_resist   = 0.0;     // highest high across the 9 SELL-setup bars

// A completed countdown-13 latches; the NEXT bar is the confirmation bar.
bool     g_buy_cd_complete    = false;
bool     g_sell_cd_complete   = false;

// One-shot entry triggers, set when a confirmation bar validates a completed
// countdown. Consumed by Strategy_EntrySignal on the same closed-bar tick.
bool     g_fire_buy           = false;
bool     g_fire_sell          = false;
double   g_fire_tdst          = 0.0;     // TDST level to anchor the stop

// Opposite-setup-9 invalidation flags (a fresh completion this bar).
bool     g_buy_setup_done     = false;
bool     g_sell_setup_done    = false;

// Time-stop tracking for the open position.
datetime g_entry_bar_time     = 0;
int      g_bars_in_trade      = 0;

// New-bar gate latch so OnTick consumes QM_IsNewBar() exactly once.
datetime g_last_advanced_bar  = 0;

// Helper: lowest low / highest high across the last `len` closed bars starting
// at shift `start`. Bounded single pass (len is the setup length, ~9). Uses
// raw iLow/iHigh for bespoke structural (TDST) levels — perf-allowed: bounded.
double SetupLowestLow(const int start, const int len)
  {
   double lo = iLow(_Symbol, _Period, start); // perf-allowed: bounded structural scan
   for(int s = start + 1; s < start + len; ++s)
     {
      const double v = iLow(_Symbol, _Period, s); // perf-allowed: bounded structural scan
      if(v > 0.0 && v < lo)
         lo = v;
     }
   return lo;
  }

double SetupHighestHigh(const int start, const int len)
  {
   double hi = iHigh(_Symbol, _Period, start); // perf-allowed: bounded structural scan
   for(int s = start + 1; s < start + len; ++s)
     {
      const double v = iHigh(_Symbol, _Period, s); // perf-allowed: bounded structural scan
      if(v > hi)
         hi = v;
     }
   return hi;
  }

// -----------------------------------------------------------------------------
// AdvanceState — called ONCE per new closed bar (after OnTick's QM_IsNewBar()).
// Reads the just-closed bar at shift 1 and steps the TD state machine by one
// bar. No second timestamp gate inside. O(setup_length) bounded work per bar.
// -----------------------------------------------------------------------------
void AdvanceState()
  {
   // Reset per-bar one-shot flags.
   g_fire_buy       = false;
   g_fire_sell      = false;
   g_buy_setup_done = false;
   g_sell_setup_done = false;

   // --- 1) Confirmation-bar check for an already-completed countdown ---------
   // The just-closed bar (shift 1) is the confirmation bar candidate for any
   // countdown that latched on the PREVIOUS closed bar.
   const double open1  = iOpen(_Symbol, _Period, 1);   // perf-allowed: single closed-bar read
   const double close1 = iClose(_Symbol, _Period, 1);  // perf-allowed: single closed-bar read

   if(g_buy_cd_complete && close1 > 0.0 && open1 > 0.0)
     {
      if(close1 > open1)            // bullish reversal candle confirms
        {
         g_fire_buy  = true;
         g_fire_tdst = g_buy_tdst_support;
        }
      // Confirmation window is the single bar after countdown-13: consume it
      // whether or not it confirmed (re-arm only on a new setup).
      g_buy_cd_complete = false;
      g_buy_cd_armed    = false;
      g_buy_cd_count    = 0;
     }
   if(g_sell_cd_complete && close1 > 0.0 && open1 > 0.0)
     {
      if(close1 < open1)            // bearish reversal candle confirms
        {
         g_fire_sell = true;
         g_fire_tdst = g_sell_tdst_resist;
        }
      g_sell_cd_complete = false;
      g_sell_cd_armed    = false;
      g_sell_cd_count    = 0;
     }

   // --- 2) TD Setup running counts on the just-closed bar --------------------
   const double close_ref = iClose(_Symbol, _Period, 1 + strategy_setup_lookback); // perf-allowed
   if(close1 > 0.0 && close_ref > 0.0)
     {
      // BUY-setup bar: close below close 4 bars earlier.
      if(close1 < close_ref)
        {
         g_buy_setup_count += 1;
         g_sell_setup_count = 0;
        }
      else if(close1 > close_ref)
        {
         g_sell_setup_count += 1;
         g_buy_setup_count = 0;
        }
      else
        {
         g_buy_setup_count  = 0;
         g_sell_setup_count = 0;
        }
     }

   // --- 3) Setup completion EVENT (single trigger) ---------------------------
   if(g_buy_setup_count >= strategy_setup_length)
     {
      g_buy_setup_done   = true;                       // for invalidation logic
      g_buy_tdst_support = SetupLowestLow(1, strategy_setup_length);
      g_buy_cd_armed     = true;                       // arm BUY countdown
      g_buy_cd_count     = 0;
      g_buy_cd_age       = 0;
      g_buy_cd_complete  = false;
      g_buy_setup_count  = 0;                          // reset for the next setup
     }
   if(g_sell_setup_count >= strategy_setup_length)
     {
      g_sell_setup_done  = true;
      g_sell_tdst_resist = SetupHighestHigh(1, strategy_setup_length);
      g_sell_cd_armed    = true;
      g_sell_cd_count    = 0;
      g_sell_cd_age      = 0;
      g_sell_cd_complete = false;
      g_sell_setup_count = 0;
     }

   // --- 4) TD Countdown progression on the just-closed bar -------------------
   // close vs low/high `ref` bars ago. ref-shift from the closed bar = 1 + ref.
   const double low_ref  = iLow(_Symbol, _Period, 1 + strategy_countdown_ref);  // perf-allowed
   const double high_ref = iHigh(_Symbol, _Period, 1 + strategy_countdown_ref); // perf-allowed

   if(g_buy_cd_armed && !g_buy_cd_complete)
     {
      g_buy_cd_age += 1;
      if(close1 > 0.0 && low_ref > 0.0 && close1 <= low_ref)
         g_buy_cd_count += 1;
      if(g_buy_cd_count >= strategy_countdown_length)
         g_buy_cd_complete = true;                     // confirm on next bar
      else if(g_buy_cd_age > strategy_max_countdown_bars)
         { g_buy_cd_armed = false; g_buy_cd_count = 0; } // stale: re-arm via new setup
     }
   if(g_sell_cd_armed && !g_sell_cd_complete)
     {
      g_sell_cd_age += 1;
      if(close1 > 0.0 && high_ref > 0.0 && close1 >= high_ref)
         g_sell_cd_count += 1;
      if(g_sell_cd_count >= strategy_countdown_length)
         g_sell_cd_complete = true;
      else if(g_sell_cd_age > strategy_max_countdown_bars)
         { g_sell_cd_armed = false; g_sell_cd_count = 0; }
     }

   // --- 5) Advance the time-stop counter for an open position ----------------
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      g_bars_in_trade += 1;
   else
      g_bars_in_trade = 0;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // defer to entry gate

   const double stop_distance = strategy_tp_atr_mult * atr_value; // scale reference
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate). Reads the
// one-shot fire flags set by AdvanceState() on this same closed bar.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(!g_fire_buy && !g_fire_sell)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double sma = QM_SMA(_Symbol, _Period, strategy_sma_period, 1);
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(sma <= 0.0 || close1 <= 0.0)
      return false;

   // --- BUY ---------------------------------------------------------------
   if(g_fire_buy)
     {
      // Trend filter: price not in a catastrophic downtrend.
      if(!(close1 > sma - strategy_filter_atr_mult * atr_value))
         return false;

      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;

      // Stop anchored on the TDST support minus an ATR buffer.
      double sl = g_fire_tdst - strategy_sl_atr_buffer_mult * atr_value;
      sl = QM_TM_NormalizePrice(_Symbol, sl);
      if(sl <= 0.0 || sl >= entry)               // stop must sit below entry
         sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, 1.0);
      if(sl <= 0.0 || sl >= entry)
         return false;

      const double tp = QM_TakeATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_tp_atr_mult);
      if(tp <= 0.0)
         return false;

      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "td_seq_buy_9_13";
      return true;
     }

   // --- SELL --------------------------------------------------------------
   if(g_fire_sell)
     {
      if(!(close1 < sma + strategy_filter_atr_mult * atr_value))
         return false;

      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;

      double sl = g_fire_tdst + strategy_sl_atr_buffer_mult * atr_value;
      sl = QM_TM_NormalizePrice(_Symbol, sl);
      if(sl <= 0.0 || sl <= entry)               // stop must sit above entry
         sl = QM_StopATRFromValue(_Symbol, QM_SELL, entry, atr_value, 1.0);
      if(sl <= 0.0 || sl <= entry)
         return false;

      const double tp = QM_TakeATRFromValue(_Symbol, QM_SELL, entry, atr_value, strategy_tp_atr_mult);
      if(tp <= 0.0)
         return false;

      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "td_seq_sell_9_13";
      return true;
     }

   return false;
  }

// No active SL/TP management beyond the fixed ATR target and TDST stop. Time
// stop + opposite-setup invalidation live in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Discretionary exit: 24-bar time stop, or opposite-direction Setup-9
// invalidation. Reads cached state advanced once per closed bar.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Determine the open position's direction for invalidation logic.
   bool is_long = false;
   bool have_pos = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      is_long  = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      have_pos = true;
      break;
     }
   if(!have_pos)
      return false;

   // Time stop: close after strategy_time_stop_bars closed bars in trade.
   if(g_bars_in_trade >= strategy_time_stop_bars)
      return true;

   // Pattern invalidation: an opposite-direction Setup-9 completed this bar.
   if(is_long && g_sell_setup_done)
      return true;
   if(!is_long && g_buy_setup_done)
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

   // Advance the closed-bar TD state machine exactly once per new closed bar.
   const bool new_bar = QM_IsNewBar();
   if(new_bar)
      AdvanceState();

   // Per-tick: discretionary exit (time stop / opposite-setup invalidation).
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

   if(!new_bar)
      return;

   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
     {
      ulong out_ticket = 0;
      if(QM_TM_OpenPosition(req, out_ticket))
        {
         g_entry_bar_time = iTime(_Symbol, _Period, 0); // perf-allowed: entry bookkeeping
         g_bars_in_trade  = 0;
        }
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
