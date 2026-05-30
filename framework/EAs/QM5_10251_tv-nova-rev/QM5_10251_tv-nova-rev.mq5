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
input double strategy_squeeze_atr_mult     = 1.00;
input int    strategy_max_hold_bars        = 30;

double PercentileRange(const int lookback, const double pct)
  {
   if(lookback <= 1)
      return 0.0;

   double ranges[];
   ArrayResize(ranges, lookback);
   for(int i = 0; i < lookback; ++i)
     {
      const int shift = i + 1;
      const double hi = iHigh(_Symbol, _Period, shift);
      const double lo = iLow(_Symbol, _Period, shift);
      if(hi <= 0.0 || lo <= 0.0 || hi < lo)
         return 0.0;
      ranges[i] = hi - lo;
     }

   ArraySort(ranges);
   int idx = (int)MathFloor(((MathMax(0.0, MathMin(100.0, pct)) / 100.0) * (lookback - 1)) + 0.5);
   idx = MathMax(0, MathMin(lookback - 1, idx));
   return ranges[idx];
  }

bool ComputeBands(const int shift, double &fair, double &upper, double &lower, double &atr, double &width)
  {
   if(strategy_fair_period < 4 || strategy_atr_period < 1 || strategy_range_lookback < 2)
      return false;

   const double hma = QM_HMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_fair_period, shift);
   const double wma = QM_WMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_fair_period, shift);
   atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, shift);
   const double prange = PercentileRange(strategy_range_lookback, strategy_range_percentile);
   if(hma <= 0.0 || wma <= 0.0 || atr <= 0.0 || prange <= 0.0 || strategy_band_mult <= 0.0)
      return false;

   fair = 0.5 * hma + 0.5 * wma;
   width = strategy_band_mult * (prange + atr);
   upper = fair + width;
   lower = fair - width;
   return (fair > 0.0 && upper > lower);
  }

bool IsBullishReversalCandle()
  {
   const double open1 = iOpen(_Symbol, _Period, 1);
   const double close1 = iClose(_Symbol, _Period, 1);
   const double high1 = iHigh(_Symbol, _Period, 1);
   const double low1 = iLow(_Symbol, _Period, 1);
   const double open2 = iOpen(_Symbol, _Period, 2);
   const double close2 = iClose(_Symbol, _Period, 2);
   const double range = high1 - low1;
   if(range <= 0.0)
      return false;

   const double lower_wick = MathMin(open1, close1) - low1;
   const bool pin = (close1 > open1 && lower_wick > strategy_pin_wick_ratio * range);
   const bool engulf = (close1 > open1 && close2 < open2 && open1 <= close2 && close1 >= open2);
   return (pin || engulf);
  }

bool IsBearishReversalCandle()
  {
   const double open1 = iOpen(_Symbol, _Period, 1);
   const double close1 = iClose(_Symbol, _Period, 1);
   const double high1 = iHigh(_Symbol, _Period, 1);
   const double low1 = iLow(_Symbol, _Period, 1);
   const double open2 = iOpen(_Symbol, _Period, 2);
   const double close2 = iClose(_Symbol, _Period, 2);
   const double range = high1 - low1;
   if(range <= 0.0)
      return false;

   const double upper_wick = high1 - MathMax(open1, close1);
   const bool pin = (close1 < open1 && upper_wick > strategy_pin_wick_ratio * range);
   const bool engulf = (close1 < open1 && close2 > open2 && open1 >= close2 && close1 <= open2);
   return (pin || engulf);
  }

int CountBandTouches(const bool lower_side)
  {
   int touches = 0;
   const int bars = MathMax(1, strategy_touch_lookback);
   for(int shift = 1; shift <= bars; ++shift)
     {
      double fair = 0.0, upper = 0.0, lower = 0.0, atr = 0.0, width = 0.0;
      if(!ComputeBands(shift, fair, upper, lower, atr, width))
         continue;
      if(lower_side)
        {
         if(iLow(_Symbol, _Period, shift) <= lower)
            touches++;
        }
      else
        {
         if(iHigh(_Symbol, _Period, shift) >= upper)
            touches++;
        }
     }
   return touches;
  }

int SignalScore(const bool long_side,
                const double upper,
                const double lower,
                const double atr,
                const double width)
  {
   double fair_prev = 0.0, upper_prev = 0.0, lower_prev = 0.0, atr_prev = 0.0, width_prev = 0.0;
   if(!ComputeBands(2, fair_prev, upper_prev, lower_prev, atr_prev, width_prev))
      return 0;

   int score = 0;
   if(long_side)
     {
      const double penetration = lower - iLow(_Symbol, _Period, 1);
      if(penetration >= strategy_deep_penetration_atr * atr)
         score++;
     }
   else
     {
      const double penetration = iHigh(_Symbol, _Period, 1) - upper;
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

   double fair = 0.0, upper = 0.0, lower = 0.0, atr = 0.0, width = 0.0;
   if(!ComputeBands(1, fair, upper, lower, atr, width))
      return false;
   if(width < strategy_squeeze_atr_mult * atr)
      return false;

   const double high1 = iHigh(_Symbol, _Period, 1);
   const double low1 = iLow(_Symbol, _Period, 1);
   if(high1 <= 0.0 || low1 <= 0.0)
      return false;

   const int lower_touches = CountBandTouches(true);
   if(low1 <= lower &&
      lower_touches >= strategy_min_touches &&
      lower_touches <= strategy_max_touches &&
      SignalScore(true, upper, lower, atr, width) >= 2 &&
      IsBullishReversalCandle())
     {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = lower - strategy_sl_atr_mult * atr;
      req.tp = fair;
      req.reason = "NOVA_REV_LONG";
      return (req.sl > 0.0 && req.tp > SymbolInfoDouble(_Symbol, SYMBOL_ASK));
     }

   const int upper_touches = CountBandTouches(false);
   if(high1 >= upper &&
      upper_touches >= strategy_min_touches &&
      upper_touches <= strategy_max_touches &&
      SignalScore(false, upper, lower, atr, width) >= 2 &&
      IsBearishReversalCandle())
     {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = upper + strategy_sl_atr_mult * atr;
      req.tp = fair;
      req.reason = "NOVA_REV_SHORT";
      return (req.sl > 0.0 && req.tp < SymbolInfoDouble(_Symbol, SYMBOL_BID));
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
      const int bars_since_open = iBarShift(_Symbol, _Period, open_time, false);
      if(bars_since_open >= strategy_max_hold_bars)
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
