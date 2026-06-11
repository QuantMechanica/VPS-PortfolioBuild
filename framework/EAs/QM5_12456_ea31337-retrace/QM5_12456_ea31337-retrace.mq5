#property strict
#property version   "5.0"
#property description "QM5_12456 EA31337 Ichimoku pivot retracement"

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
input int    qm_ea_id                   = 12456;
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
input double strategy_max_spread_pips     = 4.0;
input int    strategy_signal_shift        = 1;
input int    strategy_pivot_shift         = 1;
input int    strategy_tenkan_period       = 30;
input int    strategy_kijun_period        = 10;
input int    strategy_senkou_b_period     = 30;
input double strategy_signal_open_level   = 4.0;
input int    strategy_signal_open_method  = 0;
input double strategy_close_loss_pips     = 80.0;
input double strategy_close_profit_pips   = 80.0;
input int    strategy_close_after_bars    = 30;
input double strategy_price_stop_level    = 2.0;
input int    strategy_atr_period          = 14;
input double strategy_atr_sl_mult         = 1.5;

struct StrategyPivotLevels
  {
   double pp;
   double r1;
   double r2;
   double r3;
   double r4;
   double s1;
   double s2;
   double s3;
   double s4;
   double range;
  };

int g_last_retrace_signal = 0;

double Strategy_PipSize()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return 0.0;

   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const int pip_factor = (digits == 3 || digits == 5) ? 10 : 1;
   return point * pip_factor;
  }

double Strategy_NormalizePrice(const double price)
  {
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   return NormalizeDouble(price, digits);
  }

bool Strategy_ReadRate(const ENUM_TIMEFRAMES tf, const int shift, MqlRates &rate)
  {
   MqlRates rates[1];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, tf, shift, 1, rates) != 1) // perf-allowed: bounded fixed-shift OHLC read for D1 pivot math; no QM OHLC reader exists.
      return false;

   rate = rates[0];
   return (rate.high > 0.0 && rate.low > 0.0 && rate.close > 0.0 && rate.high > rate.low);
  }

bool Strategy_ClassicPivots(const int daily_shift, StrategyPivotLevels &levels, MqlRates &day)
  {
   if(daily_shift < 1 || !Strategy_ReadRate(PERIOD_D1, daily_shift, day))
      return false;

   levels.range = day.high - day.low;
   if(levels.range <= 0.0)
      return false;

   const bool bull = (day.close > day.open);
   const bool bear = (day.close < day.open);
   if(!bull && !bear)
      return false;

   const double applied = bull ? day.high : day.low;
   levels.pp = applied;
   levels.r1 = (2.0 * levels.pp) - day.low;
   levels.r2 = levels.pp + levels.range;
   levels.r3 = levels.pp + (levels.range * 2.0);
   levels.r4 = levels.pp + (levels.range * 3.0);
   levels.s1 = (2.0 * levels.pp) - day.high;
   levels.s2 = levels.pp - levels.range;
   levels.s3 = levels.pp - (levels.range * 2.0);
   levels.s4 = levels.pp - (levels.range * 3.0);

   return (levels.r4 > levels.r3 &&
           levels.r3 > levels.r2 &&
           levels.r2 > levels.r1 &&
           levels.r1 >= levels.pp &&
           levels.pp >= levels.s1 &&
           levels.s1 > levels.s2 &&
           levels.s2 > levels.s3 &&
           levels.s3 > levels.s4);
  }

double Strategy_IchimokuLine(const int shift)
  {
   return QM_Ichimoku_TenkanSen(_Symbol,
                                (ENUM_TIMEFRAMES)_Period,
                                strategy_tenkan_period,
                                strategy_kijun_period,
                                strategy_senkou_b_period,
                                shift);
  }

double Strategy_MinSupportDistance(const StrategyPivotLevels &levels, const double value)
  {
   double dist = MathAbs(value - levels.s1);
   dist = MathMin(dist, MathAbs(value - levels.s2));
   dist = MathMin(dist, MathAbs(value - levels.s3));
   dist = MathMin(dist, MathAbs(value - levels.s4));
   return dist;
  }

bool Strategy_MethodExtremePass(const int signal, const double line0)
  {
   if((strategy_signal_open_method & 1) == 0)
      return true;

   double extreme = line0;
   for(int shift = strategy_signal_shift + 1; shift <= strategy_signal_shift + 3; ++shift)
     {
      const double line = Strategy_IchimokuLine(shift);
      if(line <= 0.0)
         return false;
      extreme = (signal > 0) ? MathMax(extreme, line) : MathMin(extreme, line);
     }

   return (MathAbs(extreme - line0) <= (_Point * 0.1));
  }

int Strategy_CurrentSignal(StrategyPivotLevels &levels)
  {
   MqlRates day;
   if(strategy_signal_shift < 1 || !Strategy_ClassicPivots(strategy_pivot_shift, levels, day))
      return 0;

   const double line0 = Strategy_IchimokuLine(strategy_signal_shift);
   const double line1 = Strategy_IchimokuLine(strategy_signal_shift + 1);
   if(line0 <= 0.0 || line1 <= 0.0)
      return 0;

   const double level_value = levels.range * MathAbs(strategy_signal_open_level) / 100.0;
   if(level_value <= 0.0 || Strategy_MinSupportDistance(levels, line0) > level_value)
      return 0;

   if(day.close > day.open && line0 > line1 && Strategy_MethodExtremePass(1, line0))
      return 1;

   if(day.close < day.open && line0 < line1 && Strategy_MethodExtremePass(-1, line0))
      return -1;

   return 0;
  }

bool Strategy_HaveOpenPosition(ENUM_POSITION_TYPE &position_type, datetime &open_time)
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

      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

double Strategy_PivotStop(const int signal, const StrategyPivotLevels &levels, const double entry)
  {
   const double offset = levels.range * MathAbs(strategy_price_stop_level) / 100.0;
   if(signal > 0)
     {
      double stop = 0.0;
      if(entry > levels.s1)
         stop = levels.s1 - offset;
      else if(entry > levels.s2)
         stop = levels.s2 - offset;
      else if(entry > levels.s3)
         stop = levels.s3 - offset;
      else if(entry > levels.s4)
         stop = levels.s4 - offset;
      return stop;
     }

   double stop = 0.0;
   if(entry < levels.r1)
      stop = levels.r1 + offset;
   else if(entry < levels.r2)
      stop = levels.r2 + offset;
   else if(entry < levels.r3)
      stop = levels.r3 + offset;
   else if(entry < levels.r4)
      stop = levels.r4 + offset;
   return stop;
  }

double Strategy_PivotTakeProfit(const int signal, const StrategyPivotLevels &levels, const double entry)
  {
   const double offset = levels.range * MathAbs(strategy_price_stop_level) / 100.0;
   if(signal > 0)
     {
      if(entry < levels.r1)
         return levels.r1 - offset;
      if(entry < levels.r2)
         return levels.r2 - offset;
      if(entry < levels.r3)
         return levels.r3 - offset;
      if(entry < levels.r4)
         return levels.r4 - offset;
      return 0.0;
     }

   if(entry > levels.s1)
      return levels.s1 + offset;
   if(entry > levels.s2)
      return levels.s2 + offset;
   if(entry > levels.s3)
      return levels.s3 + offset;
   if(entry > levels.s4)
      return levels.s4 + offset;
   return 0.0;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   const double pip = Strategy_PipSize();
   if(pip <= 0.0 || strategy_max_spread_pips <= 0.0)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask < bid)
      return true;

   return ((ask - bid) / pip > strategy_max_spread_pips);
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

   StrategyPivotLevels levels;
   const int signal = Strategy_CurrentSignal(levels);
   g_last_retrace_signal = signal;
   if(signal == 0)
      return false;

   ENUM_POSITION_TYPE existing_type;
   datetime existing_open;
   if(Strategy_HaveOpenPosition(existing_type, existing_open))
      return false;

   const QM_OrderType side = (signal > 0) ? QM_BUY : QM_SELL;
   const double entry = (signal > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                     : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double pip = Strategy_PipSize();
   if(pip <= 0.0)
      return false;

   double stop = Strategy_PivotStop(signal, levels, entry);
   if((signal > 0 && (stop <= 0.0 || stop >= entry)) ||
      (signal < 0 && (stop <= 0.0 || stop <= entry)))
      stop = QM_StopATR(_Symbol, side, entry, strategy_atr_period, strategy_atr_sl_mult);

   if((signal > 0 && (stop <= 0.0 || stop >= entry)) ||
      (signal < 0 && (stop <= 0.0 || stop <= entry)))
     {
      const double loss_dist = MathMax(1.0, strategy_close_loss_pips) * pip;
      stop = (signal > 0) ? (entry - loss_dist) : (entry + loss_dist);
     }

   double take = Strategy_PivotTakeProfit(signal, levels, entry);
   if((signal > 0 && (take <= entry)) || (signal < 0 && (take >= entry || take <= 0.0)))
     {
      const double profit_dist = MathMax(1.0, strategy_close_profit_pips) * pip;
      take = (signal > 0) ? (entry + profit_dist) : (entry - profit_dist);
     }

   req.type = side;
   req.price = 0.0;
   req.sl = Strategy_NormalizePrice(stop);
   req.tp = Strategy_NormalizePrice(take);
   req.reason = (signal > 0) ? "EA31337_RETRACE_ICHIMOKU_SUPPORT_LONG"
                             : "EA31337_RETRACE_ICHIMOKU_SUPPORT_SHORT";
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Source default uses fixed SL/TP and time/opposite-signal exits only.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE position_type;
   datetime open_time;
   if(!Strategy_HaveOpenPosition(position_type, open_time))
      return false;

   if(strategy_close_after_bars > 0 && open_time > 0)
     {
      const int seconds_per_bar = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
      if(seconds_per_bar > 0 && TimeCurrent() - open_time >= strategy_close_after_bars * seconds_per_bar)
         return true;
     }

   if(position_type == POSITION_TYPE_BUY && g_last_retrace_signal < 0)
      return true;
   if(position_type == POSITION_TYPE_SELL && g_last_retrace_signal > 0)
      return true;

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
