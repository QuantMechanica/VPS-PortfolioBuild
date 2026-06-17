#property strict
#property version   "5.0"
#property description "QM5_10977 ftmo-bb-sqz — Bollinger squeeze breakout (H1, long+short)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_10977 ftmo-bb-sqz
// -----------------------------------------------------------------------------
// Source: FTMO blog "Technical analysis - Bollinger Bands as a combination of
//         trend and volatility" (2022-10-21).
// Card: artifacts/cards_approved/QM5_10977_ftmo-bb-sqz.md (g0_status APPROVED).
//
// Mechanics (long + short, closed-bar reads at shift 1, H1):
//   Bands       : BB(20, 2.0 dev) on PRICE_CLOSE; width = upper - lower.
//   Squeeze     : current band width in the lowest sqz_pct percentile of the
//                 previous sqz_lookback closed bars. We approximate the
//                 percentile by counting how many of the lookback widths are
//                 strictly narrower than the current width and requiring that
//                 fraction to be <= sqz_pct/100.
//   Squeeze armed: squeeze was true on any of the previous sqz_recent closed
//                 bars (the trigger bar itself need not be a squeeze bar).
//   Long  EVENT : close[1] > BB_Upper[1] AND close[1] > SMA(20)[1].
//   Short EVENT : close[1] < BB_Lower[1] AND close[1] < SMA(20)[1].
//   Range filter: skip if breakout bar range (high-low) > range_atr_mult * ATR.
//   Stop  long  : BB_Lower[1] - stop_atr_buffer_mult * ATR.
//   Stop  short : BB_Upper[1] + stop_atr_buffer_mult * ATR.
//   Take profit : tp_rr * R from entry (R = |entry - stop|).
//   Management  : move SL to breakeven once price has travelled be_trigger_rr*R.
//   Exit  long  : close[1] back below SMA(20) after entry.
//   Exit  short : close[1] back above SMA(20) after entry.
//   Time  exit  : force-close after time_exit_bars closed H1 bars.
//   Spread guard: fail-open on .DWX zero modeled spread; only a genuinely wide
//                 spread (> spread_pct_of_stop of stop distance) blocks.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10977;
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
input int    strategy_bb_period          = 20;     // Bollinger period (SMA + bands)
input double strategy_bb_deviation       = 2.0;    // Bollinger deviation (std devs)
input int    strategy_sqz_lookback       = 120;    // squeeze percentile window (bars)
input double strategy_sqz_pct            = 20.0;   // squeeze percentile threshold (%)
input int    strategy_sqz_recent         = 6;      // squeeze armed if true within N recent bars
input int    strategy_atr_period         = 14;     // ATR period (range filter + stop buffer)
input double strategy_range_atr_mult     = 2.5;    // skip if breakout range > mult * ATR
input double strategy_stop_atr_buffer_mult = 0.25; // stop buffer beyond opposite band, in ATR
input double strategy_tp_rr              = 2.5;    // take-profit R-multiple
input double strategy_be_trigger_rr      = 1.2;    // move SL to breakeven after this many R
input int    strategy_time_exit_bars     = 36;     // force-close after N closed H1 bars
input double strategy_spread_pct_of_stop = 15.0;   // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// File-scope per-position tracking. One position per magic, so a single set of
// scalars suffices. Advanced only on the closed-bar path and at entry.
// -----------------------------------------------------------------------------
ulong    g_pos_ticket    = 0;       // tracked ticket (0 = none)
datetime g_pos_open_bar  = 0;       // bar-open time of the entry bar
double   g_pos_entry     = 0.0;     // recorded entry price
double   g_pos_risk      = 0.0;     // R distance = |entry - stop| at entry
bool     g_pos_is_long   = false;   // side of the tracked position
bool     g_pos_be_done   = false;   // breakeven already applied

// Find the open position for this EA's magic. Returns its ticket or 0.
ulong QM_FindOwnPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      return ticket;
     }
   return 0;
  }

// Current Bollinger band width on the last closed bar (shift `shift`).
double QM_BandWidthAt(const int shift)
  {
   const double up = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, shift);
   const double lo = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, shift);
   if(up <= 0.0 || lo <= 0.0)
      return -1.0;
   return up - lo;
  }

// TRUE if the band width at `shift` is in the lowest sqz_pct percentile of the
// preceding sqz_lookback closed bars (relative to that bar).
bool QM_IsSqueezeAt(const int shift)
  {
   const double w = QM_BandWidthAt(shift);
   if(w <= 0.0)
      return false;

   int narrower = 0;
   int valid    = 0;
   const int first = shift + 1;
   const int last  = shift + strategy_sqz_lookback;
   for(int s = first; s <= last; ++s)
     {
      const double ws = QM_BandWidthAt(s);
      if(ws <= 0.0)
         continue;
      ++valid;
      if(ws < w)
         ++narrower;
     }
   if(valid <= 0)
      return false;

   // Fraction of the window strictly narrower than the current width must be
   // small (<= sqz_pct/100) for the current width to sit in the low tail.
   const double frac = (double)narrower / (double)valid;
   return (frac <= strategy_sqz_pct / 100.0);
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
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer, do not block here

   // Reference stop distance for the cap: opposite-band buffer is small, so use
   // the ATR buffer scaled by a representative factor (the buffer mult).
   const double stop_distance = (strategy_stop_atr_buffer_mult + 1.0) * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Long+short squeeze-breakout entry. Caller guarantees QM_IsNewBar()==true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Bands + SMA on the just-closed bar (shift 1) ---
   const double bb_up  = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   const double bb_lo  = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   const double sma    = QM_SMA(_Symbol, _Period, strategy_bb_period, 1);
   if(bb_up <= 0.0 || bb_lo <= 0.0 || sma <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double high1  = iHigh(_Symbol, _Period, 1);  // perf-allowed: single closed-bar read
   const double low1   = iLow(_Symbol, _Period, 1);   // perf-allowed: single closed-bar read
   if(close1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0)
      return false;

   // --- Squeeze armed: true within the last sqz_recent bars (shift 1..N) ---
   bool squeeze_armed = false;
   for(int s = 1; s <= strategy_sqz_recent; ++s)
     {
      if(QM_IsSqueezeAt(s))
        {
         squeeze_armed = true;
         break;
        }
     }
   if(!squeeze_armed)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   // --- Range filter: skip an over-extended breakout bar ---
   if((high1 - low1) > strategy_range_atr_mult * atr_value)
      return false;

   // --- Breakout direction (one event each, mutually exclusive) ---
   const bool long_breakout  = (close1 > bb_up && close1 > sma);
   const bool short_breakout = (close1 < bb_lo && close1 < sma);
   if(!long_breakout && !short_breakout)
      return false;

   const double entry = (long_breakout ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                        : SymbolInfoDouble(_Symbol, SYMBOL_BID));
   if(entry <= 0.0)
      return false;

   double sl = 0.0;
   double tp = 0.0;
   QM_OrderType side = QM_BUY;

   if(long_breakout)
     {
      side = QM_BUY;
      sl   = QM_StopRulesNormalizePrice(_Symbol, bb_lo - strategy_stop_atr_buffer_mult * atr_value);
      if(sl <= 0.0 || sl >= entry)
         return false;
      tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, strategy_tp_rr);
     }
   else
     {
      side = QM_SELL;
      sl   = QM_StopRulesNormalizePrice(_Symbol, bb_up + strategy_stop_atr_buffer_mult * atr_value);
      if(sl <= 0.0 || sl <= entry)
         return false;
      tp = QM_TakeRR(_Symbol, QM_SELL, entry, sl, strategy_tp_rr);
     }
   if(tp <= 0.0)
      return false;

   // Record tracking state for management/exit. Bar-open time of the trigger bar.
   g_pos_open_bar = iTime(_Symbol, _Period, 0); // current (forming) bar open = entry bar
   g_pos_entry    = entry;
   g_pos_risk     = MathAbs(entry - sl);
   g_pos_is_long  = long_breakout;
   g_pos_be_done  = false;
   g_pos_ticket   = 0; // resolved on next manage tick

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = (long_breakout ? "bb_sqz_long" : "bb_sqz_short");
   return true;
  }

// Per-tick management: move SL to breakeven once price has travelled
// be_trigger_rr * R in favour. Cheap O(1): reads current tick + cached state.
void Strategy_ManageOpenPosition()
  {
   const ulong ticket = QM_FindOwnPosition();
   if(ticket == 0)
     {
      // No position; reset tracking so stale state can't leak into the next trade.
      g_pos_ticket = 0;
      return;
     }

   // (Re)bind tracking to the live ticket.
   if(g_pos_ticket != ticket)
      g_pos_ticket = ticket;

   if(g_pos_be_done || g_pos_risk <= 0.0 || g_pos_entry <= 0.0)
      return;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return;

   const double trigger = strategy_be_trigger_rr * g_pos_risk;
   bool reached = false;
   if(g_pos_is_long)
      reached = (bid - g_pos_entry) >= trigger;
   else
      reached = (g_pos_entry - ask) >= trigger;

   if(!reached)
      return;

   const double be_price = QM_StopRulesNormalizePrice(_Symbol, g_pos_entry);
   if(QM_TM_MoveSL(ticket, be_price, "bb_sqz_breakeven"))
      g_pos_be_done = true;
  }

// Discretionary exit: SMA cross-back against the position, or time stop.
// Evaluated on the closed-bar path (OnTick gates exit before the new-bar gate,
// but our checks read shift-1 closed-bar values and cached bar-open time, so
// they are stable within a bar).
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   const double sma   = QM_SMA(_Symbol, _Period, strategy_bb_period, 1);
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(sma <= 0.0 || close1 <= 0.0)
      return false;

   // SMA cross-back exit.
   if(g_pos_is_long && close1 < sma)
      return true;
   if(!g_pos_is_long && close1 > sma)
      return true;

   // Time exit: force-close after strategy_time_exit_bars closed H1 bars.
   if(g_pos_open_bar > 0)
     {
      const datetime cur_bar = iTime(_Symbol, _Period, 0); // perf-allowed: current bar open
      if(cur_bar > g_pos_open_bar)
        {
         const long secs_per_bar = (long)PeriodSeconds(_Period);
         if(secs_per_bar > 0)
           {
            const long elapsed_bars = (long)((cur_bar - g_pos_open_bar) / secs_per_bar);
            if(elapsed_bars >= (long)strategy_time_exit_bars)
               return true;
           }
        }
     }

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
