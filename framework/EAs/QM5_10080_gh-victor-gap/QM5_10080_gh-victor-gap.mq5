#property strict
#property version   "5.0"
#property description "QM5_10080 GitHub Victor Algo Gap Reversal"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 10080;
input int    qm_magic_slot_offset         = 0;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsMode qm_news_mode            = QM_NEWS_OFF;
input int    qm_news_pause_before_minutes = 30;
input int    qm_news_pause_after_minutes  = 30;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Strategy"
input double strategy_gap_threshold_pct   = 1.0;
input int    strategy_sma_period          = 250;
input int    strategy_atr_period          = 250;
input double strategy_atr_sl_mult         = 1.0;
input double strategy_atr_tp_mult         = 1.0;
input int    strategy_session_start_hour  = 0;
input int    strategy_session_end_hour    = 24;
input int    strategy_max_spread_points   = 0;

// Return TRUE to BLOCK trading this tick (time, spread, news).
bool Strategy_NoTradeFilter()
  {
   const datetime broker_now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(broker_now, dt);

   if(strategy_session_start_hour != 0 || strategy_session_end_hour != 24)
     {
      const int start_h = MathMax(0, MathMin(23, strategy_session_start_hour));
      const int end_h = MathMax(0, MathMin(24, strategy_session_end_hour));
      const bool in_session = (start_h < end_h)
                              ? (dt.hour >= start_h && dt.hour < end_h)
                              : (dt.hour >= start_h || dt.hour < end_h);
      if(!in_session)
         return true;
     }

   if(strategy_max_spread_points > 0)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
         return true;
      if((ask - bid) / point > strategy_max_spread_points)
         return true;
     }

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

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         (int)PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }

   const datetime prior_bar_open = iTime(_Symbol, _Period, 1);
   const datetime current_bar_open = iTime(_Symbol, _Period, 0);
   if(prior_bar_open > 0 && current_bar_open > prior_bar_open &&
      HistorySelect(prior_bar_open, current_bar_open - 1))
     {
      for(int i = HistoryDealsTotal() - 1; i >= 0; --i)
        {
         const ulong deal = HistoryDealGetTicket(i);
         if(deal == 0)
            continue;
         if(HistoryDealGetString(deal, DEAL_SYMBOL) == _Symbol &&
            (int)HistoryDealGetInteger(deal, DEAL_MAGIC) == magic &&
            (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY) == DEAL_ENTRY_IN)
            return false;
        }
     }

   if(strategy_gap_threshold_pct <= 0.0 || strategy_sma_period <= 0 ||
      strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0 ||
      strategy_atr_tp_mult <= 0.0)
      return false;

   const double open1 = iOpen(_Symbol, _Period, 1);
   const double close1 = iClose(_Symbol, _Period, 1);
   const double close2 = iClose(_Symbol, _Period, 2);
   if(open1 <= 0.0 || close1 <= 0.0 || close2 <= 0.0)
      return false;

   const double gap_pct = 100.0 * (open1 - close2) / close2;
   const double sma = QM_SMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_sma_period, 1, PRICE_CLOSE);
   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(sma <= 0.0 || atr <= 0.0)
      return false;

   const bool bullish_gap_bar = (close1 > open1);
   const bool bearish_gap_bar = (close1 < open1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(gap_pct <= -strategy_gap_threshold_pct && bullish_gap_bar && close1 > sma)
     {
      req.type = QM_BUY;
      req.price = ask;
      req.sl = NormalizeDouble(req.price - atr * strategy_atr_sl_mult, _Digits);
      req.tp = NormalizeDouble(req.price + atr * strategy_atr_tp_mult, _Digits);
      req.reason = "GH_VICTOR_GAP_LONG";
      return (req.sl > 0.0 && req.tp > 0.0);
     }

   if(gap_pct >= strategy_gap_threshold_pct && bearish_gap_bar && close1 < sma)
     {
      req.type = QM_SELL;
      req.price = bid;
      req.sl = NormalizeDouble(req.price + atr * strategy_atr_sl_mult, _Digits);
      req.tp = NormalizeDouble(req.price - atr * strategy_atr_tp_mult, _Digits);
      req.reason = "GH_VICTOR_GAP_SHORT";
      return (req.sl > 0.0 && req.tp > 0.0);
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0)
      return;

   const double close1 = iClose(_Symbol, _Period, 1);
   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(close1 <= 0.0 || atr <= 0.0 || point <= 0.0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double target_sl = (ptype == POSITION_TYPE_BUY)
                               ? NormalizeDouble(close1 - atr * strategy_atr_sl_mult, _Digits)
                               : NormalizeDouble(close1 + atr * strategy_atr_sl_mult, _Digits);
      if(target_sl <= 0.0)
         continue;

      const bool improves = (current_sl <= 0.0) ||
                            (ptype == POSITION_TYPE_BUY
                             ? target_sl > current_sl + point * 0.5
                             : target_sl < current_sl - point * 0.5);
      if(improves)
         QM_TM_MoveSL(ticket, target_sl, "GH_VICTOR_GAP_ATR_TRAIL");
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
                        qm_news_mode,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        qm_news_pause_before_minutes,
                        qm_news_pause_after_minutes,
                        qm_news_stale_max_hours,
                        qm_news_min_impact))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10080\",\"slug\":\"gh-victor-gap\"}");
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
   if(!QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode))
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

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
