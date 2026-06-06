#property strict
#property version   "5.0"
#property description "QM5_10957 FTMO Multi-Timeframe Range Reversion"

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
input int    qm_ea_id                   = 10957;
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
input int    strategy_range_lookback_d1          = 60;
input int    strategy_atr_period                 = 14;
input int    strategy_ema_fast_period            = 50;
input int    strategy_ema_slow_period            = 200;
input int    strategy_rsi_period                 = 14;
input int    strategy_bb_period                  = 20;
input int    strategy_bb_return_lookback_bars    = 3;
input int    strategy_max_hold_h4_bars           = 20;
input double strategy_range_touch_atr_mult       = 0.35;
input double strategy_boundary_entry_atr_mult    = 0.25;
input double strategy_sl_atr_mult                = 0.50;
input double strategy_min_range_atr_mult         = 2.00;
input double strategy_max_range_atr_mult         = 8.00;
input double strategy_rsi_long_max               = 30.0;
input double strategy_rsi_short_min              = 70.0;
input double strategy_bb_deviation               = 2.0;
input double strategy_fallback_rr                = 2.0;
input double strategy_opposite_boundary_max_rr   = 3.0;
input double strategy_max_spread_stop_fraction   = 0.10;

// Card structural range logic needs closed OHLC bars. The framework calls
// Strategy_EntrySignal only after QM_IsNewBar(), so these reads are per-bar.
bool LoadClosedRates(const ENUM_TIMEFRAMES tf, const int count, MqlRates &rates[])
  {
   if(count <= 0)
      return false;
   ArraySetAsSeries(rates, true);
   // perf-allowed: closed-bar structural range read inside the framework new-bar gate.
   const int copied = CopyRates(_Symbol, tf, 1, count, rates);
   return (copied == count);
  }

double NormalizeStrategyPrice(const double price)
  {
   if(price <= 0.0)
      return 0.0;
   return NormalizeDouble(price, _Digits);
  }

bool HasOpenPositionForMagic()
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

bool GetD1Range(double &support, double &resistance, double &atr_d1)
  {
   support = 0.0;
   resistance = 0.0;
   atr_d1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr_d1 <= 0.0 || strategy_range_lookback_d1 < 2)
      return false;

   MqlRates d1[];
   if(!LoadClosedRates(PERIOD_D1, strategy_range_lookback_d1, d1))
      return false;

   double highest = -DBL_MAX;
   double lowest = DBL_MAX;
   for(int i = 0; i < strategy_range_lookback_d1; ++i)
     {
      highest = MathMax(highest, d1[i].high);
      lowest = MathMin(lowest, d1[i].low);
     }

   if(highest <= 0.0 || lowest <= 0.0 || highest <= lowest)
      return false;

   const double touch_tolerance = strategy_range_touch_atr_mult * atr_d1;
   int resistance_touches = 0;
   int support_touches = 0;
   for(int i = 0; i < strategy_range_lookback_d1; ++i)
     {
      if(d1[i].high >= highest - touch_tolerance)
         ++resistance_touches;
      if(d1[i].low <= lowest + touch_tolerance)
         ++support_touches;
     }

   if(resistance_touches < 2 || support_touches < 2)
      return false;

   const double range_width = highest - lowest;
   if(range_width < strategy_min_range_atr_mult * atr_d1 ||
      range_width > strategy_max_range_atr_mult * atr_d1)
      return false;

   support = lowest;
   resistance = highest;
   return true;
  }

bool ClosedBelowLowerBandRecently(const MqlRates &h4[])
  {
   for(int shift = 2; shift <= strategy_bb_return_lookback_bars + 1; ++shift)
     {
      const double lower = QM_BB_Lower(_Symbol, PERIOD_H4, strategy_bb_period, strategy_bb_deviation, shift);
      if(lower > 0.0 && h4[shift - 1].close < lower)
         return true;
     }
   return false;
  }

bool ClosedAboveUpperBandRecently(const MqlRates &h4[])
  {
   for(int shift = 2; shift <= strategy_bb_return_lookback_bars + 1; ++shift)
     {
      const double upper = QM_BB_Upper(_Symbol, PERIOD_H4, strategy_bb_period, strategy_bb_deviation, shift);
      if(upper > 0.0 && h4[shift - 1].close > upper)
         return true;
     }
   return false;
  }

bool StopDistanceAllowsSpread(const double entry_price, const double sl_price)
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double stop_distance = MathAbs(entry_price - sl_price);
   const double spread = ask - bid;
   if(stop_distance <= 0.0 || spread < 0.0)
      return false;
   return (spread <= strategy_max_spread_stop_fraction * stop_distance);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// No Trade Filter (time, spread, news): news is handled by the framework hook
// and spread is checked after planned stop distance is known in entry logic.
bool Strategy_NoTradeFilter()
  {
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

   if(HasOpenPositionForMagic())
      return false;

   if(strategy_atr_period <= 0 ||
      strategy_ema_fast_period <= 0 ||
      strategy_ema_slow_period <= 0 ||
      strategy_rsi_period <= 0 ||
      strategy_bb_period <= 0 ||
      strategy_bb_return_lookback_bars <= 0 ||
      strategy_max_hold_h4_bars <= 0)
      return false;

   double support = 0.0;
   double resistance = 0.0;
   double atr_d1 = 0.0;
   if(!GetD1Range(support, resistance, atr_d1))
      return false;

   const int h4_count = strategy_bb_return_lookback_bars + 1;
   MqlRates h4[];
   if(!LoadClosedRates(PERIOD_H4, h4_count, h4))
      return false;

   const double h4_close = h4[0].close;
   const double atr_h4 = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   const double ema_fast_d1 = QM_EMA(_Symbol, PERIOD_D1, strategy_ema_fast_period, 1);
   const double ema_slow_d1 = QM_EMA(_Symbol, PERIOD_D1, strategy_ema_slow_period, 1);
   const double rsi_h4 = QM_RSI(_Symbol, PERIOD_H4, strategy_rsi_period, 1);
   const double bb_lower_now = QM_BB_Lower(_Symbol, PERIOD_H4, strategy_bb_period, strategy_bb_deviation, 1);
   const double bb_upper_now = QM_BB_Upper(_Symbol, PERIOD_H4, strategy_bb_period, strategy_bb_deviation, 1);
   if(h4_close <= 0.0 || atr_h4 <= 0.0 || ema_fast_d1 <= 0.0 || ema_slow_d1 <= 0.0 ||
      rsi_h4 <= 0.0 || bb_lower_now <= 0.0 || bb_upper_now <= 0.0)
      return false;

   const double boundary_distance = strategy_boundary_entry_atr_mult * atr_h4;
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(ema_fast_d1 >= ema_slow_d1 &&
      MathAbs(h4_close - support) <= boundary_distance &&
      rsi_h4 < strategy_rsi_long_max &&
      h4_close >= bb_lower_now &&
      ClosedBelowLowerBandRecently(h4))
     {
      const double entry = ask;
      const double sl = support - strategy_sl_atr_mult * atr_h4;
      const double risk = entry - sl;
      const double opposite_distance = resistance - entry;
      if(entry <= 0.0 || risk <= 0.0 || opposite_distance <= 0.0)
         return false;
      if(!StopDistanceAllowsSpread(entry, sl))
         return false;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = NormalizeStrategyPrice(sl);
      req.tp = NormalizeStrategyPrice((opposite_distance > strategy_opposite_boundary_max_rr * risk)
                                      ? entry + strategy_fallback_rr * risk
                                      : resistance);
      req.reason = "FTMO_MTF_RANGE_LONG";
      return (req.sl > 0.0 && req.tp > 0.0);
     }

   if(ema_fast_d1 <= ema_slow_d1 &&
      MathAbs(h4_close - resistance) <= boundary_distance &&
      rsi_h4 > strategy_rsi_short_min &&
      h4_close <= bb_upper_now &&
      ClosedAboveUpperBandRecently(h4))
     {
      const double entry = bid;
      const double sl = resistance + strategy_sl_atr_mult * atr_h4;
      const double risk = sl - entry;
      const double opposite_distance = entry - support;
      if(entry <= 0.0 || risk <= 0.0 || opposite_distance <= 0.0)
         return false;
      if(!StopDistanceAllowsSpread(entry, sl))
         return false;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = NormalizeStrategyPrice(sl);
      req.tp = NormalizeStrategyPrice((opposite_distance > strategy_opposite_boundary_max_rr * risk)
                                      ? entry - strategy_fallback_rr * risk
                                      : support);
      req.reason = "FTMO_MTF_RANGE_SHORT";
      return (req.sl > 0.0 && req.tp > 0.0);
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no break-even, trailing stop, or partial close.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const int hold_seconds = strategy_max_hold_h4_bars * PeriodSeconds(PERIOD_H4);
   if(hold_seconds <= 0)
      return false;

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
      if(opened > 0 && now - opened >= hold_seconds)
         return true;
     }

   return false;
  }

// News Filter Hook: defer to the central high-impact news calendar gate.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   (void)broker_time;
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
