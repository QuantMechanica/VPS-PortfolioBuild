#property strict
#property version   "5.0"
#property description "QM5_11145 vbt-pair-z — Rolling-OLS spread z-score pairs trade (D1, two-leg basket)"

#include <QM/QM_Common.mqh>
#include <QM/QM_Indicators.mqh>
#include <QM/QM_BasketOrder.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11145 vbt-pair-z
// -----------------------------------------------------------------------------
// Source: Oleg Polakow / vectorbt `examples/PairsTrading.ipynb` (source_id
// 3f3833d9-8676-52e4-a822-2c5fc87bbe20), adapted from the Backtrader pair-trading
// sample. Card: artifacts/cards_approved/QM5_11145_vbt-pair-z.md (g0 APPROVED).
//
// RELATIVE-VALUE PAIRS TRADE (BASKET EA). On each completed D1 bar the EA fits a
// rolling OLS of log(host) on log(partner) over `Period` bars, forms the spread
// and its z-score, and trades the SPREAD as a market-neutral two-leg position:
//
//   z > +Upper  -> spread rich -> SHORT spread: SELL host (leg1) + BUY partner (leg2)
//   z < -Lower  -> spread cheap -> LONG  spread: BUY  host (leg1) + SELL partner (leg2)
//
// Exit (mean-reversion baseline): close the pair when z crosses back through 0
// (short-spread closes when z<=0, long-spread closes when z>=0). Safety z-stop
// when |z| expands beyond `SafetyZ` after entry; time stop after `TimeStopBars`
// D1 bars. All legs of the pair are closed together.
//
// BASKET WIRING. The host leg trades `_Symbol` through the standard framework
// magic (slot = qm_magic_slot_offset). The partner leg trades a FOREIGN .DWX
// symbol via QM_BasketOpenPosition with its own registered symbol_slot. The
// partner's bars are read for the spread; both legs are warmed in OnInit so the
// foreign-symbol reads return real data in the .DWX tester. One position per
// (magic, symbol): the host magic holds at most one host-leg position, the
// partner magic at most one partner-leg position.
//
// Pair model (host = leg1, partner = leg2), registered in magic_numbers.csv:
//   slot 0 EURUSD.DWX (host A) / slot 1 GBPUSD.DWX (partner A)
//   slot 2 AUDUSD.DWX (host B) / slot 3 NZDUSD.DWX (partner B)
//   slot 4 GDAXI.DWX  (host C) / slot 5 NDX.DWX    (partner C)
// The card named GER40.DWX for the index pair; GER40 is NOT in
// dwx_symbol_matrix.csv — the DAX-40 .DWX symbol is GDAXI.DWX, so the index
// pair is ported to GDAXI.DWX/NDX.DWX (flagged in build output + SPEC).
//
// A setfile selects WHICH pair this instance runs by binding:
//   qm_magic_slot_offset  = host leg slot (matches the host symbol it runs on)
//   strategy_partner_symbol = the partner .DWX symbol
//   strategy_partner_slot   = the partner leg slot
// (default = pair A on EURUSD.DWX host).
//
// Only the five Strategy_* hooks + OnInit basket wiring are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11145;
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
// Partner (leg2) symbol + its registered magic slot. The host leg2 is _Symbol
// at qm_magic_slot_offset. Defaults bind pair A: EURUSD.DWX host / GBPUSD.DWX.
input string strategy_partner_symbol    = "GBPUSD.DWX";  // foreign .DWX leg2
input int    strategy_partner_slot      = 1;             // partner registered slot
input int    strategy_period            = 100;   // rolling OLS / z lookback (P3 {60,100,150})
input double strategy_z_upper           = 1.96;  // short-spread threshold (P3 {1.5,1.96,2.25})
input double strategy_z_lower           = 1.96;  // long-spread threshold magnitude (mirror)
input double strategy_safety_z          = 3.25;  // pair safety exit |z| (P3 {3.0,3.25,3.5})
input int    strategy_time_stop_bars    = 30;    // close pair after N D1 bars held
input int    strategy_min_d1_bars       = 160;   // need >= Period+buffer synced D1 bars
input double strategy_leg_risk_split    = 0.5;   // share of RISK_FIXED per leg (0.5 each)

// -----------------------------------------------------------------------------
// File-scope cached pair state, advanced once per closed D1 bar.
// -----------------------------------------------------------------------------
string   g_partner          = "";     // resolved partner symbol (leg2)
double   g_z_curr           = 0.0;    // last closed-bar spread z-score
double   g_z_prev           = 0.0;    // prior closed-bar spread z-score
bool     g_z_ready          = false;  // both legs had clean synced data
double   g_z_at_entry       = 0.0;    // |z| latched on entry (for safety expansion ref)

// -----------------------------------------------------------------------------
// Rolling-OLS spread z-score over the last `Period` CLOSED D1 bars.
// Fits log(host) = a + b*log(partner); spread = log(host) - (a + b*log(partner));
// z = (spread_last - mean(spread)) / std(spread). Returns false on missing /
// degenerate data (zero std, missing bars) so the EA simply does not trade —
// matching the card's "do not trade if std==0 or missing bars" rule.
// -----------------------------------------------------------------------------
bool QM_ComputePairZ(const int period, double &z_last, double &z_prev_out)
  {
   z_last     = 0.0;
   z_prev_out = 0.0;
   if(period < 5)
      return false;

   // Need period+1 closed bars (shift 1..period+1) on BOTH legs for spread + z
   // plus the prior-bar z. Read into local arrays once per closed bar (gated).
   const int n = period + 2;            // bars 1..n closed bars per leg
   if(Bars(_Symbol, PERIOD_D1)  < strategy_min_d1_bars) return false;   // perf-allowed: bar-count availability check
   if(Bars(g_partner, PERIOD_D1) < strategy_min_d1_bars) return false;  // perf-allowed: partner-leg bar-count check

   double lh[];   // log host close, index 0 = shift 1 (last closed), ... n-1 = shift n
   double lp[];   // log partner close
   ArrayResize(lh, n);
   ArrayResize(lp, n);
   for(int i = 0; i < n; ++i)
     {
      // perf-allowed: closed-bar foreign+host close reads for the OLS window;
      // computed once per closed D1 bar (OnTick gates this via QM_IsNewBar).
      const double ch = iClose(_Symbol,  PERIOD_D1, i + 1);   // perf-allowed: closed-bar host close for OLS window
      const double cp = iClose(g_partner, PERIOD_D1, i + 1);   // perf-allowed: closed-bar partner close for OLS window
      if(ch <= 0.0 || cp <= 0.0)
         return false;                  // missing bar inside lookback -> no trade
      lh[i] = MathLog(ch);
      lp[i] = MathLog(cp);
     }

   // Fit OLS slope/intercept over the `period` bars ending at the LAST closed
   // bar (indices 0..period-1). y = lh, x = lp.
   double sx = 0.0, sy = 0.0, sxx = 0.0, sxy = 0.0;
   for(int i = 0; i < period; ++i)
     {
      sx  += lp[i];
      sy  += lh[i];
      sxx += lp[i] * lp[i];
      sxy += lp[i] * lh[i];
     }
   const double dn  = (double)period;
   const double den = dn * sxx - sx * sx;
   if(MathAbs(den) < 1e-12)
      return false;                     // degenerate regressor -> no trade
   const double slope     = (dn * sxy - sx * sy) / den;
   const double intercept = (sy - slope * sx) / dn;

   // Spread series over the same window; mean + std for the z-score.
   double smean = 0.0;
   double spread[];
   ArrayResize(spread, period);
   for(int i = 0; i < period; ++i)
     {
      spread[i] = lh[i] - (intercept + slope * lp[i]);
      smean += spread[i];
     }
   smean /= dn;
   double svar = 0.0;
   for(int i = 0; i < period; ++i)
     {
      const double d = spread[i] - smean;
      svar += d * d;
     }
   svar /= dn;
   const double sstd = MathSqrt(svar);
   if(sstd <= 1e-12)
      return false;                     // zero spread std -> no trade (card rule)

   // z of the last closed bar (index 0).
   z_last = (spread[0] - smean) / sstd;

   // z of the prior closed bar (index 1) using the SAME fit window, so the
   // zero-cross / threshold-cross logic compares like with like.
   z_prev_out = (spread[1] - smean) / sstd;
   return true;
  }

// Advance cached z-score state once per closed D1 bar.
void QM_AdvancePairState()
  {
   double zl = 0.0, zp = 0.0;
   if(QM_ComputePairZ(strategy_period, zl, zp))
     {
      g_z_prev  = zp;
      g_z_curr  = zl;
      g_z_ready = true;
     }
   else
     {
      g_z_ready = false;
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

// Close every leg of the pair (host + partner) under this ea_id.
void QM_ClosePair(const QM_ExitReason reason)
  {
   const int host_magic    = QM_Magic(qm_ea_id, qm_magic_slot_offset);
   const int partner_magic = QM_Magic(qm_ea_id, strategy_partner_slot);
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      const long m = PositionGetInteger(POSITION_MAGIC);
      if(m == host_magic || m == partner_magic)
         QM_TM_ClosePosition(ticket, reason);
     }
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
// pair logic itself runs on closed bars. No session restriction (D1 pairs).
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;                     // no valid quote — defer, never block
   // Block only a genuinely wide modeled spread (zero modeled spread passes).
   const double atr = QM_ATR(_Symbol, PERIOD_D1, 14, 1);
   if(atr <= 0.0)
      return false;
   const double spread = ask - bid;
   if(spread > 0.0 && spread > 0.50 * atr)   // >50% of D1 ATR = pathological
      return true;
   return false;
  }

// Entry on a freshly closed D1 bar. The host leg is opened here through the
// framework path; the partner leg is opened immediately via the basket path so
// both legs go on together. Caller guarantees QM_IsNewBar()==true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One pair state at a time: skip if either leg already open.
   if(QM_PairHasPosition())
      return false;
   if(!g_z_ready)
      return false;

   const double zc = g_z_curr;
   int dir = 0;                         // +1 long-spread, -1 short-spread
   if(zc > strategy_z_upper)
      dir = -1;                         // spread rich -> SHORT spread
   else if(zc < -strategy_z_lower)
      dir = +1;                         // spread cheap -> LONG spread
   if(dir == 0)
      return false;

   // Host (leg1) direction: long-spread -> BUY host; short-spread -> SELL host.
   const QM_OrderType host_ot    = (dir > 0) ? QM_BUY : QM_SELL;
   // Partner (leg2) takes the OPPOSITE side for market-neutral exposure.
   const QM_OrderType partner_ot = (dir > 0) ? QM_SELL : QM_BUY;

   // Open the partner leg FIRST through the basket path. If it fails (e.g. data
   // gap), abort the pair so we never carry a naked single leg.
   const string rsn = (dir > 0) ? "pair_z_long_spread" : "pair_z_short_spread";
   if(!QM_OpenPartnerLeg(partner_ot, rsn))
      return false;

   // Build the host leg for the framework to send. No fixed SL/TP — the pair is
   // managed by the z-score / safety / time-stop exits at the basket level.
   req.type        = host_ot;
   req.price       = 0.0;               // framework fills market price at send
   req.sl          = 0.0;
   req.tp          = 0.0;
   req.reason      = rsn;
   req.symbol_slot = qm_magic_slot_offset;  // host leg slot

   g_z_at_entry = MathAbs(zc);          // latch entry |z| for safety reference
   return true;
  }

// No active per-position trade management; pair exits are rule-based.
void Strategy_ManageOpenPosition()
  {
  }

// Pair-level exits: mean-reversion zero-cross, |z| safety expansion, time stop.
// Returning true triggers the framework's host-leg close loop in OnTick; we
// ALSO close the partner leg here so the whole pair unwinds together.
bool Strategy_ExitSignal()
  {
   const int host_dir = QM_HostLegDir();   // +1 long-spread, -1 short-spread, 0 none
   if(host_dir == 0)
      return false;

   bool do_exit = false;
   QM_ExitReason reason = QM_EXIT_STRATEGY;

   if(g_z_ready)
     {
      const double zc = g_z_curr;
      // Mean-reversion: long-spread closes when z>=0, short-spread when z<=0.
      if(host_dir > 0 && zc >= 0.0) { do_exit = true; reason = QM_EXIT_STRATEGY; }
      if(host_dir < 0 && zc <= 0.0) { do_exit = true; reason = QM_EXIT_STRATEGY; }
      // Safety z-stop: |z| expanded beyond the safety band after entry.
      if(!do_exit && MathAbs(zc) >= strategy_safety_z)
        { do_exit = true; reason = QM_EXIT_STRATEGY; }
     }

   // Time stop: close the pair after N D1 bars held.
   if(!do_exit)
     {
      const int held = QM_HostLegBarsHeld();
      if(held >= 0 && held >= strategy_time_stop_bars)
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
      g_z_at_entry = 0.0;
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
   QM_BasketWarmupHistory(universe, PERIOD_D1, strategy_period + 60);

   QM_LogEvent(QM_INFO, "INIT_OK",
               StringFormat("{\"host\":\"%s\",\"partner\":\"%s\",\"host_slot\":%d,\"partner_slot\":%d,\"period\":%d}",
                            _Symbol, g_partner, qm_magic_slot_offset,
                            strategy_partner_slot, strategy_period));
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

   // Latch the closed-bar event ONCE (single-consume) and reuse it. On a fresh
   // D1 bar, refresh the pair z-score state BEFORE the rule-based exit so the
   // exit sees the current z.
   const bool nb = QM_IsNewBar();
   if(nb)
      QM_AdvancePairState();

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
