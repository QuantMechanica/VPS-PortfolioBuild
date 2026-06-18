#property strict
#property version   "5.0"
#property description "QM5_1352 murrey-math-octave-reaction-h1 — Murrey Math 1/8 octave line-reaction fade (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_1352 murrey-math-octave-reaction-h1
// -----------------------------------------------------------------------------
// Source: forexfactory-trading-systems (Murrey Math cluster) + T. Henning Murrey,
//   "The Murrey Math Trading System for All Traded Markets" (1995, ISBN 978-0934380027).
//   Card: artifacts/cards_approved/QM5_1352_murrey-math-octave-reaction-h1.md
//         (g0_status APPROVED).
//   NOTE: card frontmatter ea_id is the stale "QM5_12145"; this build is ea_id 1352
//         per the build target. Frontmatter mismatch flagged in build_result.
//
// FAMILY: geometric-harmonic price levels. The octave grid (8 horizontal 1/8 lines)
//   is computed IN-EA from a rolling HH/LL over LOOKBACK H1 bars, then snapped to a
//   power-of-2 "Murrey frame" R: the smallest R = base_unit * 2^k with R >= RANGE.
//   The octave bottom is pinned to the largest multiple of R <= LL, top = bottom + R.
//   Lines are STATES. The single trigger EVENT is the line-REACTION rejection candle.
//
// Mechanics (H1, closed-bar reads at shift 1; session in BROKER time):
//   Octave levels (STATE), recomputed once per closed bar:
//     HH = max(high[1..LOOKBACK]),  LL = min(low[1..LOOKBACK]),  RANGE = HH-LL
//     R  = base_unit * 2^k  (smallest such that R >= RANGE)   (Murrey frame)
//     OctaveBottom = floor(LL / R) * R ;  OctaveTop = OctaveBottom + R
//     Level_k = OctaveBottom + k * R / 8,  k in {0..8}
//   RSI(14) on H1 (STATE) — oversold/overbought-and-turning confirmation.
//   ATR(14) on H1 (STATE) — stop sizing + min-distance gate.
//
//   Trigger EVENT (single, two-event-trap-safe): on the just-closed signal bar, a
//   rejection candle off a LOWER reaction level {Level_0,1,2} (low<=Level AND
//   close>Level) for BUY, or off an UPPER level {Level_6,7,8} (high>=Level AND
//   close<Level) for SELL. The rejection is the ONE event; RSI/min-distance/
//   octave-not-broken/session are all STATE gates.
//
//   Stop  : BUY  -> min(Level_0, entry - sl_atr_mult*ATR)  (octave-bottom is structural).
//           SELL -> max(Level_8, entry + sl_atr_mult*ATR).
//   Take  : nearest of (Level_{k+2}) and (Level_4 mid-octave magnet) that is above
//           entry + tp_atr_mult*ATR; fallback entry + tp_atr_mult*ATR.
//           (Mirror for SELL.)
//   Exits : octave-break (close < Level_0 for a long / > Level_8 for a short -> the
//           signal is invalidated, new octave initialises); 24-bar time stop.
//   Suppress: after an octave-break, suppress new entries for break_suppress_bars bars.
//   Session: only fire entries inside [session_start_h, session_end_h) broker time.
//
// Cache discipline: ALL octave/indicator/signal-bar state is advanced ONCE per
// closed bar in AdvanceState_OnNewBar(). The per-tick path reads cached doubles only
// (no CopyRates loops, no per-tick indicator recompute).
//
// Only the 5 Strategy_* hooks + Strategy inputs + the cache advance are EA-specific.
// Everything else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1352;
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
input int    strategy_lookback          = 64;        // HH/LL lookback for the octave (H1 bars)
input double strategy_base_unit         = 0.0;        // Murrey-frame base unit; 0 = auto from tick size
input int    strategy_rsi_period        = 14;        // RSI confirmation period
input double strategy_rsi_buy_max       = 40.0;      // BUY requires RSI < this AND turning up
input double strategy_rsi_sell_min      = 60.0;      // SELL requires RSI > this AND turning down
input int    strategy_atr_period        = 14;        // ATR period (stop / target / min-dist)
input double strategy_sl_atr_mult       = 1.5;       // catastrophic ATR stop multiplier
input double strategy_tp_atr_mult       = 1.5;       // min target distance + fallback TP, in ATR
input double strategy_min_dist_atr      = 1.0;       // skip if chosen target < this*ATR from entry
input int    strategy_time_stop_bars    = 24;        // bars-held time stop (~1 trading day H1)
input int    strategy_break_suppress_bars = 8;       // suppress entries N bars after an octave break
input int    strategy_session_start_h   = 6;         // entry session start, BROKER hour (incl.)
input int    strategy_session_end_h     = 22;        // entry session end, BROKER hour (excl.)
input double strategy_max_spread_atr    = 0.0;       // wide-spread guard cap, in ATR (0 = off)

// -----------------------------------------------------------------------------
// File-scope cached state (advanced once per closed bar).
// -----------------------------------------------------------------------------
double   g_level[9];               // Murrey 1/8 levels Level_0..Level_8 (octave grid)
double   g_octave_R   = 0.0;       // current Murrey-frame size
bool     g_octave_valid = false;

double   g_rsi   = 0.0;            // RSI(period) snapshot, closed bar
double   g_rsi_prev = 0.0;         // RSI of the bar before (turning detection)
double   g_atr   = 0.0;            // ATR(period) snapshot, closed bar

double   g_sig_high = 0.0, g_sig_low = 0.0, g_sig_close = 0.0; // signal-bar OHLC (shift 1)

datetime g_entry_bar_time = 0;     // bar-open time of the bar an entry fired on (time stop)
int      g_suppress_until_bar = -1; // bar index counter until which entries are suppressed
int      g_bar_counter = 0;        // monotonic closed-bar counter for suppression window

// Resolve the Murrey-frame base unit. If the user leaves it 0, derive from the
// symbol's tick size so the power-of-2 frame is scale-appropriate across FX/index/gold.
double FrameBaseUnit()
  {
   if(strategy_base_unit > 0.0)
      return strategy_base_unit;
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      point = _Point;
   if(point <= 0.0)
      return 0.0001;
   // ~256 points per smallest Murrey octave unit: small enough that 2^k climbs to
   // cover the rolling range in a few doublings, large enough to keep levels coarse.
   return point * 256.0;
  }

// Smallest Murrey frame R = base_unit * 2^k with R >= range (capped iterations).
double MurreyFrame(const double range, const double base_unit)
  {
   if(base_unit <= 0.0 || range <= 0.0)
      return 0.0;
   double R = base_unit;
   int guard = 0;
   while(R < range && guard < 64)
     {
      R *= 2.0;
      guard++;
     }
   return R;
  }

// Advance ALL cached state by exactly one closed bar. Called once per new bar.
void AdvanceState_OnNewBar()
  {
   g_bar_counter++;

   // --- Rolling HH/LL over LOOKBACK closed bars (shift 1..LOOKBACK) ---
   const int n = (strategy_lookback < 1) ? 1 : strategy_lookback;
   double highs[]; double lows[];
   ArraySetAsSeries(highs, true);
   ArraySetAsSeries(lows, true);
   // perf-allowed: bounded copy of the lookback window, ONCE per closed bar.
   const int gotH = CopyHigh(_Symbol, _Period, 1, n, highs);
   const int gotL = CopyLow(_Symbol, _Period, 1, n, lows);
   if(gotH == n && gotL == n)
     {
      double hh = highs[0];
      double ll = lows[0];
      for(int i = 1; i < n; ++i)
        {
         if(highs[i] > hh) hh = highs[i];
         if(lows[i]  < ll) ll = lows[i];
        }
      const double range = hh - ll;
      const double base_unit = FrameBaseUnit();
      const double R = MurreyFrame(range, base_unit);
      if(R > 0.0 && hh > ll)
        {
         const double octave_bottom = MathFloor(ll / R) * R;
         g_octave_R = R;
         for(int k = 0; k <= 8; ++k)
            g_level[k] = octave_bottom + (double)k * R / 8.0;
         g_octave_valid = true;
        }
      else
        {
         g_octave_valid = false;
        }
     }
   else
     {
      g_octave_valid = false;
     }

   // --- Signal-bar OHLC (shift 1) for the entry/exit gates ---
   g_sig_high  = iHigh(_Symbol, _Period, 1);   // perf-allowed: single closed-bar read
   g_sig_low   = iLow(_Symbol, _Period, 1);    // perf-allowed
   g_sig_close = iClose(_Symbol, _Period, 1);  // perf-allowed

   // --- Indicator snapshots (handle-pooled QM readers, closed bar) ---
   g_rsi      = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   g_rsi_prev = QM_RSI(_Symbol, _Period, strategy_rsi_period, 2);
   g_atr      = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
  }

// True if the just-closed signal bar is inside the entry session (broker time).
bool InEntrySession()
  {
   const datetime bar_time = iTime(_Symbol, _Period, 1); // perf-allowed: closed-bar timestamp
   if(bar_time <= 0)
      return false;
   MqlDateTime bt;
   TimeToStruct(bar_time, bt);
   const int h = bt.hour;
   if(strategy_session_start_h <= strategy_session_end_h)
      return (h >= strategy_session_start_h && h < strategy_session_end_h);
   return (h >= strategy_session_start_h || h < strategy_session_end_h);
  }

bool EntriesSuppressed()
  {
   return (g_suppress_until_bar >= 0 && g_bar_counter < g_suppress_until_bar);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Block outside the broker-time entry session. .DWX
// fail-OPEN spread guard: only a genuinely WIDE spread blocks; zero modeled
// spread (ask==bid) never blocks.
bool Strategy_NoTradeFilter()
  {
   if(!InEntrySession())
      return true;

   if(strategy_max_spread_atr > 0.0 && g_atr > 0.0)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double cap = strategy_max_spread_atr * g_atr;
      if(ask > 0.0 && bid > 0.0 && ask > bid && (ask - bid) > cap)
         return true; // genuinely wide spread
     }
   return false;
  }

// Pick the BUY take-profit: nearest of Level_{k+2} and Level_4 (mid-octave magnet)
// that is at least min-dist above entry; else fixed ATR fallback. Returns 0 if none.
double PickBuyTP(const int k, const double entry)
  {
   const double min_target = entry + strategy_min_dist_atr * g_atr;
   double tp = 0.0;
   // Candidate 1: two levels up (skip-one target).
   const int kk = k + 2;
   if(kk <= 8 && g_level[kk] >= min_target)
      tp = g_level[kk];
   // Candidate 2: mid-octave magnet Level_4.
   if(g_level[4] >= min_target)
     {
      if(tp <= 0.0 || g_level[4] < tp) // nearest above entry
         tp = g_level[4];
     }
   if(tp <= 0.0)
      tp = entry + strategy_tp_atr_mult * g_atr; // fallback
   return tp;
  }

double PickSellTP(const int k, const double entry)
  {
   const double min_target = entry - strategy_min_dist_atr * g_atr;
   double tp = 0.0;
   const int kk = k - 2;
   if(kk >= 0 && g_level[kk] <= min_target)
      tp = g_level[kk];
   if(g_level[4] <= min_target)
     {
      if(tp <= 0.0 || g_level[4] > tp) // nearest below entry
         tp = g_level[4];
     }
   if(tp <= 0.0)
      tp = entry - strategy_tp_atr_mult * g_atr;
   return tp;
  }

// Entry. Caller guarantees QM_IsNewBar()==true and AdvanceState_OnNewBar() ran.
// Reads cached state only.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;
   if(!g_octave_valid)
      return false;
   if(g_atr <= 0.0 || g_rsi <= 0.0 || g_rsi_prev <= 0.0)
      return false;
   if(g_sig_high <= 0.0 || g_sig_low <= 0.0 || g_sig_close <= 0.0)
      return false;
   if(EntriesSuppressed())
      return false;

   // ===================== BUY: reaction off a lower octave level ==============
   // RSI confirmation: oversold and turning up (STATE).
   const bool rsi_buy = (g_rsi < strategy_rsi_buy_max && g_rsi > g_rsi_prev);
   if(rsi_buy)
     {
      for(int k = 0; k <= 2; ++k)
        {
         // EVENT (single trigger): rejection candle off Level_k.
         const bool rejection = (g_sig_low <= g_level[k] && g_sig_close > g_level[k]);
         if(!rejection)
            continue;

         const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(entry <= 0.0)
            return false;

         // SL: lower of (Level_0) and (entry - mult*ATR) — octave-bottom is structural.
         const double sl_atr   = entry - strategy_sl_atr_mult * g_atr;
         double sl = MathMin(g_level[0], sl_atr);
         if(sl <= 0.0 || sl >= entry)
            return false;

         const double tp = PickBuyTP(k, entry);
         if(tp <= entry || (tp - entry) < strategy_min_dist_atr * g_atr)
            return false;

         req.type   = QM_BUY;
         req.price  = 0.0;
         req.sl     = QM_TM_NormalizePrice(_Symbol, sl);
         req.tp     = QM_TM_NormalizePrice(_Symbol, tp);
         req.reason = "mml_lower_reaction_long";
         req.symbol_slot = qm_magic_slot_offset;
         req.expiration_seconds = 0;
         g_entry_bar_time = iTime(_Symbol, _Period, 0); // current (open) bar
         return true;
        }
     }

   // ===================== SELL: reaction off an upper octave level ============
   const bool rsi_sell = (g_rsi > strategy_rsi_sell_min && g_rsi < g_rsi_prev);
   if(rsi_sell)
     {
      for(int k = 6; k <= 8; ++k)
        {
         const bool rejection = (g_sig_high >= g_level[k] && g_sig_close < g_level[k]);
         if(!rejection)
            continue;

         const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(entry <= 0.0)
            return false;

         const double sl_atr   = entry + strategy_sl_atr_mult * g_atr;
         double sl = MathMax(g_level[8], sl_atr);
         if(sl <= entry)
            return false;

         const double tp = PickSellTP(k, entry);
         if(tp <= 0.0 || tp >= entry || (entry - tp) < strategy_min_dist_atr * g_atr)
            return false;

         req.type   = QM_SELL;
         req.price  = 0.0;
         req.sl     = QM_TM_NormalizePrice(_Symbol, sl);
         req.tp     = QM_TM_NormalizePrice(_Symbol, tp);
         req.reason = "mml_upper_reaction_short";
         req.symbol_slot = qm_magic_slot_offset;
         req.expiration_seconds = 0;
         g_entry_bar_time = iTime(_Symbol, _Period, 0);
         return true;
        }
     }

   return false;
  }

// Fixed SL/TP; structural exits live in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Structural exits: octave-break invalidation + time stop. Also arms the
// post-break entry-suppression window.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;
   if(!g_octave_valid)
      return false;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);

      // Octave-break exit: signal invalidated, octave re-initialises -> suppress.
      if(ptype == POSITION_TYPE_BUY && g_sig_close < g_level[0])
        {
         g_suppress_until_bar = g_bar_counter + strategy_break_suppress_bars;
         return true;
        }
      if(ptype == POSITION_TYPE_SELL && g_sig_close > g_level[8])
        {
         g_suppress_until_bar = g_bar_counter + strategy_break_suppress_bars;
         return true;
        }

      // Time stop: bars held since entry.
      if(g_entry_bar_time > 0)
        {
         const datetime cur = iTime(_Symbol, _Period, 0); // perf-allowed: current bar time
         const int secs_per_bar = PeriodSeconds(_Period);
         if(secs_per_bar > 0)
           {
            const int held = (int)((cur - g_entry_bar_time) / secs_per_bar);
            if(held >= strategy_time_stop_bars)
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

   ArrayInitialize(g_level, 0.0);
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1352\",\"strategy\":\"murrey-math-octave-reaction-h1\"}");
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

   // FIRST: advance closed-bar state exactly once per new bar (single-consume).
   const bool new_bar = QM_IsNewBar();
   if(new_bar)
      AdvanceState_OnNewBar();

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

   if(!new_bar)
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
