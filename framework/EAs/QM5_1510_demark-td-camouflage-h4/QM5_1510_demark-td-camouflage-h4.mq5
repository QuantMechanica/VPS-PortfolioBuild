#property strict
#property version   "5.0"
#property description "QM5_1510 DeMark TD Camouflage H4"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1510;
input int    qm_magic_slot_offset        = 0;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsMode qm_news_mode           = QM_NEWS_PAUSE;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input int    strategy_atr_period         = 14;
input int    strategy_ema_period         = 50;
input int    strategy_d1_sma_period      = 50;
input int    strategy_warmup_h4_bars     = 100;
input double strategy_range_atr_mult     = 1.20;
input double strategy_close_range_min    = 0.60;
input int    strategy_opposite_lookback  = 14;
input int    strategy_cluster_lookback   = 30;
input int    strategy_cluster_max        = 2;
input double strategy_sl_atr_buffer      = 0.30;
input double strategy_tp1_atr_mult       = 1.20;
input double strategy_tp1_close_frac     = 0.60;
input int    strategy_time_stop_bars     = 12;
input double strategy_spread_median_mult = 1.50;

datetime g_last_h4_signal_bar = 0;
ulong    g_tp1_done_ticket = 0;
double   g_last_signal_atr = 0.0;

bool GetOurPosition(ulong &ticket, ENUM_POSITION_TYPE &ptype, double &open_price, double &volume, datetime &open_time)
  {
   ticket = 0;
   ptype = POSITION_TYPE_BUY;
   open_price = 0.0;
   volume = 0.0;
   open_time = 0;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = t;
      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      volume = PositionGetDouble(POSITION_VOLUME);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }
   return false;
  }

double BarRangeRatio(const int shift)
  {
   const double high = iHigh(_Symbol, PERIOD_H4, shift);
   const double low = iLow(_Symbol, PERIOD_H4, shift);
   const double close = iClose(_Symbol, PERIOD_H4, shift);
   if(high <= low)
      return 0.0;
   return (close - low) / (high - low);
  }

bool BullishCamouflageRaw(const int shift)
  {
   const double c0 = iClose(_Symbol, PERIOD_H4, shift);
   const double c1 = iClose(_Symbol, PERIOD_H4, shift + 1);
   const double o0 = iOpen(_Symbol, PERIOD_H4, shift);
   const double h0 = iHigh(_Symbol, PERIOD_H4, shift);
   const double h1 = iHigh(_Symbol, PERIOD_H4, shift + 1);
   const double h2 = iHigh(_Symbol, PERIOD_H4, shift + 2);
   const double l0 = iLow(_Symbol, PERIOD_H4, shift);
   const double l1 = iLow(_Symbol, PERIOD_H4, shift + 1);
   return (c0 > 0.0 && c0 < c1 && c0 > o0 && h0 > MathMax(h1, h2) && l0 < l1);
  }

bool BearishCamouflageRaw(const int shift)
  {
   const double c0 = iClose(_Symbol, PERIOD_H4, shift);
   const double c1 = iClose(_Symbol, PERIOD_H4, shift + 1);
   const double o0 = iOpen(_Symbol, PERIOD_H4, shift);
   const double h0 = iHigh(_Symbol, PERIOD_H4, shift);
   const double h1 = iHigh(_Symbol, PERIOD_H4, shift + 1);
   const double l0 = iLow(_Symbol, PERIOD_H4, shift);
   const double l1 = iLow(_Symbol, PERIOD_H4, shift + 1);
   const double l2 = iLow(_Symbol, PERIOD_H4, shift + 2);
   return (c0 > 0.0 && c0 > c1 && c0 < o0 && l0 < MathMin(l1, l2) && h0 > h1);
  }

int CountRawSignals(const bool bullish, const int start_shift, const int lookback)
  {
   int count = 0;
   for(int i = start_shift; i < start_shift + lookback; ++i)
     {
      if(bullish ? BullishCamouflageRaw(i) : BearishCamouflageRaw(i))
         ++count;
     }
   return count;
  }

bool DirectionalCamouflage(const bool bullish, const int shift)
  {
   if(bullish)
     {
      if(!BullishCamouflageRaw(shift))
         return false;
     }
   else if(!BearishCamouflageRaw(shift))
      return false;

   const double close0 = iClose(_Symbol, PERIOD_H4, shift);
   const double close1 = iClose(_Symbol, PERIOD_H4, shift + 1);
   const double close5 = iClose(_Symbol, PERIOD_H4, shift + 5);
   const double high0 = iHigh(_Symbol, PERIOD_H4, shift);
   const double low0 = iLow(_Symbol, PERIOD_H4, shift);
   const double ema = QM_EMA(_Symbol, PERIOD_H4, strategy_ema_period, shift + 1);
   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, shift);
   const double d1_close = iClose(_Symbol, PERIOD_D1, 1);
   const double d1_sma = QM_SMA(_Symbol, PERIOD_D1, strategy_d1_sma_period, 1);
   if(close0 <= 0.0 || close1 <= 0.0 || close5 <= 0.0 || ema <= 0.0 || atr <= 0.0 || d1_close <= 0.0 || d1_sma <= 0.0)
      return false;

   if((high0 - low0) < strategy_range_atr_mult * atr)
      return false;

   const double ratio = BarRangeRatio(shift);
   if(bullish)
     {
      if(!(close1 < ema && close5 > close1 && d1_close > d1_sma && ratio >= strategy_close_range_min))
         return false;
      if(CountRawSignals(false, shift + 1, strategy_opposite_lookback) > 0)
         return false;
      if(CountRawSignals(true, shift + 1, strategy_cluster_lookback) > strategy_cluster_max)
         return false;
     }
   else
     {
      if(!(close1 > ema && close5 < close1 && d1_close < d1_sma && ratio <= (1.0 - strategy_close_range_min)))
         return false;
      if(CountRawSignals(true, shift + 1, strategy_opposite_lookback) > 0)
         return false;
      if(CountRawSignals(false, shift + 1, strategy_cluster_lookback) > strategy_cluster_max)
         return false;
     }

   return true;
  }

bool SpreadAllowed()
  {
   const long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(current_spread <= 0)
      return false;

   double spreads[];
   ArrayResize(spreads, 20);
   int count = 0;
   for(int i = 1; i <= 20; ++i)
     {
      const long s = iSpread(_Symbol, PERIOD_H4, i);
      if(s > 0)
        {
         spreads[count] = (double)s;
         ++count;
        }
     }
   if(count < 10)
      return true;

   ArrayResize(spreads, count);
   ArraySort(spreads);
   const double median = (count % 2 == 1) ? spreads[count / 2] : 0.5 * (spreads[count / 2 - 1] + spreads[count / 2]);
   return ((double)current_spread <= strategy_spread_median_mult * median);
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if(Bars(_Symbol, PERIOD_H4) < strategy_warmup_h4_bars)
      return true;
   if(Bars(_Symbol, PERIOD_D1) < strategy_d1_sma_period + 5)
      return true;
   if(!SpreadAllowed())
      return true;
   return false;
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const datetime h4_bar = iTime(_Symbol, PERIOD_H4, 1);
   if(h4_bar <= 0 || h4_bar == g_last_h4_signal_bar)
      return false;
   g_last_h4_signal_bar = h4_bar;

   const int shift = 1;
   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, shift);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(atr <= 0.0 || point <= 0.0)
      return false;

   const bool bullish = DirectionalCamouflage(true, shift);
   const bool bearish = DirectionalCamouflage(false, shift);
   if(!bullish && !bearish)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(bullish)
     {
      req.type = QM_BUY;
      req.price = ask;
      req.sl = iLow(_Symbol, PERIOD_H4, shift) - strategy_sl_atr_buffer * atr;
      req.reason = "TD_CAMOUFLAGE_BULLISH";
     }
   else
     {
      req.type = QM_SELL;
      req.price = bid;
      req.sl = iHigh(_Symbol, PERIOD_H4, shift) + strategy_sl_atr_buffer * atr;
      req.reason = "TD_CAMOUFLAGE_BEARISH";
     }

   if(MathAbs(req.price - req.sl) / point <= 0.0)
      return false;

   g_last_signal_atr = atr;
   return true;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   double open_price;
   double volume;
   datetime open_time;
   if(!GetOurPosition(ticket, ptype, open_price, volume, open_time))
      return;
   if(ticket == g_tp1_done_ticket)
      return;

   double atr = g_last_signal_atr;
   if(atr <= 0.0)
      atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(atr <= 0.0 || volume <= 0.0 || open_price <= 0.0)
      return;

   const bool is_buy = (ptype == POSITION_TYPE_BUY);
   const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double target = is_buy ? (open_price + strategy_tp1_atr_mult * atr) : (open_price - strategy_tp1_atr_mult * atr);
   if((is_buy && market < target) || (!is_buy && market > target))
      return;

   if(QM_TM_PartialClose(ticket, volume * strategy_tp1_close_frac, QM_EXIT_PARTIAL))
      g_tp1_done_ticket = ticket;
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   double open_price;
   double volume;
   datetime open_time;
   if(!GetOurPosition(ticket, ptype, open_price, volume, open_time))
      return false;

   const int period_seconds = PeriodSeconds(PERIOD_H4);
   if(period_seconds > 0 && open_time > 0)
     {
      const int bars_elapsed = (int)((TimeCurrent() - open_time) / period_seconds);
      if(bars_elapsed >= strategy_time_stop_bars && ticket != g_tp1_done_ticket)
         return true;
     }

   if(ptype == POSITION_TYPE_BUY && DirectionalCamouflage(false, 1))
      return true;
   if(ptype == POSITION_TYPE_SELL && DirectionalCamouflage(true, 1))
      return true;
   return false;
  }

// News Filter Hook (callable for P8 News Impact phase)
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return !QM_NewsAllowsTrade(_Symbol, broker_time, qm_news_mode);
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
                        qm_friday_close_hour_broker))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1510\",\"strategy\":\"demark_td_camouflage_h4\"}");
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
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
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
