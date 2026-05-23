#property strict
#property version   "5.0"
#property description "QM5_10013 Robot Wealth FX Weekend Gap"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 10013;
input int    qm_magic_slot_offset        = 0;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsMode qm_news_mode           = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input int    strategy_atr_period         = 14;
input double strategy_gap_threshold_atr  = 0.35;
input double strategy_sl_gap_mult        = 1.20;
input double strategy_sl_min_atr         = 0.80;
input double strategy_sl_max_atr         = 2.00;
input int    strategy_max_hold_hours     = 24;
input int    strategy_spread_median_bars = 24;
input double strategy_spread_max_mult    = 2.00;

// -----------------------------------------------------------------------------
// Strategy helpers
// -----------------------------------------------------------------------------

int SymbolSlot()
  {
   if(_Symbol == "EURUSD.DWX") return 0;
   if(_Symbol == "GBPUSD.DWX") return 1;
   if(_Symbol == "USDJPY.DWX") return 2;
   if(_Symbol == "AUDUSD.DWX") return 3;
   if(_Symbol == "NZDUSD.DWX") return 4;
   if(_Symbol == "USDCAD.DWX") return 5;
   return qm_magic_slot_offset;
  }

bool IsSupportedSymbol()
  {
   const int slot = SymbolSlot();
   return (slot >= 0 && slot <= 5);
  }

double MedianH1SpreadPoints(const int bars)
  {
   const int n = MathMin(MathMax(bars, 3), 96);
   double spreads[];
   ArrayResize(spreads, n);

   int copied = 0;
   for(int i = 1; i <= n; ++i)
     {
      const int spread = (int)iSpread(_Symbol, PERIOD_H1, i);
      if(spread <= 0)
         continue;
      spreads[copied] = (double)spread;
      copied++;
     }

   if(copied < 3)
      return 0.0;

   ArrayResize(spreads, copied);
   ArraySort(spreads);

   const int mid = copied / 2;
   if((copied % 2) == 1)
      return spreads[mid];
   return 0.5 * (spreads[mid - 1] + spreads[mid]);
  }

bool SpreadAllowsEntry()
  {
   const long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(current_spread <= 0)
      return false;

   const double median_spread = MedianH1SpreadPoints(strategy_spread_median_bars);
   if(median_spread <= 0.0)
      return true;

   return ((double)current_spread <= median_spread * strategy_spread_max_mult);
  }

bool WeekendGapSetup(double &monday_open,
                     double &friday_close,
                     double &gap,
                     double &atr)
  {
   monday_open = 0.0;
   friday_close = 0.0;
   gap = 0.0;
   atr = 0.0;

   const datetime post_weekend_bar = iTime(_Symbol, PERIOD_H1, 1);
   const datetime pre_weekend_bar = iTime(_Symbol, PERIOD_H1, 2);
   if(post_weekend_bar <= 0 || pre_weekend_bar <= 0)
      return false;

   // The first completed H1 bar after the weekend follows a >48h timestamp gap.
   if((post_weekend_bar - pre_weekend_bar) < (48 * 3600))
      return false;

   monday_open = iOpen(_Symbol, PERIOD_H1, 1);
   friday_close = iClose(_Symbol, PERIOD_H1, 2);
   atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 2);
   if(monday_open <= 0.0 || friday_close <= 0.0 || atr <= 0.0)
      return false;

   gap = monday_open - friday_close;
   return true;
  }

bool IsPastTuesday17NY(const datetime broker_time)
  {
   const datetime utc = QM_BrokerToUTC(broker_time);
   const int ny_offset_hours = QM_IsUSDSTUTC(utc) ? -4 : -5;
   const datetime ny_time = utc + (ny_offset_hours * 3600);

   MqlDateTime ny;
   ZeroMemory(ny);
   TimeToStruct(ny_time, ny);

   if(ny.day_of_week > 2 && ny.day_of_week < 6)
      return true;
   if(ny.day_of_week == 2 && ny.hour >= 17)
      return true;
   return false;
  }

bool OurPosition(ulong &ticket,
                 ENUM_POSITION_TYPE &position_type,
                 double &open_price,
                 datetime &open_time,
                 double &tp)
  {
   ticket = 0;
   position_type = POSITION_TYPE_BUY;
   open_price = 0.0;
   open_time = 0;
   tp = 0.0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong candidate = PositionGetTicket(i);
      if(candidate == 0 || !PositionSelectByTicket(candidate))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = candidate;
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      tp = PositionGetDouble(POSITION_TP);
      return true;
     }

   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   return !IsSupportedSymbol();
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = SymbolSlot();
   req.expiration_seconds = 0;

   if(!IsSupportedSymbol())
      return false;

   if(!SpreadAllowsEntry())
      return false;

   double monday_open = 0.0;
   double friday_close = 0.0;
   double gap = 0.0;
   double atr = 0.0;
   if(!WeekendGapSetup(monday_open, friday_close, gap, atr))
      return false;

   const double normalized_gap = gap / atr;
   if(MathAbs(normalized_gap) < strategy_gap_threshold_atr)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double raw_stop_dist = MathAbs(gap) * strategy_sl_gap_mult;
   const double min_stop_dist = atr * strategy_sl_min_atr;
   const double max_stop_dist = atr * strategy_sl_max_atr;
   const double stop_dist = MathMin(MathMax(raw_stop_dist, min_stop_dist), max_stop_dist);
   if(stop_dist <= 0.0)
      return false;

   if(normalized_gap <= -strategy_gap_threshold_atr)
     {
      if(ask >= friday_close)
         return false;
      req.type = QM_BUY;
      req.sl = ask - stop_dist;
      req.tp = friday_close;
      req.reason = "RW_FX_WEEKEND_GAP_LONG_FILL";
      return true;
     }

   if(normalized_gap >= strategy_gap_threshold_atr)
     {
      if(bid <= friday_close)
         return false;
      req.type = QM_SELL;
      req.sl = bid + stop_dist;
      req.tp = friday_close;
      req.reason = "RW_FX_WEEKEND_GAP_SHORT_FILL";
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies no break-even, trailing, or partial-close management.
  }

bool Strategy_ExitSignal()
  {
   ulong ticket = 0;
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   double open_price = 0.0;
   datetime open_time = 0;
   double friday_close_tp = 0.0;
   if(!OurPosition(ticket, position_type, open_price, open_time, friday_close_tp))
      return false;

   const datetime broker_now = TimeCurrent();
   if(open_time > 0 && (broker_now - open_time) >= strategy_max_hold_hours * 3600)
      return true;

   if(IsPastTuesday17NY(broker_now))
      return true;

   if(friday_close_tp <= 0.0)
      return false;

   if(position_type == POSITION_TYPE_BUY)
     {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      return (bid >= friday_close_tp);
     }

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   return (ask <= friday_close_tp);
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line unless the framework changes.
// -----------------------------------------------------------------------------

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10013\",\"ea\":\"rw-fx-weekend-gap\"}");
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
