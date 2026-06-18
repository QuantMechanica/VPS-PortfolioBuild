#property strict
#property version   "5.0"
#property description "QM5_11733 tc-m5-s15-ema-bb-channel-macd — EMA channel + MACD trigger (M5)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11733 tc-m5-s15-ema-bb-channel-macd
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)"
//         (367145560), Strategy #15. Card:
//         artifacts/cards_approved/QM5_11733_tc-m5-s15-ema-bb-channel-macd.md
//         (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1; M5):
//   Channel STATE (Keltner-like, built from EMA(50) of bar High / Low):
//       upper = EMA(channel_period, PRICE_HIGH)
//       lower = EMA(channel_period, PRICE_LOW)
//   Trend  STATE : fast EMA(15) on close vs the channel —
//       long  trend : ema_fast > upper   (EMA15 breaks above the channel)
//       short trend : ema_fast < lower   (EMA15 breaks below the channel)
//   Trigger EVENT (the ONE fresh event — avoids the two-cross-same-bar trap):
//       MACD histogram (main - signal) CROSSES zero in the trend's direction.
//       long  : hist[2] <= 0 AND hist[1] > 0
//       short : hist[2] >= 0 AND hist[1] < 0
//   The channel breakout is a STATE that must hold ON the trigger bar; the MACD
//   zero-cross is the single per-bar EVENT. They are never required to be two
//   simultaneous fresh crosses.
//   Stop  : 2 * ATR(14) from entry (long below / short above).
//   Take  : symmetric distance via RR = tp_atr_mult / sl_atr_mult (card: 1:1).
//   Exit  : SL / TP only (card: "no discretionary exit override"). A defensive
//           exit fires if the fast EMA falls back inside the channel against the
//           open position (trend state lost).
//   Spread guard : block only a genuinely wide spread (fail-open on .DWX zero
//                  modeled spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11733;
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
input int    strategy_ema_fast_period   = 15;     // fast EMA on close (EMA15)
input int    strategy_channel_period    = 50;     // channel EMA period (EMA50 High/Low)
input int    strategy_macd_fast         = 15;     // MACD fast EMA (card: 15)
input int    strategy_macd_slow         = 70;     // MACD slow EMA (card: 70)
input int    strategy_macd_signal       = 24;     // MACD signal period (card: 24)
input int    strategy_atr_period        = 14;     // ATR period (stop / target)
input double strategy_sl_atr_mult       = 2.0;    // stop distance = mult * ATR
input double strategy_tp_atr_mult       = 2.0;    // target distance = mult * ATR (card: 1:1)
input bool   strategy_use_defensive_exit = true;  // close if EMA15 re-enters the channel
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — regime/signal work is in
// Strategy_EntrySignal on the closed-bar path. Fail-open on .DWX zero spread.
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

   // --- Channel STATE: EMA(50) of High / Low (closed bar) ---
   const double upper = QM_EMA(_Symbol, _Period, strategy_channel_period, 1, PRICE_HIGH);
   const double lower = QM_EMA(_Symbol, _Period, strategy_channel_period, 1, PRICE_LOW);
   if(upper <= 0.0 || lower <= 0.0)
      return false;

   // --- Trend STATE: fast EMA(15) on close vs the channel ---
   const double ema_fast = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1, PRICE_CLOSE);
   if(ema_fast <= 0.0)
      return false;

   const bool long_trend  = (ema_fast > upper);
   const bool short_trend = (ema_fast < lower);
   if(!long_trend && !short_trend)
      return false; // EMA15 inside the channel — no breakout state

   // --- Trigger EVENT: MACD histogram zero-cross (one fresh event per bar) ---
   // hist = MACD_Main - MACD_Signal. Compare shift 2 -> shift 1 for the cross.
   const double main1 = QM_MACD_Main(_Symbol, _Period,
                                     strategy_macd_fast, strategy_macd_slow,
                                     strategy_macd_signal, 1);
   const double sig1  = QM_MACD_Signal(_Symbol, _Period,
                                       strategy_macd_fast, strategy_macd_slow,
                                       strategy_macd_signal, 1);
   const double main2 = QM_MACD_Main(_Symbol, _Period,
                                     strategy_macd_fast, strategy_macd_slow,
                                     strategy_macd_signal, 2);
   const double sig2  = QM_MACD_Signal(_Symbol, _Period,
                                       strategy_macd_fast, strategy_macd_slow,
                                       strategy_macd_signal, 2);
   const double hist1 = main1 - sig1;
   const double hist2 = main2 - sig2;

   const bool macd_cross_up   = (hist2 <= 0.0 && hist1 > 0.0);
   const bool macd_cross_down = (hist2 >= 0.0 && hist1 < 0.0);

   // --- Compose: trend STATE + matching MACD EVENT ---
   QM_OrderType side;
   if(long_trend && macd_cross_up)
      side = QM_BUY;
   else if(short_trend && macd_cross_down)
      side = QM_SELL;
   else
      return false;

   // --- Stop / target from the same ATR value ---
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, side, entry, atr_value, strategy_sl_atr_mult);
   if(sl <= 0.0)
      return false;

   const double rr = (strategy_sl_atr_mult > 0.0)
                     ? (strategy_tp_atr_mult / strategy_sl_atr_mult) : 1.0;
   const double tp = QM_TakeRR(_Symbol, side, entry, sl, rr);
   if(tp <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = (side == QM_BUY) ? "ema_bb_chan_macd_long" : "ema_bb_chan_macd_short";
   return true;
  }

// No active trade management beyond the fixed ATR stop/target.
void Strategy_ManageOpenPosition()
  {
  }

// Defensive exit: fast EMA(15) falls back INSIDE the channel against the open
// position (the breakout state that justified the entry is lost). Card allows
// SL/TP-only; this guards a position whose trend state has reversed.
bool Strategy_ExitSignal()
  {
   if(!strategy_use_defensive_exit)
      return false;

   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double upper = QM_EMA(_Symbol, _Period, strategy_channel_period, 1, PRICE_HIGH);
   const double lower = QM_EMA(_Symbol, _Period, strategy_channel_period, 1, PRICE_LOW);
   const double ema_fast = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1, PRICE_CLOSE);
   if(upper <= 0.0 || lower <= 0.0 || ema_fast <= 0.0)
      return false;

   // Determine the open position's direction for this magic.
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && ema_fast < upper)
         return true;  // long but EMA15 dropped back into the channel
      if(ptype == POSITION_TYPE_SELL && ema_fast > lower)
         return true;  // short but EMA15 rose back into the channel
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
