#property strict
#property version   "5.0"
#property description "QM5_SRC04_S18 lien-fade-00-asia (SRC04_S18)"

// Strategy Card ID: SRC04_S18 (lien-fade-00-asia), G0 APPROVED via QUA-1568.

#include <QM/QM_Common.mqh>
#include <Trade/Trade.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 4318;
input int    qm_magic_slot_offset         = 0;

input group "Risk"
enum QM5_RiskModeInput
  {
   QM5_RISK_MODE_AUTO = 0,
   QM5_RISK_MODE_FIXED = 1,
   QM5_RISK_MODE_PERCENT = 2
  };
input QM5_RiskModeInput qm_risk_mode      = QM5_RISK_MODE_AUTO;
input double RISK_PERCENT                 = 1.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsMode qm_news_mode            = QM_NEWS_PAUSE;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Strategy"
input int    trend_ma_period              = 20;
input double entry_offset_pips            = 12.0;
input double stop_offset_pips             = 20.0;
input double stage_max_distance_pips      = 50.0;
input int    adx_period                   = 14;
input double adx_max                      = 20.0;
input int    session_start_hour_gmt       = 0;
input int    session_end_hour_gmt         = 4;
input int    time_stop_bars               = 16;
input bool   triple_zero_only             = false;
input bool   use_ma_trail_variant         = false;
input int    order_expiration_minutes     = 60;

CTrade   g_trade;
datetime g_last_bar_time = 0;

int StrategyMagic()
  {
   return QM_Magic(qm_ea_id, qm_magic_slot_offset);
  }

bool IsNewBar()
  {
   const datetime t0 = iTime(_Symbol, _Period, 0);
   if(t0 <= 0 || t0 == g_last_bar_time)
      return false;
   g_last_bar_time = t0;
   return true;
  }

double SMAAtShift(const int period, const int shift)
  {
   const int handle = iMA(_Symbol, _Period, period, 0, MODE_SMA, PRICE_CLOSE);
   if(handle == INVALID_HANDLE)
      return 0.0;

   double buffer[];
   ArraySetAsSeries(buffer, true);
   const int copied = CopyBuffer(handle, 0, shift, 1, buffer);
   IndicatorRelease(handle);
   if(copied < 1)
      return 0.0;
   return buffer[0];
  }

double ADXAtShift(const int period, const int shift)
  {
   const int handle = iADX(_Symbol, _Period, period);
   if(handle == INVALID_HANDLE)
      return 0.0;

   double buffer[];
   ArraySetAsSeries(buffer, true);
   const int copied = CopyBuffer(handle, 0, shift, 1, buffer);
   IndicatorRelease(handle);
   if(copied < 1)
      return 0.0;
   return buffer[0];
  }

double PipSize()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(digits == 3 || digits == 5)
      return point * 10.0;
   return point;
  }

double RoundStep()
  {
   const double pip = PipSize();
   if(pip <= 0.0)
      return 0.0;
   if(triple_zero_only)
      return pip * 1000.0;
   return pip * 100.0;
  }

double NearestRound(const double price)
  {
   const double step = RoundStep();
   if(step <= 0.0)
      return 0.0;
   return MathRound(price / step) * step;
  }

bool InSessionWindowGMT()
  {
   MqlDateTime now_gmt;
   TimeToStruct(TimeGMT(), now_gmt);
   const int hour = now_gmt.hour;

   // Card §4: Asian-session-only entry window 00:00-04:00 GMT.
   if(session_start_hour_gmt <= session_end_hour_gmt)
      return (hour >= session_start_hour_gmt && hour <= session_end_hour_gmt);

   return (hour >= session_start_hour_gmt || hour <= session_end_hour_gmt);
  }

bool GetOurPosition(ulong &ticket)
  {
   ticket = 0;
   const int magic = StrategyMagic();
   const int total = PositionsTotal();
   for(int i = 0; i < total; ++i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      ticket = t;
      return true;
     }
   return false;
  }

bool PlaceStopOrder(const ENUM_ORDER_TYPE order_type, const double entry, const double sl, const double tp)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || entry <= 0.0 || sl <= 0.0)
      return false;

   const double sl_points = MathAbs(entry - sl) / point;
   const double lots = QM_LotsForRisk(_Symbol, sl_points);
   if(lots <= 0.0)
      return false;

   MqlTradeRequest req;
   MqlTradeResult res;
   ZeroMemory(req);
   ZeroMemory(res);

   req.action = TRADE_ACTION_PENDING;
   req.symbol = _Symbol;
   req.magic = StrategyMagic();
   req.type = order_type;
   req.volume = lots;
   req.price = entry;
   req.sl = sl;
   req.tp = tp;
   req.deviation = 20;
   req.type_time = ORDER_TIME_SPECIFIED;
   req.expiration = TimeCurrent() + (order_expiration_minutes * 60);
   req.type_filling = ORDER_FILLING_RETURN;
   req.comment = "SRC04_S18";

   if(!OrderSend(req, res))
      return false;

   return (res.retcode == TRADE_RETCODE_DONE || res.retcode == TRADE_RETCODE_PLACED);
  }

void ApplyTrailLogic()
  {
   ulong ticket;
   if(!GetOurPosition(ticket) || !PositionSelectByTicket(ticket))
      return;

   const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   const double sl_now = PositionGetDouble(POSITION_SL);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double pip = PipSize();
   if(point <= 0.0 || pip <= 0.0)
      return;

   const double one_r = (entry_offset_pips + stop_offset_pips) * pip;
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double vol = PositionGetDouble(POSITION_VOLUME);
   const double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

   double new_sl = sl_now;
   if(ptype == POSITION_TYPE_BUY)
     {
      const bool tp1_reached = (bid - open_price >= one_r);
      const bool be_already = (sl_now >= (open_price - 2.0 * point));
      if(tp1_reached && !be_already && vol >= (2.0 * min_lot))
        {
         g_trade.SetExpertMagicNumber(StrategyMagic());
         g_trade.PositionClosePartial(_Symbol, vol * 0.5, 20);
        }
      if(tp1_reached)
         new_sl = MathMax(new_sl, open_price);
      if(use_ma_trail_variant)
        {
         const double ma = SMAAtShift(trend_ma_period, 1);
         if(ma > 0.0)
            new_sl = MathMax(new_sl, ma - 10.0 * pip);
        }
      else
        {
         const double low2 = iLow(_Symbol, _Period, 2);
         if(low2 > 0.0)
            new_sl = MathMax(new_sl, low2);
        }
     }
   else if(ptype == POSITION_TYPE_SELL)
     {
      const bool tp1_reached = (open_price - ask >= one_r);
      const bool be_already = (sl_now > 0.0 && sl_now <= (open_price + 2.0 * point));
      if(tp1_reached && !be_already && vol >= (2.0 * min_lot))
        {
         g_trade.SetExpertMagicNumber(StrategyMagic());
         g_trade.PositionClosePartial(_Symbol, vol * 0.5, 20);
        }
      if(tp1_reached)
         new_sl = (new_sl <= 0.0) ? open_price : MathMin(new_sl, open_price);
      if(use_ma_trail_variant)
        {
         const double ma = SMAAtShift(trend_ma_period, 1);
         if(ma > 0.0)
            new_sl = (new_sl <= 0.0) ? ma + 10.0 * pip : MathMin(new_sl, ma + 10.0 * pip);
        }
      else
        {
         const double high2 = iHigh(_Symbol, _Period, 2);
         if(high2 > 0.0)
            new_sl = (new_sl <= 0.0) ? high2 : MathMin(new_sl, high2);
        }
     }

   if(new_sl > 0.0 && MathAbs(new_sl - sl_now) > (2.0 * point))
     {
      g_trade.SetExpertMagicNumber(StrategyMagic());
      g_trade.PositionModify(_Symbol, new_sl, PositionGetDouble(POSITION_TP));
     }
  }

bool Strategy_NoTradeFilter()
  {
   ulong pos_ticket;
   return GetOurPosition(pos_ticket);
  }

void Strategy_ManageOpenPosition()
  {
   ApplyTrailLogic();
  }

bool Strategy_ExitSignal()
  {
   ulong ticket;
   if(!GetOurPosition(ticket) || !PositionSelectByTicket(ticket))
      return false;

   // Card §5: TIME_STOP_BARS default 16 M15 bars (4h) to keep holds inside Asian session.
   const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
   const int bars_since_open = iBarShift(_Symbol, _Period, open_time, false);
   if(bars_since_open >= time_stop_bars)
     {
      g_trade.SetExpertMagicNumber(StrategyMagic());
      return g_trade.PositionClose(_Symbol, 20);
     }

   return false;
  }

void OnStrategyBar()
  {
   if(!InSessionWindowGMT())
      return;

   // Card §4: ADX(14) < 20 ranging-regime entry gate.
   const double adx1 = ADXAtShift(adx_period, 1);
   if(adx1 <= 0.0 || adx1 >= adx_max)
      return;

   const double close1 = iClose(_Symbol, _Period, 1);
   const double ma1 = SMAAtShift(trend_ma_period, 1);
   if(close1 <= 0.0 || ma1 <= 0.0)
      return;

   const double pip = PipSize();
   if(pip <= 0.0)
      return;

   const double round_px = NearestRound(close1);
   if(round_px <= 0.0)
      return;

   const double dist_pips = MathAbs(close1 - round_px) / pip;
   if(dist_pips > stage_max_distance_pips)
      return;

   const double entry_buy = round_px + (entry_offset_pips * pip);
   const double sl_buy = round_px - (stop_offset_pips * pip);
   const double tp_buy = entry_buy + MathAbs(entry_buy - sl_buy);

   const double entry_sell = round_px - (entry_offset_pips * pip);
   const double sl_sell = round_px + (stop_offset_pips * pip);
   const double tp_sell = entry_sell - MathAbs(sl_sell - entry_sell);

   if(close1 < ma1 && close1 < round_px)
     {
      PlaceStopOrder(ORDER_TYPE_BUY_STOP, entry_buy, sl_buy, tp_buy);
      return;
     }

   if(close1 > ma1 && close1 > round_px)
      PlaceStopOrder(ORDER_TYPE_SELL_STOP, entry_sell, sl_sell, tp_sell);
  }

void Strategy_EntrySignal()
  {
   OnStrategyBar();
  }

int OnInit()
  {
   QM5_RiskModeInput selected_mode = qm_risk_mode;
   if(selected_mode == QM5_RISK_MODE_AUTO)
      selected_mode = (MQLInfoInteger(MQL_TESTER) != 0) ? QM5_RISK_MODE_FIXED : QM5_RISK_MODE_PERCENT;

   double risk_percent = 0.0;
   double risk_fixed = 0.0;
   if(selected_mode == QM5_RISK_MODE_FIXED)
      risk_fixed = RISK_FIXED;
   else
      risk_percent = RISK_PERCENT;

   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        risk_percent,
                        risk_fixed,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"SRC04_S18\",\"slug\":\"lien-fade-00-asia\"}");
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
   if(!QM_NewsAllowsTrade(_Symbol, TimeCurrent(), qm_news_mode))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   Strategy_ManageOpenPosition();
   if(Strategy_ExitSignal())
      return;

   if(!IsNewBar())
      return;
   if(Strategy_NoTradeFilter())
      return;

   Strategy_EntrySignal();
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
