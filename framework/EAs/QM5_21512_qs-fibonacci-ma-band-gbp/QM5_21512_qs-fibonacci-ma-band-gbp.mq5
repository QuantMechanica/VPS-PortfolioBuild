#property strict
#property version   "5.0"
#property description "QM5_21512 qs-fibonacci-ma-band-gbp — Fibonacci MA band breakout (D1, GBPUSD)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_21512 qs-fibonacci-ma-band-gbp
// -----------------------------------------------------------------------------
// Source: QuantifiedStrategies.com "Fibonacci Moving Averages Trading
//   Strategy: Backtest and Evaluation".
// Card: D:/QM/strategy_farm/artifacts/cards_approved/QM5_21512_qs-fibonacci-ma-band-gbp.md
//   (g0_status APPROVED).
//
// Mechanics (D1, closed-bar reads at shift 1):
//   FMA_Upper: average of EMA(High, p) for p in {13,21,34,55,89,144}.
//   FMA_Lower: average of EMA(Low,  p) for p in {13,21,34,55,89,144}.
//   Band-slope confirmation: FMA_Upper[1] > FMA_Upper[1+slope_lookback] for
//     long; FMA_Lower[1] < FMA_Lower[1+slope_lookback] for short.
//   Long EVENT : Close crosses from <= FMA_Upper[2] to > FMA_Upper[1], long
//     slope filter true, no position open.
//   Short EVENT: Close crosses from >= FMA_Lower[2] to < FMA_Lower[1], short
//     slope filter true, no position open.
//   Stop   : strategy_atr_sl_mult * ATR(strategy_atr_period) hard SL.
//   Exit   : Close recrosses back inside the band (Close < FMA_Upper for a
//     long, Close > FMA_Lower for a short) — a plain recross, not a fresh
//     breakout trigger — plus ATR stop, strategy_max_hold_bars time stop, and
//     framework Friday close. No take-profit, no trailing, no partial close.
//   A recross exit does NOT itself open the opposite position; that requires
//     its own fresh band-breakout trigger (handled naturally: entry logic is
//     independent of exit logic).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 21512;
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
input int    strategy_slope_lookback    = 5;     // bars back for the band-slope confirmation
input int    strategy_atr_period        = 14;    // ATR period for the hard stop
input double strategy_atr_sl_mult       = 2.5;   // hard SL distance = mult * ATR
input int    strategy_max_hold_bars     = 90;    // stale-position time stop (D1 bars)
input double strategy_max_spread_points = 40;    // skip entry if spread exceeds this (points)

// Fixed Fibonacci period subset per card (disclosed side-parameter fill: the
// central six terms of the source's disclosed pool {5,8,13,21,34,55,89,144,233}).
int FMA_PERIODS[6] = {13, 21, 34, 55, 89, 144};

// Average of EMA(High, p) and EMA(Low, p) over FMA_PERIODS at the given shift.
bool FMA_Band(const int shift, double &upper_out, double &lower_out)
  {
   double upper_sum = 0.0, lower_sum = 0.0;
   for(int i = 0; i < 6; i++)
     {
      const double eh = QM_EMA(_Symbol, _Period, FMA_PERIODS[i], shift, PRICE_HIGH);
      const double el = QM_EMA(_Symbol, _Period, FMA_PERIODS[i], shift, PRICE_LOW);
      if(eh <= 0.0 || el <= 0.0)
         return false;
      upper_sum += eh;
      lower_sum += el;
     }
   upper_out = upper_sum / 6.0;
   lower_out = lower_sum / 6.0;
   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double spread_points = (ask - bid) / _Point;
   if(spread_points > strategy_max_spread_points)
      return true;

   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per magic (both long and short share this cap).
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   double upper1 = 0.0, lower1 = 0.0;
   double upper2 = 0.0, lower2 = 0.0;
   double upper_slope = 0.0, lower_slope = 0.0;
   if(!FMA_Band(1, upper1, lower1))
      return false;
   if(!FMA_Band(2, upper2, lower2))
      return false;
   if(!FMA_Band(1 + strategy_slope_lookback, upper_slope, lower_slope))
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   if(close1 <= 0.0 || close2 <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const bool cross_up   = (close2 <= upper2 && close1 > upper1);
   const bool slope_up   = (upper1 > upper_slope);
   const bool cross_down = (close2 >= lower2 && close1 < lower1);
   const bool slope_down = (lower1 < lower_slope);

   if(cross_up && slope_up)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_atr_sl_mult);
      if(sl <= 0.0)
         return false;

      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = 0.0;   // no take-profit in v1 (card)
      req.reason = "fma_band_breakout_long";
      return true;
     }

   if(cross_down && slope_down)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_SELL, entry, atr_value, strategy_atr_sl_mult);
      if(sl <= 0.0)
         return false;

      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = 0.0;
      req.reason = "fma_band_breakout_short";
      return true;
     }

   return false;
  }

// No active trade management beyond the fixed ATR stop / time stop / recross
// exit, all handled in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Defensive exit: plain recross back inside the band (not a fresh breakout
// trigger) or stale-position time stop.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   double upper1 = 0.0, lower1 = 0.0;
   if(!FMA_Band(1, upper1, lower1))
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
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

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && close1 < upper1)
         return true;
      if(ptype == POSITION_TYPE_SELL && close1 > lower1)
         return true;

      if(strategy_max_hold_bars > 0)
        {
         const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
         const int open_shift = iBarShift(_Symbol, _Period, opened, false);
         if(open_shift >= strategy_max_hold_bars)
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
