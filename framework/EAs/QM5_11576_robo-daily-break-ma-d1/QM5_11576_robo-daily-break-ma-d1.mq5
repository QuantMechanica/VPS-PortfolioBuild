#property strict
#property version   "5.0"
#property description "QM5_11576 robo-daily-break-ma-d1 — RoboForex Daily Breakout + MA trend (D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11576 robo-daily-break-ma-d1
// -----------------------------------------------------------------------------
// Source: RoboForex strategy collection, "Strategy Daily Breakout and Moving
//         Average", page 117. Card: artifacts/cards_approved/
//         QM5_11576_robo-daily-break-ma-d1.md (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1; D1):
//   Trend STATE   : EMA(34, close) vs SMA(20, low).
//                     EMA above SMA-low  -> long-only regime.
//                     EMA below SMA-low  -> short-only regime.
//   ADX  STATE    : ADX(13) > adx_threshold (trend strength confirmation).
//   Breakout EVENT: the SINGLE trigger. The last closed D1 bar broke the
//                     extreme of the prior D1 bar:
//                     LONG  -> close[1] > high[2]  (broke prior-day high).
//                     SHORT -> close[1] < low[2]   (broke prior-day low).
//                   Using prior CLOSE vs prior-day EXTREME keeps the rule
//                   gap-safe on .DWX (open[0]==close[1]) and bounded (2 closed
//                   bars). The MA relation is a STATE, the break is the EVENT —
//                   so the two-cross-same-bar zero-trade trap cannot fire.
//   Entry         : market at the next D1 bar open (this closed-bar tick).
//   Stop / Take   : fixed pip brackets, scale-correct via pips->price distance.
//                     SL = sl_pips, TP = tp_pips (RoboForex 30-50 / 100-150 pts).
//   Defensive exit: EMA(34) crosses SMA(20-low) against the open position —
//                     i.e. the trend STATE flips. One event per closed bar.
//   Spread guard  : block only a genuinely wide spread (fail-open on .DWX
//                     zero modeled spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11576;
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
input int    strategy_ema_period         = 34;     // trend EMA on close
input int    strategy_sma_period         = 20;     // trend SMA on low ("20 SMA Low")
input int    strategy_adx_period         = 13;     // ADX trend-strength period
input double strategy_adx_threshold      = 25.0;   // ADX must exceed this (sweep 20/25/30)
input double strategy_tp_pips            = 125.0;  // take profit, pips (source 100-150)
input double strategy_sl_pips            = 40.0;   // stop loss, pips (source 30-50)
input double strategy_spread_pct_of_stop = 15.0;   // block if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — regime/breakout work runs on the
// closed-bar path in Strategy_EntrySignal. Fail-open on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   // Stop distance reference for the spread cap, scaled to the symbol.
   const double stop_distance = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_sl_pips);
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Breakout-in-direction-of-MA-trend entry. Caller guarantees QM_IsNewBar()==true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- ADX STATE: trend strength on the closed bar ---
   const double adx = QM_ADX(_Symbol, _Period, strategy_adx_period, 1);
   if(adx <= 0.0)
      return false;
   if(!(adx > strategy_adx_threshold))
      return false;

   // --- Trend STATE: EMA(close) vs SMA(low) on the closed bar ---
   const double ema     = QM_EMA(_Symbol, _Period, strategy_ema_period, 1, PRICE_CLOSE);
   const double sma_low = QM_SMA(_Symbol, _Period, strategy_sma_period, 1, PRICE_LOW);
   if(ema <= 0.0 || sma_low <= 0.0)
      return false;

   // --- Breakout EVENT: prior-day extreme broken by the last closed bar ---
   // Bounded, perf-allowed: prior-day OHLC from closed D1 bars (shift 1 & 2).
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: closed-bar read
   const double high2  = iHigh(_Symbol, _Period, 2);  // perf-allowed: prior-day high
   const double low2   = iLow(_Symbol, _Period, 2);   // perf-allowed: prior-day low
   if(close1 <= 0.0 || high2 <= 0.0 || low2 <= 0.0)
      return false;

   const bool long_regime  = (ema > sma_low);
   const bool short_regime = (ema < sma_low);

   QM_OrderType side;
   if(long_regime && close1 > high2)        // bullish trend + broke prior-day high
      side = QM_BUY;
   else if(short_regime && close1 < low2)   // bearish trend + broke prior-day low
      side = QM_SELL;
   else
      return false;

   // --- Build the entry. Framework sizes lots (no lots field). ---
   double entry = SymbolInfoDouble(_Symbol, (side == QM_BUY) ? SYMBOL_ASK : SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopFixedPips(_Symbol, side, entry, (int)strategy_sl_pips);
   const double tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_tp_pips / strategy_sl_pips);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = (side == QM_BUY) ? "robo_break_ma_long" : "robo_break_ma_short";
   return true;
  }

// Fixed pip brackets only; no active trade management. Defensive MA-flip exit
// lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Defensive exit: trend STATE flips against the open position (EMA crosses the
// SMA-low to the opposite side). One event evaluated on the closed bar.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double ema_now  = QM_EMA(_Symbol, _Period, strategy_ema_period, 1, PRICE_CLOSE);
   const double sma_now  = QM_SMA(_Symbol, _Period, strategy_sma_period, 1, PRICE_LOW);
   const double ema_prev = QM_EMA(_Symbol, _Period, strategy_ema_period, 2, PRICE_CLOSE);
   const double sma_prev = QM_SMA(_Symbol, _Period, strategy_sma_period, 2, PRICE_LOW);
   if(ema_now <= 0.0 || sma_now <= 0.0 || ema_prev <= 0.0 || sma_prev <= 0.0)
      return false;

   // Determine the held side and close on the opposing cross.
   bool is_long = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      is_long = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      break;
     }

   if(is_long)
     {
      // long held -> exit when EMA crosses below SMA-low
      const bool crossed_down = (ema_prev >= sma_prev && ema_now < sma_now);
      return crossed_down;
     }
   // short held -> exit when EMA crosses above SMA-low
   const bool crossed_up = (ema_prev <= sma_prev && ema_now > sma_now);
   return crossed_up;
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
