#property strict
#property version   "5.0"
#property description "QM5_10729 TradingView SMC sweep + MSS + FVG (shary890)"

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
input int    qm_ea_id                   = 10729;
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
// SMC sweep + MSS + FVG (TradingView "SMC ICT Backtest XAUUSD + MNQ", author
// shary890). Mechanics from the APPROVED card QM5_10729:
//   * Maintain last confirmed pivot high/low using swingLen = 5.
//   * Long: current low sweeps below the last pivot low, close reclaims above it,
//     close also breaks the previous-bar high (bullish MSS), and a bullish FVG
//     is present (low[1] > high[3]). Short = mirror.
//   * SL = signal-bar low (long) / high (short); TP = 2R.
//   * Trade only inside the London or New York session windows.
//   * Exit any open position at session end (no overnight carry).
//
// .DWX BACKTEST INVARIANT (binding, overrides the card's literal "same bar"
// wording): the MSS must be detected BEFORE the FVG entry, and the FVG-confirmed
// entry must fire on a LATER closed bar than the MSS-arm bar — never the same
// bar. We therefore ARM the direction on the sweep+reclaim+MSS bar, then ENTER
// on a subsequent closed bar that prints a same-direction FVG. The arm expires
// after `strategy_arm_max_bars` closed bars to avoid stale signals.
//
// Session windows are expressed in BROKER time (DXZ NY-Close GMT+2/+3) so the
// window lands on live hours regardless of US DST. The TradingView source does
// not state a timezone explicitly; the card's London 07:00-10:00 / New York
// 12:30-16:00 values are carried verbatim as broker-time HHMM inputs and are
// overridable per symbol via the setfile (per .DWX invariant #5).
input int    strategy_swing_len         = 5;     // pivot lookback each side (card swingLen=5)
input int    strategy_arm_max_bars      = 6;     // bars an MSS arm stays valid for an FVG entry
input double strategy_tp_rr             = 2.0;   // take-profit as R multiple (card 2R)
input int    strategy_london_start_hhmm = 700;   // London window start, broker HHMM
input int    strategy_london_end_hhmm   = 1000;  // London window end,   broker HHMM
input int    strategy_ny_start_hhmm     = 1230;  // New York window start, broker HHMM
input int    strategy_ny_end_hhmm       = 1600;  // New York window end,   broker HHMM
input int    strategy_max_spread_points = 0;     // 0 = disabled (DWX quotes 0 spread in tester)

// -----------------------------------------------------------------------------
// File-scope MSS-arm state. Advanced once per closed bar via the new-bar gate
// inside Strategy_EntrySignal (caller guarantees QM_IsNewBar()==true there).
// -----------------------------------------------------------------------------
int      g_arm_dir            = 0;       // +1 armed long, -1 armed short, 0 none
datetime g_arm_bar_time       = 0;       // open-time of the bar that armed the MSS
int      g_arm_bars_elapsed   = 0;       // closed bars since the arm formed
double   g_last_pivot_high    = 0.0;     // last confirmed swing high (price)
double   g_last_pivot_low     = 0.0;     // last confirmed swing low (price)

int HHMMToMinutes(const int hhmm)
  {
   const int hour   = hhmm / 100;
   const int minute = hhmm % 100;
   return hour * 60 + minute;
  }

int BrokerMinuteOfDay(const datetime broker_time)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(broker_time, dt);
   return dt.hour * 60 + dt.min;
  }

// True while broker wall-clock is inside the London OR New York window.
bool InSession(const datetime broker_time)
  {
   const int m = BrokerMinuteOfDay(broker_time);
   const bool london = (m >= HHMMToMinutes(strategy_london_start_hhmm) &&
                        m <  HHMMToMinutes(strategy_london_end_hhmm));
   const bool newyork = (m >= HHMMToMinutes(strategy_ny_start_hhmm) &&
                         m <  HHMMToMinutes(strategy_ny_end_hhmm));
   return (london || newyork);
  }

// True once the later (NY) window has closed for the day — used to force flat.
bool SessionEnded(const datetime broker_time)
  {
   const int m = BrokerMinuteOfDay(broker_time);
   return (m >= HHMMToMinutes(strategy_ny_end_hhmm));
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

bool SpreadAllowed()
  {
   // .DWX quotes ask==bid (0 modeled spread) in the tester — never fail-closed
   // on zero spread. Only block a genuinely wide spread when a cap is set.
   if(strategy_max_spread_points <= 0)
      return true;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return true; // fail-open: do not block on bad/zero quotes in the tester
   if(ask <= bid)
      return true; // zero/negative modeled spread is fine
   return ((ask - bid) / point <= strategy_max_spread_points);
  }

// --- Pivot detection (swingLen each side, closed bars) ----------------------
// A confirmed pivot sits at the center shift `swing+1`: its high (low) is the
// max (min) over the `swing` bars on each side. We evaluate using the most
// recently CLOSED window so the pivot is fully confirmed (right side filled).
// Bounded loop over 2*swing+1 closed bars.
bool ConfirmedPivotHigh(const int swing, double &pivot_price)
  {
   if(swing <= 0)
      return false;
   const int center = swing + 1; // shift of the candidate pivot bar
   const double center_high = iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, center); // perf-allowed: bounded pivot scan, closed bars.
   if(center_high <= 0.0)
      return false;
   for(int s = 1; s <= swing; ++s)
     {
      const double left  = iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, center + s); // perf-allowed: bounded pivot scan.
      const double right = iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, center - s); // perf-allowed: bounded pivot scan.
      if(left <= 0.0 || right <= 0.0)
         return false;
      if(center_high < left || center_high < right)
         return false;
     }
   pivot_price = center_high;
   return true;
  }

bool ConfirmedPivotLow(const int swing, double &pivot_price)
  {
   if(swing <= 0)
      return false;
   const int center = swing + 1;
   const double center_low = iLow(_Symbol, (ENUM_TIMEFRAMES)_Period, center); // perf-allowed: bounded pivot scan, closed bars.
   if(center_low <= 0.0)
      return false;
   for(int s = 1; s <= swing; ++s)
     {
      const double left  = iLow(_Symbol, (ENUM_TIMEFRAMES)_Period, center + s); // perf-allowed: bounded pivot scan.
      const double right = iLow(_Symbol, (ENUM_TIMEFRAMES)_Period, center - s); // perf-allowed: bounded pivot scan.
      if(left <= 0.0 || right <= 0.0)
         return false;
      if(center_low > left || center_low > right)
         return false;
     }
   pivot_price = center_low;
   return true;
  }

// Refresh the last confirmed pivot high/low once per closed bar.
void RefreshPivots()
  {
   double ph = 0.0, pl = 0.0;
   if(ConfirmedPivotHigh(strategy_swing_len, ph))
      g_last_pivot_high = ph;
   if(ConfirmedPivotLow(strategy_swing_len, pl))
      g_last_pivot_low = pl;
  }

// --- FVG (3-candle imbalance) on the most recent closed bars ----------------
// Bullish FVG: low of the newest closed bar (shift 1) is above the high of the
// bar two before it (shift 3) — gap at the middle bar (shift 2). Bearish mirror.
bool BullishFVG()
  {
   const double low_new  = iLow(_Symbol, (ENUM_TIMEFRAMES)_Period, 1);  // perf-allowed: card-defined 3-bar FVG, closed bars.
   const double high_old = iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, 3); // perf-allowed: card-defined 3-bar FVG, closed bars.
   if(low_new <= 0.0 || high_old <= 0.0)
      return false;
   return (low_new > high_old);
  }

bool BearishFVG()
  {
   const double high_new = iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, 1); // perf-allowed: card-defined 3-bar FVG, closed bars.
   const double low_old  = iLow(_Symbol, (ENUM_TIMEFRAMES)_Period, 3);  // perf-allowed: card-defined 3-bar FVG, closed bars.
   if(high_new <= 0.0 || low_old <= 0.0)
      return false;
   return (high_new < low_old);
  }

void InitRequest(QM_EntryRequest &req)
  {
   req.type               = QM_BUY;
   req.price              = 0.0;
   req.sl                 = 0.0;
   req.tp                 = 0.0;
   req.reason             = "";
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

void ClearArm()
  {
   g_arm_dir          = 0;
   g_arm_bar_time     = 0;
   g_arm_bars_elapsed = 0;
  }

// Detect a fresh sweep + reclaim + MSS on the just-closed bar (shift 1) and arm
// the direction. Overwrites any prior arm. Returns true if an arm was set.
bool TryArmMSS()
  {
   const double close1 = iClose(_Symbol, (ENUM_TIMEFRAMES)_Period, 1); // perf-allowed: MSS confirmation, closed bars.
   const double low1   = iLow(_Symbol,   (ENUM_TIMEFRAMES)_Period, 1); // perf-allowed: MSS confirmation, closed bars.
   const double high1  = iHigh(_Symbol,  (ENUM_TIMEFRAMES)_Period, 1); // perf-allowed: MSS confirmation, closed bars.
   const double high2  = iHigh(_Symbol,  (ENUM_TIMEFRAMES)_Period, 2); // perf-allowed: MSS confirmation, closed bars.
   const double low2   = iLow(_Symbol,   (ENUM_TIMEFRAMES)_Period, 2); // perf-allowed: MSS confirmation, closed bars.
   if(close1 <= 0.0 || low1 <= 0.0 || high1 <= 0.0 || high2 <= 0.0 || low2 <= 0.0)
      return false;

   const datetime bar1_time = iTime(_Symbol, (ENUM_TIMEFRAMES)_Period, 1); // perf-allowed: arm-bar timestamp, closed bar.

   // Bullish MSS: sweep below last pivot low, close reclaims above it, and close
   // breaks the previous-bar high.
   if(g_last_pivot_low > 0.0 &&
      low1 < g_last_pivot_low &&
      close1 > g_last_pivot_low &&
      close1 > high2)
     {
      g_arm_dir          = +1;
      g_arm_bar_time     = bar1_time;
      g_arm_bars_elapsed = 0;
      return true;
     }

   // Bearish MSS: sweep above last pivot high, close falls back below it, and
   // close breaks the previous-bar low.
   if(g_last_pivot_high > 0.0 &&
      high1 > g_last_pivot_high &&
      close1 < g_last_pivot_high &&
      close1 < low2)
     {
      g_arm_dir          = -1;
      g_arm_bar_time     = bar1_time;
      g_arm_bars_elapsed = 0;
      return true;
     }

   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // Let trade management / exit run while a position is open.
   if(HasOurOpenPosition())
      return false;

   if(!InSession(TimeCurrent()))
      return true;

   if(!SpreadAllowed())
      return true;

   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   InitRequest(req);

   // --- Per-closed-bar state advance (runs once; caller gated on QM_IsNewBar) -
   // 1) Age any existing arm BEFORE re-evaluating, so the entry below can only
   //    fire on a bar strictly LATER than the arm bar (.DWX invariant: MSS
   //    detected first, FVG entry on a later bar — never the same bar).
   const datetime bar1_time = iTime(_Symbol, (ENUM_TIMEFRAMES)_Period, 1); // perf-allowed: new-bar timestamp, closed bar.
   bool armed_on_a_prior_bar = false;
   if(g_arm_dir != 0)
     {
      if(g_arm_bar_time > 0 && bar1_time > g_arm_bar_time)
        {
         g_arm_bars_elapsed += 1;
         armed_on_a_prior_bar = true;
        }
      if(g_arm_bars_elapsed > strategy_arm_max_bars)
         ClearArm();
     }

   // 2) Refresh confirmed pivots from the freshly closed window.
   RefreshPivots();

   // 3) Capture the arm that is active from a PRIOR bar before this bar can
   //    re-arm (a fresh arm this bar must not enable a same-bar entry).
   const int  active_dir    = (armed_on_a_prior_bar ? g_arm_dir : 0);
   const bool can_enter_now = (active_dir != 0);

   // 4) Attempt a fresh MSS arm on this just-closed bar (may overwrite the arm
   //    AFTER we have captured `active_dir`, so it only affects later bars).
   TryArmMSS();

   // --- Entry gate: only on a bar later than the arm, inside session ---------
   if(!can_enter_now)
      return false;
   if(HasOurOpenPosition())
      return false;
   if(!InSession(TimeCurrent()))
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double sig_low  = iLow(_Symbol,  (ENUM_TIMEFRAMES)_Period, 1); // perf-allowed: signal-bar SL, closed bar.
   const double sig_high = iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, 1); // perf-allowed: signal-bar SL, closed bar.
   if(sig_low <= 0.0 || sig_high <= 0.0)
      return false;

   // --- Long: armed bullish + a bullish FVG prints on this later bar ---------
   if(active_dir > 0 && BullishFVG())
     {
      const double entry = ask;
      const double sl    = QM_StopRulesNormalizePrice(_Symbol, sig_low);
      if(sl <= 0.0 || sl >= entry)
        { ClearArm(); return false; }
      const double tp    = QM_TakeRR(_Symbol, QM_BUY, entry, sl, strategy_tp_rr);
      if(tp <= entry)
        { ClearArm(); return false; }

      req.type   = QM_BUY;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "TV_SMC_MSS_FVG_LONG";
      ClearArm();
      return true;
     }

   // --- Short: armed bearish + a bearish FVG prints on this later bar --------
   if(active_dir < 0 && BearishFVG())
     {
      const double entry = bid;
      const double sl    = QM_StopRulesNormalizePrice(_Symbol, sig_high);
      if(sl <= 0.0 || sl <= entry)
        { ClearArm(); return false; }
      const double tp    = QM_TakeRR(_Symbol, QM_SELL, entry, sl, strategy_tp_rr);
      if(tp >= entry || tp <= 0.0)
        { ClearArm(); return false; }

      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "TV_SMC_MSS_FVG_SHORT";
      ClearArm();
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card uses a fixed signal-bar SL and a 2R TP only; no BE, trail, or partial
   // close. Force-flat at session end is handled in Strategy_ExitSignal.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   // Card: exit any open position at session end if TP/SL has not fired.
   if(!SessionEnded(TimeCurrent()))
      return false;
   return HasOurOpenPosition();
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
