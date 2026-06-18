#property strict
#property version   "5.0"
#property description "QM5_11407 carter-tf17-ema18-adx-pullback — EMA18 + ADX pullback stop-order (H4)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11407 carter-tf17-ema18-adx-pullback
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Trend Following Systems" (2014), Strategy #17.
// Card: artifacts/cards_approved/QM5_11407_carter-tf17-ema18-adx-pullback.md
//       (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1; STATES vs the single EVENT):
//   Trend STATE   : close[1] vs EMA18[1] decides direction
//                     close[1] > EMA18[1]  -> uptrend candidate (long)
//                     close[1] < EMA18[1]  -> downtrend candidate (short)
//   Strength STATE: ADX(adx_period)[1] > adx_threshold on the touch bar
//                   (confirms trend strength persists DURING the pullback).
//   Touch  STATE  : LONG  -> low[1]  <= EMA18[1]   (price pulled back to EMA18)
//                   SHORT -> high[1] >= EMA18[1]   (price rallied to EMA18)
//   EVENT (single): the pending STOP order triggers when price breaks the touch
//                   bar's extreme:
//                     LONG  BUYSTOP  at high[1] + buffer
//                     SHORT SELLSTOP at low[1]  - buffer
//                   Using a resting stop order as the ONE event sidesteps the
//                   two-cross-same-bar zero-trade trap: trend + ADX + touch are
//                   STATES read on the closed bar; the break is the event.
//   Stop loss     : structure stop over the recent swing (swing_lookback bars),
//                   capped at sl_cap_pips.
//   Take profit   : RR multiple of the realised risk distance (entry->SL).
//   Break-even    : move SL to BE once price has run +be_trigger_atr * ATR.
//   Spread guard  : fail-open on .DWX zero modeled spread; block only a
//                   genuinely wide spread > spread_pct_of_stop of stop distance.
//
// Pending-order lifecycle: at most ONE resting stop order per magic at a time;
// it auto-expires after order_expiry_bars closed bars if not triggered, and a
// fresh closed-bar signal replaces a stale resting order. One position per magic.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11407;
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
input int    strategy_ema_period        = 18;     // dynamic S/R EMA for the pullback
input int    strategy_adx_period        = 12;     // ADX trend-strength period
input double strategy_adx_threshold     = 25.0;   // ADX must exceed this on the touch bar
input int    strategy_entry_buffer_pips = 1;      // stop trigger offset beyond touch-bar extreme
input int    strategy_swing_lookback    = 10;     // bars for the structure (swing) stop
input int    strategy_sl_buffer_pips    = 2;      // extra pips beyond the swing extreme
input int    strategy_sl_cap_pips       = 70;     // hard SL distance cap (card P2 cap)
input double strategy_tp_rr             = 2.0;    // take-profit as RR multiple of risk
input int    strategy_atr_period        = 14;     // ATR period (break-even trigger scale)
input double strategy_be_trigger_atr    = 1.0;    // move SL to BE after +N*ATR of favourable run
input int    strategy_order_expiry_bars = 3;      // resting stop order lifetime, in closed bars
input double strategy_spread_pct_of_stop = 20.0;  // block if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Helpers (EA-local, non-framework)
// -----------------------------------------------------------------------------

// Pip size (price units) for the symbol. 5/3-digit symbols use 10*point.
double Carter_PipSize()
  {
   const double point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(digits == 3 || digits == 5)
      return point * 10.0;
   return point;
  }

// Count this EA's resting pending orders (BUYSTOP/SELLSTOP) for _Symbol/magic.
int Carter_PendingCount(const int magic)
  {
   int count = 0;
   const int total = OrdersTotal();
   for(int i = 0; i < total; ++i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      if(!OrderSelect(ticket))
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      count++;
     }
   return count;
  }

// Remove this EA's resting pending orders for _Symbol/magic (stale-order cleanup).
void Carter_RemovePending(const int magic)
  {
   const int total = OrdersTotal();
   for(int i = total - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      if(!OrderSelect(ticket))
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      QM_TM_RemovePendingOrder(ticket, "carter_replace_stale_stop");
     }
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only. Fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate, do not block here

   const double stop_distance = atr_value; // reference scale for the spread cap
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Pullback stop-order entry. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const int magic = QM_FrameworkMagic();

   // One position per magic: if we are already in a trade, do nothing (and let
   // any leftover resting order alone — it cannot fill while a position is open).
   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;

   // --- Closed-bar STATES (shift 1 = the touch-bar candidate) ---
   const double ema   = QM_EMA(_Symbol, _Period, strategy_ema_period, 1);
   const double adx   = QM_ADX(_Symbol, _Period, strategy_adx_period, 1);
   if(ema <= 0.0 || adx <= 0.0)
      return false;

   // Strength STATE: trend strength must persist on the touch bar.
   if(adx <= strategy_adx_threshold)
      {
       // No fresh setup this bar — clear any stale resting order so we do not
       // leave a stop order from a setup whose ADX has since decayed.
       Carter_RemovePending(magic);
       return false;
      }

   const double high1  = iHigh(_Symbol, _Period, 1);  // perf-allowed: single closed-bar reads
   const double low1   = iLow(_Symbol, _Period, 1);
   const double close1 = iClose(_Symbol, _Period, 1);
   if(high1 <= 0.0 || low1 <= 0.0 || close1 <= 0.0)
      return false;

   const double pip = Carter_PipSize();
   if(pip <= 0.0)
      return false;

   bool is_long  = false;
   bool is_short = false;

   // Trend STATE decides direction; Touch STATE confirms the pullback to EMA18.
   if(close1 > ema && low1 <= ema)        // uptrend + pullback low touched EMA18
      is_long = true;
   else if(close1 < ema && high1 >= ema)  // downtrend + rally high touched EMA18
      is_short = true;

   if(!is_long && !is_short)
     {
      Carter_RemovePending(magic);
      return false;
     }

   // Fresh setup this bar — replace any stale resting order with the new one.
   if(Carter_PendingCount(magic) > 0)
      Carter_RemovePending(magic);

   // --- EVENT trigger price: break of the touch bar's extreme ---
   const double trigger = is_long
                          ? (high1 + strategy_entry_buffer_pips * pip)
                          : (low1  - strategy_entry_buffer_pips * pip);
   if(trigger <= 0.0)
      return false;

   const QM_OrderType otype = is_long ? QM_BUY_STOP : QM_SELL_STOP;

   // --- Stop loss: recent swing structure, capped at sl_cap_pips ---
   double sl = QM_StopStructure(_Symbol,
                                is_long ? QM_BUY : QM_SELL,
                                trigger,
                                strategy_swing_lookback);
   if(sl > 0.0 && strategy_sl_buffer_pips > 0)
      {
       const double buf = strategy_sl_buffer_pips * pip;
       sl = is_long ? (sl - buf) : (sl + buf);
      }

   // Enforce the hard pip cap on the stop distance (fall back to it if structure
   // is unusable or wider than the cap).
   const double cap_dist = strategy_sl_cap_pips * pip;
   if(sl <= 0.0)
      sl = is_long ? (trigger - cap_dist) : (trigger + cap_dist);
   else
      {
       const double sl_dist = MathAbs(trigger - sl);
       if(sl_dist > cap_dist)
          sl = is_long ? (trigger - cap_dist) : (trigger + cap_dist);
      }
   if(sl <= 0.0)
      return false;

   // --- Take profit: RR multiple of the risk distance (trigger -> SL) ---
   const double tp = QM_TakeRR(_Symbol, is_long ? QM_BUY : QM_SELL, trigger, sl, strategy_tp_rr);
   if(tp <= 0.0)
      return false;

   req.type               = otype;
   req.price              = trigger;   // pending stop price
   req.sl                 = sl;
   req.tp                 = tp;
   req.reason             = is_long ? "carter_ema18_adx_pb_long" : "carter_ema18_adx_pb_short";
   req.expiration_seconds = strategy_order_expiry_bars * PeriodSeconds(_Period);
   return true;
  }

// Break-even management on the open position once it has run +N*ATR.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return;

   const double pip = Carter_PipSize();
   if(pip <= 0.0)
      return;

   // Convert the +N*ATR break-even trigger to pips for the framework helper.
   const int trigger_pips = (int)MathRound((strategy_be_trigger_atr * atr_value) / pip);
   if(trigger_pips <= 0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      QM_TM_MoveToBreakEven(ticket, trigger_pips, strategy_sl_buffer_pips);
     }
  }

// No discretionary close beyond SL/TP/BE; the resting stop + RR target govern exits.
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
