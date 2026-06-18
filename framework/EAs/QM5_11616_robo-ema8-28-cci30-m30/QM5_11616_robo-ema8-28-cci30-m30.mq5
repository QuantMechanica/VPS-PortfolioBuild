#property strict
#property version   "5.0"
#property description "QM5_11616 robo-ema8-28-cci30-m30 — EMA(8/28) trend + CCI(30) zero-cross (M30)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11616 robo-ema8-28-cci30-m30
// -----------------------------------------------------------------------------
// Source: RoboForex Educational Team, "Forex Strategy Collection" (~2015),
//         page 45, strategy "EMA + CCI".
// Card: artifacts/cards_approved/QM5_11616_robo-ema8-28-cci30-m30.md (APPROVED).
//
// Mechanics (closed-bar reads at shift 1, both long and short, M30):
//   Trend STATE  : EMA(fast) vs EMA(slow) at the last closed bar.
//                    long  -> EMA(fast) > EMA(slow)
//                    short -> EMA(fast) < EMA(slow)
//                  This is a STATE (current ordering), NOT a cross event, so the
//                  two-cross-same-bar zero-trade trap is avoided.
//   Trigger EVENT: CCI(period) crosses the zero line in the trend direction —
//                  a SINGLE fresh event per bar (cci@2 vs cci@1).
//                    long  -> cci[2] <= 0  AND  cci[1] > 0   (cross up)
//                    short -> cci[2] >= 0  AND  cci[1] < 0   (cross down)
//   Stop         : entry -/+ sl_atr_mult * ATR(atr_period).
//   Take profit  : RR multiple of the stop distance (tp/sl = tp_atr/sl_atr).
//   Exit         : managed by the fixed ATR stop / RR target only (card: close
//                  via SL or TP). One position per magic.
//   Spread guard : skip only a genuinely wide spread (> spread_pct_of_stop of
//                  the ATR stop distance). Fail-open on .DWX zero modeled spread.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11616;
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
input int    strategy_ema_fast_period    = 8;      // trend-state fast EMA
input int    strategy_ema_slow_period    = 28;     // trend-state slow EMA
input int    strategy_cci_period         = 30;     // CCI lookback period
input double strategy_cci_cross_level     = 0.0;   // CCI cross level (zero line)
input int    strategy_atr_period         = 14;     // ATR period (stop / target)
input double strategy_sl_atr_mult        = 2.0;    // stop distance = mult * ATR
input double strategy_tp_atr_mult        = 4.0;    // target distance = mult * ATR (RR = tp/sl)
input double strategy_spread_pct_of_stop  = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — trend/signal work is on the
// closed-bar path in Strategy_EntrySignal. Fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate, do not block here

   const double stop_distance = strategy_sl_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Long/short entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Trend STATE: EMA(fast) vs EMA(slow) at the last closed bar ---
   const double ema_fast = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_slow = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   if(ema_fast <= 0.0 || ema_slow <= 0.0)
      return false;

   const bool trend_long  = (ema_fast > ema_slow);
   const bool trend_short = (ema_fast < ema_slow);
   if(!trend_long && !trend_short)
      return false; // EMAs equal — no trend state

   // --- Trigger EVENT: CCI crosses the level in the trend direction ---
   // cci_prev at shift 2, cci_now at shift 1: a single fresh cross per bar.
   const double cci_now  = QM_CCI(_Symbol, _Period, strategy_cci_period, 1);
   const double cci_prev = QM_CCI(_Symbol, _Period, strategy_cci_period, 2);

   const bool cross_up   = (cci_prev <= strategy_cci_cross_level &&
                            cci_now  >  strategy_cci_cross_level);
   const bool cross_down = (cci_prev >= strategy_cci_cross_level &&
                            cci_now  <  strategy_cci_cross_level);

   // STATE gates the direction; the CCI cross is the only EVENT trigger.
   const bool go_long  = (trend_long  && cross_up);
   const bool go_short = (trend_short && cross_down);
   if(!go_long && !go_short)
      return false;

   // --- ATR for stop / target ---
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const QM_OrderType otype = go_long ? QM_BUY : QM_SELL;

   const double entry = (otype == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                          : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, otype, entry, atr_value, strategy_sl_atr_mult);
   if(sl <= 0.0)
      return false;

   const double rr = (strategy_sl_atr_mult > 0.0)
                     ? (strategy_tp_atr_mult / strategy_sl_atr_mult) : 0.0;
   const double tp = (rr > 0.0) ? QM_TakeRR(_Symbol, otype, entry, sl, rr) : 0.0;
   if(tp <= 0.0)
      return false;

   req.type   = otype;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = go_long ? "robo_ema_cci_long" : "robo_ema_cci_short";
   return true;
  }

// No active management beyond the fixed ATR stop / RR target.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit — positions close via SL or TP (per card).
bool Strategy_ExitSignal()
  {
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
