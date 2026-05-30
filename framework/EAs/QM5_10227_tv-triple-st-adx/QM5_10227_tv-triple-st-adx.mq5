#property strict
#property version   "5.0"
#property description "QM5_10227 Triple Supertrend EMA ADX"

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
input int    qm_ea_id                   = 10227;
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
input ENUM_TIMEFRAMES strategy_signal_tf = PERIOD_CURRENT;
input int    strategy_supertrend_1_atr_period = 10;
input double strategy_supertrend_1_mult       = 1.0;
input int    strategy_supertrend_2_atr_period = 11;
input double strategy_supertrend_2_mult       = 2.0;
input int    strategy_supertrend_3_atr_period = 12;
input double strategy_supertrend_3_mult       = 3.0;
input bool   strategy_use_filters             = true;
input int    strategy_adx_period              = 14;
input double strategy_adx_threshold           = 20.0;
input int    strategy_ema_period              = 200;
input int    strategy_supertrend_warmup_bars  = 180;
input double strategy_emergency_stop_atr_mult = 2.0;
input int    strategy_max_spread_points       = 0;

struct Strategy_STState
  {
   int dir_1;
   int dir_2;
  };

int g_last_entry_dir = 0;
int g_cached_exit_dir = 0;

ENUM_TIMEFRAMES StrategyTF()
  {
   return (strategy_signal_tf == PERIOD_CURRENT) ? (ENUM_TIMEFRAMES)_Period : strategy_signal_tf;
  }

bool Strategy_HasOpenPosition(ENUM_POSITION_TYPE &ptype)
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }
   return false;
  }

bool Strategy_SupertrendState(const int atr_period,
                              const double multiplier,
                              Strategy_STState &state)
  {
   state.dir_1 = 0;
   state.dir_2 = 0;
   const ENUM_TIMEFRAMES tf = StrategyTF();
   const int warmup = MathMax(strategy_supertrend_warmup_bars, atr_period + 5);
   if(Bars(_Symbol, tf) <= warmup + 3 || atr_period <= 0 || multiplier <= 0.0)
      return false;

   double final_upper = 0.0;
   double final_lower = 0.0;
   int prev_dir = 1;

   for(int shift = warmup; shift >= 1; --shift)
     {
      const double high = iHigh(_Symbol, tf, shift);
      const double low = iLow(_Symbol, tf, shift);
      const double close = iClose(_Symbol, tf, shift);
      const double prev_close = iClose(_Symbol, tf, shift + 1);
      const double atr = QM_ATR(_Symbol, tf, atr_period, shift);
      if(high <= 0.0 || low <= 0.0 || close <= 0.0 || prev_close <= 0.0 || atr <= 0.0)
         return false;

      const double mid = (high + low) * 0.5;
      const double basic_upper = mid + multiplier * atr;
      const double basic_lower = mid - multiplier * atr;

      if(shift == warmup)
        {
         final_upper = basic_upper;
         final_lower = basic_lower;
         prev_dir = (close >= mid) ? 1 : -1;
        }
      else
        {
         final_upper = (basic_upper < final_upper || prev_close > final_upper) ? basic_upper : final_upper;
         final_lower = (basic_lower > final_lower || prev_close < final_lower) ? basic_lower : final_lower;

         if(close > final_upper)
            prev_dir = 1;
         else if(close < final_lower)
            prev_dir = -1;
        }

      if(shift == 2)
         state.dir_2 = prev_dir;
      if(shift == 1)
         state.dir_1 = prev_dir;
     }

   return (state.dir_1 != 0 && state.dir_2 != 0);
  }

bool Strategy_ReadTripleSupertrend(Strategy_STState &st1,
                                   Strategy_STState &st2,
                                   Strategy_STState &st3)
  {
   return Strategy_SupertrendState(strategy_supertrend_1_atr_period, strategy_supertrend_1_mult, st1) &&
          Strategy_SupertrendState(strategy_supertrend_2_atr_period, strategy_supertrend_2_mult, st2) &&
          Strategy_SupertrendState(strategy_supertrend_3_atr_period, strategy_supertrend_3_mult, st3);
  }

int Strategy_AgreementDir(const Strategy_STState &st1,
                          const Strategy_STState &st2,
                          const Strategy_STState &st3,
                          const bool previous_bar)
  {
   const int d1 = previous_bar ? st1.dir_2 : st1.dir_1;
   const int d2 = previous_bar ? st2.dir_2 : st2.dir_1;
   const int d3 = previous_bar ? st3.dir_2 : st3.dir_1;
   if(d1 > 0 && d2 > 0 && d3 > 0)
      return 1;
   if(d1 < 0 && d2 < 0 && d3 < 0)
      return -1;
   return 0;
  }

int Strategy_FirstReversalDir(const Strategy_STState &st1,
                              const Strategy_STState &st2,
                              const Strategy_STState &st3,
                              const int position_dir)
  {
   if(position_dir > 0 && (st1.dir_1 < 0 || st2.dir_1 < 0 || st3.dir_1 < 0))
      return -1;
   if(position_dir < 0 && (st1.dir_1 > 0 || st2.dir_1 > 0 || st3.dir_1 > 0))
      return 1;
   return 0;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(strategy_max_spread_points > 0)
     {
      const long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread > strategy_max_spread_points)
         return true;
     }
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

   Strategy_STState st1;
   Strategy_STState st2;
   Strategy_STState st3;
   if(!Strategy_ReadTripleSupertrend(st1, st2, st3))
      return false;

   ENUM_POSITION_TYPE ptype;
   if(Strategy_HasOpenPosition(ptype))
     {
      const int pos_dir = (ptype == POSITION_TYPE_BUY) ? 1 : -1;
      g_cached_exit_dir = Strategy_FirstReversalDir(st1, st2, st3, pos_dir);
      return false;
     }

   g_cached_exit_dir = 0;

   const int current_dir = Strategy_AgreementDir(st1, st2, st3, false);
   const int previous_dir = Strategy_AgreementDir(st1, st2, st3, true);
   if(current_dir == 0 || current_dir == previous_dir || current_dir == g_last_entry_dir)
      return false;

   const ENUM_TIMEFRAMES tf = StrategyTF();
   const double close_1 = iClose(_Symbol, tf, 1);
   if(close_1 <= 0.0)
      return false;

   if(strategy_use_filters)
     {
      const double adx = QM_ADX(_Symbol, tf, strategy_adx_period, 1);
      const double ema = QM_EMA(_Symbol, tf, strategy_ema_period, 1);
      if(adx < strategy_adx_threshold || ema <= 0.0)
         return false;
      if(current_dir > 0 && close_1 <= ema)
         return false;
      if(current_dir < 0 && close_1 >= ema)
         return false;
     }

   const double atr = QM_ATR(_Symbol, tf, strategy_supertrend_1_atr_period, 1);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr <= 0.0 || point <= 0.0 || ask <= 0.0 || bid <= 0.0 || strategy_emergency_stop_atr_mult <= 0.0)
      return false;

   if(current_dir > 0)
     {
      req.type = QM_BUY;
      req.sl = ask - strategy_emergency_stop_atr_mult * atr;
      req.reason = "TRIPLE_ST_ADX_LONG";
     }
   else
     {
      req.type = QM_SELL;
      req.sl = bid + strategy_emergency_stop_atr_mult * atr;
      req.reason = "TRIPLE_ST_ADX_SHORT";
     }

   const double entry_price = (current_dir > 0) ? ask : bid;
   const double sl_points = MathAbs(entry_price - req.sl) / point;
   if(sl_points <= 0.0 || QM_LotsForRisk(_Symbol, sl_points) <= 0.0)
      return false;

   g_last_entry_dir = current_dir;
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, or partial management.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   return (g_cached_exit_dir != 0);
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
