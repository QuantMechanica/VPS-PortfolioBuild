#property strict
#property version   "5.0"
#property description "QM5_10974 ftmo-obv-brk — OBV-confirmed range breakout (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_10974 ftmo-obv-brk
// -----------------------------------------------------------------------------
// Source: FTMO "Technical analysis - On Balance Volume relies on volumes" (2023).
// Card: artifacts/cards_approved/QM5_10974_ftmo-obv-brk.md (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1; OBV from tick volume):
//   OBV : cumulative signed tick volume, advanced ONE step per closed bar and
//         cached in file scope (no per-tick re-summation).
//   Price range : rolling N-bar (default 40) high/low over closed bars 1..N.
//   OBV   range : rolling N-bar high/low of the cached OBV series.
//   Long entry  : close[1] breaks above the N-bar price-range high (excluding
//                 the current breakout bar) by >= brk_atr_mult * ATR, AND OBV
//                 broke above its N-bar OBV-range high on bar 1 or bar 2, AND
//                 close[1] > EMA(trend_period).
//   Short entry : mirror image below the range low.
//   Quality filters (skip): range height < range_min_atr * ATR or
//                 > range_max_atr * ATR; breakout candle range > candle_max_atr * ATR.
//   Stop  : long  = farther of {range midpoint, breakout-candle low - sl_atr_buf*ATR}.
//           short = farther of {range midpoint, breakout-candle high + sl_atr_buf*ATR}.
//   Target: 2.0R (QM_TakeRR).
//   Manage: after price travels >= trail_trigger_r * R in favour, trail the stop
//           to EMA(trail_period) (only ever tightened).
//   Exit  : OBV closes back INSIDE its pre-breakout range for 2 consecutive
//           closed bars, OR time exit after max_hold_bars closed bars.
//   Spread guard : fail-open on .DWX zero modeled spread; block only a genuinely
//                  wide spread > spread_pct_of_stop of the ATR stop distance.
//
// Only the 5 Strategy_* hooks + Strategy inputs + the cached-OBV advance are
// EA-specific. Everything else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10974;
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
input int    strategy_range_lookback     = 40;    // price & OBV range lookback (closed bars)
input int    strategy_trend_period       = 100;   // EMA trend filter period
input int    strategy_trail_period       = 20;    // EMA used to trail the stop
input int    strategy_atr_period         = 14;    // ATR period (filter / breakout / stop)
input double strategy_brk_atr_mult       = 0.20;  // min breakout beyond range edge, in ATR
input double strategy_sl_atr_buf         = 0.25;  // ATR buffer beyond breakout candle extreme
input double strategy_tp_rr              = 2.0;   // take-profit as R multiple
input double strategy_trail_trigger_r    = 1.5;   // start EMA trail after this many R in favour
input double strategy_range_min_atr      = 1.2;   // skip if range height < this * ATR
input double strategy_range_max_atr      = 5.0;   // skip if range height > this * ATR
input double strategy_candle_max_atr     = 2.2;   // skip if breakout candle range > this * ATR
input int    strategy_obv_confirm_window = 2;     // OBV break allowed on bar 1..this
input int    strategy_max_hold_bars      = 30;    // time exit after this many closed bars
input int    strategy_obv_exit_bars      = 2;     // OBV-back-inside bars to force exit
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Cached OBV state (advanced ONE step per closed bar). The OBV series is a
// rolling ring buffer of the last (lookback + obv_confirm_window + a margin)
// closed-bar OBV values, newest at index 0.
// -----------------------------------------------------------------------------
#define QM_OBV_HIST 64

double   g_obv_run        = 0.0;          // running cumulative OBV (latest closed bar)
double   g_obv_hist[QM_OBV_HIST];         // index 0 = OBV at shift 1, 1 = shift 2, ...
int      g_obv_filled     = 0;            // how many history slots are populated
datetime g_obv_last_bar   = 0;            // bar-open time of the last advanced bar
double   g_obv_prev_close = 0.0;          // close used for the last OBV sign step

// Per-position latched state (single position per magic; one symbol per test).
bool     g_pos_active       = false;
bool     g_pos_is_long      = false;
double   g_pos_entry        = 0.0;
double   g_pos_risk_dist    = 0.0;        // |entry - sl| at entry (the R unit)
double   g_pos_obv_lo       = 0.0;        // pre-breakout OBV range low
double   g_pos_obv_hi       = 0.0;        // pre-breakout OBV range high
datetime g_pos_entry_bar    = 0;          // bar-open time of the entry bar
int      g_pos_obv_inside   = 0;          // consecutive bars OBV back inside range
bool     g_pos_trail_armed  = false;      // 1.5R reached -> EMA trail active

// -----------------------------------------------------------------------------
// OBV advance — called ONCE per new closed bar (after the framework new-bar gate).
// Advances the cumulative OBV by exactly one bar and pushes it into the ring.
// -----------------------------------------------------------------------------
void AdvanceOBV_OnNewBar()
  {
   // The just-closed bar is shift 1. Its OBV contribution compares close[1] to
   // close[2]; tick volume of bar 1 is added/subtracted by that sign.
   const double close1 = iClose(_Symbol, _Period, 1);   // perf-allowed: single closed-bar read
   const double close2 = iClose(_Symbol, _Period, 2);   // perf-allowed: single closed-bar read
   const double vol1   = (double)iVolume(_Symbol, _Period, 1); // perf-allowed: single closed-bar tick volume
   if(close1 <= 0.0)
      return;

   if(g_obv_filled == 0)
     {
      // Seed: first closed bar contributes its volume in the up direction by
      // convention; subsequent bars use the close-to-close sign.
      g_obv_run = vol1;
     }
   else
     {
      if(close2 > 0.0)
        {
         if(close1 > close2)       g_obv_run += vol1;
         else if(close1 < close2)  g_obv_run -= vol1;
         // equal close: OBV unchanged
        }
     }
   g_obv_prev_close = close1;

   // Push newest OBV to the front of the ring (shift positions down by one).
   for(int i = QM_OBV_HIST - 1; i >= 1; --i)
      g_obv_hist[i] = g_obv_hist[i - 1];
   g_obv_hist[0] = g_obv_run;
   if(g_obv_filled < QM_OBV_HIST)
      g_obv_filled++;
  }

// Rolling OBV range high over [from_idx .. from_idx+count-1] of g_obv_hist.
double OBV_RangeHigh(const int from_idx, const int count)
  {
   double hi = -DBL_MAX;
   const int last = from_idx + count - 1;
   if(last >= g_obv_filled)
      return 0.0; // not enough history yet
   for(int i = from_idx; i <= last; ++i)
      if(g_obv_hist[i] > hi)
         hi = g_obv_hist[i];
   return hi;
  }

double OBV_RangeLow(const int from_idx, const int count)
  {
   double lo = DBL_MAX;
   const int last = from_idx + count - 1;
   if(last >= g_obv_filled)
      return 0.0;
   for(int i = from_idx; i <= last; ++i)
      if(g_obv_hist[i] < lo)
         lo = g_obv_hist[i];
   return lo;
  }

// Rolling price high/low over closed bars [shift_from .. shift_from+count-1].
double PriceRangeHigh(const int shift_from, const int count)
  {
   double hi = -DBL_MAX;
   for(int s = shift_from; s < shift_from + count; ++s)
     {
      const double h = iHigh(_Symbol, _Period, s); // perf-allowed: rolling range, once per closed bar
      if(h > hi) hi = h;
     }
   return hi;
  }

double PriceRangeLow(const int shift_from, const int count)
  {
   double lo = DBL_MAX;
   for(int s = shift_from; s < shift_from + count; ++s)
     {
      const double l = iLow(_Symbol, _Period, s); // perf-allowed: rolling range, once per closed bar
      if(l < lo) lo = l;
     }
   return lo;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only. Fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double stop_distance = atr_value; // ATR as the stop-distance reference
   const double spread = ask - bid;
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// OBV-confirmed range-breakout entry. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const int lb = strategy_range_lookback;
   if(lb < 2)
      return false;

   // Need the price range (shifts 2..lb+1, i.e. the lb bars BEFORE the breakout
   // bar at shift 1) plus enough OBV history including the confirm window.
   if(g_obv_filled < lb + strategy_obv_confirm_window + 1)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double ema_trend = QM_EMA(_Symbol, _Period, strategy_trend_period, 1);
   if(ema_trend <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double high1  = iHigh(_Symbol, _Period, 1);  // perf-allowed: single closed-bar read
   const double low1   = iLow(_Symbol, _Period, 1);   // perf-allowed: single closed-bar read
   if(close1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0)
      return false;

   // Pre-breakout price range = lb bars BEFORE the breakout bar -> shifts 2..lb+1.
   const double range_high = PriceRangeHigh(2, lb);
   const double range_low  = PriceRangeLow(2, lb);
   if(range_high <= 0.0 || range_low <= 0.0 || range_high <= range_low)
      return false;

   const double range_height = range_high - range_low;
   const double range_mid    = 0.5 * (range_high + range_low);

   // Range-quality filter: skip too-tight or too-wide consolidations.
   if(range_height < strategy_range_min_atr * atr_value)
      return false;
   if(range_height > strategy_range_max_atr * atr_value)
      return false;

   // Breakout candle range filter.
   const double candle_range = high1 - low1;
   if(candle_range > strategy_candle_max_atr * atr_value)
      return false;

   // Pre-breakout OBV range = lb OBV values BEFORE the breakout bar. The
   // breakout bar's OBV is g_obv_hist[0]; the prior lb values are indices 1..lb.
   const double obv_range_high = OBV_RangeHigh(1, lb);
   const double obv_range_low  = OBV_RangeLow(1, lb);
   if(obv_range_high == 0.0 && obv_range_low == 0.0)
      return false;

   const double brk_buffer = strategy_brk_atr_mult * atr_value;

   // OBV broke its range on the breakout bar (idx 0) or up to obv_confirm_window
   // bars earlier (idx 0..window-1).
   bool obv_broke_up   = false;
   bool obv_broke_down = false;
   for(int k = 0; k < strategy_obv_confirm_window; ++k)
     {
      if(g_obv_hist[k] > obv_range_high) obv_broke_up   = true;
      if(g_obv_hist[k] < obv_range_low)  obv_broke_down = true;
     }

   // --- Long setup ---
   const bool long_price_break = (close1 > range_high + brk_buffer);
   const bool long_trend_ok    = (close1 > ema_trend);
   if(long_price_break && obv_broke_up && long_trend_ok)
     {
      // Stop: farther of {range midpoint, breakout candle low - buf*ATR} from entry.
      const double sl_struct = low1 - strategy_sl_atr_buf * atr_value;
      double sl = MathMin(range_mid, sl_struct); // lower (farther below entry) = farther stop
      if(sl >= close1)
         return false;

      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0 || sl >= entry)
         return false;

      const double tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, strategy_tp_rr);
      if(tp <= 0.0)
         return false;

      req.type   = QM_BUY;
      req.price  = 0.0;
      req.sl     = QM_StopRulesNormalizePrice(_Symbol, sl);
      req.tp     = tp;
      req.reason = "obv_brk_long";

      LatchEntry(true, entry, MathAbs(entry - sl), obv_range_low, obv_range_high);
      return true;
     }

   // --- Short setup ---
   const bool short_price_break = (close1 < range_low - brk_buffer);
   const bool short_trend_ok    = (close1 < ema_trend);
   if(short_price_break && obv_broke_down && short_trend_ok)
     {
      const double sl_struct = high1 + strategy_sl_atr_buf * atr_value;
      double sl = MathMax(range_mid, sl_struct); // higher (farther above entry) = farther stop
      if(sl <= close1)
         return false;

      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0 || sl <= entry)
         return false;

      const double tp = QM_TakeRR(_Symbol, QM_SELL, entry, sl, strategy_tp_rr);
      if(tp <= 0.0)
         return false;

      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = QM_StopRulesNormalizePrice(_Symbol, sl);
      req.tp     = tp;
      req.reason = "obv_brk_short";

      LatchEntry(false, entry, MathAbs(entry - sl), obv_range_low, obv_range_high);
      return true;
     }

   return false;
  }

// Latch per-position state at the moment we build the entry request.
void LatchEntry(const bool is_long, const double entry, const double risk_dist,
                const double obv_lo, const double obv_hi)
  {
   g_pos_active      = true;
   g_pos_is_long     = is_long;
   g_pos_entry       = entry;
   g_pos_risk_dist   = risk_dist;
   g_pos_obv_lo      = obv_lo;
   g_pos_obv_hi      = obv_hi;
   g_pos_entry_bar   = iTime(_Symbol, _Period, 0); // current (forming) bar = entry bar
   g_pos_obv_inside  = 0;
   g_pos_trail_armed = false;
  }

// Trade management: after trail_trigger_r in favour, trail the stop to EMA(trail).
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
     {
      g_pos_active = false;
      return;
     }
   if(!g_pos_active || g_pos_risk_dist <= 0.0)
      return;

   // Arm the trail once price has travelled trail_trigger_r * R in favour.
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return;

   const double trigger_dist = strategy_trail_trigger_r * g_pos_risk_dist;
   if(!g_pos_trail_armed)
     {
      if(g_pos_is_long && (bid - g_pos_entry) >= trigger_dist)
         g_pos_trail_armed = true;
      else if(!g_pos_is_long && (g_pos_entry - ask) >= trigger_dist)
         g_pos_trail_armed = true;
     }
   if(!g_pos_trail_armed)
      return;

   const double ema_trail = QM_EMA(_Symbol, _Period, strategy_trail_period, 1);
   if(ema_trail <= 0.0)
      return;

   // Find this EA's open position and tighten the stop toward EMA(trail).
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const double cur_sl  = PositionGetDouble(POSITION_SL);
      const double new_sl  = QM_StopRulesNormalizePrice(_Symbol, ema_trail);

      if(g_pos_is_long)
        {
         // Only ever raise the stop, and keep it below the current bid.
         if(new_sl > cur_sl && new_sl < bid)
            QM_TM_MoveSL(ticket, new_sl, "obv_brk_ema_trail");
        }
      else
        {
         // Only ever lower the stop, and keep it above the current ask.
         if((cur_sl <= 0.0 || new_sl < cur_sl) && new_sl > ask)
            QM_TM_MoveSL(ticket, new_sl, "obv_brk_ema_trail");
        }
      break;
     }
  }

// Discretionary exit: OBV back inside its pre-breakout range for N consecutive
// closed bars, OR time exit after max_hold_bars. Evaluated on the closed-bar
// path via OnTick's QM_IsNewBar gate calling Strategy_ExitSignal -> but the
// framework calls Strategy_ExitSignal every tick. We only update the OBV-inside
// counter once per new bar (latched on g_obv_last_bar) to keep it bar-accurate.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
     {
      g_pos_active = false;
      return false;
     }
   if(!g_pos_active)
      return false;

   // Time exit: count closed bars since the entry bar.
   const datetime cur_bar = iTime(_Symbol, _Period, 0);
   if(g_pos_entry_bar > 0 && cur_bar > g_pos_entry_bar)
     {
      const int bars_held = iBarShift(_Symbol, _Period, g_pos_entry_bar, false);
      if(bars_held >= strategy_max_hold_bars)
         return true;
     }

   // OBV-back-inside exit: update the consecutive counter once per closed bar.
   // g_obv_hist[0] is the most-recently-closed bar's OBV.
   if(g_obv_filled > 0)
     {
      const double obv_last = g_obv_hist[0];
      const bool inside = (obv_last <= g_pos_obv_hi && obv_last >= g_pos_obv_lo);
      // Recompute the counter from scratch over the last N closed bars so the
      // per-tick call is idempotent (no double-counting across ticks).
      int consec = 0;
      for(int k = 0; k < strategy_obv_exit_bars && k < g_obv_filled; ++k)
        {
         if(g_obv_hist[k] <= g_pos_obv_hi && g_obv_hist[k] >= g_pos_obv_lo)
            consec++;
         else
            break;
        }
      g_pos_obv_inside = consec;
      if(inside && consec >= strategy_obv_exit_bars)
         return true;
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

   ArrayInitialize(g_obv_hist, 0.0);
   g_obv_run        = 0.0;
   g_obv_filled     = 0;
   g_obv_last_bar   = 0;
   g_obv_prev_close = 0.0;
   g_pos_active     = false;

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
      g_pos_active = false;
     }

   // Per-closed-bar work below.
   if(!QM_IsNewBar())
      return;

   // FIRST: advance cached OBV state by exactly one closed bar.
   AdvanceOBV_OnNewBar();
   g_obv_last_bar = iTime(_Symbol, _Period, 0);

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
