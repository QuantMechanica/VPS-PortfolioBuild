#property strict
#property version   "5.0"
#property description "QM5_10251 TradingView Nova Reversal Bands"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_10251 — TradingView Nova Reversal Bands
// -----------------------------------------------------------------------------
// Strategy card: QM5_10251_tv-nova-rev.md, G0 APPROVED 2026-05-19.
// Band approximation is per card P1 note: fair value is 0.5*HMA(50)+0.5*WMA(50);
// envelope uses 85th percentile closed-candle range plus ATR(14), multiplied by
// strategy_band_mult. Entry is next-bar market after closed-bar reversal.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10251;
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
input int    strategy_fair_period          = 50;
input int    strategy_atr_period           = 14;
input int    strategy_range_lookback       = 50;
input double strategy_range_percentile     = 85.0;
input double strategy_band_mult            = 2.4;
input double strategy_sl_atr_mult          = 0.25;
input int    strategy_touch_lookback       = 20;
input int    strategy_min_touches          = 1;
input int    strategy_max_touches          = 4;
input double strategy_pin_wick_ratio       = 0.50;
input double strategy_deep_penetration_atr = 0.10;
input int    strategy_max_hold_bars        = 30;
input double strategy_max_spread_points    = 0.0;

int Strategy_RangeLookback()
  {
   return (strategy_range_lookback < 2) ? 2 : strategy_range_lookback;
  }

int Strategy_TouchLookback()
  {
   return (strategy_touch_lookback < 1) ? 1 : strategy_touch_lookback;
  }

int Strategy_BarsNeeded()
  {
   const int range_need = Strategy_RangeLookback() + 2;
   const int touch_need = Strategy_TouchLookback() + 2;
   return (range_need > touch_need) ? range_need : touch_need;
  }

bool Strategy_LoadClosedBars(MqlRates &rates[])
  {
   const int needed = Strategy_BarsNeeded();
   ArrayResize(rates, needed);
   const int copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 1, needed, rates); // perf-allowed: Strategy_EntrySignal is called only after the skeleton QM_IsNewBar() gate.
   return (copied >= needed);
  }

double Strategy_PercentileRange(const MqlRates &rates[],
                                const int start_index,
                                const int lookback,
                                const double percentile)
  {
   if(lookback <= 1 || start_index < 0 || ArraySize(rates) < start_index + lookback)
      return 0.0;

   double ranges[];
   ArrayResize(ranges, lookback);
   for(int i = 0; i < lookback; ++i)
     {
      const MqlRates bar = rates[start_index + i];
      if(bar.high <= 0.0 || bar.low <= 0.0 || bar.high < bar.low)
         return 0.0;
      ranges[i] = bar.high - bar.low;
     }

   ArraySort(ranges);
   double pct = percentile;
   if(pct < 0.0)
      pct = 0.0;
   if(pct > 100.0)
      pct = 100.0;
   int idx = (int)MathFloor(((pct / 100.0) * (lookback - 1)) + 0.5);
   if(idx < 0)
      idx = 0;
   if(idx >= lookback)
      idx = lookback - 1;
   return ranges[idx];
  }

bool Strategy_ComputeBands(const MqlRates &rates[],
                           const int start_index,
                           const int indicator_shift,
                           double &fair,
                           double &upper,
                           double &lower,
                           double &atr,
                           double &width)
  {
   if(strategy_fair_period < 4 || strategy_atr_period < 1)
      return false;

   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   const double hma = QM_HMA(_Symbol, tf, strategy_fair_period, indicator_shift);
   const double wma = QM_WMA(_Symbol, tf, strategy_fair_period, indicator_shift);
   atr = QM_ATR(_Symbol, tf, strategy_atr_period, indicator_shift);
   const double prange = Strategy_PercentileRange(rates, start_index, Strategy_RangeLookback(), strategy_range_percentile);
   if(hma <= 0.0 || wma <= 0.0 || atr <= 0.0 || prange <= 0.0 || strategy_band_mult <= 0.0)
      return false;

   fair = 0.5 * hma + 0.5 * wma;
   width = strategy_band_mult * (prange + atr);
   upper = fair + width;
   lower = fair - width;
   return (fair > 0.0 && upper > lower);
  }

bool Strategy_BullishReversalCandle(const MqlRates &bar1, const MqlRates &bar2)
  {
   const double range = bar1.high - bar1.low;
   if(range <= 0.0)
      return false;

   const double lower_wick = MathMin(bar1.open, bar1.close) - bar1.low;
   const bool pin = (bar1.close > bar1.open && lower_wick > strategy_pin_wick_ratio * range);
   const bool engulf = (bar1.close > bar1.open &&
                        bar2.close < bar2.open &&
                        bar1.open <= bar2.close &&
                        bar1.close >= bar2.open);
   return (pin || engulf);
  }

bool Strategy_BearishReversalCandle(const MqlRates &bar1, const MqlRates &bar2)
  {
   const double range = bar1.high - bar1.low;
   if(range <= 0.0)
      return false;

   const double upper_wick = bar1.high - MathMax(bar1.open, bar1.close);
   const bool pin = (bar1.close < bar1.open && upper_wick > strategy_pin_wick_ratio * range);
   const bool engulf = (bar1.close < bar1.open &&
                        bar2.close > bar2.open &&
                        bar1.open >= bar2.close &&
                        bar1.close <= bar2.open);
   return (pin || engulf);
  }

int Strategy_CountBandTouches(const MqlRates &rates[],
                              const bool lower_side,
                              const double upper,
                              const double lower)
  {
   int touches = 0;
   const int bars = Strategy_TouchLookback();
   const int available = ArraySize(rates);
   for(int i = 0; i < bars && i < available; ++i)
     {
      if(lower_side)
        {
         if(rates[i].low <= lower)
            touches++;
        }
      else
        {
         if(rates[i].high >= upper)
            touches++;
        }
     }
   return touches;
  }

int Strategy_SignalScore(const MqlRates &signal_bar,
                         const bool long_side,
                         const double upper,
                         const double lower,
                         const double atr,
                         const double width,
                         const double atr_prev,
                         const double width_prev)
  {
   int score = 0;
   if(long_side)
     {
      const double penetration = lower - signal_bar.low;
      if(penetration >= strategy_deep_penetration_atr * atr)
         score++;
     }
   else
     {
      const double penetration = signal_bar.high - upper;
      if(penetration >= strategy_deep_penetration_atr * atr)
         score++;
     }

   if(atr > atr_prev)
      score++;
   if(width > width_prev)
      score++;
   return score;
  }

bool HasOpenPositionForThisEA()
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
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(strategy_max_spread_points > 0.0)
     {
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(point <= 0.0 || ask <= 0.0 || bid <= 0.0)
         return true;
      if((ask - bid) / point > strategy_max_spread_points)
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

   if(HasOpenPositionForThisEA())
      return false;

   MqlRates rates[];
   if(!Strategy_LoadClosedBars(rates))
      return false;
   const MqlRates bar1 = rates[0];
   const MqlRates bar2 = rates[1];

   double fair = 0.0, upper = 0.0, lower = 0.0, atr = 0.0, width = 0.0;
   if(!Strategy_ComputeBands(rates, 0, 1, fair, upper, lower, atr, width))
      return false;

   double fair_prev = 0.0, upper_prev = 0.0, lower_prev = 0.0, atr_prev = 0.0, width_prev = 0.0;
   if(!Strategy_ComputeBands(rates, 1, 2, fair_prev, upper_prev, lower_prev, atr_prev, width_prev))
      return false;
   if(width <= width_prev && atr <= atr_prev)
      return false;

   const int lower_touches = Strategy_CountBandTouches(rates, true, upper, lower);
   if(bar1.low <= lower &&
      lower_touches >= strategy_min_touches &&
      lower_touches <= strategy_max_touches &&
      Strategy_SignalScore(bar1, true, upper, lower, atr, width, atr_prev, width_prev) >= 2 &&
      Strategy_BullishReversalCandle(bar1, bar2))
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(ask <= 0.0 || fair <= ask)
         return false;
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = NormalizeDouble(lower - strategy_sl_atr_mult * atr, _Digits);
      req.tp = NormalizeDouble(fair, _Digits);
      req.reason = "NOVA_REV_LONG";
      return (req.sl > 0.0 && req.sl < ask && req.tp > ask);
     }

   const int upper_touches = Strategy_CountBandTouches(rates, false, upper, lower);
   if(bar1.high >= upper &&
      upper_touches >= strategy_min_touches &&
      upper_touches <= strategy_max_touches &&
      Strategy_SignalScore(bar1, false, upper, lower, atr, width, atr_prev, width_prev) >= 2 &&
      Strategy_BearishReversalCandle(bar1, bar2))
     {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid <= 0.0 || fair >= bid)
         return false;
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = NormalizeDouble(upper + strategy_sl_atr_mult * atr, _Digits);
      req.tp = NormalizeDouble(fair, _Digits);
      req.reason = "NOVA_REV_SHORT";
      return (req.sl > bid && req.tp > 0.0 && req.tp < bid);
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, partial close, or break-even management.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if(strategy_max_hold_bars <= 0)
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
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int period_seconds = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
      if(open_time > 0 && period_seconds > 0 && TimeCurrent() - open_time >= strategy_max_hold_bars * period_seconds)
         return true;
     }
   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(broker_time <= 0)
      return false;
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
