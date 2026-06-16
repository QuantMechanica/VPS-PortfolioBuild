#property strict
#property version   "5.0"
#property description "QM5_10829 TradingView MACD 200 EMA Support/Resistance"
// rework v2 2026-06-16 - S/R touch over-restriction fixed: signal bar may sit near ANY confirmed
// pivot in max_age window (state), not only the single most-recent pivot. ~0 trades -> tradeable.

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails). The framework provides:
//
//   - QM_IsNewBar(sym="", tf=PERIOD_CURRENT)  - closed-bar gate
//   - QM_ATR / QM_EMA / QM_SMA / QM_RSI / QM_MACD_Main / QM_MACD_Signal /
//     QM_ADX / QM_ADX_PlusDI / QM_ADX_MinusDI /
//     QM_BB_Upper / QM_BB_Middle / QM_BB_Lower    (from QM_Indicators.mqh)
//   - QM_TM_OpenPosition(req, ticket) / QM_TM_ClosePosition(ticket, reason)
//   - QM_TM_MoveToBreakEven / QM_TM_TrailATR / QM_TM_TrailStep / QM_TM_PartialClose
//   - QM_LotsForRisk(symbol, sl_points)        - risk model lot sizing
//   - QM_StopFixedPips / QM_StopATR / QM_StopStructure / QM_StopVolatility
//   - QM_FrameworkHandleFridayClose / QM_KillSwitchCheck / QM_NewsAllowsTrade
//
// DO NOT
//   - Write per-EA IsNewBar() - use QM_IsNewBar()
//   - Call iATR / iMA / iRSI / iMACD / iADX / iBands or CopyBuffer directly -
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
input int    qm_ea_id                   = 10829;
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
// FW1 2026-05-23 - Two-axis news filter per Vault Q09.
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
// FW2 2026-05-23 - only populated by Q05 MED / Q06 HARSH stress setfiles.
// Default 0.0 = no rejection (Q02/Q03/Q04/Q07/Q08/Q09/Q10/Q13 backtests).
// Q06 HARSH sets to 0.10 (10% of entries randomly dropped before broker send,
// deterministic per qm_rng_seed). MED slip/spread/commission live in the
// tester groups file, not as EA inputs.
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_ema_period          = 200;
input int    strategy_macd_fast           = 12;
input int    strategy_macd_slow           = 26;
input int    strategy_macd_signal         = 9;
input bool   strategy_use_sr_filter       = true;
input int    strategy_pivot_strength      = 5;
input int    strategy_sr_max_age_bars     = 50;
input int    strategy_atr_period          = 14;
input double strategy_atr_touch_mult      = 0.20;
input int    strategy_stop_swing_lookback = 20;
input int    strategy_ema_buffer_ticks    = 20;
input double strategy_take_profit_rr      = 1.50;
input int    strategy_max_spread_points   = 0;

// -----------------------------------------------------------------------------
// Strategy hooks - implement these against the card mechanically.
// -----------------------------------------------------------------------------

bool Strategy_GetOurPosition(ENUM_POSITION_TYPE &position_type)
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

      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }

   return false;
  }

bool Strategy_CopyBars(MqlRates &rates[], const int bars_needed)
  {
   if(bars_needed <= 0)
      return false;

   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 0, bars_needed, rates); // perf-allowed: confirmed pivot/swing scan runs only from Strategy_EntrySignal after framework QM_IsNewBar().
   return (copied >= bars_needed);
  }

bool Strategy_IsPivotLow(const MqlRates &rates[], const int shift, const int strength)
  {
   const double price = rates[shift].low;
   if(price <= 0.0)
      return false;

   for(int k = 1; k <= strength; ++k)
     {
      if(rates[shift - k].low <= price)
         return false;
      if(rates[shift + k].low < price)
         return false;
     }
   return true;
  }

bool Strategy_IsPivotHigh(const MqlRates &rates[], const int shift, const int strength)
  {
   const double price = rates[shift].high;
   if(price <= 0.0)
      return false;

   for(int k = 1; k <= strength; ++k)
     {
      if(rates[shift - k].high >= price)
         return false;
      if(rates[shift + k].high > price)
         return false;
     }
   return true;
  }

bool Strategy_FindRecentPivot(const MqlRates &rates[],
                              const bool want_low,
                              const int strength,
                              const int max_age,
                              int &out_shift,
                              double &out_price)
  {
   out_shift = -1;
   out_price = 0.0;

   const int first_confirmed = strength + 1;
   const int last_shift = MathMax(first_confirmed, max_age);
   const int available = ArraySize(rates) - strength - 1;
   const int final_shift = MathMin(last_shift, available);
   for(int shift = first_confirmed; shift <= final_shift; ++shift)
     {
      const bool ok = want_low ? Strategy_IsPivotLow(rates, shift, strength)
                               : Strategy_IsPivotHigh(rates, shift, strength);
      if(!ok)
         continue;

      out_shift = shift;
      out_price = want_low ? rates[shift].low : rates[shift].high;
      return true;
     }

   return false;
  }

// rework v2 2026-06-16 - S/R touch is a STATE over recent levels, not a single most-recent
// pivot: scan every confirmed pivot within max_age and pass if the signal bar trades within
// ATR tolerance of ANY of them. The old single-most-recent-pivot check made the S/R filter a
// third near-impossible same-bar coincidence on top of the MACD cross + EMA side, producing
// ~0 trades. This restores the source's "price is at a horizontal S/R level" semantics.
bool Strategy_SRTouchPasses(const MqlRates &rates[], const bool is_long)
  {
   if(!strategy_use_sr_filter)
      return true;

   const int strength = MathMax(1, strategy_pivot_strength);
   const int max_age = MathMax(strength + 1, strategy_sr_max_age_bars);

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(atr <= 0.0 || strategy_atr_touch_mult < 0.0)
      return false;
   const double tolerance = atr * strategy_atr_touch_mult;
   const double probe = is_long ? rates[1].low : rates[1].high;

   const int first_confirmed = strength + 1;
   const int available = ArraySize(rates) - strength - 1;
   const int final_shift = MathMin(MathMax(first_confirmed, max_age), available);
   for(int shift = first_confirmed; shift <= final_shift; ++shift)
     {
      const bool ok = is_long ? Strategy_IsPivotLow(rates, shift, strength)
                              : Strategy_IsPivotHigh(rates, shift, strength);
      if(!ok)
         continue;
      const double level = is_long ? rates[shift].low : rates[shift].high;
      if(MathAbs(probe - level) <= tolerance)
         return true;
     }
   return false;
  }

double Strategy_SwingStop(const MqlRates &rates[], const bool is_long)
  {
   const int strength = MathMax(1, strategy_pivot_strength);
   const int lookback = MathMax(strength + 1, strategy_stop_swing_lookback);
   int pivot_shift = -1;
   double pivot_price = 0.0;
   if(Strategy_FindRecentPivot(rates, is_long, strength, lookback, pivot_shift, pivot_price))
      return QM_StopRulesNormalizePrice(_Symbol, pivot_price);
   return 0.0;
  }

double Strategy_EmaFallbackStop(const QM_OrderType side)
  {
   const double ema = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_period, 1, PRICE_CLOSE);
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(ema <= 0.0 || tick_size <= 0.0 || strategy_ema_buffer_ticks <= 0)
      return 0.0;

   const double buffer = tick_size * strategy_ema_buffer_ticks;
   if(side == QM_BUY)
      return QM_StopRulesNormalizePrice(_Symbol, ema - buffer);
   return QM_StopRulesNormalizePrice(_Symbol, ema + buffer);
  }

bool Strategy_StopDistancePasses(const double entry, const double sl)
  {
   if(entry <= 0.0 || sl <= 0.0 || entry == sl)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;

   const long min_stop_points = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const double stop_points = MathAbs(entry - sl) / point;
   if(min_stop_points > 0 && stop_points < (double)min_stop_points)
      return false;

   return true;
  }

// No Trade Filter (time, spread, news): central framework handles time/news/
// Friday filters; this hook enforces only the optional spread ceiling.
bool Strategy_NoTradeFilter()
  {
   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points < 0 || spread_points > strategy_max_spread_points)
         return true;
     }

   return false;
  }

// Trade Entry: price close relative to EMA(200), MACD/signal cross in the
// card's zero-line zone, optional confirmed pivot touch, swing/EMA stop, 1.5R TP.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_ema_period <= 0 ||
      strategy_macd_fast <= 0 ||
      strategy_macd_slow <= strategy_macd_fast ||
      strategy_macd_signal <= 0 ||
      strategy_atr_period <= 0 ||
      strategy_take_profit_rr <= 0.0)
      return false;

   ENUM_POSITION_TYPE existing_type = POSITION_TYPE_BUY;
   if(Strategy_GetOurPosition(existing_type))
      return false;

   const int strength = MathMax(1, strategy_pivot_strength);
   const int window = MathMax(strategy_sr_max_age_bars, strategy_stop_swing_lookback) + strength + 4;
   MqlRates rates[];
   if(!Strategy_CopyBars(rates, window))
      return false;

   const double close_1 = rates[1].close;
   const double ema_1 = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_period, 1, PRICE_CLOSE);
   const double macd_1 = QM_MACD_Main(_Symbol, (ENUM_TIMEFRAMES)_Period,
                                      strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1, PRICE_CLOSE);
   const double sig_1 = QM_MACD_Signal(_Symbol, (ENUM_TIMEFRAMES)_Period,
                                       strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1, PRICE_CLOSE);
   const double macd_2 = QM_MACD_Main(_Symbol, (ENUM_TIMEFRAMES)_Period,
                                      strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 2, PRICE_CLOSE);
   const double sig_2 = QM_MACD_Signal(_Symbol, (ENUM_TIMEFRAMES)_Period,
                                       strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 2, PRICE_CLOSE);
   if(close_1 <= 0.0 || ema_1 <= 0.0)
      return false;

   bool is_long = false;
   bool is_short = false;
   if(close_1 > ema_1 && macd_2 <= sig_2 && macd_1 > sig_1 && macd_1 < 0.0)
      is_long = true;
   if(close_1 < ema_1 && macd_2 >= sig_2 && macd_1 < sig_1 && macd_1 > 0.0)
      is_short = true;
   if(!is_long && !is_short)
      return false;

   if(!Strategy_SRTouchPasses(rates, is_long))
      return false;

   const QM_OrderType side = is_long ? QM_BUY : QM_SELL;
   const double entry = QM_EntryMarketPrice(side);
   if(entry <= 0.0)
      return false;

   double sl = Strategy_SwingStop(rates, is_long);
   if(sl <= 0.0 ||
      (is_long && sl >= entry) ||
      (is_short && sl <= entry))
      sl = Strategy_EmaFallbackStop(side);

   if(sl <= 0.0 ||
      (is_long && sl >= entry) ||
      (is_short && sl <= entry) ||
      !Strategy_StopDistancePasses(entry, sl))
      return false;

   const double tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_take_profit_rr);
   if(tp <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = is_long ? "TV_MACD200_SR_LONG" : "TV_MACD200_SR_SHORT";
   return true;
  }

// Trade Management: the card specifies no trailing, break-even, partial close,
// or pyramiding logic.
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close: the baseline has no discretionary exits beyond SL/TP.
bool Strategy_ExitSignal()
  {
   return false;
  }

// News Filter Hook: no card-specific override; central framework news mode applies.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade(...)
  }

// -----------------------------------------------------------------------------
// Framework wiring - do NOT edit below this line unless you know why.
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
   // FW1 - 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
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
   // per-tick recompute mistakes - EntrySignal sees one new closed bar per
   // call, not every incoming tick.
   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 - emit end-of-day equity snapshot if the day rolled
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
