#property strict
#property version   "5.0"
#property description "QM5_10986 ftmo-psar-rev — Parabolic SAR flip reversal w/ EMA+ATR filters (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_10986 ftmo-psar-rev
// -----------------------------------------------------------------------------
// Source: FTMO, "Top 11 Technical Indicators That Can Change Your Trading
//   Forever", 2019, https://ftmo.com/en/blog/technical-indicators/ (Parabolic SAR).
// Card: artifacts/cards_approved/QM5_10986_ftmo-psar-rev.md (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1/2; PSAR step 0.02 / max 0.20):
//   Long flip EVENT : PSAR was ABOVE price on the prior closed bar (shift 2) and
//                     is BELOW price on the current closed bar (shift 1).
//   Short flip EVENT: PSAR was BELOW (shift 2) and is ABOVE (shift 1).
//   Trend STATE     : long  -> close > EMA(100) OR EMA(100) rising over 10 bars;
//                     short -> close < EMA(100) OR EMA(100) falling over 10 bars.
//   Body STATE      : |close[1]-open[1]| >= body_atr_frac * ATR(14).
//   Vol  STATE      : ATR(14) NOT below its 20th percentile over the last 250 bars.
//   Stop            : long  SL = min(PSAR, entry - sl_atr_mult*ATR);
//                     short SL = max(PSAR, entry + sl_atr_mult*ATR).
//                     Skip the trade if |entry - SL| > sl_max_atr_mult*ATR.
//   Take profit     : tp_rr-multiple of the initial risk (2.0R).
//   Manage          : after price moves +1.0R in favour, trail the stop to the
//                     current PSAR if (and only if) it improves the stop.
//   Exits           : opposite PSAR flip -> manual close; time exit after
//                     time_exit_bars closed H1 bars.
//   Spread guard    : block only when current spread exceeds 1.5x the 20-bar
//                     median spread (fail-open on .DWX zero modeled spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10986;
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
input double strategy_sar_step          = 0.02;   // Parabolic SAR step (acceleration)
input double strategy_sar_max           = 0.20;   // Parabolic SAR maximum
input int    strategy_ema_period        = 100;    // broad trend EMA
input int    strategy_ema_slope_bars    = 10;     // bars for EMA slope confirmation
input int    strategy_atr_period        = 14;     // ATR period (filter / stop / target)
input double strategy_body_atr_frac     = 0.35;   // min candle body as fraction of ATR
input int    strategy_atr_pct_lookback  = 250;    // bars for ATR percentile floor
input double strategy_atr_pct_floor     = 20.0;   // skip if ATR below this percentile
input double strategy_sl_atr_mult       = 1.2;    // ATR floor leg of the initial stop
input double strategy_sl_max_atr_mult   = 2.5;    // skip if stop distance exceeds this*ATR
input double strategy_tp_rr             = 2.0;    // take-profit as R-multiple of risk
input double strategy_trail_trigger_r   = 1.0;    // start PSAR trail after +this*R
input int    strategy_time_exit_bars    = 40;     // close after this many H1 bars
input int    strategy_spread_median_bars = 20;    // median spread lookback
input double strategy_spread_median_mult = 1.5;   // skip if spread > mult * median spread

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

double MedianClosedBarSpreadPoints()
  {
   const int n = strategy_spread_median_bars;
   if(n <= 0)
      return 0.0;

   double values[];
   ArrayResize(values, n);
   int count = 0;
   for(int shift = 1; shift <= n; ++shift)
     {
      const long spread_points = iSpread(_Symbol, _Period, shift); // perf-allowed: bounded spread-window filter
      if(spread_points < 0)
         continue;
      values[count] = (double)spread_points;
      ++count;
     }
   if(count <= 0)
      return 0.0;

   ArrayResize(values, count);
   ArraySort(values);
   const int mid = count / 2;
   if((count % 2) == 1)
      return values[mid];
   return 0.5 * (values[mid - 1] + values[mid]);
  }

// Cheap per-tick gate. Spread guard only — regime/signal work is in
// Strategy_EntrySignal on the closed-bar path. Fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const long current_spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   const double median_spread_points = MedianClosedBarSpreadPoints();
   // Only a genuinely wide spread blocks; zero modeled spread passes.
   if(current_spread_points > 0 &&
      median_spread_points > 0.0 &&
      strategy_spread_median_mult > 0.0 &&
      (double)current_spread_points > strategy_spread_median_mult * median_spread_points)
      return true;

   return false;
  }

// True if ATR(now, shift 1) is NOT below its 20th percentile over the lookback
// window. Single bounded loop over the closed-bar path (runs once per new bar).
bool VolatilityAboveFloor(const double atr_now)
  {
   const int n = strategy_atr_pct_lookback;
   if(n <= 1 || atr_now <= 0.0)
      return true; // not enough basis to judge — do not block

   int below = 0;
   int counted = 0;
   for(int s = 1; s <= n; ++s)
     {
      const double atr_s = QM_ATR(_Symbol, _Period, strategy_atr_period, s);
      if(atr_s <= 0.0)
         continue;
      ++counted;
      if(atr_s < atr_now)
         ++below;
     }
   if(counted <= 0)
      return true;

   const double pct_rank = (100.0 * (double)below) / (double)counted;
   return (pct_rank >= strategy_atr_pct_floor);
  }

// PSAR flip + EMA trend + body + volatility entry. Caller guarantees
// QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Parabolic SAR at the prior (shift 2) and current (shift 1) closed bar ---
   const double sar_prev = QM_SAR(_Symbol, _Period, strategy_sar_step, strategy_sar_max, 2);
   const double sar_now  = QM_SAR(_Symbol, _Period, strategy_sar_step, strategy_sar_max, 1);
   if(sar_prev <= 0.0 || sar_now <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double open1  = iOpen(_Symbol, _Period, 1);  // perf-allowed: single closed-bar read
   const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   if(close1 <= 0.0 || open1 <= 0.0 || close2 <= 0.0)
      return false;

   // Flip EVENTs: SAR side relative to the bar CLOSE on each bar.
   const bool flip_long  = (sar_prev > close2 && sar_now < close1); // dot above -> below
   const bool flip_short = (sar_prev < close2 && sar_now > close1); // dot below -> above
   if(!flip_long && !flip_short)
      return false;

   // --- Trend STATE: EMA(100) level or slope over the last slope_bars bars ---
   const double ema_now  = QM_EMA(_Symbol, _Period, strategy_ema_period, 1);
   const double ema_back = QM_EMA(_Symbol, _Period, strategy_ema_period, 1 + strategy_ema_slope_bars);
   if(ema_now <= 0.0 || ema_back <= 0.0)
      return false;
   const bool ema_rising  = (ema_now > ema_back);
   const bool ema_falling = (ema_now < ema_back);

   // --- Volatility STATE: ATR(14) and body filter ---
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double body = MathAbs(close1 - open1);
   if(body < strategy_body_atr_frac * atr_value)
      return false;

   if(!VolatilityAboveFloor(atr_value))
      return false;

   // --- Resolve direction and trend gate ---
   QM_OrderType side;
   if(flip_long)
     {
      if(!(close1 > ema_now || ema_rising))
         return false;
      side = QM_BUY;
     }
   else
     {
      if(!(close1 < ema_now || ema_falling))
         return false;
      side = QM_SELL;
     }

   // --- Build the stop: combine PSAR with the ATR floor leg ---
   const double entry = (side == QM_BUY)
                        ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double atr_leg = (side == QM_BUY)
                          ? (entry - strategy_sl_atr_mult * atr_value)
                          : (entry + strategy_sl_atr_mult * atr_value);

   double sl_raw;
   if(side == QM_BUY)
      sl_raw = MathMin(sar_now, atr_leg);   // long: the LOWER (safer) of the two
   else
      sl_raw = MathMax(sar_now, atr_leg);   // short: the HIGHER (safer) of the two

   const double sl = QM_TM_NormalizePrice(_Symbol, sl_raw);
   if(sl <= 0.0)
      return false;

   const double stop_distance = MathAbs(entry - sl);
   if(stop_distance <= 0.0)
      return false;
   // Skip if the stop is wider than the ATR cap.
   if(stop_distance > strategy_sl_max_atr_mult * atr_value)
      return false;

   const double tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_tp_rr);
   if(tp <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = (side == QM_BUY) ? "psar_flip_long" : "psar_flip_short";
   return true;
  }

// After price moves +trail_trigger_r * R in favour, trail the stop to the
// current PSAR if it improves (tightens) the existing stop. R is recovered from
// the still-present TP, which was set to tp_rr * R from entry.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   const double sar_now = QM_SAR(_Symbol, _Period, strategy_sar_step, strategy_sar_max, 1);
   if(sar_now <= 0.0)
      return;
   if(strategy_tp_rr <= 0.0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const long pos_type = PositionGetInteger(POSITION_TYPE);
      const double entry  = PositionGetDouble(POSITION_PRICE_OPEN);
      const double cur_sl = PositionGetDouble(POSITION_SL);
      const double cur_tp = PositionGetDouble(POSITION_TP);
      if(entry <= 0.0 || cur_tp <= 0.0)
         continue;

      // Recover R from the take-profit: |TP - entry| == tp_rr * R.
      const double risk = MathAbs(cur_tp - entry) / strategy_tp_rr;
      if(risk <= 0.0)
         continue;

      if(pos_type == POSITION_TYPE_BUY)
        {
         const double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(price <= 0.0)
            continue;
         if(price - entry < strategy_trail_trigger_r * risk)
            continue; // not yet +1R
         // Trail only if PSAR is above the current stop AND still below price.
         if(sar_now < price && (cur_sl <= 0.0 || sar_now > cur_sl))
            QM_TM_MoveSL(ticket, sar_now, "psar_trail_long");
        }
      else if(pos_type == POSITION_TYPE_SELL)
        {
         const double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(price <= 0.0)
            continue;
         if(entry - price < strategy_trail_trigger_r * risk)
            continue; // not yet +1R
         // Trail only if PSAR is below the current stop AND still above price.
         if(sar_now > price && (cur_sl <= 0.0 || sar_now < cur_sl))
            QM_TM_MoveSL(ticket, sar_now, "psar_trail_short");
        }
     }
  }

// Manual exits: opposite PSAR flip, or time exit after time_exit_bars H1 bars.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const datetime current_bar_open = iTime(_Symbol, _Period, 0); // perf-allowed: current bar time for bounded time exit
   const int period_seconds = PeriodSeconds(_Period);
   if(current_bar_open <= 0 || period_seconds <= 0)
      return false;

   // PSAR side on the current closed bar (shift 1) vs that bar's close.
   const double sar_now = QM_SAR(_Symbol, _Period, strategy_sar_step, strategy_sar_max, 1);
   const double close1  = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(sar_now <= 0.0 || close1 <= 0.0)
      return false;
   const bool sar_above = (sar_now > close1); // bearish dot
   const bool sar_below = (sar_now < close1); // bullish dot

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const long pos_type = PositionGetInteger(POSITION_TYPE);

      // Opposite PSAR flip.
      if(pos_type == POSITION_TYPE_BUY && sar_above)
         return true;
      if(pos_type == POSITION_TYPE_SELL && sar_below)
         return true;

      // Time exit after time_exit_bars closed bars.
      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(open_time > 0 && strategy_time_exit_bars > 0)
        {
         const long bars_held = (long)((current_bar_open - open_time) / period_seconds);
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
