#property strict
#property version   "5.0"
#property description "QM5_11241 ht-coint-spread — Engle-Granger cointegration spread z-score pairs trade (D1, two-leg basket)"

#include <QM/QM_Common.mqh>
#include <QM/QM_Indicators.mqh>
#include <QM/QM_BasketOrder.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11241 ht-coint-spread
// -----------------------------------------------------------------------------
// Source: Hudson & Thames, "Mean Reversion", Arbitrage Research notebook
// (source_id af021dd0-e07d-5f72-9933-de7a3533934e); primary reference Ernest P.
// Chan, "Algorithmic Trading: Winning Strategies and Their Rationale".
// Card: artifacts/cards_approved/QM5_11241_ht-coint-spread.md (g0 APPROVED).
//
// COINTEGRATION RELATIVE-VALUE PAIRS TRADE (BASKET EA). On each completed D1 bar
// the EA fits a static Engle-Granger hedge ratio by rolling OLS of the host close
// on the partner close over a FORMATION window (`formation_bars` D1 bars), forms
// the spread, then standardises the spread over a SHORTER rolling z-window
// (`z_window` D1 bars) into a z-score. The spread is traded market-neutrally as a
// two-leg basket:
//
//   z >= +entry_z  -> spread rich  -> SHORT spread: SELL host (leg1) + BUY partner (leg2)
//   z <= -entry_z  -> spread cheap  -> LONG  spread: BUY  host (leg1) + SELL partner (leg2)
//
// Exit (card mean-reversion band): close the pair when |z| <= `exit_z`. Safety
// z-stop when |z| >= `stop_z` after entry. Time stop after min(3 * half_life, 90)
// D1 bars, where half_life is derived deterministically from a bounded AR(1) fit
// of the spread (no ML, no library). All legs close together.
//
// COINTEGRATION QUALIFICATION (card formation filter, fully deterministic):
//   - spread std over the formation window must be > 0 (else degenerate),
//   - AR(1) mean-reversion speed must be NEGATIVE (lambda < 0 => reverting),
//   - half_life must lie inside [min_half_life, max_half_life].
// We do NOT run a p-value ADF table at run time (no stats library in MQL5); the
// card's ADF p<=adf_p_max intent is approximated by the bounded mean-reversion
// (lambda<0) + half-life window gate, which is the deterministic core of the
// Engle-Granger / Chan half-life test. No external feed, no ML.
//
// BASKET WIRING. The host leg trades `_Symbol` via the framework magic
// (slot = qm_magic_slot_offset). The partner leg trades a FOREIGN .DWX symbol via
// QM_BasketOpenPosition at its own registered symbol_slot. Both legs are warmed in
// OnInit so foreign-symbol reads return real data in the .DWX tester. One position
// per (magic, symbol).
//
// Pair model (host = leg1, partner = leg2), to register in magic_numbers.csv:
//   slot 0 EURUSD.DWX (host A) / slot 1 GBPUSD.DWX (partner A)
//   slot 2 AUDUSD.DWX (host B) / slot 3 NZDUSD.DWX (partner B)
//   slot 4 XAUUSD.DWX (host C) / slot 5 XAGUSD.DWX (partner C)
// All six legs are REAL .DWX symbols present in dwx_symbol_matrix.csv — no port
// needed. A setfile selects WHICH pair an instance runs by binding:
//   qm_magic_slot_offset    = host leg slot (matches the host symbol it runs on)
//   strategy_partner_symbol = the partner .DWX symbol
//   strategy_partner_slot   = the partner leg slot
// (default = pair A on EURUSD.DWX host / GBPUSD.DWX partner).
//
// Only the five Strategy_* hooks + OnInit basket wiring are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11241;
input int    qm_magic_slot_offset       = 0;     // HOST leg slot (= host symbol slot)
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
// Partner (leg2) symbol + its registered magic slot. The host leg is _Symbol at
// qm_magic_slot_offset. Defaults bind pair A: EURUSD.DWX host / GBPUSD.DWX.
input string strategy_partner_symbol    = "GBPUSD.DWX";  // foreign .DWX leg2
input int    strategy_partner_slot      = 1;             // partner registered slot
input int    strategy_formation_bars    = 504;   // OLS hedge-ratio formation window (P3 {252,504,756})
input int    strategy_z_window          = 60;    // rolling spread mean/std z-score lookback
input double strategy_entry_z           = 2.0;   // |z| entry threshold (P3 {1.5,2.0,2.5})
input double strategy_exit_z            = 0.25;  // |z| mean-band exit threshold (P3 {0.0,0.25,0.5})
input double strategy_stop_z            = 4.0;   // |z| safety stop threshold
input double strategy_adf_p_max         = 0.10;  // documented card param (qualification proxy, see notes)
input int    strategy_min_half_life     = 2;     // min half-life (D1 bars) for cointegration qualification
input int    strategy_max_half_life     = 60;    // max half-life (D1 bars) (P3 {20,40,60})
input int    strategy_time_stop_cap     = 90;    // hard cap on the 3*half_life time stop (D1 bars)
input int    strategy_min_d1_bars       = 560;   // need >= formation_bars + buffer synced D1 bars
input double strategy_leg_risk_split    = 0.5;   // documentary share of RISK_FIXED per leg

// -----------------------------------------------------------------------------
// File-scope cached pair state, advanced once per closed D1 bar.
// -----------------------------------------------------------------------------
string   g_partner          = "";     // resolved partner symbol (leg2)
double   g_z_curr           = 0.0;    // last closed-bar spread z-score
bool     g_z_ready          = false;  // both legs synced + spread well-formed
bool     g_coint_ok         = false;  // cointegration qualification (lambda<0, HL in band)
int      g_time_stop_bars   = 0;      // min(3*half_life, cap), latched per qualification

// -----------------------------------------------------------------------------
// Cointegration spread + z-score over the formation/z windows on CLOSED D1 bars.
// Fits hedge ratio host = a + b*partner by OLS over `formation` bars, forms the
// spread series, standardises the LAST bar over the trailing `z_window` bars, and
// derives a deterministic AR(1) half-life over the formation window for the
// cointegration gate + time stop. Returns false on missing / degenerate data so
// the EA simply does not trade (card "skip if unstable / std==0 / missing bars").
// -----------------------------------------------------------------------------
bool QM_ComputeCointSpread(const int formation, const int zwin,
                           double &z_last, bool &coint_ok, int &time_stop_bars)
  {
   z_last         = 0.0;
   coint_ok       = false;
   time_stop_bars = 0;
   if(formation < 30 || zwin < 5 || zwin > formation)
      return false;

   // Need `formation` closed bars (shift 1..formation) on BOTH legs.
   if(Bars(_Symbol,  PERIOD_D1) < strategy_min_d1_bars) return false;   // perf-allowed: bar-count availability check
   if(Bars(g_partner, PERIOD_D1) < strategy_min_d1_bars) return false;  // perf-allowed: partner-leg bar-count check

   const int n = formation;             // bars 1..n, index 0 = shift 1 (last closed)
   double h[];   // host close,    index 0 = last closed (shift 1)
   double p[];   // partner close, index 0 = last closed (shift 1)
   ArrayResize(h, n);
   ArrayResize(p, n);
   for(int i = 0; i < n; ++i)
     {
      // perf-allowed: closed-bar foreign+host close reads for the formation window;
      // computed once per closed D1 bar (OnTick gates this via QM_IsNewBar).
      const double ch = iClose(_Symbol,   PERIOD_D1, i + 1);   // perf-allowed: closed-bar host close for formation window
      const double cp = iClose(g_partner, PERIOD_D1, i + 1);   // perf-allowed: closed-bar partner close for formation window
      if(ch <= 0.0 || cp <= 0.0)
         return false;                  // missing bar inside lookback -> no trade
      h[i] = ch;
      p[i] = cp;
     }

   // OLS hedge ratio over the full formation window: host = a + b*partner.
   double sx = 0.0, sy = 0.0, sxx = 0.0, sxy = 0.0;
   const double dn = (double)n;
   for(int i = 0; i < n; ++i)
     {
      sx  += p[i];
      sy  += h[i];
      sxx += p[i] * p[i];
      sxy += p[i] * h[i];
     }
   const double den = dn * sxx - sx * sx;
   if(MathAbs(den) < 1e-12)
      return false;                     // degenerate regressor -> no trade
   const double slope     = (dn * sxy - sx * sy) / den;
   const double intercept = (sy - slope * sx) / dn;

   // Spread series over the formation window: spread[i] = host - (a + b*partner).
   // index 0 = last closed bar; higher index = older.
   double spread[];
   ArrayResize(spread, n);
   for(int i = 0; i < n; ++i)
      spread[i] = h[i] - (intercept + slope * p[i]);

   // --- z-score of the last closed bar over the trailing z-window -----------
   // The z-window are the most-recent `zwin` spread values: indices 0..zwin-1.
   double zmean = 0.0;
   for(int i = 0; i < zwin; ++i)
      zmean += spread[i];
   zmean /= (double)zwin;
   double zvar = 0.0;
   for(int i = 0; i < zwin; ++i)
     {
      const double d = spread[i] - zmean;
      zvar += d * d;
     }
   zvar /= (double)zwin;
   const double zstd = MathSqrt(zvar);
   if(zstd <= 1e-12)
      return false;                     // zero spread std -> no trade (card rule)
   z_last = (spread[0] - zmean) / zstd;

   // --- deterministic AR(1) half-life over the formation window -------------
   // Regress dS_t = lambda * S_{t-1} + c.  Mean-reversion speed = lambda; for a
   // reverting spread lambda < 0 and half_life = -ln(2)/lambda.  spread index 0 is
   // the newest bar, so S_{t-1} = spread[i+1], dS_t = spread[i]-spread[i+1].
   double ax = 0.0, ay = 0.0, axx = 0.0, axy = 0.0;
   const int m = n - 1;                 // number of (lag, delta) pairs
   for(int i = 0; i < m; ++i)
     {
      const double s_prev = spread[i + 1];
      const double ds     = spread[i] - spread[i + 1];
      ax  += s_prev;
      ay  += ds;
      axx += s_prev * s_prev;
      axy += s_prev * ds;
     }
   const double dm   = (double)m;
   const double aden = dm * axx - ax * ax;
   if(MathAbs(aden) < 1e-12)
      return true;                      // z valid but HL undefined -> z_ready, coint_ok=false
   const double lambda = (dm * axy - ax * ay) / aden;

   if(lambda < 0.0)                     // negative => mean-reverting spread
     {
      const double half_life = -MathLog(2.0) / lambda;
      if(half_life >= (double)strategy_min_half_life &&
         half_life <= (double)strategy_max_half_life)
        {
         coint_ok = true;
         int ts = (int)MathRound(3.0 * half_life);
         if(ts < 1) ts = 1;
         if(ts > strategy_time_stop_cap) ts = strategy_time_stop_cap;
         time_stop_bars = ts;
        }
     }
   return true;
  }

// Advance cached cointegration state once per closed D1 bar.
void QM_AdvanceCointState()
  {
   double zl = 0.0;
   bool   ok = false;
   int    ts = 0;
   if(QM_ComputeCointSpread(strategy_formation_bars, strategy_z_window, zl, ok, ts))
     {
      g_z_curr        = zl;
      g_coint_ok      = ok;
      g_time_stop_bars = ts;
      g_z_ready       = true;
     }
   else
     {
      g_z_ready  = false;
      g_coint_ok = false;
     }
  }

// Count open positions for an arbitrary (slot,symbol) leg of THIS ea_id.
int QM_LegOpenCount(const int slot, const string sym)
  {
   const int magic = QM_Magic(qm_ea_id, slot);
   if(magic <= 0)
      return 0;
   int c = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != sym)
         continue;
      ++c;
     }
   return c;
  }

// True if EITHER leg of the pair currently holds a position.
bool QM_PairHasPosition()
  {
   if(QM_LegOpenCount(qm_magic_slot_offset, _Symbol) > 0)
      return true;
   if(QM_LegOpenCount(strategy_partner_slot, g_partner) > 0)
      return true;
   return false;
  }

// Direction of the open HOST leg: +1 host long (long-spread), -1 host short
// (short-spread), 0 none.
int QM_HostLegDir()
  {
   const int magic = QM_Magic(qm_ea_id, qm_magic_slot_offset);
   if(magic <= 0)
      return 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      return (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? +1 : -1;
     }
   return 0;
  }

// Bars held by the host leg (D1), or -1 if no host position.
int QM_HostLegBarsHeld()
  {
   const int magic = QM_Magic(qm_ea_id, qm_magic_slot_offset);
   if(magic <= 0)
      return -1;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      // perf-allowed: single bar-open time read for the time-stop bar count.
      const datetime cur_bar = iTime(_Symbol, PERIOD_D1, 0);   // perf-allowed: bar-open time for time-stop count
      if(open_time <= 0 || cur_bar <= 0)
         return 0;
      return Bars(_Symbol, PERIOD_D1, open_time, cur_bar) - 1;  // perf-allowed: bars-held count for time stop
     }
   return -1;
  }

// Open the partner (leg2) market order on the FOREIGN symbol via the basket path.
bool QM_OpenPartnerLeg(const QM_OrderType ot, const string reason)
  {
   QM_BasketOrderRequest br;
   br.symbol             = g_partner;
   br.type               = ot;
   br.price              = 0.0;     // basket path fills market price at send
   br.sl                 = 0.0;     // pair-level exits manage the position
   br.tp                 = 0.0;
   br.lots               = 0.0;     // 0 -> basket sizes via QM_LotsForRisk(partner, sl_pts)
   br.reason             = reason;
   br.symbol_slot        = strategy_partner_slot;
   br.expiration_seconds = 0;

   ulong tk = 0;
   return QM_BasketOpenPosition(qm_ea_id, qm_news_mode_legacy, 20, br, tk);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick filter. Fail-open spread guard on the host leg only; the
// pair logic runs on closed bars. No session restriction (D1 pairs).
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;                     // no valid quote — defer, never block
   const double atr = QM_ATR(_Symbol, PERIOD_D1, 14, 1);
   if(atr <= 0.0)
      return false;
   const double spread = ask - bid;
   if(spread > 0.0 && spread > 0.50 * atr)   // >50% of D1 ATR = pathological
      return true;
   return false;
  }

// Entry on a freshly closed D1 bar. Host leg opened via the framework path; the
// partner leg opened first via the basket path so both legs go on together.
// Caller guarantees QM_IsNewBar()==true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One pair state at a time: skip if either leg already open.
   if(QM_PairHasPosition())
      return false;
   if(!g_z_ready || !g_coint_ok)         // require cointegration qualification
      return false;

   const double zc = g_z_curr;
   int dir = 0;                          // +1 long-spread, -1 short-spread
   if(zc >= strategy_entry_z)
      dir = -1;                          // spread rich -> SHORT spread
   else if(zc <= -strategy_entry_z)
      dir = +1;                          // spread cheap -> LONG spread
   if(dir == 0)
      return false;

   // Host (leg1): long-spread -> BUY host; short-spread -> SELL host.
   const QM_OrderType host_ot    = (dir > 0) ? QM_BUY : QM_SELL;
   // Partner (leg2) takes the OPPOSITE side for market-neutral exposure.
   const QM_OrderType partner_ot = (dir > 0) ? QM_SELL : QM_BUY;

   // Open the partner leg FIRST. If it fails, abort so we never carry a naked leg.
   const string rsn = (dir > 0) ? "coint_long_spread" : "coint_short_spread";
   if(!QM_OpenPartnerLeg(partner_ot, rsn))
      return false;

   // Host leg for the framework. No fixed SL/TP — pair managed at basket level.
   req.type        = host_ot;
   req.price       = 0.0;                // framework fills market price at send
   req.sl          = 0.0;
   req.tp          = 0.0;
   req.reason      = rsn;
   req.symbol_slot = qm_magic_slot_offset;  // host leg slot
   return true;
  }

// No active per-position trade management; pair exits are rule-based.
void Strategy_ManageOpenPosition()
  {
  }

// Pair-level exits: mean-band (|z|<=exit_z), |z| safety stop, time stop.
// Returning true triggers the framework's host-leg close loop in OnTick; we ALSO
// close the partner leg here so the whole pair unwinds together.
bool Strategy_ExitSignal()
  {
   const int host_dir = QM_HostLegDir();   // +1 long-spread, -1 short-spread, 0 none
   if(host_dir == 0)
      return false;

   bool do_exit = false;
   QM_ExitReason reason = QM_EXIT_STRATEGY;

   if(g_z_ready)
     {
      const double az = MathAbs(g_z_curr);
      // Mean-reversion band: close when the spread has reverted to its mean.
      if(az <= strategy_exit_z)
        { do_exit = true; reason = QM_EXIT_STRATEGY; }
      // Safety z-stop: |z| expanded beyond the stop band.
      if(!do_exit && az >= strategy_stop_z)
        { do_exit = true; reason = QM_EXIT_STRATEGY; }
     }

   // Time stop: close the pair after the qualification-derived bar budget.
   if(!do_exit)
     {
      const int budget = (g_time_stop_bars > 0) ? g_time_stop_bars : strategy_time_stop_cap;
      const int held = QM_HostLegBarsHeld();
      if(held >= 0 && held >= budget)
        { do_exit = true; reason = QM_EXIT_TIME_STOP; }
     }

   if(do_exit)
     {
      // Close the PARTNER leg here; the OnTick close loop closes the host leg.
      const int partner_magic = QM_Magic(qm_ea_id, strategy_partner_slot);
      if(partner_magic > 0)
        {
         for(int i = PositionsTotal() - 1; i >= 0; --i)
           {
            const ulong ticket = PositionGetTicket(i);
            if(!PositionSelectByTicket(ticket))
               continue;
            if(PositionGetInteger(POSITION_MAGIC) != partner_magic)
               continue;
            QM_TM_ClosePosition(ticket, reason);
           }
        }
      return true;
     }
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

   // Resolve the partner leg. If blank or equal to the host, the pair is
   // degenerate and the EA simply never trades (still a valid, safe init).
   g_partner = strategy_partner_symbol;
   if(StringLen(g_partner) == 0)
      g_partner = _Symbol;

   // BASKET wiring: register host + partner and warm their D1 history so the
   // foreign-symbol close reads return real data in the .DWX tester.
   string universe[];
   if(g_partner == _Symbol)
     {
      ArrayResize(universe, 1);
      universe[0] = _Symbol;
     }
   else
     {
      ArrayResize(universe, 2);
      universe[0] = _Symbol;
      universe[1] = g_partner;
     }
   QM_SymbolGuardInit(universe);
   QM_BasketWarmupHistory(universe, PERIOD_D1, strategy_formation_bars + 60);

   QM_LogEvent(QM_INFO, "INIT_OK",
               StringFormat("{\"host\":\"%s\",\"partner\":\"%s\",\"host_slot\":%d,\"partner_slot\":%d,\"formation\":%d,\"z_window\":%d}",
                            _Symbol, g_partner, qm_magic_slot_offset,
                            strategy_partner_slot, strategy_formation_bars, strategy_z_window));
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

   // Latch the closed-bar event ONCE (single-consume) and reuse it. On a fresh D1
   // bar refresh the cointegration/z state BEFORE the rule-based exit so the exit
   // sees the current z.
   const bool nb = QM_IsNewBar();
   if(nb)
      QM_AdvanceCointState();

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

   if(!nb)
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
