#property strict
#property version   "5.0"
#property description "QM5_11646 robo-rsi8-pending-d1 — RSI(8) momentum-breakout pending-stop entries (D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11646 robo-rsi8-pending-d1
// -----------------------------------------------------------------------------
// Source: RoboForex Educational Team, "Forex Strategy Collection" (~2015),
//         strategy "RSI Pending", page 115.
// Card: artifacts/cards_approved/QM5_11646_robo-rsi8-pending-d1.md (g0 APPROVED).
//
// Mechanics (D1, closed-bar reads at shift 1):
//   Setup STATE (long) : RSI(8) on the just-closed D1 bar (shift 1) > rsi_buy.
//   Setup STATE (short): RSI(8) on the just-closed D1 bar (shift 1) < rsi_sell.
//   Entry EVENT        : a PENDING stop order placed beyond the current D1 open
//                        FILLS. The RSI condition is the setup; the breakout
//                        fill is the entry — momentum has to confirm direction.
//                          long : BUY STOP  = current-D1-open + offset_pips
//                          short: SELL STOP = current-D1-open - offset_pips
//   Pending lifetime   : valid for the CURRENT D1 bar only; expires (auto-cancel)
//                        at D1 bar close via req.expiration_seconds.
//   OCO / one-per-magic: at most one open position and one live pending per
//                        magic. On each new bar, leftover pendings from the prior
//                        bar are removed before a fresh one is placed; if a
//                        position is open, any stray pending is removed.
//   Stop  : ATR(14)-derived, sl_atr_mult * ATR from the pending fill price.
//   Take  : ATR(14)-derived, tp_atr_mult * ATR from the pending fill price.
//   Spread guard : block only a genuinely wide spread (.DWX models 0 spread —
//                  fail-open on zero).
//
// Two-cross trap avoided: the setup is a single closed-bar STATE (RSI level),
// never two coincident cross events. The breakout fill is the only event.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11646;
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
input int    strategy_rsi_period         = 8;     // RSI period (card: RSI(8))
input double strategy_rsi_buy_level      = 70.0;  // RSI > this on closed bar => long setup
input double strategy_rsi_sell_level     = 30.0;  // RSI < this on closed bar => short setup
input int    strategy_breakout_offset_pips = 20;  // pending stop offset beyond D1 open
input int    strategy_atr_period         = 14;    // ATR period (stop / target)
input double strategy_sl_atr_mult        = 2.0;   // stop distance = mult * ATR from fill
input double strategy_tp_atr_mult        = 4.0;   // target distance = mult * ATR from fill
input double strategy_spread_pct_of_stop = 15.0;  // block if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Pending-order helpers (magic-scoped). Iterating OrdersTotal() is standard
// trade-ops, not an indicator reimplementation.
// -----------------------------------------------------------------------------

int Strategy_PendingCount(const int magic)
  {
   int count = 0;
   const int total = OrdersTotal();
   for(int i = 0; i < total; ++i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      count++;
     }
   return count;
  }

// Remove every live pending order for this magic/symbol (OCO + stale-bar cancel).
void Strategy_RemovePendings(const int magic, const string reason)
  {
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      QM_TM_RemovePendingOrder(ticket, reason);
     }
  }

// Seconds remaining until the current D1 bar closes, so the pending expires at
// bar close (auto-cancel if unfilled). iTime(...,0) = current bar open time;
// PeriodSeconds(PERIOD_D1) = 86400. perf-allowed: single current-bar read.
int Strategy_SecondsToBarClose()
  {
   const datetime bar_open = iTime(_Symbol, _Period, 0); // perf-allowed: current bar open
   if(bar_open <= 0)
      return PeriodSeconds(_Period);
   const datetime bar_close = bar_open + PeriodSeconds(_Period);
   const int remaining = (int)(bar_close - TimeCurrent());
   // Guard a non-positive value so the framework still sets an expiration.
   return (remaining > 0) ? remaining : 1;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only; setup/entry work runs on the
// closed-bar path. Fail-open on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to entry gate

   const double stop_distance = strategy_sl_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar D1 gate).
// Places ONE pending stop in the RSI-indicated direction beyond the current D1
// open. The framework sends it as a TRADE_ACTION_PENDING order (req.type stop +
// req.price + req.expiration_seconds), sizing lots from the pending price's SL.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const int magic = QM_FrameworkMagic();

   // One position per magic: never stack entries.
   if(QM_TM_OpenPositionCount(magic) > 0)
     {
      // A position is open — drop any orphan pending leg (OCO cleanup).
      Strategy_RemovePendings(magic, "oco_position_open");
      return false;
     }

   // New bar: cancel any pending left over from the previous D1 bar before
   // (re)placing one for the current bar. This is the explicit OCO/expire step.
   Strategy_RemovePendings(magic, "stale_bar_pending");

   // --- Setup STATE: RSI(8) on the just-closed D1 bar (shift 1). ---
   const double rsi1 = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   if(rsi1 <= 0.0)
      return false;

   QM_OrderType side;
   if(rsi1 > strategy_rsi_buy_level)
      side = QM_BUY_STOP;     // overbought momentum -> upside breakout pending
   else if(rsi1 < strategy_rsi_sell_level)
      side = QM_SELL_STOP;    // oversold momentum -> downside breakout pending
   else
      return false;           // no setup this bar

   // --- Reference price: current D1 bar open. perf-allowed single read. ---
   const double bar_open = iOpen(_Symbol, _Period, 0); // perf-allowed: current bar open
   if(bar_open <= 0.0)
      return false;

   const double offset = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_breakout_offset_pips);
   if(offset <= 0.0)
      return false;

   double pending_price;
   if(side == QM_BUY_STOP)
      pending_price = bar_open + offset;
   else
      pending_price = bar_open - offset;
   pending_price = QM_TM_NormalizePrice(_Symbol, pending_price);
   if(pending_price <= 0.0)
      return false;

   // ATR-derived SL/TP anchored to the pending fill price (the card measures the
   // stop from the order fill price).
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, side, pending_price, atr_value, strategy_sl_atr_mult);
   const double tp = QM_TakeATRFromValue(_Symbol, side, pending_price, atr_value, strategy_tp_atr_mult);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type               = side;
   req.price              = pending_price;
   req.sl                 = sl;
   req.tp                 = tp;
   req.reason             = (side == QM_BUY_STOP) ? "robo_rsi8_buystop" : "robo_rsi8_sellstop";
   req.expiration_seconds = Strategy_SecondsToBarClose(); // expire at D1 bar close
   return true;
  }

// No active trade management beyond the fixed ATR stop/target.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary close: exits are the ATR SL/TP. Pending lifecycle (cancel /
// expire) is handled in Strategy_EntrySignal on each new bar.
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
