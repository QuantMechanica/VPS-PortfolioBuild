#property strict
#property version   "5.0"
#property description "QM5_11486 Carter-T 20 EMA MACD Zero M5"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11486;
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
input int    strategy_ema_period          = 20;
input int    strategy_macd_fast           = 12;
input int    strategy_macd_slow           = 26;
input int    strategy_macd_signal         = 9;
input int    strategy_macd_lookback       = 5;
input int    strategy_entry_offset_pips   = 10;
input int    strategy_stop_ema_pips       = 20;
input int    strategy_trail_ema_pips      = 15;
input double strategy_partial_fraction    = 0.5;
input double strategy_tp_rr               = 1.0;
input int    strategy_spread_cap_pips     = 15;
input bool   strategy_no_friday_entry     = true;

ulong g_partial_done_ticket = 0;

double Strategy_PipDistance(const int pips)
  {
   return QM_StopRulesPipsToPriceDistance(_Symbol, pips);
  }

bool Strategy_HasPendingOrder()
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

      const ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_SELL_STOP)
         return true;
     }

   return false;
  }

bool Strategy_MacdSideWithinLookback(const bool want_positive)
  {
   const int lookback = (strategy_macd_lookback < 1) ? 1 : strategy_macd_lookback;
   for(int shift = 1; shift <= lookback; ++shift)
     {
      const double macd = QM_MACD_Main(_Symbol, (ENUM_TIMEFRAMES)_Period,
                                       strategy_macd_fast,
                                       strategy_macd_slow,
                                       strategy_macd_signal,
                                       shift);
      if(want_positive && macd > 0.0)
         return true;
      if(!want_positive && macd < 0.0)
         return true;
     }

   return false;
  }

bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double spread = ask - bid;
   const double cap = Strategy_PipDistance(strategy_spread_cap_pips);
   if(spread > 0.0 && cap > 0.0 && spread > cap)
      return true;

   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_no_friday_entry)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.day_of_week == 5)
         return false;
     }

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;
   if(QM_TM_OpenPositionCount(magic) > 0 || Strategy_HasPendingOrder())
      return false;

   const double ema_1 = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_period, 1);
   const double ema_2 = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_period, 2);
   if(ema_1 <= 0.0 || ema_2 <= 0.0)
      return false;

   const double close_1 = iClose(_Symbol, (ENUM_TIMEFRAMES)_Period, 1); // perf-allowed: closed-bar EMA cross read inside framework new-bar gate.
   const double close_2 = iClose(_Symbol, (ENUM_TIMEFRAMES)_Period, 2); // perf-allowed: closed-bar EMA cross read inside framework new-bar gate.
   if(close_1 <= 0.0 || close_2 <= 0.0)
      return false;

   const bool cross_up = (close_2 <= ema_2 && close_1 > ema_1);
   const bool cross_down = (close_2 >= ema_2 && close_1 < ema_1);
   if(!cross_up && !cross_down)
      return false;

   const double entry_offset = Strategy_PipDistance(strategy_entry_offset_pips);
   const double stop_offset = Strategy_PipDistance(strategy_stop_ema_pips);
   if(entry_offset <= 0.0 || stop_offset <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(cross_up)
     {
      if(!Strategy_MacdSideWithinLookback(true))
         return false;

      const double entry = QM_StopRulesNormalizePrice(_Symbol, ema_1 + entry_offset);
      const double sl = QM_StopRulesNormalizePrice(_Symbol, ema_1 - stop_offset);
      if(entry <= ask || sl <= 0.0 || sl >= entry)
         return false;

      req.type = QM_BUY_STOP;
      req.price = entry;
      req.sl = sl;
      req.tp = 0.0;
      req.reason = "ema20_cross_up_macd_zero_buy_stop";
      return true;
     }

   if(!Strategy_MacdSideWithinLookback(false))
      return false;

   const double entry = QM_StopRulesNormalizePrice(_Symbol, ema_1 - entry_offset);
   const double sl = QM_StopRulesNormalizePrice(_Symbol, ema_1 + stop_offset);
   if(entry >= bid || sl <= 0.0 || sl <= entry)
      return false;

   req.type = QM_SELL_STOP;
   req.price = entry;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = "ema20_cross_down_macd_zero_sell_stop";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   if(QM_TM_OpenPositionCount(magic) <= 0)
     {
      g_partial_done_ticket = 0;
      return;
     }

   const double ema_1 = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_period, 1);
   const double trail_dist = Strategy_PipDistance(strategy_trail_ema_pips);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const bool is_buy = (pos_type == POSITION_TYPE_BUY);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double sl_price = PositionGetDouble(POSITION_SL);
      const double volume = PositionGetDouble(POSITION_VOLUME);
      if(open_price <= 0.0 || volume <= 0.0)
         continue;

      double risk_dist = is_buy ? (open_price - sl_price) : (sl_price - open_price);
      if(risk_dist <= 0.0)
         risk_dist = Strategy_PipDistance(strategy_stop_ema_pips + strategy_entry_offset_pips);
      if(risk_dist <= 0.0)
         continue;

      const double market_price = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(market_price <= 0.0)
         continue;

      if(g_partial_done_ticket != ticket)
        {
         const bool already_at_be = is_buy ? (sl_price >= open_price) : (sl_price <= open_price && sl_price > 0.0);
         if(already_at_be)
            g_partial_done_ticket = ticket;
        }

      const double tp1 = is_buy ? (open_price + strategy_tp_rr * risk_dist)
                                : (open_price - strategy_tp_rr * risk_dist);
      const bool reached_tp1 = is_buy ? (market_price >= tp1) : (market_price <= tp1);

      if(g_partial_done_ticket != ticket && reached_tp1)
        {
         const double close_lots = QM_TM_NormalizeVolume(_Symbol, volume * strategy_partial_fraction);
         if(close_lots > 0.0 && close_lots < volume)
            QM_TM_PartialClose(ticket, close_lots, QM_EXIT_STRATEGY);
         QM_TM_MoveSL(ticket, QM_TM_NormalizePrice(_Symbol, open_price), "tp1_move_to_breakeven");
         g_partial_done_ticket = ticket;
         continue;
        }

      if(g_partial_done_ticket == ticket && ema_1 > 0.0 && trail_dist > 0.0)
        {
         if(is_buy)
           {
            const double new_sl = QM_TM_NormalizePrice(_Symbol, ema_1 - trail_dist);
            if(new_sl > sl_price && new_sl < market_price)
               QM_TM_MoveSL(ticket, new_sl, "ema20_trail_long");
           }
         else
           {
            const double new_sl = QM_TM_NormalizePrice(_Symbol, ema_1 + trail_dist);
            if((sl_price <= 0.0 || new_sl < sl_price) && new_sl > market_price)
               QM_TM_MoveSL(ticket, new_sl, "ema20_trail_short");
           }
        }
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
