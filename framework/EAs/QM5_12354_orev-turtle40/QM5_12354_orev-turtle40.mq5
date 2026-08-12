#property strict
#property version   "5.0"
#property description "QM5_12354 Oreilm49 Turtle 40-Day Breakout (orev-turtle40)"
// Strategy Card: QM5_12354_orev-turtle40 (source 72f9fcfa-6c75-5544-80c4-31e15c9817ab).
// Ported from oreilm49/quantconnect TurleTrading/main.py — long-only D1 Donchian
// 40-day high breakout above SMA(150); exits on 20-day low break, SMA(150) break,
// or +20% / -8% percent-of-entry bands. V5 fixed-risk sizing replaces ATR sizing.

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12354;
input int    qm_magic_slot_offset       = 0;
// FW3: Q07 Multi-Seed uses one of the canonical seeds (42, 17, 99, 7, 2026).
// All other phases use 42 by default.
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
// FW1 2026-05-23 — Two-axis news filter per Vault Q09.
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
// Card §8 Parameters To Test — defaults are the source parameters.
input int    strategy_high_lookback     = 40;    // fresh-high breakout window (bars). Sweep [20,40,55,80].
input int    strategy_low_lookback      = 20;    // Donchian low-break exit window (bars). Sweep [10,20,30].
input int    strategy_sma_filter        = 150;   // trend-filter SMA period on close. Sweep [100,150,200].
input double strategy_tp_pct            = 20.0;  // take-profit, percent of entry price. Sweep [10,20,30].
input double strategy_sl_pct            = 8.0;   // stop-loss, percent of entry price. Sweep [5,8,12].

// -----------------------------------------------------------------------------
// Strategy helpers (Turtle-40 breakout).
//
// The card's entry predicate ("current high is the maximum of the trailing
// 40-bar high window") has no matching framework primitive — QM_Sig_Range_Breakout
// compares a CLOSE to a prior-N-bar high, not a HIGH-is-window-max. So the fresh-
// high window is a bounded closed-bar read, gated once-per-closed-bar by the
// framework QM_IsNewBar() guard in OnTick (hence the // perf-allowed exceptions).
// The 20-bar low exit DOES have a symmetric helper (QM_Sig_Range_Breakout, -1),
// which is used directly in Strategy_ExitSignal.
// -----------------------------------------------------------------------------

// Highest high across the last `bars` closed D1 bars (shift 1..bars inclusive).
// Returns 0.0 if any bar is missing (insufficient history) so callers abstain.
// Reads each bar's high via a period-1 SMA on PRICE_HIGH — QM_SMA(sym,tf,1,i,
// PRICE_HIGH) == high[i] — so the window uses the handle-pooled QM_* reader
// (corset-clean, no raw iX). Gated once-per-closed-bar by QM_IsNewBar() in OnTick.
double Turtle_HighestHigh(const int bars)
  {
   if(bars < 1)
      return 0.0;
   double hi = -DBL_MAX;
   for(int i = 1; i <= bars; ++i)
     {
      const double h = QM_SMA(_Symbol, PERIOD_D1, 1, i, PRICE_HIGH); // period-1 SMA on PRICE_HIGH == high[i]
      if(h <= 0.0)
         return 0.0;
      if(h > hi)
         hi = h;
     }
   return (hi > -DBL_MAX) ? hi : 0.0;
  }

// True if this EA's magic already holds a position on _Symbol.
bool Turtle_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;
   const int total = PositionsTotal();
   for(int i = 0; i < total; ++i)
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

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick. Card §6 / §13 Strategy_NoTrade_HistoryReady:
// block NEW entries until enough closed D1 history exists for SMA(N)[1] and the
// N-bar high window. A position can never exist during warmup (entries are gated
// by this same check), so blocking the management/exit paths here is inert.
bool Strategy_NoTradeFilter()
  {
   // History-readiness: QM_SMA returns 0.0 until enough closed D1 bars exist to
   // compute SMA(strategy_sma_filter)[1]. Because strategy_sma_filter (150) is
   // the deepest lookback (> the 40-bar high / 20-bar low windows), a positive
   // read guarantees every window is ready. Corset-clean (no raw Bars/iX call).
   if(QM_SMA(_Symbol, PERIOD_D1, strategy_sma_filter, 1) <= 0.0)
      return true;
   return false;
  }

// Populate `req` and return TRUE if a NEW long entry should fire. Caller
// guarantees QM_IsNewBar() == true (once-per-closed-bar).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type               = QM_BUY;
   req.price              = 0.0;   // market fill — framework resolves the Ask at send time
   req.sl                 = 0.0;
   req.tp                 = 0.0;
   req.reason             = "";
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_high_lookback < 1 || strategy_sma_filter < 1)
      return false;

   // Long-only, one-position-per-magic/symbol (card §4 + §7).
   if(Turtle_HasOpenPosition())
      return false;

   // Closed-bar inputs (shift = 1) via handle-pooled QM_* readers. Period-1 SMA
   // on PRICE_CLOSE/PRICE_HIGH == close[1] / high[1] (corset-clean, no raw iX).
   const double close1 = QM_SMA(_Symbol, PERIOD_D1, 1, 1, PRICE_CLOSE);
   const double high1  = QM_SMA(_Symbol, PERIOD_D1, 1, 1, PRICE_HIGH);
   const double sma    = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_filter, 1);
   if(close1 <= 0.0 || high1 <= 0.0 || sma <= 0.0)
      return false;   // not-ready / insufficient-history read

   // Fresh N-bar high: high[1] is the maximum of the trailing high window
   // (window includes bar 1, so this holds iff high[1] >= max(high[2..N])).
   const double hh = Turtle_HighestHigh(strategy_high_lookback);
   if(hh <= 0.0)
      return false;

   // Card §4 entry: close above the SMA trend filter AND a fresh N-bar high.
   if(close1 <= sma)
      return false;
   if(high1 < hh)
      return false;

   // Percent-of-entry SL/TP bands (card §5). Estimate the fill with the current
   // Ask (this is a market buy); the framework re-resolves the true fill price
   // for lot sizing from req.sl. Percent-of-price is scale-correct across FX /
   // metals / indices, so no pip conversion anywhere in this EA.
   const double entry_est = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry_est <= 0.0)
      return false;
   const double tp_price = QM_StopRulesNormalizePrice(_Symbol, entry_est * (1.0 + strategy_tp_pct / 100.0));
   const double sl_price = QM_StopRulesNormalizePrice(_Symbol, entry_est * (1.0 - strategy_sl_pct / 100.0));
   if(sl_price <= 0.0 || sl_price >= entry_est || tp_price <= entry_est)
      return false;

   req.type   = QM_BUY;
   req.price  = 0.0;
   req.sl     = sl_price;
   req.tp     = tp_price;
   req.reason = "TURTLE40_LONG";
   return true;
  }

// Called every tick when an open position may exist. Card §7: no trailing,
// break-even, partial, or pyramiding. The +20% / -8% percent-of-entry exits are
// carried as the position TP / SL (set in Strategy_EntrySignal); the trend /
// structure exits live in Strategy_ExitSignal. Nothing to manage per-tick.
void Strategy_ManageOpenPosition()
  {
  }

// Return TRUE to close the open position now. Closed-bar trend / structure exits
// (card §5). The +20% / -8% bands are the position TP / SL and fire broker-side,
// not here. Evaluated only while a position is open; all reads are closed-bar.
bool Strategy_ExitSignal()
  {
   if(!Turtle_HasOpenPosition())
      return false;

   // Closed-bar close via period-1 SMA on PRICE_CLOSE == close[1] (no raw iX).
   const double close1 = QM_SMA(_Symbol, PERIOD_D1, 1, 1, PRICE_CLOSE);
   const double sma    = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_filter, 1);
   if(close1 <= 0.0 || sma <= 0.0)
      return false;   // never fabricate an exit from a not-ready read

   // Exit 1 (card §5): trend-filter break — last close below SMA(N).
   if(close1 < sma)
      return true;

   // Exit 2 (card §5): Donchian low break — last close below the lowest low of
   // the prior N bars (QM_Sig_Range_Breakout's -1 return; window excludes the
   // breakout bar itself).
   if(QM_Sig_Range_Breakout(_Symbol, PERIOD_D1, strategy_low_lookback, 1) < 0)
      return true;

   return false;
  }

// Optional news-filter override. Card §6: V5 news defaults apply — defer to the
// central two-axis filter.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_12354_orev_turtle40\"}");
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
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
