#property strict
#property version   "5.0"
#property description "QM5_11159 dwx-donchian — Donchian Timed Breakout (long+short, H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11159 dwx-donchian
// -----------------------------------------------------------------------------
// Source: Darwinex Blog "Journey to Trading Profit: Sample Size, Filters &
//   Timed Exits" (interview subject Ben; core system "basically" a Donchian
//   Channel Breakout). source_id 0d015701-0978-5f79-85bc-045914b12692.
// Card: artifacts/cards_approved/QM5_11159_dwx-donchian.md (g0_status APPROVED).
//
// Mechanics (long+short, all reads on CLOSED bars, shift >= 1):
//   Donchian channel : highest HIGH / lowest LOW of `donchian_period` bars,
//                      computed over PRIOR CLOSED bars only (shifts 1..period).
//   Long  EVENT      : the previous closed bar (shift 1) CLOSED above the
//                      Donchian high of the bars BEFORE it (shifts 2..period+1).
//   Short EVENT      : prev closed bar (shift 1) CLOSED below the Donchian low
//                      of the bars before it (shifts 2..period+1).
//   Activity STATE   : ATR(14)[1] > median of ATR(14) over the last
//                      `atr_median_lookback` closed bars (skip dead ranges).
//   Trend filter     : optional close[1] vs SMA(trend_ma_period) gate.
//   Entry            : market on the new bar's open (we are on the new-bar gate).
//   Stop             : opposite side of a shorter Donchian channel
//                      (`exit_channel_period`), but at least min_stop_atr_mult
//                      * ATR(14) away — whichever stop is FURTHER from entry.
//   Exits (manual)   : (a) timed exit after max_holding_bars closed bars,
//                      (b) opposite Donchian breakout of the entry channel,
//                      (c) stagnation: if not >= +0.25R after stagnation_bars.
//   Spread guard     : fail-open on .DWX zero modeled spread; block only a
//                      genuinely wide spread > spread_pct_of_stop of the stop.
//
// .DWX invariants honoured: fail-open spread, no swap gate, prior-CLOSE-based
// breakout (not range/gap), QM_IsNewBar consumed ONCE in OnTick, ATR median
// scaled to a multi-bar baseline. No external feed. One position per magic.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11159;
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
input int    strategy_donchian_period    = 55;    // entry Donchian channel length (closed bars)
input int    strategy_exit_channel_period = 20;   // shorter Donchian for the initial stop
input int    strategy_atr_period         = 14;    // ATR period (activity filter + min stop)
input int    strategy_atr_median_lookback = 100;  // bars for the ATR activity median
input double strategy_min_stop_atr_mult  = 1.5;   // minimum stop distance = mult * ATR
input int    strategy_max_holding_bars   = 24;    // timed exit after N closed bars
input int    strategy_stagnation_bars    = 8;     // stagnation check window (bars)
input double strategy_stagnation_min_r   = 0.25;  // require >= this R progress by stagnation_bars
input int    strategy_trend_ma_period    = 0;     // 0 = trend filter OFF; else SMA period
input bool   strategy_skip_friday_late   = true;  // skip entries Fri >= 15:00 broker time
input int    strategy_friday_cutoff_hour = 15;    // broker-time hour for the Friday cutoff
input double strategy_spread_pct_of_stop = 12.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Helpers (closed-bar Donchian over PRIOR CLOSED bars only)
// -----------------------------------------------------------------------------

// Highest HIGH over `count` closed bars starting at `start_shift` (>=1).
// perf-allowed: bounded single-pass over closed bars, run on the new-bar gate.
double DonchianHigh(const int start_shift, const int count)
  {
   double hi = 0.0;
   for(int s = start_shift; s < start_shift + count; ++s)
     {
      const double h = iHigh(_Symbol, _Period, s); // perf-allowed: closed-bar read
      if(h <= 0.0)
         continue;
      if(h > hi)
         hi = h;
     }
   return hi;
  }

// Lowest LOW over `count` closed bars starting at `start_shift` (>=1).
double DonchianLow(const int start_shift, const int count)
  {
   double lo = 0.0;
   for(int s = start_shift; s < start_shift + count; ++s)
     {
      const double l = iLow(_Symbol, _Period, s); // perf-allowed: closed-bar read
      if(l <= 0.0)
         continue;
      if(lo <= 0.0 || l < lo)
         lo = l;
     }
   return lo;
  }

// Median of ATR(period) over the last `lookback` closed bars (shifts 1..lookback).
// Scales the activity baseline to a multi-bar window, not a single ATR sample.
double ATRMedian(const int atr_period, const int lookback)
  {
   if(lookback <= 0)
      return 0.0;
   double vals[];
   ArrayResize(vals, lookback);
   int n = 0;
   for(int s = 1; s <= lookback; ++s)
     {
      const double a = QM_ATR(_Symbol, _Period, atr_period, s);
      if(a > 0.0)
        {
         vals[n] = a;
         ++n;
        }
     }
   if(n <= 0)
      return 0.0;
   ArrayResize(vals, n);
   ArraySort(vals);
   if((n % 2) == 1)
      return vals[n / 2];
   return 0.5 * (vals[(n / 2) - 1] + vals[n / 2]);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only; fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate

   const double stop_distance = strategy_min_stop_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Donchian breakout entry (long + short). Caller guarantees QM_IsNewBar()==true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Friday late-session cutoff (broker time): skip new entries.
   if(strategy_skip_friday_late)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.day_of_week == 5 && dt.hour >= strategy_friday_cutoff_hour)
         return false;
     }

   // --- Activity STATE: ATR(1) above its multi-bar median (skip dead ranges) ---
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;
   const double atr_median = ATRMedian(strategy_atr_period, strategy_atr_median_lookback);
   if(atr_median <= 0.0)
      return false;
   if(!(atr_value > atr_median))
      return false;

   // --- Donchian breakout EVENT on the prior CLOSED bar (shift 1) ---
   // Channel is built from the bars BEFORE the trigger bar: shifts 2..period+1.
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: closed-bar read
   if(close1 <= 0.0)
      return false;

   const double don_high = DonchianHigh(2, strategy_donchian_period);
   const double don_low  = DonchianLow(2, strategy_donchian_period);
   if(don_high <= 0.0 || don_low <= 0.0)
      return false;

   const bool long_break  = (close1 > don_high);
   const bool short_break = (close1 < don_low);
   if(!long_break && !short_break)
      return false;

   // --- Optional trend filter: close[1] vs SMA(trend_ma_period) ---
   if(strategy_trend_ma_period > 0)
     {
      const double sma = QM_SMA(_Symbol, _Period, strategy_trend_ma_period, 1);
      if(sma <= 0.0)
         return false;
      if(long_break && !(close1 > sma))
         return false;
      if(short_break && !(close1 < sma))
         return false;
     }

   const QM_OrderType side = long_break ? QM_BUY : QM_SELL;

   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   // --- Initial stop: opposite side of the SHORTER Donchian channel, but at
   //     least min_stop_atr_mult * ATR away. Take whichever is FURTHER. ---
   // Structure stop uses the exit channel over prior closed bars (shifts 1..N).
   const double exit_hi = DonchianHigh(1, strategy_exit_channel_period);
   const double exit_lo = DonchianLow(1, strategy_exit_channel_period);
   if(exit_hi <= 0.0 || exit_lo <= 0.0)
      return false;

   const double struct_stop = QM_StopStructureFromExtremes(_Symbol, side, exit_lo, exit_hi);
   const double atr_stop    = QM_StopATRFromValue(_Symbol, side, entry, atr_value, strategy_min_stop_atr_mult);
   if(struct_stop <= 0.0 || atr_stop <= 0.0)
      return false;

   // Pick the stop that is further from entry (wider / safer min distance).
   double sl;
   if(side == QM_BUY)
      sl = MathMin(struct_stop, atr_stop);   // lower stop = further below entry
   else
      sl = MathMax(struct_stop, atr_stop);   // higher stop = further above entry

   // Sanity: stop must be on the correct side of entry.
   if(side == QM_BUY && !(sl < entry))
      return false;
   if(side == QM_SELL && !(sl > entry))
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = 0.0;   // no fixed target; exits are timed / opposite-break / stagnation
   req.reason = long_break ? "donchian_break_long" : "donchian_break_short";
   return true;
  }

// No active SL/TP modification — exits are handled in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Manual exits: timed, opposite Donchian breakout, stagnation (no +0.25R).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Select this EA's open position to read its entry time / price / side.
   bool found = false;
   long pos_type = -1;
   double entry_price = 0.0;
   datetime open_time = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      pos_type    = PositionGetInteger(POSITION_TYPE);
      entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
      open_time   = (datetime)PositionGetInteger(POSITION_TIME);
      found = true;
      break;
     }
   if(!found || entry_price <= 0.0)
      return false;

   const bool is_long = (pos_type == POSITION_TYPE_BUY);

   // Bars held = closed bars between the open bar and the last closed bar.
   const datetime open_bar = iTime(_Symbol, _Period, 0); // current forming bar open
   const int period_secs = PeriodSeconds(_Period);
   if(period_secs <= 0)
      return false;
   const int bars_held = (int)((open_bar - open_time) / period_secs);

   // (a) Timed exit after max_holding_bars closed bars.
   if(bars_held >= strategy_max_holding_bars)
      return true;

   // (b) Opposite Donchian breakout of the ENTRY channel (prior closed bar).
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: closed-bar read
   if(close1 > 0.0)
     {
      const double don_high = DonchianHigh(2, strategy_donchian_period);
      const double don_low  = DonchianLow(2, strategy_donchian_period);
      if(is_long && don_low > 0.0 && close1 < don_low)
         return true;
      if(!is_long && don_high > 0.0 && close1 > don_high)
         return true;
     }

   // (c) Stagnation: if after stagnation_bars the trade has not reached
   //     +stagnation_min_r R of progress, close it.
   if(bars_held >= strategy_stagnation_bars)
     {
      // R = initial risk per unit = |entry - initial_stop|. Recover it from
      // the live SL if present; otherwise fall back to min_stop_atr_mult*ATR.
      double risk_dist = 0.0;
      const double live_sl = PositionGetDouble(POSITION_SL);
      if(live_sl > 0.0)
         risk_dist = MathAbs(entry_price - live_sl);
      if(risk_dist <= 0.0)
        {
         const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
         risk_dist = strategy_min_stop_atr_mult * atr_value;
        }
      if(risk_dist > 0.0)
        {
         const double price_now = is_long ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                          : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(price_now > 0.0)
           {
            const double progress = is_long ? (price_now - entry_price)
                                            : (entry_price - price_now);
            const double r_progress = progress / risk_dist;
            if(r_progress < strategy_stagnation_min_r)
               return true;
           }
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
     }

   if(!QM_IsNewBar())
      return;

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
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
