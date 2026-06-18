#property strict
#property version   "5.0"
#property description "QM5_1290 classic-pivot-points-fade-break — H1 classic floor pivots, dual-mode (S1/R1 fade + S2/R2 break) day-latched"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_1290 classic-pivot-points-fade-break
// -----------------------------------------------------------------------------
// Source: 6e967762 — ForexFactory Trading Systems forum, Classic Floor-Trader
//         Pivot Points cluster (intraday day-trade variant). Published lineage:
//         Etzkorn (Futures 1996), Pesavento, Schlossberg/Lien "Day Trading the
//         Currency Market" (Wiley 2008, Ch.6).
// Card: artifacts/cards_approved/QM5_1290_classic-pivot-points-fade-break.md
//       (g0_status APPROVED).
//
// Mechanics (H1 entry timeframe; closed-bar reads; broker time):
//
//   PIVOT STATE (per broker D1, recomputed at day rollover):
//     Classic floor pivots from the prior D1 bar OHLC (D1 shift 1):
//       P     = (H + L + C) / 3
//       range = H - L
//       R1 = 2P - L,        S1 = 2P - H
//       R2 = P + range,     S2 = P - range
//       R3 = R1 + range,    S3 = S1 - range
//     Levels static for the whole next broker day.
//
//   MODE SELECTION (latched at day-open, NOT re-evaluated intraday — MUTEX):
//     prev_day_range = H - L of the just-closed D1 bar.
//     atr_baseline   = ATR(20, D1)[1].
//     range_ratio    = prev_day_range / atr_baseline.
//       range_ratio < 0.85  -> Mode A (S1/R1 fade, mean-reversion).
//       range_ratio >= 0.85 -> Mode B (S2/R2 break, trend-continuation).
//     Skip the whole day if prev_day_range < 0.4 * atr_baseline (degenerate
//     no-movement day -> pivot levels too compressed).
//
//   ENTRY — Mode A (S1/R1 fade), single trigger EVENT per closed H1 bar:
//     LONG  : Low[1] <= S1 AND Close[1] > S1 AND Close[1] > S2 (outer S2 intact).
//     SHORT : High[1] >= R1 AND Close[1] < R1 AND Close[1] < R2.
//   ENTRY — Mode B (S2/R2 break), single trigger EVENT per closed H1 bar:
//     LONG  : Close[1] > R2 AND Close[2] <= R2 (first H1 close above R2).
//     SHORT : Close[1] < S2 AND Close[2] >= S2.
//     The pivot levels are STATE; the touch/rejection (fade) or the first close
//     beyond the level (break) is the single trigger EVENT. The break compares
//     Close[1] vs Close[2] (two distinct closed bars), and the fade requires a
//     touch+reject on one closed bar — neither is a same-bar two-cross, so the
//     zero-trade two-cross trap is avoided.
//     One position per symbol per magic per day; a per-direction day-lock
//     prevents repeat re-entries on later touches/re-breaks of the same level
//     group.
//
//   EXIT:
//     Mode A LONG  -> TP at P  (mid-pivot mean target). SHORT mirror.
//     Mode B LONG  -> TP at R3 (next outer level).      SHORT mirror.
//     Time-stop: flatten any open position at broker day-close (next D1 roll);
//                overnight pivot levels are stale.
//     Opposite-direction signal in the same level group closes first (handled
//     naturally: one-pos-per-magic + per-direction lock; the framework SL/TP
//     do the carrying, the time-stop the flattening).
//
//   STOP LOSS:
//     Mode A LONG  -> SL = S2 - 0.3*ATR(14,H1). SHORT -> R2 + 0.3*ATR(14,H1).
//     Mode B LONG  -> SL = R1 (inner pivot).    SHORT -> S1.
//     Floor: minimum SL distance = ATR(14,H1) * 1.0 (avoids micro-stops when
//            pivot levels are very tight).
//
//   FILTERS:
//     Spread cap: 25 pts FX / 50 pts index (only blocks a genuinely wide spread;
//                 .DWX quotes 0 spread in the tester -> never fail-closed).
//     No trade in the first H1 bar of broker-day-open (let the opening spike
//     print) nor in the last H1 bar before broker-day-close.
//     News-filter hook (framework-driven; off by default for P2).
//
// Per-tick path is O(1): pivots + mode + the per-bar trigger are computed once
// per closed H1 bar in AdvanceState_OnNewBar(); Strategy_EntrySignal only reads
// cached state. Only the 5 Strategy_* hooks + Strategy inputs are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1290;
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
input int    strategy_atr_d1_period      = 20;    // D1 ATR baseline for mode selection
input int    strategy_atr_h1_period      = 14;    // H1 ATR for SL buffer / floor
input double strategy_mode_threshold     = 0.85;  // range_ratio < => fade, >= => break
input double strategy_min_range_ratio    = 0.40;  // skip day if prev range below this * ATR
input double strategy_modeA_sl_atr_mult  = 0.30;  // Mode A SL buffer beyond S2/R2 (x H1 ATR)
input double strategy_sl_floor_atr_mult  = 1.00;  // minimum SL distance (x H1 ATR)
input double strategy_spread_cap_fx_pts  = 25.0;  // wide-spread block, FX majors (points)
input double strategy_spread_cap_idx_pts = 50.0;  // wide-spread block, index CFDs (points)

// -----------------------------------------------------------------------------
// Cached strategy state (advanced by AdvanceState_OnNewBar on each closed H1 bar)
// -----------------------------------------------------------------------------
// Pivot levels for the current broker day.
double   g_P  = 0.0;
double   g_R1 = 0.0, g_S1 = 0.0;
double   g_R2 = 0.0, g_S2 = 0.0;
double   g_R3 = 0.0, g_S3 = 0.0;
double   g_atr_h1 = 0.0;           // ATR(14,H1)[1] cached for SL math

bool     g_levels_valid  = false;
datetime g_pivot_day     = 0;      // broker-day key (D1 bar-1 open) of the levels

// Latched mode + skip flag for the current broker day.
int      g_mode          = 0;      // 0 none / 1 = Mode A fade / 2 = Mode B break
bool     g_day_skip      = true;   // true until a valid tradable day is latched

// Per-direction day-lock (one position per direction per day per symbol).
bool     g_traded_long   = false;
bool     g_traded_short  = false;

// Trigger latched by the state machine for Strategy_EntrySignal to consume.
bool     g_trigger_ready = false;
int      g_trigger_dir   = 0;      // +1 long / -1 short
double   g_trigger_sl    = 0.0;    // resolved SL price
double   g_trigger_tp    = 0.0;    // resolved TP price

// New-bar latch shared between exit and entry within one OnTick.
bool     g_new_bar_this_tick = false;

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

double PipSize()
  {
   // 1 pip = 10 points on 5/3-digit symbols, 1 point on 4/2-digit.
   const int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const double point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(digits == 3 || digits == 5)
      return point * 10.0;
   return point;
  }

// Is this an index CFD? Used only to pick the spread cap (FX vs index).
bool IsIndexSymbol()
  {
   const int calc = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_CALC_MODE);
   // CFD-style calc modes (index/CFD) vs forex calc modes.
   if(calc == SYMBOL_CALC_MODE_CFD || calc == SYMBOL_CALC_MODE_CFDINDEX ||
      calc == SYMBOL_CALC_MODE_CFDLEVERAGE)
      return true;
   return false;
  }

// Recompute classic floor pivots + latch the day's mode from the prior broker D1
// bar. Returns false if the D1 history is not yet available. perf-allowed:
// single closed D1 read, gated to run only when the broker day rolls.
bool ComputePivotsAndMode()
  {
   const datetime d1_open = iTime(_Symbol, PERIOD_D1, 1); // perf-allowed: prior D1 bar open (broker time)
   if(d1_open <= 0)
      return false;

   const double H = iHigh(_Symbol, PERIOD_D1, 1);  // perf-allowed: prior D1 OHLC
   const double L = iLow(_Symbol, PERIOD_D1, 1);
   const double C = iClose(_Symbol, PERIOD_D1, 1);
   if(H <= 0.0 || L <= 0.0 || C <= 0.0 || H < L)
      return false;

   const double range = H - L;
   g_P  = (H + L + C) / 3.0;
   g_R1 = 2.0 * g_P - L;
   g_S1 = 2.0 * g_P - H;
   g_R2 = g_P + range;
   g_S2 = g_P - range;
   g_R3 = g_R1 + range;
   g_S3 = g_S1 - range;

   // Mode selection on the just-closed day's range vs D1 ATR baseline.
   const double atr_d1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_d1_period, 1);
   if(atr_d1 <= 0.0)
      return false;
   const double range_ratio = range / atr_d1;

   g_day_skip     = false;
   g_traded_long  = false;
   g_traded_short = false;

   if(range_ratio < strategy_min_range_ratio)
     {
      // Degenerate no-movement day -> levels too compressed; skip the whole day.
      g_mode     = 0;
      g_day_skip = true;
     }
   else if(range_ratio < strategy_mode_threshold)
      g_mode = 1; // Mode A: S1/R1 fade
   else
      g_mode = 2; // Mode B: S2/R2 break

   g_pivot_day    = d1_open;
   g_levels_valid = true;
   return true;
  }

// Resolve SL price for a Mode-A fade, applying the ATR floor.
double ModeA_SL(const int dir, const double atr_h1)
  {
   const double buf = strategy_modeA_sl_atr_mult * atr_h1;
   const double floor_dist = strategy_sl_floor_atr_mult * atr_h1;
   if(dir > 0)
     {
      double sl = g_S2 - buf;
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry > 0.0 && (entry - sl) < floor_dist)
         sl = entry - floor_dist;
      return sl;
     }
   double sl = g_R2 + buf;
   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry > 0.0 && (sl - entry) < floor_dist)
      sl = entry + floor_dist;
   return sl;
  }

// Resolve SL price for a Mode-B break, applying the ATR floor.
double ModeB_SL(const int dir, const double atr_h1)
  {
   const double floor_dist = strategy_sl_floor_atr_mult * atr_h1;
   if(dir > 0)
     {
      double sl = g_R1; // inner pivot
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry > 0.0 && (entry - sl) < floor_dist)
         sl = entry - floor_dist;
      return sl;
     }
   double sl = g_S1;
   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry > 0.0 && (sl - entry) < floor_dist)
      sl = entry + floor_dist;
   return sl;
  }

// Advance the strategy state by exactly ONE closed H1 bar (the bar at shift 1).
// Recomputes pivots + mode on a day roll; latches at most one entry trigger.
void AdvanceState_OnNewBar()
  {
   g_trigger_ready = false;
   g_trigger_dir   = 0;
   g_trigger_sl    = 0.0;
   g_trigger_tp    = 0.0;

   // (Re)compute pivots + latch mode when the broker day rolls.
   const datetime cur_d1_open = iTime(_Symbol, PERIOD_D1, 1); // perf-allowed: day-roll key
   if(!g_levels_valid || cur_d1_open != g_pivot_day)
     {
      if(!ComputePivotsAndMode())
         return;
     }
   if(!g_levels_valid || g_day_skip || g_mode == 0)
      return;

   // Last two closed H1 bars. perf-allowed: single closed-bar OHLC reads.
   const double c1 = iClose(_Symbol, _Period, 1);
   const double h1 = iHigh(_Symbol, _Period, 1);
   const double l1 = iLow(_Symbol, _Period, 1);
   const double c2 = iClose(_Symbol, _Period, 2);
   if(c1 <= 0.0 || h1 <= 0.0 || l1 <= 0.0)
      return;

   const double atr_h1 = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_h1_period, 1);
   if(atr_h1 <= 0.0)
      return;
   g_atr_h1 = atr_h1;

   if(g_mode == 1)
     {
      // ----- Mode A: S1/R1 fade -----
      // LONG: touched S1 and closed back above it, with outer S2 still intact.
      if(!g_traded_long &&
         l1 <= g_S1 && c1 > g_S1 && c1 > g_S2)
        {
         g_trigger_ready = true;
         g_trigger_dir   = +1;
         g_trigger_sl    = ModeA_SL(+1, atr_h1);
         g_trigger_tp    = g_P;           // mean target
         return;
        }
      // SHORT mirror.
      if(!g_traded_short &&
         h1 >= g_R1 && c1 < g_R1 && c1 < g_R2)
        {
         g_trigger_ready = true;
         g_trigger_dir   = -1;
         g_trigger_sl    = ModeA_SL(-1, atr_h1);
         g_trigger_tp    = g_P;
         return;
        }
     }
   else if(g_mode == 2)
     {
      // ----- Mode B: S2/R2 break -----
      // LONG: first H1 close above R2 (Close[1] > R2 AND Close[2] <= R2).
      if(!g_traded_long &&
         c2 > 0.0 && c1 > g_R2 && c2 <= g_R2)
        {
         g_trigger_ready = true;
         g_trigger_dir   = +1;
         g_trigger_sl    = ModeB_SL(+1, atr_h1);
         g_trigger_tp    = g_R3;          // next outer level
         return;
        }
      // SHORT mirror: first H1 close below S2.
      if(!g_traded_short &&
         c2 > 0.0 && c1 < g_S2 && c2 >= g_S2)
        {
         g_trigger_ready = true;
         g_trigger_dir   = -1;
         g_trigger_sl    = ModeB_SL(-1, atr_h1);
         g_trigger_tp    = g_S3;
         return;
        }
     }
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// No-trade filter: block the first and last H1 bar of the broker day (opening
// spike / no fresh position into rollover), and a genuinely wide spread. Cheap
// O(1). .DWX quotes 0 spread in the tester so the spread guard never fail-closes.
bool Strategy_NoTradeFilter()
  {
   // First / last H1 bar of the broker day.
   const datetime broker_now = TimeCurrent();
   MqlDateTime bt;
   TimeToStruct(broker_now, bt);
   if(bt.hour == 0)        // first H1 bar of the broker day
      return true;
   if(bt.hour == 23)       // last H1 bar before broker-day-close
      return true;

   // Wide-spread guard (never block on zero spread; .DWX tester quotes 0).
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask > 0.0 && bid > 0.0 && ask > bid)
     {
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(point > 0.0)
        {
         const double spread_pts = (ask - bid) / point;
         const double cap = IsIndexSymbol() ? strategy_spread_cap_idx_pts
                                             : strategy_spread_cap_fx_pts;
         if(spread_pts > cap)
            return true;
        }
     }
   return false;
  }

// Entry: consume the latched dual-mode trigger. Caller guarantees
// QM_IsNewBar() == true. Only reads cached state — no per-tick lookback.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;
   if(!g_trigger_ready || g_trigger_dir == 0)
      return false;

   const double sl = QM_StopRulesNormalizePrice(_Symbol, g_trigger_sl);
   const double tp = (g_trigger_tp > 0.0)
                     ? QM_StopRulesNormalizePrice(_Symbol, g_trigger_tp) : 0.0;

   if(g_trigger_dir > 0)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;     // framework fills market at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = (g_mode == 1) ? "pivot_fade_long" : "pivot_break_long";
      g_traded_long = true; // one long per day
     }
   else
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = (g_mode == 1) ? "pivot_fade_short" : "pivot_break_short";
      g_traded_short = true; // one short per day
     }

   g_trigger_ready = false; // consume
   return true;
  }

// SL/TP are fixed at entry (level-based). No active management.
void Strategy_ManageOpenPosition()
  {
  }

// Time-stop: flatten any open position at broker day-close (last H1 bar of the
// broker day). One event-check per tick.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   const datetime broker_now = TimeCurrent();
   MqlDateTime bt;
   TimeToStruct(broker_now, bt);
   if(bt.hour == 23)   // at/into broker-day-close -> flatten (levels go stale)
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

   g_levels_valid  = false;
   g_pivot_day     = 0;
   g_mode          = 0;
   g_day_skip      = true;
   g_traded_long   = false;
   g_traded_short  = false;
   g_trigger_ready = false;
   g_trigger_dir   = 0;
   g_trigger_sl    = 0.0;
   g_trigger_tp    = 0.0;
   g_atr_h1        = 0.0;

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

   // Advance the closed-bar state machine FIRST so exit/entry see fresh state.
   // QM_IsNewBar() is single-consume per tick — latch it once and reuse.
   g_new_bar_this_tick = QM_IsNewBar();
   if(g_new_bar_this_tick)
      AdvanceState_OnNewBar();

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
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
        }
     }

   if(!g_new_bar_this_tick)
      return;

   QM_EquityStreamOnNewBar();

   if(Strategy_NoTradeFilter())
      return;

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
