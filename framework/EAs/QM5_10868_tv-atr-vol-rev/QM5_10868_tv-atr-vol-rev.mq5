#property strict
#property version   "5.0"
#property description "QM5_10868 TradingView ATR volume reversal"

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
input int    qm_ea_id                   = 10868;
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
input int    strategy_atr_period         = 14;
input double strategy_atr_multiplier     = 2.0;
input int    strategy_volume_period      = 20;
input double strategy_volume_spike_mult  = 2.0;
input int    strategy_range_lookback     = 20;
input double strategy_body_min_pct       = 0.40;
input double strategy_atr_stop_buffer    = 0.25;
input double strategy_target_r           = 1.0;
input int    strategy_time_exit_bars     = 12;
input int    strategy_cooldown_bars      = 8;
input double strategy_max_spread_stop_pct = 0.12;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // Card has no session filter. Framework handles news/Friday; spread is
   // checked in EntrySignal after the stop distance is known.
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

   if(strategy_atr_period <= 0 ||
      strategy_atr_multiplier <= 0.0 ||
      strategy_volume_period <= 0 ||
      strategy_volume_spike_mult <= 0.0 ||
      strategy_range_lookback <= 0 ||
      strategy_body_min_pct < 0.0 ||
      strategy_body_min_pct > 1.0 ||
      strategy_atr_stop_buffer < 0.0 ||
      strategy_target_r <= 0.0 ||
      strategy_time_exit_bars <= 0 ||
      strategy_cooldown_bars < 0 ||
      strategy_max_spread_stop_pct < 0.0)
      return false;

   if(strategy_cooldown_bars > 0)
     {
      const int period_seconds = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
      if(period_seconds <= 0)
         return false;

      const datetime now = TimeCurrent();
      const datetime from = now - (datetime)(period_seconds * MathMax(strategy_cooldown_bars * 4, strategy_cooldown_bars + 2));
      if(HistorySelect(from, now))
        {
         const int magic = QM_FrameworkMagic();
         const int deals = HistoryDealsTotal();
         for(int i = deals - 1; i >= 0; --i)
           {
            const ulong deal = HistoryDealGetTicket(i);
            if(deal == 0)
               continue;
            if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol)
               continue;
            if((int)HistoryDealGetInteger(deal, DEAL_MAGIC) != magic)
               continue;
            if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY) != DEAL_ENTRY_OUT)
               continue;

            const datetime exit_time = (datetime)HistoryDealGetInteger(deal, DEAL_TIME);
            const int bars_since_exit = (int)((now - exit_time) / period_seconds);
            if(bars_since_exit < strategy_cooldown_bars)
               return false;
            break;
           }
        }
     }

   const int needed = MathMax(strategy_range_lookback, strategy_volume_period) + 3;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 0, needed, rates); // perf-allowed: EntrySignal is called only after QM_IsNewBar().
   if(copied < needed)
      return false;

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const double open1 = rates[1].open;
   const double high1 = rates[1].high;
   const double low1 = rates[1].low;
   const double close1 = rates[1].close;
   const double range1 = high1 - low1;
   const double body1 = MathAbs(close1 - open1);
   if(open1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0 || close1 <= 0.0 || range1 <= 0.0)
      return false;
   if(body1 < strategy_body_min_pct * range1)
      return false;
   if(range1 < strategy_atr_multiplier * atr)
      return false;

   double volume_sum = 0.0;
   for(int i = 2; i < 2 + strategy_volume_period; ++i)
      volume_sum += (double)rates[i].tick_volume;
   const double average_volume = volume_sum / (double)strategy_volume_period;
   if(average_volume <= 0.0 || (double)rates[1].tick_volume < strategy_volume_spike_mult * average_volume)
      return false;

   double lower_recent = DBL_MAX;
   double upper_recent = -DBL_MAX;
   double close_sum = 0.0;
   for(int i = 2; i < 2 + strategy_range_lookback; ++i)
     {
      lower_recent = MathMin(lower_recent, rates[i].low);
      upper_recent = MathMax(upper_recent, rates[i].high);
      close_sum += rates[i].close;
     }
   if(lower_recent == DBL_MAX || upper_recent == -DBL_MAX)
      return false;
   const double pre_exhaustion_mean = close_sum / (double)strategy_range_lookback;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask <= bid)
      return false;

   const bool bullish_exhaustion = (close1 < open1 && close1 < lower_recent);
   const bool bearish_exhaustion = (close1 > open1 && close1 > upper_recent);
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const int expiry_seconds = PeriodSeconds((ENUM_TIMEFRAMES)_Period);

   if(bullish_exhaustion)
     {
      const double trigger = NormalizeDouble((high1 + close1) * 0.5, digits);
      const double entry = (ask >= trigger) ? ask : trigger;
      const double stop = NormalizeDouble(low1 - strategy_atr_stop_buffer * atr, digits);
      const double risk_distance = entry - stop;
      if(risk_distance <= 0.0)
         return false;
      if((ask - bid) > strategy_max_spread_stop_pct * risk_distance)
         return false;

      const double fixed_target = entry + strategy_target_r * risk_distance;
      double target = fixed_target;
      if(pre_exhaustion_mean > entry)
         target = MathMin(fixed_target, pre_exhaustion_mean);
      if(target <= entry)
         target = fixed_target;

      req.type = (ask >= trigger) ? QM_BUY : QM_BUY_STOP;
      req.price = (req.type == QM_BUY) ? 0.0 : trigger;
      req.sl = stop;
      req.tp = NormalizeDouble(target, digits);
      req.reason = "ATR_VOL_BULL_EXHAUST";
      req.expiration_seconds = (expiry_seconds > 0 && req.type == QM_BUY_STOP) ? expiry_seconds : 0;
      return true;
     }

   if(bearish_exhaustion)
     {
      const double trigger = NormalizeDouble((low1 + close1) * 0.5, digits);
      const double entry = (bid <= trigger) ? bid : trigger;
      const double stop = NormalizeDouble(high1 + strategy_atr_stop_buffer * atr, digits);
      const double risk_distance = stop - entry;
      if(risk_distance <= 0.0)
         return false;
      if((ask - bid) > strategy_max_spread_stop_pct * risk_distance)
         return false;

      const double fixed_target = entry - strategy_target_r * risk_distance;
      double target = fixed_target;
      if(pre_exhaustion_mean < entry)
         target = MathMax(fixed_target, pre_exhaustion_mean);
      if(target >= entry)
         target = fixed_target;

      req.type = (bid <= trigger) ? QM_SELL : QM_SELL_STOP;
      req.price = (req.type == QM_SELL) ? 0.0 : trigger;
      req.sl = stop;
      req.tp = NormalizeDouble(target, digits);
      req.reason = "ATR_VOL_BEAR_EXHAUST";
      req.expiration_seconds = (expiry_seconds > 0 && req.type == QM_SELL_STOP) ? expiry_seconds : 0;
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no break-even, trailing, or partial-close management.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int period_seconds = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   if(period_seconds <= 0 || strategy_time_exit_bars <= 0)
      return false;

   const int magic = QM_FrameworkMagic();
   const datetime now = TimeCurrent();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      const int bars_held = (int)((now - opened) / period_seconds);
      if(bars_held >= strategy_time_exit_bars)
         return true;
     }

   return false;
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
