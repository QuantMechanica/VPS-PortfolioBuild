#property strict
#property version   "5.0"
#property description "QM5_10990 ftmo-woodcci — Woodies CCI Trend-State (H1, long+short)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_10990 ftmo-woodcci
// -----------------------------------------------------------------------------
// Source: FTMO "Trading the Woodies CCI System - COMPLETE Guide" (2018).
// Card: artifacts/cards_approved/QM5_10990_ftmo-woodcci.md (g0_status APPROVED).
//
// Mechanics (long+short, H1, closed-bar reads at shift 1):
//   Trend CCI(20) STATE : closed ABOVE/BELOW zero for 6 consecutive H1 bars.
//   LSMA(25) slope STATE: linear-regression endpoint rising/falling over the
//                         last 3 closed bars (lsma1>lsma2>lsma3 for long).
//   Turbo CCI(6) TRIGGER: crosses zero on the trigger bar, OR has been on the
//                         trade side of zero for no more than turbo_max_bars.
//   Chop FILTER         : Trend CCI did NOT cross zero more than chop_max_cross
//                         times in the prior chop_lookback (20) bars.
//   Vol  FILTER         : skip if ATR(14) is below its atr_pctile-th percentile
//                         over the last atr_pctile_lookback (250) bars.
//   Stop                : long  = entry - sl_atr_mult*ATR(14)
//                         short = entry + sl_atr_mult*ATR(14).
//   Take profit         : tp_rr (=2.0R) multiple of the stop distance.
//   Exit                : (a) Trend CCI closes back across zero AGAINST the
//                             position, OR
//                         (b) LSMA slope flips against the position for 2
//                             consecutive closed bars, OR
//                         (c) time exit after time_exit_bars (48) H1 bars.
//   Spread guard        : entry skips only a genuinely wide spread >
//                         spread_median_mult x the 20-bar median spread
//                         (fail-open on .DWX 0 spread).
//
// LSMA has no dedicated QM_* reader; it is a least-squares (linear-regression)
// endpoint. The closed-form regression below is bespoke structural math the
// framework cannot supply — it runs on the closed-bar path only and reads a
// bounded window of closed bars (// perf-allowed).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10990;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_trend_cci_period   = 20;    // Trend CCI period
input int    strategy_turbo_cci_period   = 6;     // Turbo CCI period
input int    strategy_lsma_period        = 25;    // LSMA (least-squares MA) period
input int    strategy_trend_bars         = 6;     // consecutive Trend-CCI bars one side of zero
input int    strategy_turbo_max_bars     = 3;     // Turbo CCI may already be on-side for <= this
input int    strategy_chop_lookback      = 20;    // bars scanned for the chop filter
input int    strategy_chop_max_cross     = 3;     // max Trend-CCI zero crossings allowed in lookback
input int    strategy_atr_period         = 14;    // ATR period (filter / stop)
input double strategy_atr_pctile         = 20.0;  // skip if ATR below this percentile ...
input int    strategy_atr_pctile_lookback = 250;  // ... over this many closed bars
input double strategy_sl_atr_mult        = 1.5;   // stop distance = mult * ATR
input double strategy_tp_rr              = 2.0;    // take profit = RR multiple of the stop
input int    strategy_time_exit_bars     = 48;    // time exit after this many H1 bars
input int    strategy_spread_lookback    = 20;    // bars for the median-spread reference
input double strategy_spread_median_mult = 1.5;   // skip if spread > this x median spread

// -----------------------------------------------------------------------------
// LSMA helper — least-squares (linear-regression) endpoint at a given shift.
// Returns the projected value of the regression line over `period` closing
// prices ending at bar `shift`. Bespoke structural math; closed-bar path only.
// -----------------------------------------------------------------------------
double Woodcci_LSMA(const int period, const int shift)
  {
   if(period < 2)
      return 0.0;
   // x runs 0..period-1 across the window (oldest=0 .. newest=period-1).
   const double n      = (double)period;
   const double sum_x  = n * (n - 1.0) / 2.0;
   const double sum_xx = (n - 1.0) * n * (2.0 * n - 1.0) / 6.0;
   double sum_y  = 0.0;
   double sum_xy = 0.0;
   for(int i = 0; i < period; ++i)
     {
      // newest closing price (x=period-1) sits at chart shift = `shift`.
      const int    chart_shift = shift + (period - 1 - i);
      const double price = iClose(_Symbol, _Period, chart_shift); // perf-allowed: bounded LSMA window
      if(price <= 0.0)
         return 0.0;
      sum_y  += price;
      sum_xy += (double)i * price;
     }
   const double denom = n * sum_xx - sum_x * sum_x;
   if(MathAbs(denom) < 1e-12)
      return 0.0;
   const double slope     = (n * sum_xy - sum_x * sum_y) / denom;
   const double intercept = (sum_y - slope * sum_x) / n;
   // endpoint = regression value at x = period-1 (the most recent bar).
   return intercept + slope * (n - 1.0);
  }

// LSMA slope sign over the 3 most recent closed bars ending at `shift`.
// +1 strictly rising, -1 strictly falling, 0 otherwise.
int Woodcci_LSMASlopeSign(const int shift)
  {
   const double l0 = Woodcci_LSMA(strategy_lsma_period, shift);     // newest
   const double l1 = Woodcci_LSMA(strategy_lsma_period, shift + 1);
   const double l2 = Woodcci_LSMA(strategy_lsma_period, shift + 2); // oldest of the 3
   if(l0 <= 0.0 || l1 <= 0.0 || l2 <= 0.0)
      return 0;
   if(l0 > l1 && l1 > l2)
      return 1;
   if(l0 < l1 && l1 < l2)
      return -1;
   return 0;
  }

// Count Trend-CCI zero crossings within the prior `lookback` closed bars
// (between shift 1 and shift lookback). Used by the chop filter.
int Woodcci_TrendZeroCrossings(const int lookback)
  {
   int crossings = 0;
   for(int s = 1; s <= lookback; ++s)
     {
      const double c_new = QM_CCI(_Symbol, _Period, strategy_trend_cci_period, s);
      const double c_old = QM_CCI(_Symbol, _Period, strategy_trend_cci_period, s + 1);
      if((c_new > 0.0 && c_old <= 0.0) || (c_new < 0.0 && c_old >= 0.0))
         ++crossings;
     }
   return crossings;
  }

// True if ATR(14) at shift 1 is below its `pctile`-th percentile over the
// last `lookback` closed ATR values (low-volatility skip).
bool Woodcci_ATRBelowPercentile()
  {
   const int lookback = strategy_atr_pctile_lookback;
   if(lookback < 10)
      return false;
   const double atr_now = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_now <= 0.0)
      return false; // no ATR yet — defer, do not skip
   int below = 0;
   int valid = 0;
   for(int s = 1; s <= lookback; ++s)
     {
      const double a = QM_ATR(_Symbol, _Period, strategy_atr_period, s);
      if(a <= 0.0)
         continue;
      ++valid;
      if(a < atr_now)
         ++below;
     }
   if(valid < 10)
      return false; // not enough history yet — do not skip
   const double rank_pct = 100.0 * (double)below / (double)valid;
   return (rank_pct < strategy_atr_pctile);
  }

// Entry-only spread filter. The NoTrade hook stays O(1); this bounded median
// check runs only after the framework closed-bar gate reaches EntrySignal.
bool Woodcci_CurrentSpreadTooWide()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double spread = ask - bid;
   if(spread <= 0.0)
      return false; // .DWX modeled spread can be zero; never block on that.

   const int want = strategy_spread_lookback;
   if(want < 3)
      return false;

   MqlRates rates[];
   const int got = CopyRates(_Symbol, _Period, 1, want, rates); // perf-allowed: EntrySignal is closed-bar gated
   if(got < 3)
      return false;

   double spreads_pts[];
   ArrayResize(spreads_pts, got);
   int valid = 0;
   for(int i = 0; i < got; ++i)
     {
      const double sp = (double)rates[i].spread;
      if(sp > 0.0)
        {
         spreads_pts[valid] = sp;
         ++valid;
        }
     }
   if(valid < 3)
      return false;

   ArrayResize(spreads_pts, valid);
   ArraySort(spreads_pts);

   double median_pts = 0.0;
   if(valid % 2 == 1)
      median_pts = spreads_pts[valid / 2];
   else
      median_pts = 0.5 * (spreads_pts[valid / 2 - 1] + spreads_pts[valid / 2]);

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || median_pts <= 0.0)
      return false;

   return (spread > strategy_spread_median_mult * median_pts * point);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Historical spread/regime/signal work is on the
// closed-bar path in Strategy_EntrySignal. Fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;
   if(ask < bid)
      return true;
   return false; // zero or normal positive spread remains tradeable
  }

// Long+short entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Volatility floor: skip low-ATR regimes ---
   if(Woodcci_ATRBelowPercentile())
      return false;

   // --- Spread guard: skip only genuinely wide current spread ---
   if(Woodcci_CurrentSpreadTooWide())
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   // --- Chop filter: too many Trend-CCI zero crossings recently => skip ---
   if(Woodcci_TrendZeroCrossings(strategy_chop_lookback) > strategy_chop_max_cross)
      return false;

   // --- Trend CCI(20) STATE: N consecutive closed bars one side of zero ---
   bool trend_up   = true;
   bool trend_down = true;
   for(int s = 1; s <= strategy_trend_bars; ++s)
     {
      const double tc = QM_CCI(_Symbol, _Period, strategy_trend_cci_period, s);
      if(!(tc > 0.0))
         trend_up = false;
      if(!(tc < 0.0))
         trend_down = false;
     }
   if(!trend_up && !trend_down)
      return false;

   // --- LSMA(25) slope STATE over the last 3 closed bars ---
   const int slope = Woodcci_LSMASlopeSign(1);
   if(trend_up && slope <= 0)
      return false;
   if(trend_down && slope >= 0)
      return false;

   // --- Turbo CCI(6) TRIGGER: fresh zero cross OR on-side for <= max bars ---
   const double turbo1 = QM_CCI(_Symbol, _Period, strategy_turbo_cci_period, 1);
   const double turbo2 = QM_CCI(_Symbol, _Period, strategy_turbo_cci_period, 2);

   bool turbo_ok = false;
   if(trend_up)
     {
      const bool crossed_up = (turbo2 <= 0.0 && turbo1 > 0.0);
      // count how many consecutive recent bars Turbo has been above zero.
      int bars_above = 0;
      for(int s = 1; s <= strategy_turbo_max_bars; ++s)
        {
         if(QM_CCI(_Symbol, _Period, strategy_turbo_cci_period, s) > 0.0)
            ++bars_above;
         else
            break;
        }
      turbo_ok = (crossed_up || (bars_above >= 1 && bars_above <= strategy_turbo_max_bars));
     }
   else // trend_down
     {
      const bool crossed_dn = (turbo2 >= 0.0 && turbo1 < 0.0);
      int bars_below = 0;
      for(int s = 1; s <= strategy_turbo_max_bars; ++s)
        {
         if(QM_CCI(_Symbol, _Period, strategy_turbo_cci_period, s) < 0.0)
            ++bars_below;
         else
            break;
        }
      turbo_ok = (crossed_dn || (bars_below >= 1 && bars_below <= strategy_turbo_max_bars));
     }
   if(!turbo_ok)
      return false;

   // --- Build the entry. Framework sizes lots (no lots field). ---
   const QM_OrderType side = trend_up ? QM_BUY : QM_SELL;
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, side, entry, atr_value, strategy_sl_atr_mult);
   if(sl <= 0.0)
      return false;
   const double tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_tp_rr);
   if(tp <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = trend_up ? "woodcci_long" : "woodcci_short";
   return true;
  }

// Fixed ATR stop + RR target; no active trailing. Discretionary exits live in
// Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Discretionary exit: (a) Trend CCI closes back across zero against the
// position, (b) LSMA slope flips against the position for 2 consecutive bars,
// or (c) time exit after time_exit_bars H1 bars. One closed-bar evaluation.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Resolve this EA's open position direction + open time.
   bool   is_long = false;
   bool   have    = false;
   datetime open_time = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      is_long   = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      have      = true;
      break;
     }
   if(!have)
      return false;

   // (a) Trend CCI closes back across zero against the position.
   const double trend1 = QM_CCI(_Symbol, _Period, strategy_trend_cci_period, 1);
   if(is_long && trend1 < 0.0)
      return true;
   if(!is_long && trend1 > 0.0)
      return true;

   // (b) LSMA slope flips against for 2 consecutive closed bars.
   const int slope1 = Woodcci_LSMASlopeSign(1);
   const int slope2 = Woodcci_LSMASlopeSign(2);
   if(is_long && slope1 < 0 && slope2 < 0)
      return true;
   if(!is_long && slope1 > 0 && slope2 > 0)
      return true;

   // (c) Time exit after time_exit_bars closed H1 bars.
   if(open_time > 0)
     {
      const int secs_per_bar = PeriodSeconds(_Period);
      if(secs_per_bar > 0)
        {
         const datetime bar_open = iTime(_Symbol, _Period, 0); // perf-allowed: current bar-open time
         const int bars_held = (int)((bar_open - open_time) / secs_per_bar);
         if(bars_held >= strategy_time_exit_bars)
            return true;
        }
     }

   return false;
  }

// Defer to the central news filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
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

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   Strategy_ManageOpenPosition();

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
      return;
     }

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
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
