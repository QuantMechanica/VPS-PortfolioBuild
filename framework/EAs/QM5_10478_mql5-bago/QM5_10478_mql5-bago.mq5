#property strict
#property version   "5.0"
#property description "QM5_10478 MQL5 Bago EMA/RSI Trend Filter"
// rework v2 2026-06-16: over-restrictive AND-chain — entry required EMA(5/12) cross AND
// RSI(21)/50 cross to coincide on the EXACT same bar. Card specifies RSI "in the same
// signal window" as a confirmation (Bago source uses RSI>50 / <50 as a directional
// filter at EMA-cross time, not a simultaneous RSI crossover). Relaxed RSI to a level
// confirmation on the cross bar; EMA cross + tunnel context remain the triggers. Keeps
// entry/exit symmetric and mechanical.

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails). The framework provides:
//
//   - QM_IsNewBar(sym="", tf=PERIOD_CURRENT)  ? closed-bar gate
//   - QM_ATR / QM_EMA / QM_SMA / QM_RSI / QM_MACD_Main / QM_MACD_Signal /
//     QM_ADX / QM_ADX_PlusDI / QM_ADX_MinusDI /
//     QM_BB_Upper / QM_BB_Middle / QM_BB_Lower    (from QM_Indicators.mqh)
//   - QM_TM_OpenPosition(req, ticket) / QM_TM_ClosePosition(ticket, reason)
//   - QM_TM_MoveToBreakEven / QM_TM_TrailATR / QM_TM_TrailStep / QM_TM_PartialClose
//   - QM_LotsForRisk(symbol, sl_points)        ? risk model lot sizing
//   - QM_StopFixedPips / QM_StopATR / QM_StopStructure / QM_StopVolatility
//   - QM_FrameworkHandleFridayClose / QM_KillSwitchCheck / QM_NewsAllowsTrade
//
// DO NOT
//   - Write per-EA IsNewBar() ? use QM_IsNewBar()
//   - Call iATR / iMA / iRSI / iMACD / iADX / iBands or CopyBuffer directly ?
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
input int    qm_ea_id                   = 10478;
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
// FW1 2026-05-23 ? Two-axis news filter per Vault Q09.
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
// FW2 2026-05-23 ? only populated by Q05 MED / Q06 HARSH stress setfiles.
// Default 0.0 = no rejection (Q02/Q03/Q04/Q07/Q08/Q09/Q10/Q13 backtests).
// Q06 HARSH sets to 0.10 (10% of entries randomly dropped before broker send,
// deterministic per qm_rng_seed). MED slip/spread/commission live in the
// tester groups file, not as EA inputs.
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_fast_ema_period   = 5;
input int    strategy_slow_ema_period   = 12;
input int    strategy_rsi_period        = 21;
input double strategy_rsi_midline       = 50.0;
input int    strategy_tunnel_ema_fast   = 144;
input int    strategy_tunnel_ema_slow   = 169;
input int    strategy_atr_period        = 14;
input double strategy_atr_sl_mult       = 1.2;
input int    strategy_swing_lookback    = 5;
input double strategy_atr_sl_cap_mult   = 2.5;
input double strategy_take_profit_rr    = 2.0;
input int    strategy_time_stop_bars    = 5;
input int    strategy_max_spread_points = 0;

// -----------------------------------------------------------------------------
// Strategy hooks ? implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only ? runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // No Trade Filter (time, spread, news): framework handles time/news gates;
   // this hook applies the card's default spread guard when configured.
   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points < 0 || spread_points > strategy_max_spread_points)
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

   if(strategy_fast_ema_period <= 0 ||
      strategy_slow_ema_period <= 0 ||
      strategy_rsi_period <= 0 ||
      strategy_tunnel_ema_fast <= 0 ||
      strategy_tunnel_ema_slow <= 0 ||
      strategy_atr_period <= 0 ||
      strategy_atr_sl_mult <= 0.0 ||
      strategy_atr_sl_cap_mult <= 0.0 ||
      strategy_take_profit_rr <= 0.0)
      return false;

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
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }

   const int warmup = MathMax(MathMax(strategy_tunnel_ema_fast, strategy_tunnel_ema_slow),
                              MathMax(strategy_slow_ema_period, strategy_rsi_period));
   if(Bars(_Symbol, (ENUM_TIMEFRAMES)_Period) < warmup + 3)
      return false;

   const double fast_1 = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_fast_ema_period, 1);
   const double fast_2 = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_fast_ema_period, 2);
   const double slow_1 = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_slow_ema_period, 1);
   const double slow_2 = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_slow_ema_period, 2);
   const double rsi_1 = QM_RSI(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_rsi_period, 1);
   const double rsi_2 = QM_RSI(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_rsi_period, 2);
   const double tunnel_a = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_tunnel_ema_fast, 1);
   const double tunnel_b = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_tunnel_ema_slow, 1);
   const double close_1 = iClose(_Symbol, (ENUM_TIMEFRAMES)_Period, 1);

   if(fast_1 <= 0.0 || fast_2 <= 0.0 || slow_1 <= 0.0 || slow_2 <= 0.0 ||
      rsi_1 <= 0.0 || rsi_2 <= 0.0 || tunnel_a <= 0.0 || tunnel_b <= 0.0 ||
      close_1 <= 0.0)
      return false;

   // rework v2 2026-06-16: EMA(5/12) cross is the trigger on the closed bar; RSI(21) acts
   // as a same-window directional confirmation (level, not a simultaneous crossover).
   const bool long_signal = (fast_2 <= slow_2 && fast_1 > slow_1 &&
                             rsi_1 > strategy_rsi_midline &&
                             close_1 > tunnel_a && close_1 > tunnel_b);
   const bool short_signal = (fast_2 >= slow_2 && fast_1 < slow_1 &&
                              rsi_1 < strategy_rsi_midline &&
                              close_1 < tunnel_a && close_1 < tunnel_b);
   if(!long_signal && !short_signal)
      return false;

   const QM_OrderType side = long_signal ? QM_BUY : QM_SELL;
   const double entry = QM_EntryMarketPrice(side);
   if(entry <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const double structure_stop = QM_StopStructure(_Symbol, side, entry, strategy_swing_lookback);
   double structure_distance = 0.0;
   if(structure_stop > 0.0)
      structure_distance = MathAbs(entry - structure_stop);

   double stop_distance = MathMax(atr * strategy_atr_sl_mult, structure_distance);
   stop_distance = MathMin(stop_distance, atr * strategy_atr_sl_cap_mult);
   if(stop_distance <= 0.0)
      return false;

   const double sl = QM_StopRulesStopFromDistance(_Symbol, side, entry, stop_distance);
   if(sl <= 0.0)
      return false;

   const double tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_take_profit_rr);
   if(tp <= 0.0)
      return false;

   req.type = side;
   req.sl = sl;
   req.tp = tp;
   req.reason = long_signal ? "BAGO_EMA_RSI_LONG" : "BAGO_EMA_RSI_SHORT";
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, partial close, or add-on logic.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   int signal = 0;
   if(strategy_fast_ema_period > 0 &&
      strategy_slow_ema_period > 0 &&
      strategy_rsi_period > 0 &&
      strategy_tunnel_ema_fast > 0 &&
      strategy_tunnel_ema_slow > 0)
     {
      const double fast_1 = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_fast_ema_period, 1);
      const double fast_2 = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_fast_ema_period, 2);
      const double slow_1 = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_slow_ema_period, 1);
      const double slow_2 = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_slow_ema_period, 2);
      const double rsi_1 = QM_RSI(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_rsi_period, 1);
      const double rsi_2 = QM_RSI(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_rsi_period, 2);
      const double tunnel_a = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_tunnel_ema_fast, 1);
      const double tunnel_b = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_tunnel_ema_slow, 1);
      const double close_1 = iClose(_Symbol, (ENUM_TIMEFRAMES)_Period, 1);

      if(fast_1 > 0.0 && fast_2 > 0.0 && slow_1 > 0.0 && slow_2 > 0.0 &&
         rsi_1 > 0.0 && rsi_2 > 0.0 && tunnel_a > 0.0 && tunnel_b > 0.0 &&
         close_1 > 0.0)
        {
         // rework v2 2026-06-16: mirror entry — EMA cross trigger + RSI level confirmation.
         if(fast_2 <= slow_2 && fast_1 > slow_1 &&
            rsi_1 > strategy_rsi_midline &&
            close_1 > tunnel_a && close_1 > tunnel_b)
            signal = 1;
         else if(fast_2 >= slow_2 && fast_1 < slow_1 &&
                 rsi_1 < strategy_rsi_midline &&
                 close_1 < tunnel_a && close_1 < tunnel_b)
            signal = -1;
        }
     }

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(position_type == POSITION_TYPE_BUY && signal < 0)
         return true;
      if(position_type == POSITION_TYPE_SELL && signal > 0)
         return true;

      if(strategy_time_stop_bars > 0)
        {
         const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
         const int bars_since_open = iBarShift(_Symbol, (ENUM_TIMEFRAMES)_Period, opened, false);
         if(bars_since_open >= strategy_time_stop_bars)
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
   // News Filter Hook: no card-specific override; central framework news mode applies.
   return false; // defer to QM_NewsAllowsTrade(...)
  }

// -----------------------------------------------------------------------------
// Framework wiring ? do NOT edit below this line unless you know why.
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
   // FW1 ? 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
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
   // per-tick recompute mistakes ? EntrySignal sees one new closed bar per
   // call, not every incoming tick.
   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 ? emit end-of-day equity snapshot if the day rolled
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

