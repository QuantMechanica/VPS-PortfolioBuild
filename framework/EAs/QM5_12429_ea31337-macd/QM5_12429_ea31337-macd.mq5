#property strict
#property version   "5.0"
#property description "QM5_12429 ea31337-macd — EA31337 MACD signal momentum (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_12429 ea31337-macd
// -----------------------------------------------------------------------------
// Source: EA31337 Strategy-MACD (Stg_MACD.mqh SignalOpen()).
//   https://github.com/EA31337/Strategy-MACD/blob/master/Stg_MACD.mqh
// Card: artifacts/cards_approved/QM5_12429_ea31337-macd.md (g0_status APPROVED).
//
// Mechanics (MACD fast 6 / slow 34 / signal 10 on open price; closed-bar reads).
//   EA31337 SignalOpenLevel default = 2.0 over a 3-bar main-line move.
//   Long:
//     STATE  : MACD signal(1) > MACD main(1)            (signal above main)
//     STATE  : signal(1) > signal(2) > signal(3)        (signal rising 2 bars)
//     EVENT  : main(1) - main(3) >= +SignalOpenLevel    (3-bar main up-thrust)
//   Short (mirror):
//     STATE  : signal(1) < main(1)
//     STATE  : signal(1) < signal(2) < signal(3)        (signal falling 2 bars)
//     EVENT  : main(1) - main(3) <= -SignalOpenLevel    (3-bar main down-thrust)
//   The single trigger is the 3-bar main-line thrust crossing the level; the
//   signal/main relation and the 2-bar signal slope are STATES, not a second
//   cross EVENT. This avoids the .DWX two-cross-same-bar zero-trade trap. The
//   source's signal-vs-main relation is counterintuitive vs the common MACD
//   cross (Lessons Learned 2026-05-26) and is ported literally.
//
//   Stop   : ATR-based (source price-stop method 1/level 2 not directly
//            portable -> V5 framework default ATR stop, per card Stop Loss).
//   Take   : RR multiple of the stop distance.
//   Exits  : (a) time exit after exit_max_bars closed bars held (source
//                close-time -30 bars);
//            (b) opposite MACD momentum signal closes early (source close
//                loss/profit controls are not ported; opposite-signal exit
//                is the V5 baseline per the card Exit note).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12429;
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
input int    strategy_macd_fast          = 6;      // EA31337 MACD fast EMA period
input int    strategy_macd_slow          = 34;     // EA31337 MACD slow EMA period
input int    strategy_macd_signal        = 10;     // EA31337 MACD signal SMA period
input double strategy_signal_level       = 2.0;    // EA31337 SignalOpenLevel (3-bar main-line move)
input int    strategy_atr_period         = 14;     // ATR period for the stop
input double strategy_sl_atr_mult        = 2.0;    // stop distance = mult * ATR
input double strategy_tp_rr              = 1.5;    // take-profit RR multiple of the stop
input int    strategy_exit_max_bars      = 30;     // EA31337 close-time: exit after N bars held
input double strategy_spread_pct_of_stop = 15.0;   // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Shared MACD signal evaluation (closed-bar). Returns +1 long / -1 short / 0.
// MACD applied price = PRICE_OPEN per the EA31337 source default.
// -----------------------------------------------------------------------------
int MacdSignal()
  {
   const double main1 = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast, strategy_macd_slow,
                                     strategy_macd_signal, 1, PRICE_OPEN);
   const double main3 = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast, strategy_macd_slow,
                                     strategy_macd_signal, 3, PRICE_OPEN);
   const double sig1  = QM_MACD_Signal(_Symbol, _Period, strategy_macd_fast, strategy_macd_slow,
                                       strategy_macd_signal, 1, PRICE_OPEN);
   const double sig2  = QM_MACD_Signal(_Symbol, _Period, strategy_macd_fast, strategy_macd_slow,
                                       strategy_macd_signal, 2, PRICE_OPEN);
   const double sig3  = QM_MACD_Signal(_Symbol, _Period, strategy_macd_fast, strategy_macd_slow,
                                       strategy_macd_signal, 3, PRICE_OPEN);

   // Long: signal above main (STATE) + signal rising 2 bars (STATE) +
   //       3-bar main up-thrust >= level (EVENT/trigger).
   if(sig1 > main1 &&
      sig1 > sig2 && sig2 > sig3 &&
      (main1 - main3) >= strategy_signal_level)
      return 1;

   // Short: signal below main (STATE) + signal falling 2 bars (STATE) +
   //        3-bar main down-thrust <= -level (EVENT/trigger).
   if(sig1 < main1 &&
      sig1 < sig2 && sig2 < sig3 &&
      (main1 - main3) <= -strategy_signal_level)
      return -1;

   return 0;
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

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const int sig = MacdSignal();
   if(sig == 0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   if(sig > 0)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_sl_atr_mult);
      if(sl <= 0.0)
         return false;
      const double tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, strategy_tp_rr);
      if(tp <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "ea31337_macd_long";
      return true;
     }

   // sig < 0 -> short
   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;
   const double sl = QM_StopATRFromValue(_Symbol, QM_SELL, entry, atr_value, strategy_sl_atr_mult);
   if(sl <= 0.0)
      return false;
   const double tp = QM_TakeRR(_Symbol, QM_SELL, entry, sl, strategy_tp_rr);
   if(tp <= 0.0)
      return false;
   req.type   = QM_SELL;
   req.price  = 0.0;
   req.sl     = sl;
   req.tp     = tp;
   req.reason = "ea31337_macd_short";
   return true;
  }

// Fixed ATR stop/RR target carry the position; no active trailing.
void Strategy_ManageOpenPosition()
  {
  }

// Discretionary exit: time stop (>= exit_max_bars held) OR opposite MACD signal.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Find this EA's open position to read its direction + open time.
   long pos_type = -1;
   datetime open_time = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      pos_type  = PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      break;
     }
   if(pos_type < 0)
      return false;

   // Time exit: bars held = elapsed broker seconds / bar seconds. Pure time
   // math (no iTime/Bars strategy reads). PeriodSeconds() is framework-safe.
   const int bar_secs = PeriodSeconds(_Period);
   if(bar_secs > 0 && open_time > 0)
     {
      const long held_bars = (long)((TimeCurrent() - open_time) / bar_secs);
      if(held_bars >= strategy_exit_max_bars)
         return true;
     }

   // Opposite-signal exit: long open + fresh short trigger, or short open +
   // fresh long trigger.
   const int sig = MacdSignal();
   if(pos_type == POSITION_TYPE_BUY && sig < 0)
      return true;
   if(pos_type == POSITION_TYPE_SELL && sig > 0)
      return true;

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
