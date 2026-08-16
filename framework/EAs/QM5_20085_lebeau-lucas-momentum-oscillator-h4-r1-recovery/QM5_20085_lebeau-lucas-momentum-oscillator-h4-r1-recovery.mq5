#property strict
#property version   "5.0"
#property description "QuantMechanica V5 EA — QM5_20085 lebeau-lucas-momentum-oscillator-h4-r1-recovery"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_20085 lebeau-lucas-momentum-oscillator-h4-r1-recovery
// -----------------------------------------------------------------------------
// LeBeau & Lucas (1992) smoothed momentum oscillator (LLMO) on H4 with a D1
// regime overlay. LLMO(t) = SMA(ROC_12, 8) where ROC_12 is the classic
// rate-of-change. Zero-line crossovers of LLMO, gated by an EMA(21,H4) price
// trend + an EMA(50,D1) macro regime + a momentum-expansion check, produce
// entries:
//   Long  : LLMO crosses UP through 0, close>EMA21(H4), D1 close>EMA50(D1),
//           LLMO expanding (llmo[0]>llmo[1]).
//   Short : mirror.
// Exits (all in Strategy_ManageOpenPosition): time-stop 20 H4 bars, opposite
// LLMO zero-cross full close, and a Chandelier-style ATR trail that arms only
// after price has moved 1.5*ATR(20) in favour (QM_TM_TrailATR ratchets the SL
// from the running extreme). Initial protective SL = 2.5*ATR(20,H4).
//
// LLMO derivation (documented, not invented): MT5's native momentum indicator,
// wrapped by QM_Momentum, returns Close[shift]/Close[shift+period]*100. Classic
// ROC is QM_Momentum(...) - 100. Because SMA is linear,
//   LLMO(shift) = mean_{i=0..7}( QM_Momentum(sym,PERIOD_CURRENT,12,shift+i) ) - 100.
// LLMO() is only ever called from the QM_IsNewBar-gated entry path and from the
// per-position management pass — never per-tick outside a new-bar gate.
//
// Only QM_* helpers used for indicators / bar reads / stops / trade management.
// Framework wiring below the marker line is untouched.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 20085;
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
input int    roc_period                 = 12;    // ROC lookback for the momentum oscillator
input int    llmo_smooth                = 8;     // SMA smoothing window applied to ROC
input int    ema_trend_period           = 21;    // H4 price trend filter EMA period
input int    d1_regime_ema_period       = 50;    // D1 macro-regime EMA period
input int    atr_period                 = 20;    // ATR period for stops / trail
input double sl_atr_mult                = 2.5;   // initial protective SL = mult * ATR
input double trail_atr_mult             = 2.0;   // Chandelier trail distance = mult * ATR
input double trail_activate_atr_mult    = 1.5;   // arm trail after this * ATR of favourable move
input int    time_stop_bars             = 20;    // max hold in H4 bars before flat-exit
input double spread_atr_mult_cap        = 0.35;  // skip entry if spread > cap * ATR

// File-scope strategy state.
datetime g_position_entry_time = 0;

// LeBeau-Lucas Momentum Oscillator at a given bar shift:
//   LLMO(shift) = mean_{i=0..llmo_smooth-1}( QM_Momentum(...,roc_period,shift+i) ) - 100
// (see derivation in the file header). Costs llmo_smooth QM_Momentum reads;
// only called from new-bar-gated paths.
double LLMO(const string sym, const int shift)
  {
   if(llmo_smooth <= 0)
      return 0.0;
   double sum = 0.0;
   for(int i = 0; i < llmo_smooth; ++i)
      sum += QM_Momentum(sym, PERIOD_CURRENT, roc_period, shift + i);
   return (sum / llmo_smooth) - 100.0;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.symbol_slot = qm_magic_slot_offset;

   // 1. Oscillator reads on the two most recent closed H4 bars.
   const double llmo1 = LLMO(_Symbol, 1);   // current closed bar ("LLMO[0]")
   const double llmo2 = LLMO(_Symbol, 2);   // prior closed bar   ("LLMO[1]")

   // 2. H4 trend/vol context on the last closed bar.
   MqlRates c1;
   if(!QM_ReadBar(_Symbol, PERIOD_CURRENT, 1, c1))
      return false;
   const double ema21_1 = QM_EMA(_Symbol, PERIOD_CURRENT, ema_trend_period, 1);
   const double atr20_1 = QM_ATR(_Symbol, PERIOD_CURRENT, atr_period, 1);

   // 3. D1 macro-regime context on the last closed D1 bar.
   MqlRates d1c1;
   if(!QM_ReadBar(_Symbol, PERIOD_D1, 1, d1c1))
      return false;
   const double d1ema50_1 = QM_EMA(_Symbol, PERIOD_D1, d1_regime_ema_period, 1);

   // 4. Warm-up guard.
   if(ema21_1 <= 0.0 || atr20_1 <= 0.0 || d1ema50_1 <= 0.0)
      return false;

   // 5. Spread filter (do NOT fail-closed on zero spread — .DWX quotes 0 in tester).
   const double spread = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(spread > 0.0 && spread > spread_atr_mult_cap * atr20_1)
      return false;

   // 6. Zero-line crossovers.
   const bool cross_up   = (llmo2 < 0.0 && llmo1 > 0.0);
   const bool cross_down = (llmo2 > 0.0 && llmo1 < 0.0);

   // 7/8. Direction gates: cross + H4 trend + D1 regime + momentum expansion.
   const bool long_ok  = cross_up   && c1.close > ema21_1   && d1c1.close > d1ema50_1 && llmo1 > llmo2;
   const bool short_ok = cross_down && c1.close < ema21_1   && d1c1.close < d1ema50_1 && llmo1 < llmo2;

   // 9. Long entry.
   if(long_ok)
     {
      req.type   = QM_BUY;
      req.price  = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      req.sl     = QM_StopATR(_Symbol, QM_BUY, req.price, atr_period, sl_atr_mult);
      req.tp     = 0.0;
      req.reason = "llmo_zero_cross_long";
      g_position_entry_time = c1.time;
      return true;
     }

   // 10. Short entry (mirror).
   if(short_ok)
     {
      req.type   = QM_SELL;
      req.price  = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      req.sl     = QM_StopATR(_Symbol, QM_SELL, req.price, atr_period, sl_atr_mult);
      req.tp     = 0.0;
      req.reason = "llmo_zero_cross_short";
      g_position_entry_time = c1.time;
      return true;
     }

   // 11. No signal.
   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// LeBeau-Lucas exits: time-stop, opposite LLMO zero-cross, Chandelier ATR trail.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   const int bars_since_entry = (g_position_entry_time > 0)
                                ? iBarShift(_Symbol, PERIOD_CURRENT, g_position_entry_time, false) // perf-allowed structural bar-index lookup
                                : 0;
   const double llmo1   = LLMO(_Symbol, 1);
   const double llmo2   = LLMO(_Symbol, 2);
   const double atr20_1 = QM_ATR(_Symbol, PERIOD_CURRENT, atr_period, 1);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const bool is_buy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);

      // Time-stop.
      if(bars_since_entry >= time_stop_bars)
        {
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
         continue;
        }

      // Opposite LLMO zero-cross full exit.
      if(is_buy && (llmo2 > 0.0 && llmo1 < 0.0))
        {
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
         continue;
        }
      if(!is_buy && (llmo2 < 0.0 && llmo1 > 0.0))
        {
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
         continue;
        }

      // Chandelier-style ATR trail — arm only after price has moved
      // trail_activate_atr_mult * ATR in favour. QM_TM_TrailATR only ever
      // ratchets the SL favourably, i.e. trails from the running extreme.
      if(atr20_1 > 0.0)
        {
         const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
         if(is_buy)
           {
            const double profit_dist = SymbolInfoDouble(_Symbol, SYMBOL_BID) - open_price;
            if(profit_dist >= trail_activate_atr_mult * atr20_1)
               QM_TM_TrailATR(ticket, atr_period, trail_atr_mult);
           }
         else
           {
            const double profit_dist = open_price - SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            if(profit_dist >= trail_activate_atr_mult * atr20_1)
               QM_TM_TrailATR(ticket, atr_period, trail_atr_mult);
           }
        }
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   // All exits handled in Strategy_ManageOpenPosition (HR14 one-pos-per-magic).
   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // framework's own 2-axis news gate already applies
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
   // Q08 evidence lifecycle: sample floating P&L before any per-tick guard can
   // return. QM_KillSwitchCheck retains the same call as a compatibility
   // fallback for pre-template EAs; keep this explicit hook in all new builds.
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // Per-tick: trade management can adjust SL/TP on open positions.
   // Management, rule-based exits and the Friday sweep above MUST keep
   // running through news windows — the news gate below blocks NEW entries
   // only (2026-07-02 audit rule; canonical order per QM5_12821 OnTick,
   // commit dc418a720).
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
   // FW1 — 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults. Gates NEW entries only —
   // never the management/exit paths above.
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req); // symbol_slot=0 (host slot) + expiration=0 defaults; garbage
                    // in unset fields = the silent-zero-trades class (9e4cfedb1)
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
