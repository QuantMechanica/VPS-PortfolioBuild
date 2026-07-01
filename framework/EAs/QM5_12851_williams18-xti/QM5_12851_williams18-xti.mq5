#property strict
#property version   "5.0"
#property description "QM5_12851 Williams 18-Bar Two-Bar MA WTI (SRC03 S12)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12851 - Williams 18-Bar Two-Bar MA Entry, WTI (XTIUSD.DWX D1)
// Source: SRC03 S12 - Williams, L.R. (1999). Long-Term Secrets to Short-Term Trading.
// Card: QM5_12851_williams18-xti_card.md | G0 APPROVED 2026-07-01
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12851;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal      = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance    = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours                  = 336;
input string qm_news_min_impact                       = "high";
input QM_NewsMode qm_news_mode_legacy                 = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_ma_period           = 18;     // Williams 18-day close SMA
input int    strategy_atr_period          = 20;     // ATR period for hard stop
input double strategy_atr_sl_mult         = 2.5;    // SL distance = ATR * mult
input double strategy_take_rr             = 2.0;    // TP = R multiple; 0 = disabled
input int    strategy_entry_buffer_points = 2;      // stop-entry buffer beyond two-bar extreme
input int    strategy_order_expiry_bars   = 3;      // pending stop expiry in D1 bars
input int    strategy_max_hold_days       = 10;     // time stop for open positions
input int    strategy_max_spread_points   = 1000;   // skip entry if bid-ask spread > N points

void InitRequest(QM_EntryRequest &req)
  {
   req.type               = QM_BUY_STOP;
   req.price              = 0.0;
   req.sl                 = 0.0;
   req.tp                 = 0.0;
   req.reason             = "";
   req.symbol_slot        = qm_magic_slot_offset;

   const int d1_seconds = PeriodSeconds(PERIOD_D1);
   const int bars = MathMax(1, strategy_order_expiry_bars);
   req.expiration_seconds = (d1_seconds > 0) ? bars * d1_seconds : bars * 86400;
  }

bool HasOpenPositionForMagic()
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

bool HasPendingOrderForMagic()
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

bool SpreadAllowsEntry()
  {
   if(strategy_max_spread_points <= 0)
      return true;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;

   const double ask_px = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid_px = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask_px > 0.0 && bid_px > 0.0)
     {
      if(ask_px < bid_px)
         return false;
      const double spread_points = (ask_px - bid_px) / point;
      if(spread_points > strategy_max_spread_points)
         return false;
     }
   return true;
  }

bool IsInsideDay(const int shift)
  {
   const double bar_high  = iHigh(_Symbol, PERIOD_D1, shift);      // perf-allowed
   const double bar_low   = iLow(_Symbol, PERIOD_D1, shift);       // perf-allowed
   const double prev_high = iHigh(_Symbol, PERIOD_D1, shift + 1);  // perf-allowed
   const double prev_low  = iLow(_Symbol, PERIOD_D1, shift + 1);   // perf-allowed
   if(bar_high <= 0.0 || bar_low <= 0.0 || prev_high <= 0.0 || prev_low <= 0.0)
      return true;
   return (bar_high < prev_high && bar_low > prev_low);
  }

bool Strategy_NoTradeFilter()
  {
   if(_Symbol != "XTIUSD.DWX")
      return true;
   if(_Period != PERIOD_D1)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   InitRequest(req);

   if(strategy_ma_period < 2 || strategy_atr_period < 1 ||
      strategy_atr_sl_mult <= 0.0 || strategy_order_expiry_bars < 1)
      return false;

   if(HasOpenPositionForMagic() || HasPendingOrderForMagic())
      return false;
   if(!SpreadAllowsEntry())
      return false;

   const double high1 = iHigh(_Symbol, PERIOD_D1, 1);  // perf-allowed
   const double low1  = iLow(_Symbol, PERIOD_D1, 1);   // perf-allowed
   const double high2 = iHigh(_Symbol, PERIOD_D1, 2);  // perf-allowed
   const double low2  = iLow(_Symbol, PERIOD_D1, 2);   // perf-allowed
   if(high1 <= 0.0 || low1 <= 0.0 || high2 <= 0.0 || low2 <= 0.0)
      return false;

   const double ma1 = QM_SMA(_Symbol, PERIOD_D1, strategy_ma_period, 1);
   const double ma2 = QM_SMA(_Symbol, PERIOD_D1, strategy_ma_period, 2);
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(ma1 <= 0.0 || ma2 <= 0.0 || atr <= 0.0)
      return false;

   const bool inside1 = IsInsideDay(1);
   const bool inside2 = IsInsideDay(2);
   const bool buy_signal = (low1 > ma1 && low2 > ma2 && !inside1 && !inside2);
   const bool sell_signal = (high1 < ma1 && high2 < ma2 && !inside1 && !inside2);
   if(buy_signal == sell_signal)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;

   const double buffer = MathMax(0, strategy_entry_buffer_points) * point;
   const double stop_dist = strategy_atr_sl_mult * atr;
   if(stop_dist <= 0.0)
      return false;

   const double ask_px = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid_px = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(buy_signal)
     {
      const double entry = MathMax(high1, high2) + buffer;
      if(ask_px > 0.0 && entry <= ask_px)
         return false;
      const double sl = entry - stop_dist;
      if(sl <= 0.0 || sl >= entry)
         return false;
      const double risk = entry - sl;
      const double tp = (strategy_take_rr > 0.0) ? entry + strategy_take_rr * risk : 0.0;

      req.type   = QM_BUY_STOP;
      req.price  = QM_TM_NormalizePrice(_Symbol, entry);
      req.sl     = QM_TM_NormalizePrice(_Symbol, sl);
      req.tp     = (tp > 0.0) ? QM_TM_NormalizePrice(_Symbol, tp) : 0.0;
      req.reason = "SRC03_WILLIAMS18_XTI_LONG";
      return true;
     }

   const double entry = MathMin(low1, low2) - buffer;
   if(bid_px > 0.0 && entry >= bid_px)
      return false;
   const double sl = entry + stop_dist;
   if(sl <= entry)
      return false;
   const double risk = sl - entry;
   const double tp = (strategy_take_rr > 0.0) ? entry - strategy_take_rr * risk : 0.0;
   if(tp < 0.0)
      return false;

   req.type   = QM_SELL_STOP;
   req.price  = QM_TM_NormalizePrice(_Symbol, entry);
   req.sl     = QM_TM_NormalizePrice(_Symbol, sl);
   req.tp     = (tp > 0.0) ? QM_TM_NormalizePrice(_Symbol, tp) : 0.0;
   req.reason = "SRC03_WILLIAMS18_XTI_SHORT";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   if(strategy_max_hold_days <= 0)
      return;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   const datetime now = TimeCurrent();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int held_days = (int)((now - open_time) / 86400);
      if(held_days >= strategy_max_hold_days)
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
     }
  }

bool Strategy_ExitSignal()
  {
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"SRC03_S12_XTI_20260701\",\"ea\":\"QM5_12851_williams18-xti\"}");
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
                        const MqlTradeRequest      &request,
                        const MqlTradeResult       &result)
  {
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
