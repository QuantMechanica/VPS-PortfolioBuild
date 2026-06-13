#property strict
#property version   "5.0"
#property description "QM5_10354 Elite Trader Crude ORB"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10354;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours    = 336;
input string qm_news_min_impact         = "high";
input QM_NewsMode qm_news_mode_legacy   = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_timeframe = PERIOD_M15;
input int    strategy_range_a_start_cet  = 12;
input int    strategy_range_b_start_cet  = 14;
input int    strategy_range_minutes      = 60;
input double strategy_oil_buffer_price   = 0.15;
input double strategy_oil_stop_price     = 0.70;
input double strategy_oil_target_price   = 1.60;
input double strategy_oil_max_range      = 1.00;
input double strategy_port_buffer_atr    = 0.10;
input double strategy_port_stop_atr      = 1.00;
input double strategy_port_max_range_atr = 1.50;
input double strategy_port_target_r      = 2.25;
input int    strategy_atr_period         = 14;
input double strategy_spread_median_mult = 2.50;
input int    strategy_spread_median_bars = 96;
input int    strategy_eod_close_hour_cet = 21;
input int    strategy_friday_close_hour_cet = 20;

datetime Strategy_BrokerToFixedCET(const datetime broker_time)
  {
   return QM_BrokerToUTC(broker_time) + 3600;
  }

int Strategy_ClampInt(const int value, const int min_value, const int max_value)
  {
   return MathMax(min_value, MathMin(max_value, value));
  }

int Strategy_DateKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

int Strategy_MinuteOfDayCET(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(Strategy_BrokerToFixedCET(broker_time), dt);
   return dt.hour * 60 + dt.min;
  }

bool Strategy_IsFridayCET(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(Strategy_BrokerToFixedCET(broker_time), dt);
   return (dt.day_of_week == 5);
  }

bool Strategy_IsOilSymbol()
  {
   return (_Symbol == "XTIUSD.DWX" || _Symbol == "XTIUSD");
  }

bool Strategy_CurrentSpread(double &spread_price, double &spread_points)
  {
   spread_price = 0.0;
   spread_points = 0.0;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || ask <= bid || point <= 0.0)
      return false;

   spread_price = ask - bid;
   spread_points = spread_price / point;
   return true;
  }

bool Strategy_HasOurOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

bool Strategy_IsStopOrderType(const ENUM_ORDER_TYPE order_type)
  {
   return (order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_SELL_STOP);
  }

int Strategy_OurPendingStopCount()
  {
   const int magic = QM_FrameworkMagic();
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(Strategy_IsStopOrderType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         ++count;
     }
   return count;
  }

void Strategy_RemoveOurPendingStops(const string reason)
  {
   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(!Strategy_IsStopOrderType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         continue;
      QM_TM_RemovePendingOrder(ticket, reason);
     }
  }

bool Strategy_SpreadMedianOk(const double current_spread_points)
  {
   const int lookback = Strategy_ClampInt(strategy_spread_median_bars, 10, 500);
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, strategy_timeframe, 1, lookback, rates); // perf-allowed opening-range spread median on closed-bar path
   if(copied < 10)
      return true;

   double spreads[];
   ArrayResize(spreads, copied);
   int n = 0;
   for(int i = 0; i < copied; ++i)
     {
      if(rates[i].spread > 0)
        {
         spreads[n] = (double)rates[i].spread;
         ++n;
        }
     }
   if(n < 10)
      return true;

   ArrayResize(spreads, n);
   ArraySort(spreads);
   const double median = ((n % 2) == 1) ? spreads[n / 2] : 0.5 * (spreads[n / 2 - 1] + spreads[n / 2]);
   if(median <= 0.0)
      return true;

   return (current_spread_points <= strategy_spread_median_mult * median);
  }

bool Strategy_BuildOpeningRange(const int start_hour_cet, double &range_high, double &range_low, int &range_key)
  {
   range_high = 0.0;
   range_low = 0.0;
   range_key = 0;

   if(strategy_timeframe != PERIOD_M15)
      return false;

   const int bars_required = MathMax(1, strategy_range_minutes / 15);
   if(bars_required != 4)
      return false;

   const datetime last_bar_open = iTime(_Symbol, strategy_timeframe, 1); // perf-allowed structural ORB window timestamp
   if(last_bar_open <= 0)
      return false;

   MqlDateTime last_cet;
   TimeToStruct(Strategy_BrokerToFixedCET(last_bar_open), last_cet);
   const int expected_last_hour = start_hour_cet;
   const int expected_last_minute = 45;
   if(last_cet.hour != expected_last_hour || last_cet.min != expected_last_minute)
      return false;

   const int start_minute = Strategy_ClampInt(start_hour_cet, 0, 23) * 60;
   const int end_minute = start_minute + strategy_range_minutes;
   double high = -DBL_MAX;
   double low = DBL_MAX;
   int matched = 0;

   for(int shift = bars_required; shift >= 1; --shift)
     {
      const datetime bar_open = iTime(_Symbol, strategy_timeframe, shift); // perf-allowed bounded 4-bar ORB structural read
      if(bar_open <= 0)
         return false;

      MqlDateTime cet;
      TimeToStruct(Strategy_BrokerToFixedCET(bar_open), cet);
      const int bar_minute = cet.hour * 60 + cet.min;
      if(bar_minute < start_minute || bar_minute >= end_minute)
         return false;

      const double bar_high = iHigh(_Symbol, strategy_timeframe, shift); // perf-allowed bounded 4-bar ORB structural read
      const double bar_low = iLow(_Symbol, strategy_timeframe, shift); // perf-allowed bounded 4-bar ORB structural read
      if(bar_high <= 0.0 || bar_low <= 0.0 || bar_high <= bar_low)
         return false;

      high = MathMax(high, bar_high);
      low = MathMin(low, bar_low);
      ++matched;
     }

   if(matched != bars_required || high <= low)
      return false;

   range_high = high;
   range_low = low;
   range_key = Strategy_DateKey(Strategy_BrokerToFixedCET(last_bar_open)) * 100 + start_hour_cet;
   return true;
  }

void Strategy_InitRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = MathMax(900, (strategy_eod_close_hour_cet * 60 - Strategy_MinuteOfDayCET(TimeCurrent())) * 60);
  }

bool Strategy_BuildStopRequests(const double range_high,
                                const double range_low,
                                const int range_key,
                                QM_EntryRequest &buy_req,
                                QM_EntryRequest &sell_req)
  {
   Strategy_InitRequest(buy_req);
   Strategy_InitRequest(sell_req);

   double spread_price = 0.0;
   double spread_points = 0.0;
   if(!Strategy_CurrentSpread(spread_price, spread_points))
      return false;
   if(!Strategy_SpreadMedianOk(spread_points))
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || range_high <= range_low)
      return false;

   const double range_size = range_high - range_low;
   double buffer = strategy_oil_buffer_price;
   double fixed_stop = strategy_oil_stop_price;
   double target_distance = strategy_oil_target_price;
   double max_range = strategy_oil_max_range;
   if(!Strategy_IsOilSymbol())
     {
      const double atr = QM_ATR(_Symbol, strategy_timeframe, MathMax(1, strategy_atr_period), 1);
      if(atr <= 0.0)
         return false;
      buffer = MathMax(0.0, strategy_port_buffer_atr) * atr;
      fixed_stop = MathMax(0.0, strategy_port_stop_atr) * atr;
      target_distance = 0.0;
      max_range = MathMax(0.1, strategy_port_max_range_atr) * atr;
     }

   if(buffer <= 0.0 || fixed_stop <= 0.0 || max_range <= 0.0 || range_size > max_range)
      return false;

   const double buy_entry = QM_TM_NormalizePrice(_Symbol, range_high + buffer);
   const double sell_entry = QM_TM_NormalizePrice(_Symbol, range_low - buffer);
   if(buy_entry <= 0.0 || sell_entry <= 0.0 || buy_entry <= sell_entry)
      return false;

   double buy_sl = MathMax(buy_entry - fixed_stop, range_low);
   double sell_sl = MathMin(sell_entry + fixed_stop, range_high);
   buy_sl = QM_TM_NormalizePrice(_Symbol, buy_sl);
   sell_sl = QM_TM_NormalizePrice(_Symbol, sell_sl);
   if(buy_sl <= 0.0 || sell_sl <= 0.0 || buy_sl >= buy_entry || sell_sl <= sell_entry)
      return false;

   const double buy_risk = buy_entry - buy_sl;
   const double sell_risk = sell_sl - sell_entry;
   if(buy_risk < 4.0 * spread_price || sell_risk < 4.0 * spread_price)
      return false;

   buy_req.type = QM_BUY_STOP;
   buy_req.price = buy_entry;
   buy_req.sl = buy_sl;
   buy_req.tp = Strategy_IsOilSymbol()
                ? QM_TM_NormalizePrice(_Symbol, buy_entry + target_distance)
                : QM_TM_NormalizePrice(_Symbol, buy_entry + strategy_port_target_r * buy_risk);
   buy_req.reason = StringFormat("ET_CRUDE_ORB_BUY_%d", range_key);

   sell_req.type = QM_SELL_STOP;
   sell_req.price = sell_entry;
   sell_req.sl = sell_sl;
   sell_req.tp = Strategy_IsOilSymbol()
                 ? QM_TM_NormalizePrice(_Symbol, sell_entry - target_distance)
                 : QM_TM_NormalizePrice(_Symbol, sell_entry - strategy_port_target_r * sell_risk);
   sell_req.reason = StringFormat("ET_CRUDE_ORB_SELL_%d", range_key);

   return (buy_req.tp > buy_entry && sell_req.tp > 0.0 && sell_req.tp < sell_entry);
  }

// No Trade Filter: time, spread, news.
bool Strategy_NoTradeFilter()
  {
   double spread_price = 0.0;
   double spread_points = 0.0;
   if(!Strategy_CurrentSpread(spread_price, spread_points))
      return true;

   return false;
  }

// Trade Entry: 12:00-13:00 and 14:00-15:00 CET opening-range breakout stops.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   Strategy_InitRequest(req);

   if(Strategy_HasOurOpenPosition() || Strategy_OurPendingStopCount() > 0)
      return false;

   double range_high = 0.0;
   double range_low = 0.0;
   int range_key = 0;
   if(!Strategy_BuildOpeningRange(strategy_range_a_start_cet, range_high, range_low, range_key) &&
      !Strategy_BuildOpeningRange(strategy_range_b_start_cet, range_high, range_low, range_key))
      return false;

   QM_EntryRequest buy_req;
   QM_EntryRequest sell_req;
   if(!Strategy_BuildStopRequests(range_high, range_low, range_key, buy_req, sell_req))
      return false;

   ulong buy_ticket = 0;
   if(!QM_TM_OpenPosition(buy_req, buy_ticket))
      return false;

   req = sell_req;
   return true;
  }

// Trade Management: cancel opposite stops after a fill and remove all stops at EOD.
void Strategy_ManageOpenPosition()
  {
   const int minute_cet = Strategy_MinuteOfDayCET(TimeCurrent());
   const int close_hour = Strategy_IsFridayCET(TimeCurrent()) ? strategy_friday_close_hour_cet : strategy_eod_close_hour_cet;
   if(minute_cet >= close_hour * 60)
      Strategy_RemoveOurPendingStops("et_crude_orb_eod_pending_cancel");

   if(Strategy_HasOurOpenPosition())
      Strategy_RemoveOurPendingStops("et_crude_orb_position_open_cancel_opposite");
  }

// Trade Close: end-of-day flat at 21:00 CET, Friday 20:00 CET.
bool Strategy_ExitSignal()
  {
   const int close_hour = Strategy_IsFridayCET(TimeCurrent()) ? strategy_friday_close_hour_cet : strategy_eod_close_hour_cet;
   return (Strategy_MinuteOfDayCET(TimeCurrent()) >= close_hour * 60);
  }

// News Filter Hook: callable for P8 News Impact phase; central framework owns news.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10354_et_crude_orb\"}");
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
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
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
