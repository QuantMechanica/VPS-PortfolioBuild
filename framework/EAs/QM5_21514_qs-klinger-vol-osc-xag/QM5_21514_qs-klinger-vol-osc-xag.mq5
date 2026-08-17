#property strict
#property version   "5.0"
#property description "QuantMechanica V5 EA skeleton template"

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
input int    qm_ea_id                   = 21514;
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
input int    strategy_kvo_fast_period    = 34;
input int    strategy_kvo_slow_period    = 55;
input int    strategy_kvo_signal_period  = 13;
input int    strategy_atr_period         = 14;
input double strategy_atr_sl_mult        = 2.5;
input int    strategy_max_hold_bars      = 60;
input int    strategy_warmup_buffer      = 20;
input int    strategy_max_spread_points  = 400;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // Card scope is deliberately single-symbol and D1-only. The spread cap is
   // applied in Strategy_EntrySignal so it never suspends position exits.
   if(_Symbol != "XAGUSD.DWX")
      return true;
   if((ENUM_TIMEFRAMES)_Period != PERIOD_D1)
      return true;
   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_kvo_fast_period <= 0 ||
      strategy_kvo_slow_period <= 0 ||
      strategy_kvo_signal_period <= 0 ||
      strategy_atr_period <= 0 ||
      strategy_atr_sl_mult <= 0.0 ||
      strategy_warmup_buffer < 0 ||
      strategy_max_spread_points < 0)
      return false;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(bid <= 0.0 || ask <= 0.0 || point <= 0.0)
      return false;
   if(ask > bid && ((ask - bid) / point) > (double)strategy_max_spread_points)
      return false;

   // Volume Force is a bespoke path-dependent series, so no framework
   // price-indicator reader can construct it. The caller's QM_IsNewBar gate
   // guarantees this bounded history scan runs only once per completed D1 bar.
   const int vf_samples = strategy_kvo_slow_period +
                          strategy_kvo_signal_period +
                          strategy_warmup_buffer;
   const int rates_needed = vf_samples + 1;
   if(vf_samples < 2)
      return false;

   MqlRates kvo_rates[];
   ArraySetAsSeries(kvo_rates, false);
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, rates_needed, kvo_rates); // perf-allowed: card-authorized KVO warmup scan behind the skeleton's QM_IsNewBar gate.
   if(copied < rates_needed)
      return false;

   const double alpha_fast = 2.0 / ((double)strategy_kvo_fast_period + 1.0);
   const double alpha_slow = 2.0 / ((double)strategy_kvo_slow_period + 1.0);
   const double alpha_signal = 2.0 / ((double)strategy_kvo_signal_period + 1.0);

   double cm_value = 0.0;
   double dm_previous = kvo_rates[0].high - kvo_rates[0].low;
   int trend_previous = 0;
   double ema_fast = 0.0;
   double ema_slow = 0.0;
   double kvo_current = 0.0;
   double signal_current = 0.0;
   double kvo_previous = 0.0;
   double signal_previous = 0.0;
   bool ema_seeded = false;

   for(int bar_index = 1; bar_index < copied; ++bar_index)
     {
      const double dm_current = kvo_rates[bar_index].high - kvo_rates[bar_index].low;
      const double typical_current = kvo_rates[bar_index].high +
                                     kvo_rates[bar_index].low +
                                     kvo_rates[bar_index].close;
      const double typical_previous = kvo_rates[bar_index - 1].high +
                                      kvo_rates[bar_index - 1].low +
                                      kvo_rates[bar_index - 1].close;
      const int trend_current = (typical_current > typical_previous) ? 1 : -1;

      if(bar_index == 1)
         cm_value = dm_previous + dm_current;
      else if(trend_current == trend_previous)
         cm_value += dm_current;
      else
         cm_value = dm_previous + dm_current;

      double volume_force = 0.0;
      if(cm_value > 0.0)
        {
         volume_force = (double)kvo_rates[bar_index].tick_volume *
                        MathAbs(2.0 * (dm_current / cm_value - 1.0)) *
                        (double)trend_current * 100.0;
        }

      if(!ema_seeded)
        {
         ema_fast = volume_force;
         ema_slow = volume_force;
         kvo_current = 0.0;
         signal_current = 0.0;
         ema_seeded = true;
        }
      else
        {
         kvo_previous = kvo_current;
         signal_previous = signal_current;
         ema_fast = alpha_fast * volume_force + (1.0 - alpha_fast) * ema_fast;
         ema_slow = alpha_slow * volume_force + (1.0 - alpha_slow) * ema_slow;
         kvo_current = ema_fast - ema_slow;
         signal_current = alpha_signal * kvo_current +
                          (1.0 - alpha_signal) * signal_current;
        }

      dm_previous = dm_current;
      trend_previous = trend_current;
     }

   if(!ema_seeded)
      return false;

   const bool cross_up = (kvo_previous <= signal_previous &&
                          kvo_current > signal_current);
   const bool cross_down = (kvo_previous >= signal_previous &&
                            kvo_current < signal_current);
   if(!cross_up && !cross_down)
      return false;

   req.type = cross_up ? QM_BUY : QM_SELL;
   const double entry_price = cross_up ? ask : bid;
   req.sl = QM_StopATR(_Symbol,
                       req.type,
                       entry_price,
                       strategy_atr_period,
                       strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;
   req.reason = cross_up ? "KVO_SIGNAL_CROSS_LONG" : "KVO_SIGNAL_CROSS_SHORT";
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card v1 specifies no trailing stop, break-even, partial close, or scale-in.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // This framework-owned daily cadence is distinct from the entry gate and
   // cannot consume QM_IsNewBar(). It keeps both completed-bar exits ahead of
   // the entry path so an opposite cross may flip on the same D1 bar.
   if(!QM_IsNewCalendarPeriod(PERIOD_D1, _Symbol))
      return false;

   const int held_periods = QM_TM_HeldPeriodsForMagic((long)magic,
                                                       _Symbol,
                                                       PERIOD_D1,
                                                       TimeCurrent());
   if(strategy_max_hold_bars > 0 && held_periods >= strategy_max_hold_bars)
     {
      for(int position_index = PositionsTotal() - 1; position_index >= 0; --position_index)
        {
         const ulong ticket = PositionGetTicket(position_index);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic ||
            PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
        }
      return false;
     }

   if(strategy_kvo_fast_period <= 0 ||
      strategy_kvo_slow_period <= 0 ||
      strategy_kvo_signal_period <= 0 ||
      strategy_warmup_buffer < 0)
      return false;

   const int vf_samples = strategy_kvo_slow_period +
                          strategy_kvo_signal_period +
                          strategy_warmup_buffer;
   const int rates_needed = vf_samples + 1;
   if(vf_samples < 2)
      return false;

   MqlRates kvo_rates[];
   ArraySetAsSeries(kvo_rates, false);
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, rates_needed, kvo_rates); // perf-allowed: card-authorized KVO exit scan behind QM_IsNewCalendarPeriod(PERIOD_D1).
   if(copied < rates_needed)
      return false;

   const double alpha_fast = 2.0 / ((double)strategy_kvo_fast_period + 1.0);
   const double alpha_slow = 2.0 / ((double)strategy_kvo_slow_period + 1.0);
   const double alpha_signal = 2.0 / ((double)strategy_kvo_signal_period + 1.0);

   double cm_value = 0.0;
   double dm_previous = kvo_rates[0].high - kvo_rates[0].low;
   int trend_previous = 0;
   double ema_fast = 0.0;
   double ema_slow = 0.0;
   double kvo_current = 0.0;
   double signal_current = 0.0;
   double kvo_previous = 0.0;
   double signal_previous = 0.0;
   bool ema_seeded = false;

   for(int bar_index = 1; bar_index < copied; ++bar_index)
     {
      const double dm_current = kvo_rates[bar_index].high - kvo_rates[bar_index].low;
      const double typical_current = kvo_rates[bar_index].high +
                                     kvo_rates[bar_index].low +
                                     kvo_rates[bar_index].close;
      const double typical_previous = kvo_rates[bar_index - 1].high +
                                      kvo_rates[bar_index - 1].low +
                                      kvo_rates[bar_index - 1].close;
      const int trend_current = (typical_current > typical_previous) ? 1 : -1;

      if(bar_index == 1)
         cm_value = dm_previous + dm_current;
      else if(trend_current == trend_previous)
         cm_value += dm_current;
      else
         cm_value = dm_previous + dm_current;

      double volume_force = 0.0;
      if(cm_value > 0.0)
        {
         volume_force = (double)kvo_rates[bar_index].tick_volume *
                        MathAbs(2.0 * (dm_current / cm_value - 1.0)) *
                        (double)trend_current * 100.0;
        }

      if(!ema_seeded)
        {
         ema_fast = volume_force;
         ema_slow = volume_force;
         kvo_current = 0.0;
         signal_current = 0.0;
         ema_seeded = true;
        }
      else
        {
         kvo_previous = kvo_current;
         signal_previous = signal_current;
         ema_fast = alpha_fast * volume_force + (1.0 - alpha_fast) * ema_fast;
         ema_slow = alpha_slow * volume_force + (1.0 - alpha_slow) * ema_slow;
         kvo_current = ema_fast - ema_slow;
         signal_current = alpha_signal * kvo_current +
                          (1.0 - alpha_signal) * signal_current;
        }

      dm_previous = dm_current;
      trend_previous = trend_current;
     }

   if(!ema_seeded)
      return false;

   const bool cross_up = (kvo_previous <= signal_previous &&
                          kvo_current > signal_current);
   const bool cross_down = (kvo_previous >= signal_previous &&
                            kvo_current < signal_current);
   if(!cross_up && !cross_down)
      return false;

   for(int position_index = PositionsTotal() - 1; position_index >= 0; --position_index)
     {
      const ulong ticket = PositionGetTicket(position_index);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic ||
         PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const ENUM_POSITION_TYPE position_type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if((position_type == POSITION_TYPE_BUY && cross_down) ||
         (position_type == POSITION_TYPE_SELL && cross_up))
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
     }

   // Closures are performed above with their precise framework exit reason;
   // returning false prevents the skeleton from issuing a second close.
   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   // No card-specific override: defer to the framework's fail-closed 2-axis
   // news gate, which is deliberately below management and exit handling.
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
