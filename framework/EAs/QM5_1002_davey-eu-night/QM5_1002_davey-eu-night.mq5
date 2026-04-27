#property strict
#property version   "5.0"
#property description "QM5_1002 Davey Euro Night (SRC01_S01) baseline build"

#include <QM/QM_Common.mqh>
#include <Trade/Trade.mqh>

input group "QuantMechanica V5 Framework"
input int    ea_id              = 1002;
input int    magic_slot_offset  = 0;

input group "Risk"
input double RISK_PERCENT       = 0.0;
input double RISK_FIXED         = 1000.0;
input double PORTFOLIO_WEIGHT   = 1.0;

input group "News"
input QM_NewsMode news_mode     = QM_NEWS_OFF;

input group "Friday Close"
input bool   friday_close_enabled     = true;
input int    friday_close_hour_broker = 21;

input group "Strategy"
input int    Nb                 = 14;
input int    NATR               = 93;
input double ATRmult            = 2.55;
input double TRmult             = 0.71;
input double Stoplo             = 425.0;
input int    FirstTime          = 1800;
input int    LastTime           = 2359;
input int    SessionCloseHHMM   = 600;
input bool   block_friday_entry = true;

int      g_h_ma_high            = INVALID_HANDLE;
int      g_h_ma_low             = INVALID_HANDLE;
int      g_h_atr                = INVALID_HANDLE;
datetime g_last_bar_open_time   = 0;
int      g_last_entry_day_key   = -1;
int      g_last_close_day_key   = -1;
CTrade   g_trade;

int DayKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (dt.year * 1000 + dt.day_of_year);
  }

int HHMM(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (dt.hour * 100 + dt.min);
  }

bool InWindowHHMM(const int hhmm, const int start_hhmm, const int end_hhmm)
  {
   if(start_hhmm <= end_hhmm)
      return (hhmm >= start_hhmm && hhmm <= end_hhmm);
   return (hhmm >= start_hhmm || hhmm <= end_hhmm);
  }

double IndicatorValue(const int handle, const int shift)
  {
   if(handle == INVALID_HANDLE)
      return 0.0;
   double buf[];
   if(CopyBuffer(handle, 0, shift, 1, buf) != 1)
      return 0.0;
   return buf[0];
  }

double PrevTrueRange()
  {
   const double high1  = iHigh(_Symbol, _Period, 1);
   const double low1   = iLow(_Symbol, _Period, 1);
   const double close2 = iClose(_Symbol, _Period, 2);
   if(high1 <= 0.0 || low1 <= 0.0 || close2 <= 0.0)
      return 0.0;

   const double a = high1 - low1;
   const double b = MathAbs(high1 - close2);
   const double c = MathAbs(low1 - close2);
   return MathMax(a, MathMax(b, c));
  }

double PipSize()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return 0.0;
   if(_Digits == 3 || _Digits == 5)
      return (10.0 * point);
   return point;
  }

double StoploPriceDelta()
  {
   const double pip = PipSize();
   if(pip <= 0.0)
      return 0.0;
   // Davey @EC mapping: 1 tick ($12.50) ~= 1 pip on EURUSD.
   const double stop_pips = Stoplo / 12.5;
   return stop_pips * pip;
  }

int FrameworkMagic()
  {
   return QM_MagicChecked(ea_id, magic_slot_offset, _Symbol);
  }

bool HasOpenPositionForMagic(const int magic)
  {
   const int total = PositionsTotal();
   for(int i = 0; i < total; ++i)
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

bool HasPendingOrderForMagic(const int magic)
  {
   const int total = OrdersTotal();
   for(int i = 0; i < total; ++i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      if(!OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;

      const ENUM_ORDER_TYPE t = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(t == ORDER_TYPE_BUY_LIMIT || t == ORDER_TYPE_SELL_LIMIT || t == ORDER_TYPE_BUY_STOP || t == ORDER_TYPE_SELL_STOP)
         return true;
     }
   return false;
  }

void CancelPendingOrdersForMagic(const int magic, const string reason)
  {
   const int total = OrdersTotal();
   for(int i = total - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      if(!OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;

      const ENUM_ORDER_TYPE t = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(!(t == ORDER_TYPE_BUY_LIMIT || t == ORDER_TYPE_SELL_LIMIT || t == ORDER_TYPE_BUY_STOP || t == ORDER_TYPE_SELL_STOP))
         continue;

      MqlTradeRequest req;
      MqlTradeResult  res;
      ZeroMemory(req);
      ZeroMemory(res);
      req.action = TRADE_ACTION_REMOVE;
      req.order  = ticket;
      if(!OrderSend(req, res))
         QM_LogEvent(QM_WARN, "PENDING_CANCEL_FAILED", StringFormat("{\"ticket\":%I64u,\"reason\":\"%s\"}", ticket, QM_LoggerEscapeJson(reason)));
     }
  }

void ForceFlatAtSessionClose(const datetime now_time)
  {
   const int hhmm = HHMM(now_time);
   const int day_key = DayKey(now_time);
   if(hhmm < SessionCloseHHMM || day_key == g_last_close_day_key)
      return;

   const int magic = FrameworkMagic();
   if(magic <= 0)
      return;

   const int total = PositionsTotal();
   for(int i = total - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      g_trade.PositionClose(ticket);
     }

   CancelPendingOrdersForMagic(magic, "session_close");
   g_last_close_day_key = day_key;
   QM_LogEvent(QM_INFO, "SESSION_CLOSE_FORCE_FLAT", StringFormat("{\"hhmm\":%d}", hhmm));
  }

void RefreshOpenPositionTargets()
  {
   const int magic = FrameworkMagic();
   if(magic <= 0)
      return;

   const double tr_prev = PrevTrueRange();
   const double stop_delta = StoploPriceDelta();
   if(tr_prev <= 0.0 || stop_delta <= 0.0)
      return;

   const int total = PositionsTotal();
   for(int i = 0; i < total; ++i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      double new_sl = 0.0;
      double new_tp = 0.0;
      if(ptype == POSITION_TYPE_BUY)
        {
         new_sl = NormalizeDouble(entry - stop_delta, _Digits);
         new_tp = NormalizeDouble(entry + TRmult * tr_prev, _Digits);
        }
      else if(ptype == POSITION_TYPE_SELL)
        {
         new_sl = NormalizeDouble(entry + stop_delta, _Digits);
         new_tp = NormalizeDouble(entry - TRmult * tr_prev, _Digits);
        }
      else
         continue;

      g_trade.PositionModify(_Symbol, new_sl, new_tp);
     }
  }

void EvaluateEntryOnNewBar(const datetime now_time)
  {
   const int hhmm = HHMM(now_time);
   if(!InWindowHHMM(hhmm, FirstTime, LastTime))
      return;

   MqlDateTime dt;
   TimeToStruct(now_time, dt);
   if(block_friday_entry && dt.day_of_week == 5)
      return;

   const int day_key = DayKey(now_time);
   if(day_key == g_last_entry_day_key)
      return;

   const int magic = FrameworkMagic();
   if(magic <= 0)
      return;
   if(HasOpenPositionForMagic(magic) || HasPendingOrderForMagic(magic))
      return;

   const double avg_high = IndicatorValue(g_h_ma_high, 1);
   const double avg_low  = IndicatorValue(g_h_ma_low, 1);
   const double atr_val  = IndicatorValue(g_h_atr, 1);
   const double close_1  = iClose(_Symbol, _Period, 1);
   if(avg_high <= 0.0 || avg_low <= 0.0 || atr_val <= 0.0 || close_1 <= 0.0)
      return;

   const double long_price  = avg_high - ATRmult * atr_val;
   const double short_price = avg_low + ATRmult * atr_val;
   const bool use_long = (MathAbs(close_1 - long_price) <= MathAbs(close_1 - short_price));

   const double stop_delta = StoploPriceDelta();
   double tr_prev = PrevTrueRange();
   if(tr_prev <= 0.0)
      tr_prev = atr_val;
   if(stop_delta <= 0.0 || tr_prev <= 0.0)
      return;

   QM_EntryRequest req;
   ZeroMemory(req);
   req.symbol_slot = magic_slot_offset;
   req.reason = "davey_eu_night_entry";
   req.expiration_seconds = PeriodSeconds(_Period);
   if(use_long)
     {
      req.type  = QM_BUY_LIMIT;
      req.price = NormalizeDouble(long_price, _Digits);
      req.sl    = NormalizeDouble(req.price - stop_delta, _Digits);
      req.tp    = NormalizeDouble(req.price + TRmult * tr_prev, _Digits);
     }
   else
     {
      req.type  = QM_SELL_LIMIT;
      req.price = NormalizeDouble(short_price, _Digits);
      req.sl    = NormalizeDouble(req.price + stop_delta, _Digits);
      req.tp    = NormalizeDouble(req.price - TRmult * tr_prev, _Digits);
     }

   ulong ticket = 0;
   const QM_EntryResult result = QM_Entry(req, ticket);
   if(result == QM_ENTRY_OK)
      g_last_entry_day_key = day_key;
  }

bool IsNewBar()
  {
   const datetime bar_time = iTime(_Symbol, _Period, 0);
   if(bar_time <= 0)
      return false;
   if(bar_time == g_last_bar_open_time)
      return false;
   g_last_bar_open_time = bar_time;
   return true;
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

   g_h_ma_high = iMA(_Symbol, _Period, Nb, 0, MODE_SMA, PRICE_HIGH);
   g_h_ma_low  = iMA(_Symbol, _Period, Nb, 0, MODE_SMA, PRICE_LOW);
   g_h_atr     = iATR(_Symbol, _Period, NATR);
   if(g_h_ma_high == INVALID_HANDLE || g_h_ma_low == INVALID_HANDLE || g_h_atr == INVALID_HANDLE)
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"SRC01_S01\",\"ea\":\"QM5_1002_davey-eu-night\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   if(g_h_ma_high != INVALID_HANDLE)
      IndicatorRelease(g_h_ma_high);
   if(g_h_ma_low != INVALID_HANDLE)
      IndicatorRelease(g_h_ma_low);
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

   const datetime now_time = TimeCurrent();
   if(now_time <= 0)
      return;

   ForceFlatAtSessionClose(now_time);
   if(!IsNewBar())
      return;

   RefreshOpenPositionTargets();
   EvaluateEntryOnNewBar(now_time);
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
