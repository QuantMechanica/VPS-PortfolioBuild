#property strict
#property version   "5.0"
#property description "QM5_11187 Freqtrade ADX CCI stochastic reversal"

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
input int    qm_ea_id                   = 11187;
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
input int    strategy_adx_fast_period       = 14;
input int    strategy_adx_slow_period       = 35;
input double strategy_adx_fast_min          = 50.0;
input double strategy_adx_slow_min          = 26.0;
input double strategy_exit_adx_slow_max     = 25.0;
input int    strategy_cci_period            = 14;
input double strategy_cci_entry_max         = -100.0;
input int    strategy_fast_stoch_k          = 5;
input int    strategy_fast_stoch_d          = 3;
input int    strategy_fast_stoch_slowing    = 3;
input int    strategy_slow_stoch_k          = 50;
input int    strategy_slow_stoch_d          = 3;
input int    strategy_slow_stoch_slowing    = 3;
input double strategy_fast_oversold         = 20.0;
input double strategy_slow_oversold         = 30.0;
input double strategy_fast_exit_overbought  = 70.0;
input int    strategy_ema_exit_period       = 5;
input int    strategy_volume_mean_period    = 12;
input double strategy_volume_mean_min       = 0.75;
input double strategy_min_close             = 0.000001;
input int    strategy_atr_stop_period       = 14;
input double strategy_atr_stop_mult         = 2.0;
input double strategy_max_spread_stop_frac  = 0.08;
input double strategy_roi_0m_pct            = 5.0;
input double strategy_roi_20m_pct           = 4.0;
input double strategy_roi_30m_pct           = 3.0;
input double strategy_roi_60m_pct           = 1.0;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   const long spread_points_raw = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(spread_points_raw < 0 || point <= 0.0)
      return true;

   const double atr = QM_ATR(_Symbol, PERIOD_CURRENT, strategy_atr_stop_period, 1);
   const double stop_distance = atr * strategy_atr_stop_mult;
   if(atr <= 0.0 || stop_distance <= 0.0 || !MathIsValidNumber(stop_distance))
      return true;

   const double spread_price = (double)spread_points_raw * point;
   if(spread_price > stop_distance * strategy_max_spread_stop_frac)
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
   req.reason = "FT_ADX_STOCH_LONG";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_volume_mean_period <= 0)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_CURRENT, 1, strategy_volume_mean_period, rates);
   if(copied < strategy_volume_mean_period)
      return false;

   double volume_sum = 0.0;
   for(int i = 0; i < copied; ++i)
      volume_sum += (double)rates[i].tick_volume;
   const double volume_mean = volume_sum / (double)copied;
   if(volume_mean <= strategy_volume_mean_min)
      return false;

   const double close1 = rates[0].close;
   if(close1 <= strategy_min_close)
      return false;

   const double adx_fast = QM_ADX(_Symbol, PERIOD_CURRENT, strategy_adx_fast_period, 1);
   const double adx_slow = QM_ADX(_Symbol, PERIOD_CURRENT, strategy_adx_slow_period, 1);
   const double cci = QM_CCI(_Symbol, PERIOD_CURRENT, strategy_cci_period, 1);
   const double fast_k_1 = QM_Stoch_K(_Symbol, PERIOD_CURRENT, strategy_fast_stoch_k,
                                      strategy_fast_stoch_d, strategy_fast_stoch_slowing, 1);
   const double fast_d_1 = QM_Stoch_D(_Symbol, PERIOD_CURRENT, strategy_fast_stoch_k,
                                      strategy_fast_stoch_d, strategy_fast_stoch_slowing, 1);
   const double fast_k_2 = QM_Stoch_K(_Symbol, PERIOD_CURRENT, strategy_fast_stoch_k,
                                      strategy_fast_stoch_d, strategy_fast_stoch_slowing, 2);
   const double fast_d_2 = QM_Stoch_D(_Symbol, PERIOD_CURRENT, strategy_fast_stoch_k,
                                      strategy_fast_stoch_d, strategy_fast_stoch_slowing, 2);
   const double slow_k_2 = QM_Stoch_K(_Symbol, PERIOD_CURRENT, strategy_slow_stoch_k,
                                      strategy_slow_stoch_d, strategy_slow_stoch_slowing, 2);
   const double slow_d_2 = QM_Stoch_D(_Symbol, PERIOD_CURRENT, strategy_slow_stoch_k,
                                      strategy_slow_stoch_d, strategy_slow_stoch_slowing, 2);

   if(adx_fast == EMPTY_VALUE || adx_slow == EMPTY_VALUE || cci == EMPTY_VALUE ||
      fast_k_1 == EMPTY_VALUE || fast_d_1 == EMPTY_VALUE ||
      fast_k_2 == EMPTY_VALUE || fast_d_2 == EMPTY_VALUE ||
      slow_k_2 == EMPTY_VALUE || slow_d_2 == EMPTY_VALUE)
      return false;

   if(!(adx_fast > strategy_adx_fast_min || adx_slow > strategy_adx_slow_min))
      return false;
   if(cci >= strategy_cci_entry_max)
      return false;
   if(fast_k_2 >= strategy_fast_oversold || fast_d_2 >= strategy_fast_oversold)
      return false;
   if(slow_k_2 >= strategy_slow_oversold || slow_d_2 >= strategy_slow_oversold)
      return false;
   if(!(fast_k_2 < fast_d_2 && fast_k_1 > fast_d_1))
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(ask <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, QM_BUY, ask, strategy_atr_stop_period, strategy_atr_stop_mult);
   if(req.sl <= 0.0 || req.sl >= ask)
      return false;

   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no break-even, trailing, partial close, or add-on logic.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   bool has_position = false;
   datetime open_time = 0;
   double open_price = 0.0;
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      has_position = true;
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      break;
     }

   if(!has_position || position_type != POSITION_TYPE_BUY || open_price <= 0.0)
      return false;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(bid <= 0.0)
      return false;

   const int age_minutes = (int)((TimeCurrent() - open_time) / 60);
   double roi_threshold = strategy_roi_0m_pct;
   if(age_minutes >= 60)
      roi_threshold = strategy_roi_60m_pct;
   else if(age_minutes >= 30)
      roi_threshold = strategy_roi_30m_pct;
   else if(age_minutes >= 20)
      roi_threshold = strategy_roi_20m_pct;

   const double profit_pct = ((bid - open_price) / open_price) * 100.0;
   if(profit_pct >= roi_threshold)
      return true;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_CURRENT, 1, 1, rates) != 1) // perf-allowed: single closed-bar close read for source exit condition.
      return false;

   const double adx_slow = QM_ADX(_Symbol, PERIOD_CURRENT, strategy_adx_slow_period, 1);
   const double fast_k_1 = QM_Stoch_K(_Symbol, PERIOD_CURRENT, strategy_fast_stoch_k,
                                      strategy_fast_stoch_d, strategy_fast_stoch_slowing, 1);
   const double fast_d_1 = QM_Stoch_D(_Symbol, PERIOD_CURRENT, strategy_fast_stoch_k,
                                      strategy_fast_stoch_d, strategy_fast_stoch_slowing, 1);
   const double fast_k_2 = QM_Stoch_K(_Symbol, PERIOD_CURRENT, strategy_fast_stoch_k,
                                      strategy_fast_stoch_d, strategy_fast_stoch_slowing, 2);
   const double fast_d_2 = QM_Stoch_D(_Symbol, PERIOD_CURRENT, strategy_fast_stoch_k,
                                      strategy_fast_stoch_d, strategy_fast_stoch_slowing, 2);
   const double ema5 = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_ema_exit_period, 1);

   if(adx_slow == EMPTY_VALUE || fast_k_1 == EMPTY_VALUE || fast_d_1 == EMPTY_VALUE ||
      fast_k_2 == EMPTY_VALUE || fast_d_2 == EMPTY_VALUE || ema5 == EMPTY_VALUE)
      return false;

   return (adx_slow < strategy_exit_adx_slow_max &&
           (fast_k_1 > strategy_fast_exit_overbought || fast_d_1 > strategy_fast_exit_overbought) &&
           fast_k_2 < fast_d_2 &&
           rates[0].close > ema5);
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
