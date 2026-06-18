#property strict
#property version   "5.0"
#property description "QM5_11337 TC20 #13 — EMA(5/10) Cross + RSI(10,Median/hl2) 50-state (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11337
// -----------------------------------------------------------------------------
// Strategy (Thomas Carter, "20 Forex Trading Strategies" #13, H1):
//   - EVENT  : EMA(5) crosses EMA(10) on the last closed bar (the trigger).
//   - STATE  : RSI(10) on Median price (H+L)/2 == PRICE_MEDIAN confirms the
//              direction by being on the correct side of the 50 midline.
//   - Stops  : fixed 30-pip SL, fixed 50-pip TP (pip-scale correct).
//
// DESIGN NOTE (zero-trade trap avoidance — DWX invariant #4):
//   The card prose says the RSI should "approach and cross 50 in the same
//   direction" simultaneously with the EMA cross. Two fresh cross EVENTS on
//   the same bar almost never coincide on .DWX → 0 trades. So the EMA cross is
//   the single EVENT and RSI-vs-50 is a directional STATE filter:
//     LONG  : EMA5 crosses ABOVE EMA10  AND  RSI(10,median)[1] >= 50
//     SHORT : EMA5 crosses BELOW EMA10  AND  RSI(10,median)[1] <= 50
//   This preserves the card's intent (momentum confirms the trend trigger)
//   without the impossible double-cross requirement. Flagged in build output.
//
// Framework corset: only the five Strategy_* hooks + inputs are EA-specific.
// All per-tick scaffolding, risk, magic, news, Friday-close live in framework.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11337;
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
input ENUM_TIMEFRAMES strategy_signal_tf      = PERIOD_H1;  // H1 base TF (card)
input int    strategy_fast_ema_period         = 5;          // EMA fast (yellow)
input int    strategy_slow_ema_period         = 10;         // EMA slow (red)
input int    strategy_rsi_period              = 10;         // RSI period
input double strategy_rsi_midline             = 50.0;       // RSI directional state threshold
input double strategy_sl_pips                 = 30.0;       // fixed SL (card)
input double strategy_tp_pips                 = 50.0;       // fixed TP (card)
input double strategy_max_spread_pips         = 20.0;       // spread cap (card); fail-OPEN on 0 spread

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick. Spread cap is fail-OPEN: a .DWX
// tester quotes ask==bid (0 modeled spread) → we must NOT block on that.
// Only a genuinely wide, well-formed quote (ask>bid by more than the cap)
// blocks. Zero/invalid prices never block here (the entry path validates them).
bool Strategy_NoTradeFilter()
  {
   if(strategy_max_spread_pips <= 0.0)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false; // fail-OPEN: bad point data is not a "wide spread"

   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const int pip_factor = (digits == 3 || digits == 5) ? 10 : 1;
   const double cap_price = strategy_max_spread_pips * point * pip_factor;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   // Only block on a genuinely wide, well-formed spread. ask==bid (0 spread on
   // .DWX) and any zero/invalid price fall through to "allowed".
   if(ask > 0.0 && bid > 0.0 && ask > bid && (ask - bid) > cap_price)
      return true;

   return false;
  }

// Populate `req` and return TRUE to fire a NEW entry on this closed bar.
// Caller guarantees QM_IsNewBar() == true. One position per magic.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_fast_ema_period <= 0 ||
      strategy_slow_ema_period <= 0 ||
      strategy_fast_ema_period >= strategy_slow_ema_period ||
      strategy_rsi_period <= 1 ||
      strategy_sl_pips <= 0.0 ||
      strategy_tp_pips <= 0.0)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   // One position per magic: bail if we already hold one on this symbol+magic.
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }

   // --- EVENT: EMA(5) cross EMA(10) on the last closed bar (shift 1 vs 2) ---
   const double fast_last = QM_EMA(_Symbol, strategy_signal_tf, strategy_fast_ema_period, 1);
   const double slow_last = QM_EMA(_Symbol, strategy_signal_tf, strategy_slow_ema_period, 1);
   const double fast_prev = QM_EMA(_Symbol, strategy_signal_tf, strategy_fast_ema_period, 2);
   const double slow_prev = QM_EMA(_Symbol, strategy_signal_tf, strategy_slow_ema_period, 2);
   if(fast_last <= 0.0 || slow_last <= 0.0 || fast_prev <= 0.0 || slow_prev <= 0.0)
      return false;

   const bool bullish_cross = (fast_prev <= slow_prev && fast_last > slow_last);
   const bool bearish_cross = (fast_prev >= slow_prev && fast_last < slow_last);
   if(!bullish_cross && !bearish_cross)
      return false;

   // --- STATE: RSI(10) on Median price (H+L)/2 vs the 50 midline ---
   const double rsi = QM_RSI(_Symbol, strategy_signal_tf, strategy_rsi_period, 1, PRICE_MEDIAN);
   if(rsi <= 0.0)
      return false;

   const bool long_ok  = bullish_cross && (rsi >= strategy_rsi_midline);
   const bool short_ok = bearish_cross && (rsi <= strategy_rsi_midline);
   if(!long_ok && !short_ok)
      return false;

   const QM_OrderType side = long_ok ? QM_BUY : QM_SELL;

   const double entry = (side == QM_BUY)
                        ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   // Fixed pip SL/TP, pip-scale correct (3/5-digit & JPY safe).
   const double sl = QM_StopFixedPips(_Symbol, side, entry, (int)strategy_sl_pips);
   const double tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_tp_pips / strategy_sl_pips);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   if(side == QM_BUY && (sl >= entry || tp <= entry))
      return false;
   if(side == QM_SELL && (sl <= entry || tp >= entry))
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = long_ok ? "TC20_13_EMA5x10_RSI50_LONG" : "TC20_13_EMA5x10_RSI50_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   return true;
  }

// Card uses fixed SL/TP only; no trailing/BE in P2 (P3 sweep territory).
void Strategy_ManageOpenPosition()
  {
  }

// Card exit is purely the fixed 30-pip SL / 50-pip TP attached at entry.
// No discretionary close.
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
