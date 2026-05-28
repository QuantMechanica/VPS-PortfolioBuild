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
input int    qm_ea_id                   = 10185;
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
input ENUM_TIMEFRAMES strategy_signal_tf        = PERIOD_H1;
input ENUM_TIMEFRAMES strategy_bias_tf          = PERIOD_D1;
input int             strategy_tenkan_period   = 9;
input int             strategy_kijun_period    = 26;
input int             strategy_senkou_b_period = 52;
input int             strategy_displacement    = 26;
input int             strategy_setup_lookback  = 21;
input int             strategy_daily_ema       = 200;
input int             strategy_volume_sma      = 20;
input int             strategy_trail_lookback  = 5;
input int             strategy_atr_period      = 14;
input double          strategy_trail_atr_mult  = 3.0;
input double          strategy_initial_atr_cap = 2.5;

double Strategy_Midpoint(const ENUM_TIMEFRAMES tf, const int period, const int shift)
  {
   if(period <= 0 || shift < 0)
      return 0.0;

   double highest = 0.0;
   double lowest = 0.0;
   for(int i = shift; i < shift + period; ++i)
     {
      const double high = iHigh(_Symbol, tf, i);
      const double low = iLow(_Symbol, tf, i);
      if(high <= 0.0 || low <= 0.0)
         return 0.0;
      if(i == shift || high > highest)
         highest = high;
      if(i == shift || low < lowest)
         lowest = low;
     }

   return (highest + lowest) * 0.5;
  }

double Strategy_Tenkan(const int shift)
  {
   return Strategy_Midpoint(strategy_signal_tf, strategy_tenkan_period, shift);
  }

double Strategy_Kijun(const int shift)
  {
   return Strategy_Midpoint(strategy_signal_tf, strategy_kijun_period, shift);
  }

double Strategy_SenkouA(const int shift)
  {
   const int cloud_shift = shift + strategy_displacement;
   const double tenkan = Strategy_Tenkan(cloud_shift);
   const double kijun = Strategy_Kijun(cloud_shift);
   if(tenkan <= 0.0 || kijun <= 0.0)
      return 0.0;
   return (tenkan + kijun) * 0.5;
  }

double Strategy_SenkouB(const int shift)
  {
   return Strategy_Midpoint(strategy_signal_tf, strategy_senkou_b_period,
                            shift + strategy_displacement);
  }

bool Strategy_Cloud(const int shift, double &span_a, double &span_b,
                    double &senkou_min, double &senkou_max)
  {
   span_a = Strategy_SenkouA(shift);
   span_b = Strategy_SenkouB(shift);
   if(span_a <= 0.0 || span_b <= 0.0)
      return false;
   senkou_min = MathMin(span_a, span_b);
   senkou_max = MathMax(span_a, span_b);
   return true;
  }

bool Strategy_SetupMemory()
  {
   for(int shift = 1; shift <= strategy_setup_lookback; ++shift)
     {
      double span_a = 0.0, span_b = 0.0, senkou_min = 0.0, senkou_max = 0.0;
      if(!Strategy_Cloud(shift, span_a, span_b, senkou_min, senkou_max))
         continue;

      const double kijun = Strategy_Kijun(shift);
      const double close = iClose(_Symbol, strategy_signal_tf, shift);
      if(kijun > senkou_max && close > 0.0 && close < senkou_min)
         return true;
     }
   return false;
  }

bool Strategy_VolumeFilter()
  {
   if(strategy_volume_sma <= 0)
      return true;

   const long current_volume = iVolume(_Symbol, strategy_signal_tf, 1);
   if(current_volume <= 0)
      return false;

   double volume_sum = 0.0;
   for(int shift = 2; shift < 2 + strategy_volume_sma; ++shift)
     {
      const long volume = iVolume(_Symbol, strategy_signal_tf, shift);
      if(volume <= 0)
         return false;
      volume_sum += (double)volume;
     }

   return ((double)current_volume > volume_sum / (double)strategy_volume_sma);
  }

bool Strategy_BullishBias()
  {
   const double low = iLow(_Symbol, strategy_signal_tf, 1);
   const double ema = QM_EMA(_Symbol, strategy_bias_tf, strategy_daily_ema, 1);
   return (low > 0.0 && ema > 0.0 && low > ema);
  }

bool Strategy_Trigger()
  {
   const double tenkan_1 = Strategy_Tenkan(1);
   const double tenkan_2 = Strategy_Tenkan(2);
   const double kijun_1 = Strategy_Kijun(1);
   const double kijun_2 = Strategy_Kijun(2);
   const double close_1 = iClose(_Symbol, strategy_signal_tf, 1);
   const double close_2 = iClose(_Symbol, strategy_signal_tf, 2);
   if(tenkan_1 <= 0.0 || tenkan_2 <= 0.0 || kijun_1 <= 0.0 || kijun_2 <= 0.0 ||
      close_1 <= 0.0 || close_2 <= 0.0)
      return false;

   const bool tenkan_cross = (tenkan_2 <= kijun_2 && tenkan_1 > kijun_1);
   const bool kijun_reclaim = (close_2 < kijun_2 && close_1 > kijun_1);
   return (tenkan_cross || kijun_reclaim);
  }

double Strategy_TrailingStop()
  {
   double highest = 0.0;
   for(int shift = 1; shift <= strategy_trail_lookback; ++shift)
     {
      const double high = iHigh(_Symbol, strategy_signal_tf, shift);
      if(high <= 0.0)
         return 0.0;
      if(shift == 1 || high > highest)
         highest = high;
     }

   const double atr = QM_ATR(_Symbol, strategy_signal_tf, strategy_atr_period, 1);
   if(highest <= 0.0 || atr <= 0.0)
      return 0.0;

   return QM_StopRulesNormalizePrice(_Symbol, highest - strategy_trail_atr_mult * atr);
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
   double span_a = 0.0, span_b = 0.0, senkou_min = 0.0, senkou_max = 0.0;
   if(!Strategy_Cloud(1, span_a, span_b, senkou_min, senkou_max))
      return false;

   const double close = iClose(_Symbol, strategy_signal_tf, 1);
   const double high = iHigh(_Symbol, strategy_signal_tf, 1);
   const double low = iLow(_Symbol, strategy_signal_tf, 1);
   const double kijun = Strategy_Kijun(1);
   if(close <= 0.0 || high <= 0.0 || low <= 0.0 || kijun <= 0.0)
      return false;

   const bool outside_cloud = (close > senkou_max || close < senkou_min);
   const bool main_entry = close > senkou_max &&
                           span_a > span_b &&
                           Strategy_SetupMemory() &&
                           Strategy_VolumeFilter() &&
                           outside_cloud;
   const bool ultra_entry = close > senkou_max &&
                            low <= kijun &&
                            close > kijun &&
                            outside_cloud;

   if(!Strategy_BullishBias() || !Strategy_Trigger() || (!main_entry && !ultra_entry))
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double atr = QM_ATR(_Symbol, strategy_signal_tf, strategy_atr_period, 1);
   double sl = Strategy_TrailingStop();
   if(ask <= 0.0 || atr <= 0.0 || sl <= 0.0)
      return false;

   const double capped_sl = ask - strategy_initial_atr_cap * atr;
   if(sl < capped_sl)
      sl = capped_sl;
   sl = QM_StopRulesNormalizePrice(_Symbol, sl);
   if(sl <= 0.0 || sl >= ask)
      return false;

   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = main_entry ? "kumo_ichimoku_main_long" : "kumo_ichimoku_ultra_long";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   const double target_sl = Strategy_TrailingStop();
   if(target_sl <= 0.0)
      return;

   const int magic = QM_FrameworkMagic();
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY)
         continue;

      const double current_sl = PositionGetDouble(POSITION_SL);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid <= 0.0 || target_sl >= bid)
         continue;
      if(current_sl <= 0.0 || target_sl > current_sl + point * 0.5)
         QM_TM_MoveSL(ticket, target_sl, "kumo_high5_atr_trailing_stop");
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   bool has_position = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      has_position = true;
      break;
     }
   if(!has_position)
      return false;

   double span_a = 0.0, span_b = 0.0, senkou_min = 0.0, senkou_max = 0.0;
   if(!Strategy_Cloud(1, span_a, span_b, senkou_min, senkou_max))
      return false;

   const double close = iClose(_Symbol, strategy_signal_tf, 1);
   return (close > 0.0 && close < senkou_min);
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
