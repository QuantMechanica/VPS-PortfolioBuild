#property strict
#property version   "5.0"
#property description "QM5_1003 Davey World Cup (SRC01_S05)"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    ea_id                    = 1003;
input int    magic_slot_offset        = 0;

input group "Risk"
input double RISK_PERCENT             = 0.0;
input double RISK_FIXED               = 1000.0;
input double PORTFOLIO_WEIGHT         = 1.0;

input group "News"
input QM_NewsMode news_mode           = QM_NEWS_OFF;

input group "Friday Close"
input bool   friday_close_enabled     = true;
input int    friday_close_hour_broker = 21;

input group "Strategy"
input int    X_Bars                   = 48;
input int    RSI_Period               = 30;
input double RSI_Threshold            = 50.0;
input double FixedDollarStop          = 1000.0;
input int    ATR_Period               = 14;
input double Y_ATR_Trail              = 3.0;
input double Z_ATR_Target             = 5.0;
input int    WaitAfterLoserBars       = 5;
input int    WaitAfterWinnerBars      = 20;

int      g_h_rsi               = INVALID_HANDLE;
int      g_h_atr               = INVALID_HANDLE;
datetime g_last_bar_time       = 0;
CTrade   g_trade;

bool IsNewBar()
  {
   const datetime t0 = iTime(_Symbol, _Period, 0);
   if(t0 <= 0 || t0 == g_last_bar_time)
      return false;
   g_last_bar_time = t0;
   return true;
  }

double ReadBufferValue(const int handle, const int shift)
  {
   if(handle == INVALID_HANDLE)
      return 0.0;
   double b[];
   if(CopyBuffer(handle, 0, shift, 1, b) != 1)
      return 0.0;
   return b[0];
  }

int BarsSince(const datetime since_time)
  {
   if(since_time <= 0)
      return 1000000;
   const int shift = iBarShift(_Symbol, _Period, since_time, false);
   return (shift < 0 ? 1000000 : shift);
  }

bool LastClosedOutcome(bool &has_trade, bool &was_winner, datetime &last_close_time)
  {
   has_trade = false;
   was_winner = false;
   last_close_time = 0;
   if(!HistorySelect(0, TimeCurrent()))
      return false;

   const long magic = QM_Magic(ea_id, magic_slot_offset);
   const int total = HistoryDealsTotal();
   for(int i = total - 1; i >= 0; --i)
     {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;
      if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol)
         continue;
      if(HistoryDealGetInteger(deal, DEAL_MAGIC) != magic)
         continue;
      if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY) != DEAL_ENTRY_OUT)
         continue;

      const double pnl = HistoryDealGetDouble(deal, DEAL_PROFIT)
                         + HistoryDealGetDouble(deal, DEAL_SWAP)
                         + HistoryDealGetDouble(deal, DEAL_COMMISSION);
      last_close_time = (datetime)HistoryDealGetInteger(deal, DEAL_TIME);
      was_winner = (pnl > 0.0);
      has_trade = true;
      return true;
     }

   return true;
  }

bool EntryWaitRuleAllowsTrade()
  {
   bool has_trade = false;
   bool was_winner = false;
   datetime last_close = 0;
   if(!LastClosedOutcome(has_trade, was_winner, last_close))
      return false;
   if(!has_trade)
      return true;

   const int required = was_winner ? WaitAfterWinnerBars : WaitAfterLoserBars;
   // Card ?4 / p.24: wait 5 bars after loser, 20 bars after winner.
   return (BarsSince(last_close) >= required);
  }

bool HasOpenPositionForMagic()
  {
   const long magic = QM_Magic(ea_id, magic_slot_offset);
   const int total = PositionsTotal();
   for(int i = 0; i < total; ++i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      return true;
     }
   return false;
  }

bool EstimateStopDistancePrice(double &out_delta)
  {
   out_delta = 0.0;
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   const double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   if(tick_size <= 0.0 || tick_value <= 0.0)
      return false;

   // Card ?5 / p.24: fixed-dollar stop layer = $1,000.
   const double ticks = FixedDollarStop / tick_value;
   if(ticks <= 0.0)
      return false;
   out_delta = ticks * tick_size;
   return (out_delta > 0.0);
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(_Period != PERIOD_D1)
      return false;
   if(!EntryWaitRuleAllowsTrade())
      return false;

   const double close1 = iClose(_Symbol, _Period, 1);
   if(close1 <= 0.0)
      return false;

   const int idx_high = iHighest(_Symbol, _Period, MODE_CLOSE, X_Bars, 1);
   const int idx_low  = iLowest(_Symbol, _Period, MODE_CLOSE, X_Bars, 1);
   if(idx_high < 0 || idx_low < 0)
      return false;

   const double high_close = iClose(_Symbol, _Period, idx_high);
   const double low_close  = iClose(_Symbol, _Period, idx_low);
   const double rsi1 = ReadBufferValue(g_h_rsi, 1);
   const double atr1 = ReadBufferValue(g_h_atr, 1);
   if(rsi1 <= 0.0 || atr1 <= 0.0)
      return false;

   double stop_delta = 0.0;
   if(!EstimateStopDistancePrice(stop_delta))
      return false;

   bool long_signal = false;
   bool short_signal = false;

   // Card ?4 / p.24: long on 48-bar high close with RSI(30) > 50.
   if(close1 >= high_close && rsi1 > RSI_Threshold)
      long_signal = true;
   // Card ?4 / p.24: short on 48-bar low close with RSI(30) < 50.
   if(close1 <= low_close && rsi1 < RSI_Threshold)
      short_signal = true;

   if(!long_signal && !short_signal)
      return false;

   ZeroMemory(req);
   req.symbol_slot = magic_slot_offset;
   req.expiration_seconds = 0;
   req.reason = "SRC01_S05_entry";

   // Card ?4 / p.24: enter next bar at market.
   if(long_signal)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = NormalizeDouble(ask - stop_delta, _Digits);
      req.tp = NormalizeDouble(ask + (Z_ATR_Target * atr1), _Digits);
      return (req.sl > 0.0 && req.tp > 0.0);
     }

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   req.type = QM_SELL;
   req.price = 0.0;
   req.sl = NormalizeDouble(bid + stop_delta, _Digits);
   req.tp = NormalizeDouble(bid - (Z_ATR_Target * atr1), _Digits);
   return (req.sl > 0.0 && req.tp > 0.0);
  }

void Strategy_ManageOpenPosition(const ulong ticket)
  {
   if(ticket == 0 || !PositionSelectByTicket(ticket))
      return;

   const double atr1 = ReadBufferValue(g_h_atr, 1);
   if(atr1 <= 0.0)
      return;

   const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   const double current_sl = PositionGetDouble(POSITION_SL);
   const double current_tp = PositionGetDouble(POSITION_TP);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   double new_sl = current_sl;
   double new_tp = current_tp;

   // Card ?5 / p.24: trailing stop layer Y*ATR and target layer Z*ATR.
   if(type == POSITION_TYPE_BUY)
     {
      const double trail_sl = NormalizeDouble(bid - (Y_ATR_Trail * atr1), _Digits);
      if(current_sl <= 0.0 || trail_sl > current_sl)
         new_sl = trail_sl;
      if(current_tp <= 0.0)
         new_tp = NormalizeDouble(bid + (Z_ATR_Target * atr1), _Digits);
     }
   else if(type == POSITION_TYPE_SELL)
     {
      const double trail_sl = NormalizeDouble(ask + (Y_ATR_Trail * atr1), _Digits);
      if(current_sl <= 0.0 || trail_sl < current_sl)
         new_sl = trail_sl;
      if(current_tp <= 0.0)
         new_tp = NormalizeDouble(ask - (Z_ATR_Target * atr1), _Digits);
     }

   if(new_sl != current_sl || new_tp != current_tp)
      g_trade.PositionModify(_Symbol, new_sl, new_tp);
  }

bool Strategy_ExitSignal(const ulong ticket, QM_ExitReason &reason)
  {
   // Card ?5 / pp.24-25: no independent time-based exit signal.
   reason = QM_EXIT_STRATEGY;
   return false;
  }

int OnInit()
  {
   if(!QM_FrameworkInit(ea_id,
                        magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        news_mode,
                        friday_close_enabled,
                        friday_close_hour_broker))
      return INIT_FAILED;

   g_h_rsi = iRSI(_Symbol, _Period, RSI_Period, PRICE_CLOSE);
   g_h_atr = iATR(_Symbol, _Period, ATR_Period);
   if(g_h_rsi == INVALID_HANDLE || g_h_atr == INVALID_HANDLE)
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"SRC01_S05\",\"ea\":\"QM5_1003_davey_worldcup\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   if(g_h_rsi != INVALID_HANDLE)
      IndicatorRelease(g_h_rsi);
   if(g_h_atr != INVALID_HANDLE)
      IndicatorRelease(g_h_atr);
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   if(!QM_KillSwitchCheck())
      return;
   if(!QM_NewsAllowsTrade(_Symbol, TimeCurrent(), news_mode))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;
   if(!IsNewBar())
      return;

   // Card ?7 / p.25: enforce one position per instrument (no pyramiding).
   if(HasOpenPositionForMagic())
     {
      const int total = PositionsTotal();
      const long magic = QM_Magic(ea_id, magic_slot_offset);
      for(int i = 0; i < total; ++i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;

         Strategy_ManageOpenPosition(ticket);
         QM_ExitReason reason = QM_EXIT_STRATEGY;
         if(Strategy_ExitSignal(ticket, reason))
            QM_Exit(ticket, reason);
        }
      return;
     }

   QM_EntryRequest req;
   if(!Strategy_EntrySignal(req))
      return;

   ulong ticket = 0;
   QM_Entry(req, ticket);
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
