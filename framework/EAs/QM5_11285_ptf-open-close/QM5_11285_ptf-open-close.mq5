#property strict
#property version   "5.0"
#property description "QM5_11285 ptf-open-close - PyTrendFollow prior open-close forecast (long/short, D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA - QM5_11285 ptf-open-close
// -----------------------------------------------------------------------------
// Source: chrism2671/PyTrendFollow, trading/rules.py open_close().
// Card: artifacts/cards_approved/QM5_11285_ptf-open-close.md (g0_status APPROVED).
//
// Mechanics (long AND short, closed-bar reads at shift >= 1, D1):
//   Per completed daily bar, forecast the prior open-close move scaled by
//   return-volatility and normalized using the source norm_forecast convention:
//       raw       = (close[s] - open[s]) / ATR[s]        (prior CLOSED bar)
//       forecast  = raw * 10 / trailing_abs_mean(raw)    (clipped to +/-20)
//
//   The (close - open) of a CLOSED daily bar is a pure bar feature derived from
//   the bar timestamp/data - NOT a wall-clock open/close. No intraday timing.
//   On gapless .DWX CFDs open[0] == close[1]; we read prior CLOSED bars only.
//
//   Entry EVENT (one trigger per bar):
//     Long  : forecast crosses ABOVE +entry_threshold (prev <= +T, now > +T).
//     Short : forecast crosses BELOW -entry_threshold (prev >= -T, now < -T).
//   Exit STATE / time-stop (whichever first):
//     Long  : forecast <= exit_level (0) OR held >= max_hold_bars closed bars.
//     Short : forecast >= -exit_level (0) OR held >= max_hold_bars closed bars.
//   Stop loss : catastrophic stop = sl_atr_mult * ATR (card: 1.5 * ATR(14)).
//
// One open position per symbol/magic. Framework sizes lots (no lots field).
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11285;
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
input int    strategy_atr_period        = 14;     // return-volatility / stop ATR period
input int    strategy_norm_lookback     = 40;     // trailing abs-mean window for norm_forecast
input int    strategy_min_norm_samples  = 20;     // minimum samples before a normalized forecast is valid
input double strategy_entry_threshold   = 5.0;    // |forecast| cross level for entry (card +/-5)
input double strategy_exit_level        = 0.0;    // forecast level for the mean-revert exit (card: 0)
input int    strategy_max_hold_bars     = 5;      // time-stop in completed daily bars (card: 5)
input double strategy_sl_atr_mult       = 1.5;    // catastrophic stop = mult * ATR (card: 1.5)
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

double ClampForecast(const double value)
  {
   if(value > 20.0)
      return 20.0;
   if(value < -20.0)
      return -20.0;
   return value;
  }

// Raw open-close forecast for a CLOSED D1 bar. CopyRates is used because the
// V5 indicator helpers expose indicators, not raw daily open/close fields.
bool RawForecastFromRates(MqlRates &rates[], const int copied, const int shift, double &out_raw)
  {
   out_raw = 0.0;
   if(shift < 1 || shift >= copied)
      return false;

   const double open_s = rates[shift].open;
   const double close_s = rates[shift].close;
   if(open_s <= 0.0 || close_s <= 0.0)
      return false;

   const double atr_s = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, shift);
   if(atr_s <= 0.0)
      return false;

   out_raw = (close_s - open_s) / atr_s;
   return true;
  }

// Source norm_forecast: scale so mean absolute forecast is 10, then clip
// to +/-20. This build uses only trailing closed bars to avoid source lookahead.
double ForecastAt(const int shift)
  {
   const int norm_lookback = MathMax(strategy_norm_lookback, strategy_min_norm_samples);
   const int needed = shift + norm_lookback + 2;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   // perf-allowed: bounded D1 OHLC window required by open_close() source rule.
   const int copied = CopyRates(_Symbol, PERIOD_D1, 0, needed, rates);
   if(copied <= shift + strategy_min_norm_samples)
      return 0.0;

   double raw_now = 0.0;
   if(!RawForecastFromRates(rates, copied, shift, raw_now))
      return 0.0;

   double abs_sum = 0.0;
   int samples = 0;
   const int last_shift = MathMin(copied - 1, shift + strategy_norm_lookback - 1);
   for(int s = shift; s <= last_shift; ++s)
     {
      double raw_s = 0.0;
      if(!RawForecastFromRates(rates, copied, s, raw_s))
         continue;
      abs_sum += MathAbs(raw_s);
      samples++;
     }

   if(samples < strategy_min_norm_samples || abs_sum <= 0.0)
      return 0.0;

   const double abs_mean = abs_sum / (double)samples;
   if(abs_mean <= 0.0)
      return 0.0;

   return ClampForecast(raw_now * 10.0 / abs_mean);
  }

// Completed daily bars elapsed since the open position was filled. Derived from
// the bar-open timestamp of the entry bar vs the latest closed bar - pure bar
// arithmetic in broker time, never a fixed wall-clock rule.
int BarsHeld(const datetime position_open_time)
  {
   const int max_scan = MathMax(strategy_max_hold_bars + 2, 10);
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   // perf-allowed: small bounded D1 window for 5-bar time stop accounting.
   const int copied = CopyRates(_Symbol, PERIOD_D1, 0, max_scan + 2, rates);
   if(copied <= 1)
      return 0;

   const int seconds = PeriodSeconds(PERIOD_D1);
   int held = 0;
   for(int s = 1; s < copied; ++s)
     {
      const datetime close_time = rates[s].time + seconds;
      if(close_time > position_open_time)
         held++;
     }
   return held;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate: spread guard only. Fail-OPEN on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet - never block on a zero price

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet - defer to the entry gate

   const double stop_distance = strategy_sl_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
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

   // Forecast on the last closed bar (shift 1) and the one before (shift 2).
   const double f_now  = ForecastAt(1);
   const double f_prev = ForecastAt(2);
   if(f_now == 0.0)
      return false; // no usable signal/ATR yet

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double up_T   = strategy_entry_threshold;
   const double down_T = -strategy_entry_threshold;

   // Long: forecast crosses ABOVE +threshold (one fresh upward cross).
   const bool cross_long  = (f_prev <= up_T   && f_now > up_T);
   // Short: forecast crosses BELOW -threshold (one fresh downward cross).
   const bool cross_short = (f_prev >= down_T && f_now < down_T);

   if(cross_long)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_sl_atr_mult);
      if(sl <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = 0.0;   // exit via forecast revert / time-stop, no fixed TP
      req.reason = "ptf_open_close_long";
      return true;
     }

   if(cross_short)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_SELL, entry, atr_value, strategy_sl_atr_mult);
      if(sl <= 0.0)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = 0.0;
      req.reason = "ptf_open_close_short";
      return true;
     }

   return false;
  }

// No active trade management beyond the catastrophic ATR stop. Exit logic is
// the forecast-revert / time-stop in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Exit: forecast reverts through the exit level OR the time-stop is hit.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Select this EA's open position to read its direction + open time.
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const long pos_type = PositionGetInteger(POSITION_TYPE);
      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);

      // Time-stop: held at least max_hold_bars completed daily bars.
      if(BarsHeld(open_time) >= strategy_max_hold_bars)
         return true;

      double f_now = 0.0;
      if(strategy_exit_level == 0.0)
        {
         MqlRates rates[];
         ArraySetAsSeries(rates, true);
         const int copied = CopyRates(_Symbol, PERIOD_D1, 0, 3, rates);
         if(copied <= 2 || !RawForecastFromRates(rates, copied, 1, f_now))
            return false;
        }
      else
        {
         f_now = ForecastAt(1);
        }

      // Forecast-revert exit on the last closed bar.
      if(pos_type == POSITION_TYPE_BUY)
        {
         if(f_now <= strategy_exit_level)
            return true;
        }
      else if(pos_type == POSITION_TYPE_SELL)
        {
         if(f_now >= -strategy_exit_level)
            return true;
        }
      return false;
     }
   return false;
  }

// Defer to the central news filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
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
