#property strict
#property version   "5.0"
#property description "QM5_10474 MQL5 TDSGlobal Pending-Limit Momentum"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_10474 - MQL5 TDSGlobal Pending Limit Momentum
// -----------------------------------------------------------------------------
// Source: MQL5 CodeBase "TDSGlobal" (idea Scriptor, code Vladimir Karputov /
// barabashkakvn), https://www.mql5.com/en/code/23255. Card:
// artifacts/cards_approved/QM5_10474_mql5-tdsglobal.md (R1-R4 all PASS).
//
// Mechanic (H1 baseline, momentum-confirmed pending-limit reversal):
//   - Momentum confirmation from MACD + OsMA on the work timeframe.
//     OsMA = MACD_Main - MACD_Signal (standard OsMA identity), derived from the
//     pooled QM_MACD_* readers. The framework exposes no QM_OsMA / QM_Force
//     reader, and raw iForce/iOsMA calls are forbidden by the V5 build corset,
//     so Force Index is intentionally omitted; MACD + OsMA fully express the
//     card's "momentum confirmation bullish/bearish" rule.
//   - LONG setup (momentum bullish): MACD_Main > MACD_Signal (state) AND
//     OsMA > 0 AND OsMA rising vs the prior closed bar (the single fresh
//     trigger). Place a BUY LIMIT below price at entry_atr_fraction x ATR
//     (the source engine's limit-order distance logic).
//   - SHORT setup: mirror - SELL LIMIT above price.
//   - Stale/opposite pending orders for this magic are cancelled before a new
//     pending order is placed (card: at most one active pending per side,
//     opposite cancelled).
//   - SL = stop_atr_mult x ATR(atr_period) from the limit price.
//   - TP = take_rr x R (card baseline 2R).
//   - Unfilled pending orders expire after expiry_bars work-timeframe bars.
//   - Exit: close an open position on the opposite momentum setup.
//   - One position per magic (framework duplicate guard); no grid/martingale.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10474;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_signal_tf       = PERIOD_H1;  // Work TimeFrame (card: H1 baseline, sweep M15-D1)
input int    strategy_macd_fast                = 12;         // MACD fast EMA
input int    strategy_macd_slow                = 26;         // MACD slow EMA
input int    strategy_macd_signal              = 9;          // MACD signal SMA
input int    strategy_atr_period               = 14;         // ATR period for distance + stop
input double strategy_entry_atr_fraction       = 0.50;       // limit-order distance = fraction x ATR
input double strategy_stop_atr_mult            = 1.50;       // SL = mult x ATR (card baseline 1.5)
input double strategy_take_rr                  = 2.0;        // TP = R-multiple (card baseline 2R)
input int    strategy_expiry_bars              = 4;          // unfilled pending expires after N work bars

// ---------------------------------------------------------------------------
// Momentum classification on closed bars using pooled MACD readers.
// OsMA = MACD_Main - MACD_Signal. Returns +1 bullish, -1 bearish, 0 neutral.
//   LONG  : MACD_Main>MACD_Signal (state) AND OsMA>0 AND OsMA rising (trigger).
//   SHORT : MACD_Main<MACD_Signal (state) AND OsMA<0 AND OsMA falling (trigger).
// One fresh trigger (OsMA slope); the MACD relation and OsMA sign are states.
// ---------------------------------------------------------------------------
int Strategy_MomentumDirection()
  {
   const double macd_main_1 = QM_MACD_Main(_Symbol, strategy_signal_tf,
                                            strategy_macd_fast, strategy_macd_slow,
                                            strategy_macd_signal, 1, PRICE_CLOSE);
   const double macd_sig_1  = QM_MACD_Signal(_Symbol, strategy_signal_tf,
                                             strategy_macd_fast, strategy_macd_slow,
                                             strategy_macd_signal, 1, PRICE_CLOSE);
   const double macd_main_2 = QM_MACD_Main(_Symbol, strategy_signal_tf,
                                            strategy_macd_fast, strategy_macd_slow,
                                            strategy_macd_signal, 2, PRICE_CLOSE);
   const double macd_sig_2  = QM_MACD_Signal(_Symbol, strategy_signal_tf,
                                             strategy_macd_fast, strategy_macd_slow,
                                             strategy_macd_signal, 2, PRICE_CLOSE);

   const double osma_1 = macd_main_1 - macd_sig_1;
   const double osma_2 = macd_main_2 - macd_sig_2;

   if(macd_main_1 > macd_sig_1 && osma_1 > 0.0 && osma_1 > osma_2)
      return 1;
   if(macd_main_1 < macd_sig_1 && osma_1 < 0.0 && osma_1 < osma_2)
      return -1;
   return 0;
  }

bool Strategy_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
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
      return true;
     }
   return false;
  }

bool Strategy_HasOwnPendingOrder()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      return true;
     }
   return false;
  }

// Cancel every still-pending order for this magic + symbol. Used to drop
// stale/opposite pending orders before placing a fresh one.
void Strategy_CancelOwnPendingOrders(const string reason)
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      QM_TM_RemovePendingOrder(ticket, reason);
     }
  }

bool Strategy_NoTradeFilter()
  {
   // Act only on the configured work timeframe; cheap O(1) guard.
   if(_Period != strategy_signal_tf)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY_LIMIT;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   // One position per magic - never stack a pending order on top of a fill.
   if(Strategy_HasOpenPosition())
      return false;

   const int dir = Strategy_MomentumDirection();
   if(dir == 0)
      return false;

   const double atr = QM_ATR(_Symbol, strategy_signal_tf, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   // Zero-PRICE check only; never block on zero spread (DWX invariant #1).
   if(bid <= 0.0 || ask <= 0.0)
      return false;

   const double offset = strategy_entry_atr_fraction * atr;
   if(offset <= 0.0)
      return false;

   QM_OrderType side = QM_BUY_LIMIT;
   double limit_price = 0.0;
   if(dir > 0)
     {
      // Bullish: BUY LIMIT below current ask.
      side = QM_BUY_LIMIT;
      limit_price = ask - offset;
     }
   else
     {
      // Bearish: SELL LIMIT above current bid.
      side = QM_SELL_LIMIT;
      limit_price = bid + offset;
     }
   if(limit_price <= 0.0)
      return false;
   limit_price = NormalizeDouble(limit_price, _Digits);

   // SL = stop_atr_mult x ATR from the limit price; TP = take_rr x R.
   const double sl = QM_StopATRFromValue(_Symbol, side, limit_price, atr, strategy_stop_atr_mult);
   if(sl <= 0.0)
      return false;
   const double tp = QM_TakeRR(_Symbol, side, limit_price, sl, strategy_take_rr);
   if(tp <= 0.0)
      return false;

   // Drop any stale/opposite pending order for this magic before placing anew.
   Strategy_CancelOwnPendingOrders("TDSGLOBAL_REPLACE_PENDING");

   int expiry_seconds = 0;
   if(strategy_expiry_bars > 0)
     {
      const int bar_seconds = PeriodSeconds(strategy_signal_tf);
      if(bar_seconds > 0)
         expiry_seconds = strategy_expiry_bars * bar_seconds;
     }

   req.type = side;
   req.price = limit_price;
   req.sl = sl;
   req.tp = tp;
   req.reason = (dir > 0) ? "TDSGLOBAL_BUYLIMIT" : "TDSGLOBAL_SELLLIMIT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = expiry_seconds;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // If a position is open, no pending order should linger for this magic.
   // Keep at most one working order per magic + symbol.
   if(Strategy_HasOpenPosition() && Strategy_HasOwnPendingOrder())
      Strategy_CancelOwnPendingOrders("TDSGLOBAL_CANCEL_AFTER_FILL");
  }

bool Strategy_ExitSignal()
  {
   // Close an open position when momentum flips to the opposite setup.
   // Per-tick safe: does NOT consume QM_IsNewBar (invariant #3) - the entry
   // gate owns the single new-bar event each tick.
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const int dir = Strategy_MomentumDirection();
   if(dir == 0)
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

      const long pos_type = PositionGetInteger(POSITION_TYPE);
      if(pos_type == POSITION_TYPE_BUY && dir < 0)
         return true;
      if(pos_type == POSITION_TYPE_SELL && dir > 0)
         return true;
     }
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade(...)
  }

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,
                        30,
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,
                        qm_news_compliance))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10474\",\"strategy\":\"mql5-tdsglobal\"}");
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
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
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
