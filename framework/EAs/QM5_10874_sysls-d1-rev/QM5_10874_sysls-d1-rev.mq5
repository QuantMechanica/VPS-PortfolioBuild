#property strict
#property version   "5.0"
#property description "QM5_10874 SystematicLS same-close D1 reversal"

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
input int    qm_ea_id                   = 10874;
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
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
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
input int    strategy_atr_period        = 20;
input double strategy_entry_threshold   = 0.75;
input double strategy_sl_atr_mult       = 0.75;
input double strategy_tp_atr_mult       = 0.50;
input double strategy_min_tr_atr_mult   = 0.50;
input double strategy_max_spread_stop_pct = 8.0;
input int    strategy_entry_hour        = 23;
input int    strategy_entry_minute      = 45;
input int    strategy_exit_hour         = 0;
input int    strategy_exit_minute       = 30;
input bool   strategy_exit_next_close   = false;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // No Trade Filter: the strategy-specific time and spread gates are evaluated
   // in EntrySignal because they depend on the configured entry minute and stop distance.
   // News Filter Hook: central framework news axes are callable through Strategy_NewsFilterHook.
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

   // Trade Entry: M15 close-minus-session-close approximation for the D1 reversal card.
   if(_Period != PERIOD_M15)
      return false;

   // rework v2 2026-06-16 — BUG: gated entry on TimeCurrent() minute==45 exactly.
   // QM_IsNewBar() fires on the FIRST real tick of the new M15 bar; near the
   // 23:45 broker close (thin DWX liquidity at the daily rollover) that first
   // tick routinely lands after :45:59, so dt.min!=45 and the entry never fired
   // (0 trades / MIN_TRADES). Key the gate off the bar's OPEN time instead — in
   // the tester M15 bars open exactly at :00/:15/:30/:45, so this is robust.
   const datetime bar_open = iTime(_Symbol, PERIOD_M15, 0);
   if(bar_open <= 0)
      return false;
   MqlDateTime dt;
   TimeToStruct(bar_open, dt);
   if(dt.hour != strategy_entry_hour || dt.min != strategy_entry_minute)
      return false;

   const int day_key = dt.year * 1000 + dt.day_of_year;
   static int s_entry_attempt_day_key = 0;
   if(s_entry_attempt_day_key == day_key)
      return false;
   s_entry_attempt_day_key = day_key;

   MqlRates d1_rates[];
   ArraySetAsSeries(d1_rates, true);
   // perf-allowed: bounded two-bar D1 OHLC read inside framework closed-bar EntrySignal.
   if(CopyRates(_Symbol, PERIOD_D1, 0, 2, d1_rates) != 2)
      return false;

   MqlRates m15_close_bar[];
   ArraySetAsSeries(m15_close_bar, true);
   // perf-allowed: bounded one-bar M15 close read at the configured entry minute only.
   if(CopyRates(_Symbol, PERIOD_M15, 1, 1, m15_close_bar) != 1)
      return false;

   const double prior_close = d1_rates[1].close;
   const double today_high = d1_rates[0].high;
   const double today_low = d1_rates[0].low;
   const double m15_close = m15_close_bar[0].close;
   if(prior_close <= 0.0 || today_high <= 0.0 || today_low <= 0.0 || m15_close <= 0.0)
      return false;

   const double atr_d1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr_d1 <= 0.0)
      return false;

   const double tr_today = MathMax(today_high - today_low,
                           MathMax(MathAbs(today_high - prior_close),
                                   MathAbs(today_low - prior_close)));
   if(tr_today < strategy_min_tr_atr_mult * atr_d1)
      return false;

   const double stop_distance = strategy_sl_atr_mult * atr_d1;
   if(stop_distance <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask <= bid)
      return false;

   // No Trade Filter: spread gate from the card, expressed as percent of stop distance.
   if((ask - bid) > (strategy_max_spread_stop_pct / 100.0) * stop_distance)
      return false;

   const double norm_return = ((m15_close - prior_close) / prior_close) / (atr_d1 / prior_close);
   double entry = 0.0;
   if(norm_return > strategy_entry_threshold)
     {
      req.type = QM_SELL;
      entry = bid;
      req.reason = "D1_SAME_CLOSE_REV_SHORT";
     }
   else if(norm_return < -strategy_entry_threshold)
     {
      req.type = QM_BUY;
      entry = ask;
      req.reason = "D1_SAME_CLOSE_REV_LONG";
     }
   else
      return false;

   req.sl = QM_StopATRFromValue(_Symbol, req.type, entry, atr_d1, strategy_sl_atr_mult);
   req.tp = QM_TakeATRFromValue(_Symbol, req.type, entry, atr_d1, strategy_tp_atr_mult);
   if(req.sl <= 0.0 || req.tp <= 0.0)
      return false;

   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Trade Management: no trailing, break-even, or partial exits are specified by the card.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   MqlDateTime now_dt;
   TimeToStruct(TimeCurrent(), now_dt);
   const int now_hhmm = now_dt.hour * 100 + now_dt.min;
   const int exit_hhmm = strategy_exit_hour * 100 + strategy_exit_minute;
   const int entry_hhmm = strategy_entry_hour * 100 + strategy_entry_minute;
   const int today_key = now_dt.year * 1000 + now_dt.day_of_year;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      MqlDateTime open_dt;
      TimeToStruct((datetime)PositionGetInteger(POSITION_TIME), open_dt);
      const int open_day_key = open_dt.year * 1000 + open_dt.day_of_year;
      const bool next_day_or_later = (today_key != open_day_key);

      // Trade Close: primary exit at next session open plus configured minutes.
      if(!strategy_exit_next_close && next_day_or_later && now_hhmm >= exit_hhmm)
         return true;

      // Trade Close: alternate next D1 close test.
      if(strategy_exit_next_close && next_day_or_later && now_hhmm >= entry_hhmm)
         return true;

      // Trade Close: flatten on opposite same-close signal before scheduled exit.
      // rework v2 2026-06-16 — same minute-exact fragility as entry: key the
      // opposite-signal check off the M15 bar open time, not the tick minute,
      // so it is reachable once-per-day on the 23:45 bar like the entry.
      MqlDateTime sig_dt;
      const datetime sig_bar_open = iTime(_Symbol, PERIOD_M15, 0);
      TimeToStruct(sig_bar_open, sig_dt);
      if(sig_bar_open > 0 && sig_dt.hour == strategy_entry_hour && sig_dt.min == strategy_entry_minute)
        {
         MqlRates d1_rates[];
         ArraySetAsSeries(d1_rates, true);
         // perf-allowed: bounded two-bar D1 read only at the configured close signal minute.
         if(CopyRates(_Symbol, PERIOD_D1, 0, 2, d1_rates) != 2)
            continue;
         MqlRates m15_close_bar[];
         ArraySetAsSeries(m15_close_bar, true);
         // perf-allowed: bounded one-bar M15 read only at the configured close signal minute.
         if(CopyRates(_Symbol, PERIOD_M15, 1, 1, m15_close_bar) != 1)
            continue;

         const double prior_close = d1_rates[1].close;
         const double m15_close = m15_close_bar[0].close;
         const double atr_d1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
         if(prior_close <= 0.0 || m15_close <= 0.0 || atr_d1 <= 0.0)
            continue;

         const double norm_return = ((m15_close - prior_close) / prior_close) / (atr_d1 / prior_close);
         const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         if(pos_type == POSITION_TYPE_BUY && norm_return > strategy_entry_threshold)
            return true;
         if(pos_type == POSITION_TYPE_SELL && norm_return < -strategy_entry_threshold)
            return true;
        }
     }

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   // News Filter Hook: no card-specific override; defer to central framework wiring.
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
