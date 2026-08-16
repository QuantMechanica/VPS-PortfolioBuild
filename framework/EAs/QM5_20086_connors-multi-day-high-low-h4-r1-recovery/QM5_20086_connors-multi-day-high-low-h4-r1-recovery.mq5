#property strict
#property version   "5.0"
#property description "QuantMechanica V5 EA — QM5_20086 connors-multi-day-high-low-h4-r1-recovery"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_20086 connors-multi-day-high-low-h4-r1-recovery
// -----------------------------------------------------------------------------
// Connors 2008 ch.10 "Multi-Day Highs and Lows" consecutive-extreme-streak mean
// reversion on H4, gated by a D1 SMA(200) regime read. Entry requires TWO
// consecutive H4 bars (shift 1 and shift 2) to each register a new 10-bar
// extreme, still on the mean-revert side of SMA(5,H4), and in agreement with the
// D1 trend regime:
//   Long : D1 close > SMA(200,D1) && bar1 & bar2 both 10-bar lows && close1 < SMA(5,H4)
//   Short: D1 close < SMA(200,D1) && bar1 & bar2 both 10-bar highs && close1 > SMA(5,H4)
// Exits (all in Strategy_ManageOpenPosition): mean-revert TP at SMA(5,H4) touch,
// time-stop after 8 H4 bars. Backstop SL at 2.5*ATR(14,H4). Spread guard skips
// entries when spread > 0.4*ATR(14,H4) (never fail-closed on a zero spread).
//
// Only QM_* helpers used for indicators / bar reads / stops / trade management,
// plus one bespoke bounded structural streak loop (IsNBarLow / IsNBarHigh) that
// has no QM_* equivalent — called ONLY from the QM_IsNewBar-gated entry path.
// Framework wiring below the marker line is untouched.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 20086;
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
// NOTE: card names this input `lookback_bars`; renamed to `extreme_lookback`
// to avoid an identifier collision with a framework function parameter
// (QM_StopRules.mqh / QM_Signals.mqh both use `lookback_bars`), which triggers
// warning 62 "declaration hides global variable" and fails strict build_check.
// Semantics unchanged: N-bar window for the high/low extreme-streak check.
input int    extreme_lookback           = 10;
input int    sma_fast                   = 5;
input int    d1_trend_sma               = 200;
input int    atr_period                 = 14;
input double sl_atr_mult                = 2.5;
input int    time_stop_bars             = 8;
input double spread_atr_mult_cap        = 0.4;

// File-scope strategy state.
datetime g_position_entry_time = 0;

// -----------------------------------------------------------------------------
// Bespoke structural streak helpers (no QM_* equivalent for "is this bar's low
// the lowest of the trailing N bars"). Bounded lookback loop, called ONLY from
// the QM_IsNewBar-gated entry path.
// -----------------------------------------------------------------------------

// perf-allowed structural streak lookup — bounded 10-bar loop, called once per new bar only
bool IsNBarLow(const string sym, const int shift, const int lookback)
  {
   MqlRates c;
   if(!QM_ReadBar(sym, PERIOD_CURRENT, shift, c)) return false;
   double lowest = c.low;
   for(int i = shift + 1; i <= shift + lookback - 1; i++)
     {
      MqlRates cj;
      if(!QM_ReadBar(sym, PERIOD_CURRENT, i, cj)) continue;
      if(cj.low < lowest) lowest = cj.low;
     }
   return (c.low <= lowest + SymbolInfoDouble(sym, SYMBOL_POINT) * 0.5);
  }

bool IsNBarHigh(const string sym, const int shift, const int lookback)
  {
   MqlRates c;
   if(!QM_ReadBar(sym, PERIOD_CURRENT, shift, c)) return false;
   double highest = c.high;
   for(int i = shift + 1; i <= shift + lookback - 1; i++)
     {
      MqlRates cj;
      if(!QM_ReadBar(sym, PERIOD_CURRENT, i, cj)) continue;
      if(cj.high > highest) highest = cj.high;
     }
   return (c.high >= highest - SymbolInfoDouble(sym, SYMBOL_POINT) * 0.5);
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

   // 1. D1 regime read (last closed D1 bar + D1 SMA200).
   MqlRates d1c1;
   if(!QM_ReadBar(_Symbol, PERIOD_D1, 1, d1c1))
      return false;
   const double d1sma200_1 = QM_SMA(_Symbol, PERIOD_D1, d1_trend_sma, 1);

   // 2. H4 reads: last closed bar, SMA(5), ATR(14).
   MqlRates c1;
   if(!QM_ReadBar(_Symbol, PERIOD_CURRENT, 1, c1))
      return false;
   const double sma5_1  = QM_SMA(_Symbol, PERIOD_CURRENT, sma_fast, 1);
   const double atr14_1 = QM_ATR(_Symbol, PERIOD_CURRENT, atr_period, 1);

   // 3. Bail on unavailable warm-up indicators.
   if(d1sma200_1 <= 0.0 || atr14_1 <= 0.0)
      return false;

   // 4. Spread filter (do NOT fail-closed on zero spread — .DWX quotes 0 in tester).
   const double spread = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(spread > 0.0 && spread > spread_atr_mult_cap * atr14_1)
      return false;

   // 5. D1 trend regime.
   const bool regime_up   = d1c1.close > d1sma200_1;
   const bool regime_down = d1c1.close < d1sma200_1;

   // 6. Consecutive-extreme streak (two consecutive new 10-bar extremes).
   const bool long_streak  = IsNBarLow(_Symbol, 1, extreme_lookback)  && IsNBarLow(_Symbol, 2, extreme_lookback);
   const bool short_streak = IsNBarHigh(_Symbol, 1, extreme_lookback) && IsNBarHigh(_Symbol, 2, extreme_lookback);

   // 7. Composite entry gates (streak + regime + mean-revert headroom vs SMA5).
   const bool long_ok  = regime_up   && long_streak  && c1.close < sma5_1;
   const bool short_ok = regime_down && short_streak && c1.close > sma5_1;

   // 8. Long entry.
   if(long_ok)
     {
      req.type   = QM_BUY;
      req.price  = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      req.sl     = QM_StopATR(_Symbol, QM_BUY, req.price, atr_period, sl_atr_mult);
      req.tp     = 0.0;
      req.reason = "connors_multiday_hl_long";
      g_position_entry_time = c1.time;
      return true;
     }

   // 9. Short entry (mirror).
   if(short_ok)
     {
      req.type   = QM_SELL;
      req.price  = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      req.sl     = QM_StopATR(_Symbol, QM_SELL, req.price, atr_period, sl_atr_mult);
      req.tp     = 0.0;
      req.reason = "connors_multiday_hl_short";
      g_position_entry_time = c1.time;
      return true;
     }

   // 10. No signal.
   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Mean-revert TP at the SMA(5,H4) mean-line touch, plus a fixed time-stop.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   // perf-allowed structural bar-index lookup
   const int    bars_since_entry = (g_position_entry_time > 0)
                                   ? iBarShift(_Symbol, PERIOD_CURRENT, g_position_entry_time, false) : 0;
   const double sma5_1 = QM_SMA(_Symbol, PERIOD_CURRENT, sma_fast, 1);

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

      // Mean-revert TP at the SMA(5,H4) touch.
      if(sma5_1 > 0.0)
        {
         if(is_buy && SymbolInfoDouble(_Symbol, SYMBOL_BID) >= sma5_1)
           {
            QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
            continue;
           }
         if(!is_buy && SymbolInfoDouble(_Symbol, SYMBOL_ASK) <= sma5_1)
           {
            QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
            continue;
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
