#property strict
#property version   "5.0"
#property description "QM5_9641 Bandy CCI Extreme Fade (Index, Long-Only)"

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
//     QM_ADX / QM_ADX_PlusDI / QM_ADX_MinusDI / QM_CCI /
//     QM_BB_Upper / QM_BB_Middle / QM_BB_Lower    (from QM_Indicators.mqh)
//   - QM_TM_OpenPosition(req, ticket) / QM_TM_ClosePosition(ticket, reason)
//   - QM_TM_MoveToBreakEven / QM_TM_TrailATR / QM_TM_TrailStep / QM_TM_PartialClose
//   - QM_LotsForRisk(symbol, sl_points)        — risk model lot sizing
//   - QM_StopFixedPips / QM_StopATR / QM_StopStructure / QM_StopVolatility
//   - QM_FrameworkTrackOpenPositionMae / QM_FrameworkHandleFridayClose /
//     QM_KillSwitchCheck / QM_NewsAllowsTrade
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
input int    qm_ea_id                   = 9641;
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
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
// FW2 2026-05-23 — only populated by Q05 MED / Q06 HARSH stress setfiles.
// Default 0.0 = no rejection (Q02/Q03/Q04/Q07/Q08/Q09/Q10/Q13 backtests).
// Q06 HARSH sets to 0.10 (10% of entries randomly dropped before broker send,
// deterministic per qm_rng_seed). MED slip/spread/commission live in the
// tester groups file, not as EA inputs.
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_cci_period            = 20;
input double strategy_entry_cci             = -100.0;
input double strategy_exit_cci              = 0.0;
input int    strategy_regime_sma_period     = 200;
input int    strategy_atr_period            = 14;
input double strategy_atr_stop_mult         = 2.5;
input int    strategy_time_stop_days        = 7;
input int    strategy_vol_lookback_bars     = 252;
input double strategy_vol_percentile        = 99.0;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// No Trade Filter: the approved card declares no custom time or spread gate
// beyond skipping incomplete daily bars (handled by the QM_IsNewBar closed-bar
// gate in OnTick) and the vol-chaos filter evaluated inside EntrySignal.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Vol-chaos guard (card "Zusätzliche Filter"): skip new entries if
// ATR(14)/close sits in the top `strategy_vol_percentile` percentile over the
// last `strategy_vol_lookback_bars` closed D1 bars (Bandy's "no-trade-on-chaos"
// rule). Evaluated once per new D1 bar inside the closed-bar entry gate —
// mirrors the bounded percentile-lookback pattern in QM_Mod_GrimesNestedPbV2.
bool PassesVolChaosFilter()
  {
   if(strategy_vol_lookback_bars < 20)
      return true;

   double ratios[];
   ArrayResize(ratios, strategy_vol_lookback_bars);
   double current_ratio = 0.0;
   for(int i = 0; i < strategy_vol_lookback_bars; ++i)
     {
      MqlRates bar_i;
      if(!QM_ReadBar(_Symbol, PERIOD_D1, i + 1, bar_i) || bar_i.close <= 0.0)
         return false;
      const double atr_i = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, i + 1);
      if(atr_i <= 0.0)
         return false;
      ratios[i] = atr_i / bar_i.close;
      if(i == 0)
         current_ratio = ratios[i];
     }
   ArraySort(ratios);
   int idx = (int)MathFloor((strategy_vol_percentile / 100.0) * (strategy_vol_lookback_bars - 1));
   if(idx < 0)
      idx = 0;
   if(idx >= strategy_vol_lookback_bars)
      idx = strategy_vol_lookback_bars - 1;
   return (current_ratio < ratios[idx]);
  }

// Trade Entry: on the first tick of each closed D1 bar, evaluate the CCI
// extreme-fade condition gated by the SMA200 regime filter and the vol-chaos
// guard. Long-only per the card (equity-drawdown asymmetry makes the short
// side noise-dominated in Bandy's treatment).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_cci_period < 2 || strategy_regime_sma_period < 2 ||
      strategy_atr_period < 1 || strategy_atr_stop_mult <= 0.0)
      return false;

   MqlRates closed_bar;
   if(!QM_ReadBar(_Symbol, PERIOD_D1, 1, closed_bar))
      return false;

   const double cci = QM_CCI(_Symbol, PERIOD_D1, strategy_cci_period, 1);
   if(cci > strategy_entry_cci)
      return false;

   const double regime_sma = QM_SMA(_Symbol, PERIOD_D1, strategy_regime_sma_period, 1, PRICE_CLOSE);
   if(regime_sma <= 0.0 || closed_bar.close <= regime_sma)
      return false;

   if(!PassesVolChaosFilter())
      return false;

   const double entry_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry_price <= 0.0)
      return false;

   const double stop_price = QM_StopATR(_Symbol,
                                        QM_BUY,
                                        entry_price,
                                        strategy_atr_period,
                                        strategy_atr_stop_mult);
   if(stop_price <= 0.0 || stop_price >= entry_price)
      return false;

   req.sl = stop_price;
   req.reason = StringFormat("BANDY_CCI_FADE_LONG cci=%.2f", cci);
   return true;
  }

// Trade Management: the card specifies no trailing, break-even, partial-close
// or scale-in rule. The ATR catastrophic stop is server-side from entry.
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close: evaluate only once per D1 calendar edge. Close at the
// zero-line CCI take-profit or after the card's 7-trading-day time stop.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   if(!QM_IsNewCalendarPeriod(PERIOD_D1))
      return false;

   if(strategy_time_stop_days > 0)
     {
      const int held_bars = QM_TM_HeldPeriodsForMagic((long)magic,
                                                       _Symbol,
                                                       PERIOD_D1,
                                                       TimeCurrent());
      if(held_bars >= strategy_time_stop_days)
         return true;
     }

   if(strategy_cci_period < 2)
      return false;

   const double cci = QM_CCI(_Symbol, PERIOD_D1, strategy_cci_period, 1);
   return (cci >= strategy_exit_cci);
  }

// News Filter Hook: no card-specific override. The framework's callable
// two-axis news gate (default ±30min pre/post high-impact) already matches
// the card's news filter requirement.
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
