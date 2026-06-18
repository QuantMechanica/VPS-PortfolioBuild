#property strict
#property version   "5.0"
#property description "QM5_11285 ptf-open-close — PyTrendFollow prior open-close forecast (long/short, D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11285 ptf-open-close
// -----------------------------------------------------------------------------
// Source: chrism2671/PyTrendFollow, trading/rules.py open_close(),
//   https://github.com/chrism2671/PyTrendFollow/blob/master/trading/rules.py
// Card: artifacts/cards_approved/QM5_11285_ptf-open-close.md (g0_status APPROVED).
//
// Mechanics (long AND short, closed-bar reads at shift >= 1, D1):
//   Per completed daily bar, forecast the prior open-close move scaled by
//   return-volatility:
//       raw       = close[s] - open[s]                  (prior CLOSED bar)
//       vol       = ATR(atr_period) at the same shift    (return-vol proxy)
//       forecast  = forecast_scalar * raw / vol          (normalized, ~PyTF norm)
//
//   The (close - open) of a CLOSED daily bar is a pure bar feature derived from
//   the bar timestamp/data — NOT a wall-clock open/close. No intraday timing.
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
input double strategy_forecast_scalar   = 4.0;    // PyTF norm_forecast scaling constant
input double strategy_entry_threshold   = 5.0;    // |forecast| cross level for entry (card +/-5)
input double strategy_exit_level        = 0.0;    // forecast level for the mean-revert exit (card: 0)
input int    strategy_max_hold_bars     = 5;      // time-stop in completed daily bars (card: 5)
input double strategy_sl_atr_mult       = 1.5;    // catastrophic stop = mult * ATR (card: 1.5)
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

// Normalized open-close forecast for the CLOSED bar at `shift` (shift >= 1).
// Returns 0.0 when data/ATR are not yet available (treated as "no signal").
double ForecastAt(const int shift)
  {
   const double open_s  = iOpen(_Symbol,  _Period, shift); // perf-allowed: closed-bar feature
   const double close_s = iClose(_Symbol, _Period, shift); // perf-allowed: closed-bar feature
   if(open_s <= 0.0 || close_s <= 0.0)
      return 0.0;
   const double atr_s = QM_ATR(_Symbol, _Period, strategy_atr_period, shift);
   if(atr_s <= 0.0)
      return 0.0;
   return strategy_forecast_scalar * (close_s - open_s) / atr_s;
  }

// Completed daily bars elapsed since the open position was filled. Derived from
// the bar-open timestamp of the entry bar vs the latest closed bar — pure bar
// arithmetic in broker time, never a fixed wall-clock rule.
int BarsHeld(const datetime position_open_time)
  {
   // Count CLOSED bars (shift 1..N) whose bar-open time is at or after the
   // entry bar's open. Bar 1 is the most recent CLOSED bar. Pure bar
   // arithmetic in broker time — never a fixed wall-clock rule.
   for(int s = 1; s < 5000; ++s)
     {
      const datetime bt = iTime(_Symbol, _Period, s); // perf-allowed: bar-open timestamp
      if(bt == 0)
         return s - 1;          // ran out of history
      if(bt < position_open_time)
         return s - 1;          // older than the entry bar — stop counting
     }
   return 0;
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
      return false; // no valid quote yet — never block on a zero price

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate

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

      // Forecast-revert exit on the last closed bar.
      const double f_now = ForecastAt(1);
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
