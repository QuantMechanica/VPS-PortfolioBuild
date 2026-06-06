#property strict
#property version   "5.0"
#property description "QM5_10856 TradingView Xiznit ER Regime Scalper"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_10856 tv-xiznit-er
// -----------------------------------------------------------------------------
// Mechanised from card QM5_10856_tv-xiznit-er.md (TradingView "Xiznit Advanced
// Scalper"). Efficiency-Ratio regime filter + session VWAP + dual EMA alignment
// scalper with fixed ATR bracket, regime-shift exit, and EOD flatten.
//
// Framework corset: only the five Strategy_* hooks + strategy inputs are filled.
// All per-tick wiring, risk, magic, news and Friday-close handling is framework
// boilerplate (unchanged). ER, VWAP and the candle-pattern filters are bespoke
// structural math with no QM_* reader equivalent, so the raw bar-series reads
// carry an explicit `// perf-allowed` exception. Every such read runs ONLY
// inside Strategy_EntrySignal, which OnTick gates behind QM_IsNewBar() — i.e.
// once per closed bar, never on the per-tick path.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10856;
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
// --- Efficiency Ratio regime ---
input int    er_length              = 20;    // Kaufman ER lookback (card tests 10/20/30)
input double er_trend_threshold     = 0.30;  // ER >= thr => regime is "trending" (card unspecified; see SPEC open question)
// --- Dual moving averages (EMA) ---
input int    fast_ma_period         = 9;     // fast EMA (card tests 9/12)
input int    slow_ma_period         = 21;    // slow EMA (card tests 21/34)
// --- Bracket (ATR-calibrated, approximates source 100-tick fixed SL/TP) ---
input int    strat_atr_period       = 14;    // ATR period for stop/target
input double atr_sl_mult            = 1.0;   // stop = 1.0*ATR(14) (card P2 baseline)
input double atr_tp_mult            = 1.0;   // target = 1.0*ATR (source 100t SL == 100t TP => 1:1)
// --- Entry quality filters ---
input double min_body_atr_frac      = 0.10;  // signal-candle body must be >= frac*ATR (card unspecified; see SPEC)
input double spread_guard_frac      = 0.15;  // skip if spread > 15% of stop distance (card V5 spread guard)
// --- Session windows (BROKER time; CST + 8h, DST-stable for NY-Close server) ---
input int    ny_open_hour_broker    = 16;    // NY RTH open 08:30 CST -> 16:30 broker
input int    ny_open_min_broker     = 30;
input int    ny_open_block_minutes  = 20;    // block first 20 min of NY session
input int    lunch_start_hour_broker= 20;    // 12:00 CST lunch -> 20:00 broker
input int    lunch_end_hour_broker  = 21;    // 13:00 CST lunch end -> 21:00 broker
input int    eod_flat_hour_broker   = 23;    // 15:58 CST EOD flatten -> 23:58 broker
input int    eod_flat_min_broker    = 58;

// -----------------------------------------------------------------------------
// File-scope cached strategy state. Advanced exactly one closed bar per call to
// Strategy_EntrySignal (which OnTick gates with QM_IsNewBar()). The per-tick
// path (Strategy_ExitSignal / Strategy_ManageOpenPosition) reads these only.
// -----------------------------------------------------------------------------
double   g_vwap         = 0.0;   // session VWAP up to the last closed bar
datetime g_vwap_day     = 0;     // broker date of the current VWAP session
double   g_vwap_cum_pv  = 0.0;   // cumulative typical*volume this session
double   g_vwap_cum_vol = 0.0;   // cumulative volume this session
int      g_regime       = 0;     // +1 uptrend / -1 downtrend / 0 non-trending
int      g_prev_regime  = 0;     // regime classified on the previous closed bar

// =============================================================================
// SECTION: News Filter Hook  (callable for Q09 News Impact phase)
// =============================================================================
// Optional news-filter override. Return TRUE to suppress trading regardless of
// the framework filter. This EA carries no bespoke news rule beyond the central
// two-axis filter, so it defers.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade2(...)
  }

// =============================================================================
// SECTION: No Trade Filter  (time, spread, news)
// =============================================================================
// Return TRUE to BLOCK this tick. Cheap O(1) broker-time gates only. Blocks the
// first 20 minutes of the NY session and the CST lunch hour — short windows in
// which neither new entries nor discretionary management should run. The EOD
// flatten (23:58 broker) is deliberately NOT gated here: it must remain on the
// live tick path so Strategy_ExitSignal can flatten open positions. Per-entry
// spread rejection lives in Strategy_EntrySignal (needs the stop distance).
bool Strategy_NoTradeFilter()
  {
   MqlDateTime t;
   TimeToStruct(TimeCurrent(), t);
   const int mod = t.hour * 60 + t.min;

   const int ny_open = ny_open_hour_broker * 60 + ny_open_min_broker;
   if(mod >= ny_open && mod < ny_open + ny_open_block_minutes)
      return true;

   const int lunch_start = lunch_start_hour_broker * 60;
   const int lunch_end   = lunch_end_hour_broker * 60;
   if(mod >= lunch_start && mod < lunch_end)
      return true;

   return false;
  }

// -----------------------------------------------------------------------------
// Helpers (closed-bar / time math)
// -----------------------------------------------------------------------------
bool IsAfterEodFlat(const datetime now)
  {
   MqlDateTime t;
   TimeToStruct(now, t);
   const int mod = t.hour * 60 + t.min;
   const int eod = eod_flat_hour_broker * 60 + eod_flat_min_broker;
   return (mod >= eod);
  }

// Advance the session VWAP by exactly one closed bar (shift=1). Resets the
// cumulative sums when the broker date rolls. O(1) — no history scan.
void AdvanceState_OnNewBar()
  {
   const double h1 = iHigh(_Symbol, _Period, 1);             // perf-allowed: bespoke VWAP typical price
   const double l1 = iLow(_Symbol, _Period, 1);              // perf-allowed: bespoke VWAP typical price
   const double c1 = iClose(_Symbol, _Period, 1);            // perf-allowed: bespoke VWAP typical price
   const double v1 = (double)iVolume(_Symbol, _Period, 1);   // perf-allowed: bespoke VWAP volume weight
   const datetime bt = iTime(_Symbol, _Period, 1);           // perf-allowed: bespoke VWAP session reset
   if(h1 <= 0.0 || l1 <= 0.0 || c1 <= 0.0 || bt <= 0)
      return;

   const datetime day = (datetime)(bt - (bt % 86400));
   if(day != g_vwap_day)
     {
      g_vwap_day     = day;
      g_vwap_cum_pv  = 0.0;
      g_vwap_cum_vol = 0.0;
     }

   const double typical = (h1 + l1 + c1) / 3.0;
   g_vwap_cum_pv  += typical * v1;
   g_vwap_cum_vol += v1;
   g_vwap = (g_vwap_cum_vol > 0.0) ? (g_vwap_cum_pv / g_vwap_cum_vol) : c1;
  }

// Kaufman Efficiency Ratio over `length` closed bars (ending at shift=1).
double ComputeER(const int length)
  {
   if(length < 1)
      return 0.0;
   const double c_now = iClose(_Symbol, _Period, 1);          // perf-allowed: bespoke efficiency ratio
   const double c_old = iClose(_Symbol, _Period, 1 + length); // perf-allowed: bespoke efficiency ratio
   if(c_now <= 0.0 || c_old <= 0.0)
      return 0.0;

   const double direction = MathAbs(c_now - c_old);
   double volatility = 0.0;
   for(int i = 1; i <= length; ++i)
     {
      const double a = iClose(_Symbol, _Period, i);     // perf-allowed: bespoke efficiency ratio
      const double b = iClose(_Symbol, _Period, i + 1); // perf-allowed: bespoke efficiency ratio
      if(a <= 0.0 || b <= 0.0)
         return 0.0;
      volatility += MathAbs(a - b);
     }
   if(volatility <= 0.0)
      return 0.0;
   return direction / volatility;
  }

// Classify the regime on the last closed bar: trending requires ER >= threshold
// PLUS full VWAP/MA directional alignment.
int ClassifyRegime(const double er, const double fast, const double slow, const double close1)
  {
   if(g_vwap <= 0.0 || er < er_trend_threshold)
      return 0;
   if(fast > slow && fast > g_vwap && slow > g_vwap && close1 > g_vwap)
      return +1;
   if(fast < slow && fast < g_vwap && slow < g_vwap && close1 < g_vwap)
      return -1;
   return 0;
  }

// =============================================================================
// SECTION: Trade Entry
// =============================================================================
// Called once per closed bar (OnTick guarantees QM_IsNewBar() == true). Fires on
// the FIRST candle that transitions from non-trending into a fully-aligned
// trend, with the card's "Full Filter" candle confirmations.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Advance bespoke per-bar state first (VWAP), then regime.
   AdvanceState_OnNewBar();

   const double fast1 = QM_EMA(_Symbol, _Period, fast_ma_period, 1);
   const double slow1 = QM_EMA(_Symbol, _Period, slow_ma_period, 1);
   const double fast2 = QM_EMA(_Symbol, _Period, fast_ma_period, 2);
   const double slow2 = QM_EMA(_Symbol, _Period, slow_ma_period, 2);
   const double atr   = QM_ATR(_Symbol, _Period, strat_atr_period, 1);
   const double er    = ComputeER(er_length);
   const double close1 = iClose(_Symbol, _Period, 1);  // perf-allowed: bespoke regime/candle close
   const double open1  = iOpen(_Symbol, _Period, 1);   // perf-allowed: bespoke candle body size
   const double high2  = iHigh(_Symbol, _Period, 2);   // perf-allowed: bespoke breakout confirmation
   const double low2   = iLow(_Symbol, _Period, 2);    // perf-allowed: bespoke breakout confirmation

   g_prev_regime = g_regime;
   g_regime      = ClassifyRegime(er, fast1, slow1, close1);

   if(atr <= 0.0 || g_vwap <= 0.0 || close1 <= 0.0 || open1 <= 0.0)
      return false;

   // No new entries once the EOD flatten window has begun.
   if(IsAfterEodFlat(TimeCurrent()))
      return false;

   // Signal-candle body must clear the minimum-size threshold.
   if(MathAbs(close1 - open1) < min_body_atr_frac * atr)
      return false;

   const double stop_dist = atr * atr_sl_mult;
   const double tp_dist   = atr * atr_tp_mult;
   if(stop_dist <= 0.0 || tp_dist <= 0.0)
      return false;

   // V5 spread guard: skip if spread > 15% of stop distance.
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;
   if((ask - bid) > spread_guard_frac * stop_dist)
      return false;

   req.price              = 0.0;   // market order
   req.sl                 = 0.0;
   req.tp                 = 0.0;
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   // LONG: non-trend -> uptrend transition + Full Filter confirmations.
   if(g_regime == +1 && g_prev_regime != +1 &&
      fast2 > slow2 &&                    // prior-bar MA alignment confirmed
      fast1 > fast2 && slow1 > slow2 &&   // both MAs sloping up
      close1 > high2)                     // close beyond prior-bar high
     {
      req.type   = QM_BUY;
      req.sl     = ask - stop_dist;
      req.tp     = ask + tp_dist;
      req.reason = "XIZNIT_ER_LONG";
      return true;
     }

   // SHORT: non-trend -> downtrend transition + Full Filter confirmations.
   if(g_regime == -1 && g_prev_regime != -1 &&
      fast2 < slow2 &&
      fast1 < fast2 && slow1 < slow2 &&
      close1 < low2)
     {
      req.type   = QM_SELL;
      req.sl     = bid + stop_dist;
      req.tp     = bid - tp_dist;
      req.reason = "XIZNIT_ER_SHORT";
      return true;
     }

   return false;
  }

// =============================================================================
// SECTION: Trade Management
// =============================================================================
// Card disables breakeven/trailing for the P2 baseline (tested in P3). The fixed
// ATR bracket is attached at entry; nothing to adjust per tick.
void Strategy_ManageOpenPosition()
  {
   // intentionally empty — P2 baseline runs the static bracket only.
  }

// =============================================================================
// SECTION: Trade Close
// =============================================================================
// Per-tick discretionary close. Returns TRUE to flatten our position(s) when the
// ER regime shifts away from the trade direction, or at the EOD flatten time.
// Reads cached regime only (advanced once per closed bar) — O(1) per tick.
bool Strategy_ExitSignal()
  {
   if(IsAfterEodFlat(TimeCurrent()))
      return true;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE pt = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(pt == POSITION_TYPE_BUY  && g_regime != +1)
         return true;
      if(pt == POSITION_TYPE_SELL && g_regime != -1)
         return true;
     }
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_10856_tv_xiznit_er\",\"card\":\"QM5_10856\"}");
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

   // Per-tick: discretionary exit (regime shift / EOD flat). Separate from SL/TP.
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

   // Per-closed-bar: entry-signal evaluation.
   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled.
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
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
