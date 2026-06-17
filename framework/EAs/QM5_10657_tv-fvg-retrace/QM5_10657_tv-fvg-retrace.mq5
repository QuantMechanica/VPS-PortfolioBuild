#property strict
#property version   "5.0"
#property description "QM5_10657 TradingView FVG Retracement — 3-bar fair-value-gap + break-of-structure, armed retracement entry into a Fibonacci level inside the gap, FVG-boundary stop, RR take-profit."

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_10657 tv-fvg-retrace
// -----------------------------------------------------------------------------
// Card: artifacts/cards_approved/QM5_10657_tv-fvg-retrace.md (g0_status APPROVED).
// Mechanic (P2 baseline, candle-close entry path):
//   1. On each closed bar, scan for a 3-bar Fair Value Gap (imbalance) whose
//      size >= min_fvg_atr * ATR.   Bullish FVG: low[i] > high[i+2] (gap between
//      the high of the older bar and the low of the newer bar).  Bearish FVG:
//      high[i] < low[i+2].
//   2. Require a Break Of Structure in the FVG direction *after* the gap forms
//      (close pushes beyond the prior swing high/low over a lookback window).
//   3. ARM the setup. On a LATER bar (never the same bar the gap completes —
//      .DWX invariant #1) wait for price to retrace into the gap and reach the
//      configured Fibonacci level measured from the far edge toward the near
//      edge of the gap.  Confirm with a candle close that rebounds in the trade
//      direction.  Fire a market entry then.
//   4. Delete the armed setup if no trigger within `setup_expiry_bars`.
//
//   Stop  : FVG far boundary +/- stop_buffer_atr * ATR  (P2 default).
//   Take  : fixed reward_rr multiple of risk (RR-based TP).
//   Sizing: framework risk model (QM_LotsForRisk via QM_TM_OpenPosition).
//
// Closed-bar reads only (shift>=1). One position per symbol/magic. Strict MQL5.
// All structural state is cached in file-scope vars advanced ONCE per closed bar
// inside Strategy_EntrySignal (caller guarantees QM_IsNewBar()==true there).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10657;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
// Base timeframe: M5 on indices, M15 on FX/metals — set per-symbol via setfile.
input ENUM_TIMEFRAMES strategy_timeframe   = PERIOD_M5;
// FVG minimum size as a fraction of ATR (card sweep: 0.1, 0.2, 0.4).
input double strategy_min_fvg_atr          = 0.2;
input int    strategy_atr_period           = 14;
// Fibonacci retracement trigger inside the gap (card sweep: 0.50, 0.618, 0.705).
// Measured from the FAR edge (gap origin) toward the NEAR edge (entry side).
input double strategy_fib_trigger          = 0.618;
// Setup expiry: bars allowed from FVG formation to retrace trigger (card: 10/20/40).
input int    strategy_setup_expiry_bars    = 20;
// Break-of-structure lookback (bars) used to confirm directional validity.
input int    strategy_bos_lookback         = 10;
// Stop buffer beyond the FVG far boundary, in ATR multiples (P2 default 0.1).
input double strategy_stop_buffer_atr      = 0.1;
// Reward target as an R multiple (card sweep: 1.5, 2.0, 3.0).
input double strategy_reward_rr            = 2.0;
// Big-FVG no-trade guard: skip setups whose gap exceeds this ATR multiple
// (P2 treats oversized gaps as no-trade — keeps stop inside max-risk bounds).
input double strategy_big_fvg_atr          = 3.0;

// -----------------------------------------------------------------------------
// Armed-setup state (one pending FVG setup at a time). Advanced once per closed
// bar from Strategy_EntrySignal. No second new-bar gate inside helpers.
// -----------------------------------------------------------------------------
bool     g_setup_active   = false;   // a valid FVG+BOS setup is armed
int      g_setup_dir      = 0;       // +1 long / -1 short
double   g_gap_near       = 0.0;     // edge of gap closest to current price (entry side)
double   g_gap_far        = 0.0;     // edge of gap furthest from price (stop side)
double   g_fib_level      = 0.0;     // retracement trigger price inside the gap
double   g_setup_atr      = 0.0;     // ATR snapshot at FVG formation (for stop buffer)
int      g_bars_armed     = 0;       // bars elapsed since the setup was armed

void QM_ResetSetup()
  {
   g_setup_active = false;
   g_setup_dir    = 0;
   g_gap_near     = 0.0;
   g_gap_far      = 0.0;
   g_fib_level    = 0.0;
   g_setup_atr    = 0.0;
   g_bars_armed   = 0;
  }

// Try to detect a fresh 3-bar FVG that just completed at the last closed bars,
// then require a same-direction break of structure. Arms g_setup_* on success.
// shift 1 = most recent closed bar; the 3-bar window is bars (1,2,3).
void QM_TryArmSetup()
  {
   const string sym = _Symbol;
   const double atr = QM_ATR(sym, strategy_timeframe, strategy_atr_period, 1);
   if(atr <= 0.0)
      return;

   // 3-bar FVG window: bar1 (newest closed), bar2 (middle/impulse), bar3 (oldest).
   const double high1 = iHigh(sym, strategy_timeframe, 1);   // perf-allowed: closed-bar structural read, new-bar gated
   const double low1  = iLow(sym, strategy_timeframe, 1);
   const double high3 = iHigh(sym, strategy_timeframe, 3);
   const double low3  = iLow(sym, strategy_timeframe, 3);

   int    dir      = 0;
   double gap_near = 0.0;   // entry-side edge
   double gap_far  = 0.0;   // stop-side edge

   // Bullish FVG: gap between high of older bar (bar3) and low of newer bar (bar1).
   if(low1 > high3)
     {
      const double size = low1 - high3;
      if(size >= strategy_min_fvg_atr * atr && size <= strategy_big_fvg_atr * atr)
        {
         dir      = 1;
         gap_near = low1;    // top of gap — price retraces DOWN into it from above
         gap_far  = high3;   // bottom of gap — stop side
        }
     }
   // Bearish FVG: gap between low of older bar (bar3) and high of newer bar (bar1).
   else if(high1 < low3)
     {
      const double size = low3 - high1;
      if(size >= strategy_min_fvg_atr * atr && size <= strategy_big_fvg_atr * atr)
        {
         dir      = -1;
         gap_near = high1;   // bottom of gap — price retraces UP into it from below
         gap_far  = low3;    // top of gap — stop side
        }
     }

   if(dir == 0)
      return;

   // Break of structure in the FVG direction: the newest closed bar's close must
   // push beyond the prior swing extreme over the BOS lookback window (bars 2..N+1,
   // i.e. excluding the bar that broke). Uses closed-bar extremes.
   const double close1 = iClose(sym, strategy_timeframe, 1);
   double swing_high = -DBL_MAX;
   double swing_low  =  DBL_MAX;
   for(int s = 2; s <= strategy_bos_lookback + 1; ++s)
     {
      const double h = iHigh(sym, strategy_timeframe, s);   // perf-allowed: closed-bar structural read, new-bar gated
      const double l = iLow(sym, strategy_timeframe, s);
      if(h > swing_high) swing_high = h;
      if(l < swing_low)  swing_low  = l;
     }

   bool bos = false;
   if(dir == 1 && close1 > swing_high)
      bos = true;
   else if(dir == -1 && close1 < swing_low)
      bos = true;
   if(!bos)
      return;

   // Arm. Fibonacci trigger measured from the FAR edge toward the NEAR edge:
   //   long  : trigger = far + fib*(near-far)   (price must dip to this level)
   //   short : trigger = far - fib*(far-near)   (price must rally to this level)
   g_setup_active = true;
   g_setup_dir    = dir;
   g_gap_near     = gap_near;
   g_gap_far      = gap_far;
   g_setup_atr    = atr;
   g_bars_armed   = 0;

   if(dir == 1)
      g_fib_level = gap_far + strategy_fib_trigger * (gap_near - gap_far);
   else
      g_fib_level = gap_far - strategy_fib_trigger * (gap_far - gap_near);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// O(1) per-tick filter. No structural work here.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Entry evaluation — runs on each closed bar (QM_IsNewBar guaranteed by caller).
// Advances armed-setup state by one bar, then checks for a retrace trigger.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const string sym = _Symbol;

   // One position per symbol/magic — do not arm/fire while a position is open.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
     {
      QM_ResetSetup();
      return false;
     }

   // 1) Age the currently-armed setup; expire it if too old.
   if(g_setup_active)
     {
      g_bars_armed++;
      if(g_bars_armed > strategy_setup_expiry_bars)
         QM_ResetSetup();
     }

   // 2) If nothing armed, try to arm a fresh FVG+BOS setup on this bar.
   //    The gap completes on bar1 here; the entry can only fire on a LATER bar
   //    (a subsequent call), satisfying the .DWX "arm then retrace" invariant.
   if(!g_setup_active)
     {
      QM_TryArmSetup();
      return false;   // never enter on the bar the gap completes
     }

   // 3) Setup armed on a prior bar — look for the retrace trigger now.
   const double close1 = iClose(sym, strategy_timeframe, 1);   // perf-allowed: closed-bar read, new-bar gated
   const double low1   = iLow(sym, strategy_timeframe, 1);
   const double high1  = iHigh(sym, strategy_timeframe, 1);

   bool triggered = false;
   if(g_setup_dir == 1)
     {
      // Price must dip into the gap to/below the fib level, then close back up
      // (rebound) — candle-close confirmation, still above the far/stop edge.
      if(low1 <= g_fib_level && close1 > g_fib_level && close1 > g_gap_far)
         triggered = true;
     }
   else
     {
      // Price must rally into the gap to/above the fib level, then close back
      // down (rebound), still below the far/stop edge.
      if(high1 >= g_fib_level && close1 < g_fib_level && close1 < g_gap_far)
         triggered = true;
     }

   if(!triggered)
      return false;

   // Build the entry request. Market entry at fill; SL at FVG far boundary plus
   // an ATR buffer; TP at reward_rr multiple of risk.
   const QM_OrderType side = (g_setup_dir == 1) ? QM_BUY : QM_SELL;
   const double entry_ref  = SymbolInfoDouble(sym, (g_setup_dir == 1) ? SYMBOL_ASK : SYMBOL_BID);
   if(entry_ref <= 0.0)
     {
      QM_ResetSetup();
      return false;
     }

   const double buffer = strategy_stop_buffer_atr * g_setup_atr;
   double sl = (g_setup_dir == 1) ? (g_gap_far - buffer) : (g_gap_far + buffer);
   sl = QM_StopRulesNormalizePrice(sym, sl);

   // Guard against a degenerate / inverted stop (gap collapsed inside spread).
   if((g_setup_dir == 1 && sl >= entry_ref) || (g_setup_dir == -1 && sl <= entry_ref))
     {
      QM_ResetSetup();
      return false;
     }

   const double tp = QM_TakeRR(sym, side, entry_ref, sl, strategy_reward_rr);

   req.type               = side;
   req.price              = 0.0;   // framework fills market price at send
   req.sl                 = sl;
   req.tp                 = tp;
   req.reason             = "fvg_retrace";
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   QM_ResetSetup();   // consume the setup whether or not the open succeeds
   return true;
  }

// No active trade management — fixed SL/TP carry the position (P2 keeps one
// clean exit path; trailing is a P3 variant per the card).
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit beyond SL/TP.
bool Strategy_ExitSignal()
  {
   return false;
  }

// Defer to the central two-axis news filter.
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
                        qm_news_mode_legacy,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,
                        30,
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,
                        qm_news_compliance))
      return INIT_FAILED;

   QM_ResetSetup();
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
