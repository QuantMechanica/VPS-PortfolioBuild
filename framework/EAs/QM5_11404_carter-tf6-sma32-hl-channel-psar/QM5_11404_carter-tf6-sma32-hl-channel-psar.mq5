#property strict
#property version   "5.0"
#property description "QM5_11404 carter-tf6-sma32-hl-channel-psar — SMA32 High/Low channel break + PSAR + SMA100/200 (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11404 carter-tf6-sma32-hl-channel-psar
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Trend Following Systems" (2014), Strategy #6.
// Card: artifacts/cards_approved/QM5_11404_carter-tf6-sma32-hl-channel-psar.md
//       (g0_status APPROVED).
//
// Concept (closed-bar reads, shift 1 = last closed bar):
//   A moving-average channel is built from SMA(period) on the HIGH series
//   (upper rail) and SMA(period) on the LOW series (lower rail). A close
//   outside that channel, aligned with the SMA100/200 trend stack and a PSAR
//   that sits on the correct side of price, is the trend-resumption signal.
//
// Card mechanics (closed-bar reads, shift 1 = last closed trigger bar):
//   LONG (mirror for SHORT):
//     close[1] > SMA(period, HIGH)[1]
//     close[1] > SMA100[1] AND close[1] > SMA200[1]
//     close[1] > open[1]
//     PSAR[1] < close[1]
//
//   Stop   : 5-bar swing low/high (QM_StopStructure, lookback = swing_bars).
//   Take   : entry +/- tp_atr_mult * ATR(atr_period)  (Carter TP ~ATR*1.5).
//   Manage : optional break-even shift at +1 * ATR (QM_TM_MoveToBreakEven).
//   Spread : skip only a genuinely WIDE spread (> 20 pips by default).
//            Fail-OPEN on .DWX zero modeled spread.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11404;
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
input int    strategy_channel_period     = 32;    // SMA period on HIGH/LOW series (channel rails)
input int    strategy_sma_mid_period     = 100;   // trend filter SMA (mid)
input int    strategy_sma_slow_period    = 200;   // trend filter SMA (slow)
input double strategy_psar_step          = 0.02;  // Parabolic SAR acceleration step
input double strategy_psar_max           = 0.2;   // Parabolic SAR max acceleration
input int    strategy_swing_bars         = 5;     // swing-low/high lookback for the structural stop
input int    strategy_atr_period         = 14;    // ATR period (take-profit / break-even reference)
input double strategy_tp_atr_mult        = 1.5;   // take-profit distance = mult * ATR
input bool   strategy_use_breakeven      = true;  // shift to break-even at +1*ATR
input int    strategy_spread_cap_pips    = 20;    // skip only if modeled spread exceeds this cap
input int    strategy_max_stop_pips      = 50;    // P2 cap: structural stop cannot exceed this distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only; channel/PSAR/trend work is on
// the closed-bar path in Strategy_EntrySignal. Fail-OPEN on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double spread_cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_spread_cap_pips);
   if(spread_cap <= 0.0)
      return false;

   const double spread = ask - bid;
   if(spread > 0.0 && spread > spread_cap)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   // Closed-bar prices: shift 1 = trigger bar.
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double open1  = iOpen(_Symbol,  _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0 || open1 <= 0.0)
      return false;

   // --- Channel rails: SMA on the HIGH series (upper) and LOW series (lower) ---
   const double upper1 = QM_SMA(_Symbol, _Period, strategy_channel_period, 1, PRICE_HIGH);
   const double lower1 = QM_SMA(_Symbol, _Period, strategy_channel_period, 1, PRICE_LOW);
   if(upper1 <= 0.0 || lower1 <= 0.0)
      return false;

   // --- Trend filter STATE: close vs SMA100 / SMA200 ---
   const double sma_mid  = QM_SMA(_Symbol, _Period, strategy_sma_mid_period,  1, PRICE_CLOSE);
   const double sma_slow = QM_SMA(_Symbol, _Period, strategy_sma_slow_period, 1, PRICE_CLOSE);
   if(sma_mid <= 0.0 || sma_slow <= 0.0)
      return false;

   // --- PSAR STATE: dot side relative to the trigger close ---
   const double sar1 = QM_SAR(_Symbol, _Period, strategy_psar_step, strategy_psar_max, 1);
   if(sar1 <= 0.0)
      return false;

   const bool long_ok = (close1 > upper1 &&
                         close1 > sma_mid &&
                         close1 > sma_slow &&
                         close1 > open1 &&
                         sar1 < close1);

   const bool short_ok = (close1 < lower1 &&
                          close1 < sma_mid &&
                          close1 < sma_slow &&
                          close1 < open1 &&
                          sar1 > close1);

   if(!long_ok && !short_ok)
      return false;

   const QM_OrderType side = long_ok ? QM_BUY : QM_SELL;

   // Entry reference at the live quote for the chosen side.
   const double entry = (side == QM_BUY)
                        ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   // Stop: 5-bar swing low (long) / swing high (short) structural stop.
   double sl = QM_StopStructure(_Symbol, side, entry, strategy_swing_bars);
   if(sl <= 0.0)
      return false;

   const double max_stop_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_max_stop_pips);
   if(max_stop_distance > 0.0 && MathAbs(entry - sl) > max_stop_distance)
     {
      const double capped_sl = QM_StopFixedPips(_Symbol, side, entry, strategy_max_stop_pips);
      if(capped_sl <= 0.0)
         return false;
      sl = capped_sl;
     }

   if((side == QM_BUY && sl >= entry) || (side == QM_SELL && sl <= entry))
      return false;

   // Take: ATR * tp_atr_mult from entry, same direction.
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;
   const double tp = QM_TakeATRFromValue(_Symbol, side, entry, atr_value, strategy_tp_atr_mult);
   if(tp <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = (side == QM_BUY) ? "carter_sma32hl_break_long" : "carter_sma32hl_break_short";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// Optional break-even shift at +1*ATR. Trigger distance is derived from ATR and
// converted to pips so it scales across 5-digit / JPY symbols.
void Strategy_ManageOpenPosition()
  {
   if(!strategy_use_breakeven)
      return;
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return;

   // Convert one ATR of price distance to whole pips for the BE trigger.
   const double pip = QM_StopRulesPipsToPriceDistance(_Symbol, 1);
   if(pip <= 0.0)
      return;
   const int trigger_pips = (int)MathRound(atr_value / pip);
   if(trigger_pips <= 0)
      return;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      QM_TM_MoveToBreakEven(ticket, trigger_pips, 2);
     }
  }

// No discretionary exit — fixed structural SL + ATR TP carry the trade.
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
