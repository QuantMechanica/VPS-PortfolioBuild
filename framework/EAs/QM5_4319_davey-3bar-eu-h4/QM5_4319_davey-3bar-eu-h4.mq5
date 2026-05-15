#property strict
#property version   "5.0"
#property description "QM5_4319 Davey 3-Bar EURUSD H4 v2 (SRC01_S06)"
// Strategy Card: SRC01_S06 (davey-3bar-eu-h4), CEO+QB G0 APPROVED.

#include <QM/QM_Common.mqh>
#include <Trade/Trade.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                  = 4319;
input int    qm_magic_slot_offset      = 0;

input group "Risk"
input double RISK_PERCENT              = 0.0;
input double RISK_FIXED                = 1000.0;
input double PORTFOLIO_WEIGHT          = 1.0;

input group "News"
input QM_NewsMode qm_news_mode         = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Strategy"
input double ssl1                         = 0.75;   // Card §4/§8
input double ssl_usd_cap                  = 2000.0; // Card §4/§8
input int    strategy_atr_period          = 14;     // Card §4/§8
input double strategy_atr_floor_frac      = 0.70;   // Card §4
input int    strategy_atr_floor_lookback  = 60;     // Card §4
input int    strategy_time_stop_bars      = 12;     // Card §5

CTrade   g_trade;
datetime g_last_bar_time = 0;

bool IsNewBar()
  {
   const datetime t0 = iTime(_Symbol, _Period, 0);
   if(t0 <= 0)
      return false;
   if(t0 == g_last_bar_time)
      return false;
   g_last_bar_time = t0;
   return true;
  }

bool GetOurPosition(ENUM_POSITION_TYPE &ptype, double &price_open, datetime &time_open, ulong &ticket)
  {
   ptype = POSITION_TYPE_BUY;
   price_open = 0.0;
   time_open = 0;
   ticket = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

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

      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      price_open = PositionGetDouble(POSITION_PRICE_OPEN);
      time_open = (datetime)PositionGetInteger(POSITION_TIME);
      ticket = t;
      return true;
     }

   return false;
  }

double TickValuePriceDistancePerLot(const double dollars)
  {
   const double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(dollars <= 0.0 || tick_value <= 0.0 || tick_size <= 0.0)
      return 0.0;
   return (dollars * tick_size / tick_value);
  }

bool ReadAtrSeries(const int period, const int bars_needed, double &out_arr[])
  {
   if(period <= 0 || bars_needed <= 0)
      return false;

   const int handle = iATR(_Symbol, _Period, period);
   if(handle == INVALID_HANDLE)
      return false;

   ArrayResize(out_arr, bars_needed);
   ArraySetAsSeries(out_arr, true);
   const int copied = CopyBuffer(handle, 0, 1, bars_needed, out_arr);
   IndicatorRelease(handle);
   return (copied == bars_needed);
  }

double MedianOfArray(double &arr[])
  {
   const int n = ArraySize(arr);
   if(n <= 0)
      return 0.0;

   double sorted[];
   ArrayResize(sorted, n);
   for(int i = 0; i < n; ++i)
      sorted[i] = arr[i];
   ArraySort(sorted);

   if((n % 2) == 1)
      return sorted[n / 2];
   return 0.5 * (sorted[(n / 2) - 1] + sorted[n / 2]);
  }

bool PassesAtrRegimeGate()
  {
   if(strategy_atr_floor_lookback <= 0 || strategy_atr_floor_frac <= 0.0)
      return false;

   const int bars_needed = strategy_atr_floor_lookback;
   double atr_vals[];
   if(!ReadAtrSeries(strategy_atr_period, bars_needed, atr_vals))
      return false;

   const double atr_now = atr_vals[0];
   const double atr_median = MedianOfArray(atr_vals);
   if(atr_now <= 0.0 || atr_median <= 0.0)
      return false;

   return (atr_now >= strategy_atr_floor_frac * atr_median);
  }

double ResolveStopDistancePrice()
  {
   double atr_value = 0.0;
   if(!QM_StopRulesReadATRValue(_Symbol, strategy_atr_period, 1, atr_value))
      return 0.0;

   const double atr_distance = atr_value * ssl1;
   const double cap_distance = TickValuePriceDistancePerLot(ssl_usd_cap);
   if(atr_distance <= 0.0 || cap_distance <= 0.0)
      return 0.0;
   return MathMin(atr_distance, cap_distance);
  }

bool Has3BarDownSignal()
  {
   const double c1 = iClose(_Symbol, _Period, 1);
   const double c2 = iClose(_Symbol, _Period, 2);
   const double c3 = iClose(_Symbol, _Period, 3);
   return (c1 > 0.0 && c2 > 0.0 && c3 > 0.0 && c1 < c2 && c2 < c3);
  }

bool Has3BarUpSignal()
  {
   const double c1 = iClose(_Symbol, _Period, 1);
   const double c2 = iClose(_Symbol, _Period, 2);
   const double c3 = iClose(_Symbol, _Period, 3);
   return (c1 > 0.0 && c2 > 0.0 && c3 > 0.0 && c1 > c2 && c2 > c3);
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

   // Card §5: single open position; no flip while position is open.
   ENUM_POSITION_TYPE ptype;
   double price_open;
   datetime time_open;
   ulong ticket;
   if(GetOurPosition(ptype, price_open, time_open, ticket))
      return false;

   if(!PassesAtrRegimeGate())
      return false;

   const double stop_distance = ResolveStopDistancePrice();
   if(stop_distance <= 0.0)
      return false;

   if(Has3BarDownSignal())
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      req.type = QM_BUY;
      req.sl = QM_StopRulesStopFromDistance(_Symbol, req.type, entry, stop_distance);
      req.reason = "SRC01_S06_LONG_3BAR_DOWN";
      return (req.sl > 0.0);
     }

   if(Has3BarUpSignal())
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      req.type = QM_SELL;
      req.sl = QM_StopRulesStopFromDistance(_Symbol, req.type, entry, stop_distance);
      req.reason = "SRC01_S06_SHORT_3BAR_UP";
      return (req.sl > 0.0);
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   ENUM_POSITION_TYPE ptype;
   double price_open;
   datetime time_open;
   ulong ticket;
   if(!GetOurPosition(ptype, price_open, time_open, ticket))
      return;

   const double stop_distance = ResolveStopDistancePrice();
   if(stop_distance > 0.0)
     {
      const QM_OrderType side = (ptype == POSITION_TYPE_BUY) ? QM_BUY : QM_SELL;
      const double sl = QM_StopRulesStopFromDistance(_Symbol, side, price_open, stop_distance);
      if(sl > 0.0)
        {
         g_trade.SetExpertMagicNumber(QM_FrameworkMagic());
         g_trade.PositionModify(_Symbol, sl, 0.0);
        }
     }

   // Card §5: time stop after 12 H4 bars.
   if(strategy_time_stop_bars > 0 && time_open > 0)
     {
      const int bars_since_open = iBarShift(_Symbol, _Period, time_open, false);
      if(bars_since_open >= strategy_time_stop_bars)
        {
         g_trade.SetExpertMagicNumber(QM_FrameworkMagic());
         g_trade.PositionClose(ticket);
        }
     }
  }

bool Strategy_ExitSignal()
  {
   return false;
  }

bool ExecuteEntrySignal(const QM_EntryRequest &req)
  {
   const double entry = (req.type == QM_BUY)
                        ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0 || req.sl <= 0.0)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;

   const double sl_points = MathAbs(entry - req.sl) / point;
   const double lots = QM_LotsForRisk(_Symbol, sl_points);
   if(lots <= 0.0)
      return false;

   g_trade.SetExpertMagicNumber(QM_FrameworkMagic());
   if(req.type == QM_BUY)
      return g_trade.Buy(lots, _Symbol, 0.0, req.sl, 0.0, req.reason);
   return g_trade.Sell(lots, _Symbol, 0.0, req.sl, 0.0, req.reason);
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"SRC01_S06\",\"ea\":\"QM5_4319_davey-3bar-eu-h4\"}");
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

   if(!IsNewBar())
      return;

   Strategy_ManageOpenPosition();
   if(Strategy_ExitSignal())
      return;

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
      ExecuteEntrySignal(req);
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
