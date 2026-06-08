#property strict
#property version   "5.0"
#property description "QM5_11209 ft-cci-cmf"

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
input int    qm_ea_id                   = 11209;
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
input int    strategy_cci_slow_period      = 170;
input int    strategy_cci_fast_period      = 34;
input int    strategy_mfi_period           = 14;
input double strategy_mfi_entry            = 25.0;
input int    strategy_cmf_period           = 20;
input double strategy_cmf_entry            = -0.10;
input double strategy_cmf_exit             = 0.30;
input int    strategy_m5_sma_fast_period   = 25;
input int    strategy_m5_sma_mid_period    = 50;
input int    strategy_m5_sma_exit_period   = 100;
input int    strategy_m5_sma_slow_period   = 200;
input int    strategy_atr_period           = 14;
input double strategy_atr_stop_mult        = 1.50;
input double strategy_source_stop_pct      = 2.00;
input double strategy_roi_target_pct       = 10.00;
input double strategy_max_spread_stop_pct  = 6.00;

double g_strategy_mfi_last = 0.0;
double g_strategy_cmf_last = 0.0;
double g_strategy_close_last = 0.0;
bool   g_strategy_state_ready = false;
bool   g_strategy_exit_signal = false;

bool Strategy_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
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

bool Strategy_RefreshClosedBarState()
  {
   g_strategy_state_ready = false;
   g_strategy_exit_signal = false;
   g_strategy_mfi_last = 0.0;
   g_strategy_cmf_last = 0.0;
   g_strategy_close_last = 0.0;

   if(strategy_mfi_period < 1 || strategy_cmf_period < 1)
      return false;

   const int needed = (int)MathMax((double)strategy_mfi_period + 1.0,
                                  (double)strategy_cmf_period);
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 1, needed, rates); // perf-allowed: closed-bar tick-volume MFI/CMF window, called only from framework new-bar entry hook.
   if(copied < needed)
      return false;

   g_strategy_close_last = rates[0].close;
   if(g_strategy_close_last <= 0.0)
      return false;

   double positive_flow = 0.0;
   double negative_flow = 0.0;
   for(int i = 0; i < strategy_mfi_period; ++i)
     {
      if(rates[i].tick_volume <= 0 || rates[i + 1].tick_volume <= 0)
         return false;

      const double typical_now = (rates[i].high + rates[i].low + rates[i].close) / 3.0;
      const double typical_prev = (rates[i + 1].high + rates[i + 1].low + rates[i + 1].close) / 3.0;
      const double raw_flow = typical_now * (double)rates[i].tick_volume;
      if(typical_now > typical_prev)
         positive_flow += raw_flow;
      else if(typical_now < typical_prev)
         negative_flow += raw_flow;
     }

   if(negative_flow <= 0.0)
      g_strategy_mfi_last = 100.0;
   else if(positive_flow <= 0.0)
      g_strategy_mfi_last = 0.0;
   else
      g_strategy_mfi_last = 100.0 - (100.0 / (1.0 + positive_flow / negative_flow));

   double mfv_sum = 0.0;
   double volume_sum = 0.0;
   for(int i = 0; i < strategy_cmf_period; ++i)
     {
      if(rates[i].tick_volume <= 0)
         return false;

      const double range = rates[i].high - rates[i].low;
      const double multiplier = (range > 0.0)
                                ? (((rates[i].close - rates[i].low) - (rates[i].high - rates[i].close)) / range)
                                : 0.0;
      const double volume = (double)rates[i].tick_volume;
      mfv_sum += multiplier * volume;
      volume_sum += volume;
     }

   if(volume_sum <= 0.0)
      return false;
   g_strategy_cmf_last = mfv_sum / volume_sum;

   const double cci_slow = QM_CCI(_Symbol, PERIOD_CURRENT, strategy_cci_slow_period, 1);
   const double cci_fast = QM_CCI(_Symbol, PERIOD_CURRENT, strategy_cci_fast_period, 1);
   const double sma25 = QM_SMA(_Symbol, PERIOD_M5, strategy_m5_sma_fast_period, 1, PRICE_CLOSE);
   const double sma50 = QM_SMA(_Symbol, PERIOD_M5, strategy_m5_sma_mid_period, 1, PRICE_CLOSE);
   const double sma100 = QM_SMA(_Symbol, PERIOD_M5, strategy_m5_sma_exit_period, 1, PRICE_CLOSE);
   if(sma25 <= 0.0 || sma50 <= 0.0 || sma100 <= 0.0)
      return false;

   g_strategy_exit_signal = (cci_slow > 100.0 &&
                             cci_fast > 100.0 &&
                             g_strategy_cmf_last > strategy_cmf_exit &&
                             sma100 < sma50 &&
                             sma50 < sma25);
   g_strategy_state_ready = true;
   return true;
  }

double Strategy_SourceStopCap(const double entry)
  {
   if(entry <= 0.0 || strategy_source_stop_pct <= 0.0)
      return 0.0;
   return QM_StopRulesNormalizePrice(_Symbol, entry * (1.0 - strategy_source_stop_pct / 100.0));
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(bid <= 0.0 || ask <= 0.0 || point <= 0.0 || ask <= bid)
      return true;

   const double atr = QM_ATR(_Symbol, PERIOD_CURRENT, strategy_atr_period, 1);
   if(atr <= 0.0 || strategy_atr_stop_mult <= 0.0)
      return true;

   const double planned_stop_points = (atr * strategy_atr_stop_mult) / point;
   const double spread_points = (ask - bid) / point;
   if(planned_stop_points <= 0.0)
      return true;

   if(spread_points > planned_stop_points * (strategy_max_spread_stop_pct / 100.0))
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
   req.reason = "FT_CCI_CMF_LONG";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!Strategy_RefreshClosedBarState())
      return false;

   if(Strategy_HasOpenPosition())
      return false;

   const double cci_slow = QM_CCI(_Symbol, PERIOD_CURRENT, strategy_cci_slow_period, 1);
   const double cci_fast = QM_CCI(_Symbol, PERIOD_CURRENT, strategy_cci_fast_period, 1);
   if(cci_slow >= -100.0 || cci_fast >= -100.0)
      return false;

   if(g_strategy_cmf_last >= strategy_cmf_entry)
      return false;

   if(g_strategy_mfi_last >= strategy_mfi_entry)
      return false;

   const double sma25 = QM_SMA(_Symbol, PERIOD_M5, strategy_m5_sma_fast_period, 1, PRICE_CLOSE);
   const double sma50 = QM_SMA(_Symbol, PERIOD_M5, strategy_m5_sma_mid_period, 1, PRICE_CLOSE);
   const double sma200 = QM_SMA(_Symbol, PERIOD_M5, strategy_m5_sma_slow_period, 1, PRICE_CLOSE);
   if(sma25 <= 0.0 || sma50 <= 0.0 || sma200 <= 0.0)
      return false;

   if(sma50 <= sma25)
      return false;

   if(sma200 >= g_strategy_close_last)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || point <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_CURRENT, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   double sl = QM_StopATRFromValue(_Symbol, QM_BUY, ask, atr, strategy_atr_stop_mult);
   const double cap_sl = Strategy_SourceStopCap(ask);
   if(cap_sl > 0.0 && (sl <= 0.0 || sl < cap_sl))
      sl = cap_sl;
   if(sl <= 0.0 || sl >= ask)
      return false;

   const double sl_points = MathAbs(ask - sl) / point;
   if(sl_points <= 0.0 || QM_LotsForRisk(_Symbol, sl_points) <= 0.0)
      return false;

   req.sl = sl;
   req.tp = QM_StopRulesNormalizePrice(_Symbol, ask * (1.0 + strategy_roi_target_pct / 100.0));
   if(req.tp <= ask)
      req.tp = 0.0;

   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, partial, or break-even management.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   return g_strategy_state_ready && g_strategy_exit_signal;
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
