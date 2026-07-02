#property strict
#property version   "5.0"
#property description "QM5_12844 Crude Commodity Trend Breakout"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12844 - Crude Commodity Trend Breakout
// -----------------------------------------------------------------------------
// OWNER-approved card of record:
//   - D1 Donchian buy-stop / sell-stop entries at the last N-bar extremes
//   - ADX(11) trend-state gate
//   - 3.0 ATR hard stop, 3.0 ATR trail from favorable movement
//   - stop-and-reverse on the opposite Donchian signal
//   - optional time exit where time_exit_bars=0 means disabled
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12844;
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
input int    donchian_lookback          = 20;
input int    adx_period                 = 11;
input double adx_min                    = 20.0;
input int    atr_period                 = 14;
input double atr_trail_mult             = 3.0;
input int    time_exit_bars             = 0;
input bool   use_stop_and_reverse       = true;
input int    strategy_max_spread_points = 1000;

datetime g_last_entry_bar_time = 0;
datetime g_last_no_reverse_bar_time = 0;

bool Strategy_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
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

int Strategy_OwnedPendingOrders()
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
      ++count;
     }
   return count;
  }

void Strategy_CancelOwnedPendingOrders(const string reason)
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
      QM_TM_RemovePendingOrder(ticket, reason);
     }
  }

bool Strategy_SpreadAllowsEntry()
  {
   if(strategy_max_spread_points <= 0)
      return true;
   const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (spread_points <= strategy_max_spread_points);
  }

bool Strategy_LoadClosedState(double &close_last,
                              datetime &closed_time,
                              double &entry_high,
                              double &entry_low,
                              double &adx_value,
                              double &atr_value)
  {
   const int lookback = MathMax(2, donchian_lookback);
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, lookback, rates); // perf-allowed: bounded D1 channel math.
   if(copied < lookback)
      return false;

   close_last = rates[0].close;
   closed_time = rates[0].time;
   if(close_last <= 0.0 || closed_time <= 0)
      return false;

   entry_high = -DBL_MAX;
   entry_low = DBL_MAX;
   for(int i = 0; i < lookback; ++i)
     {
      if(rates[i].high > entry_high)
         entry_high = rates[i].high;
      if(rates[i].low < entry_low)
         entry_low = rates[i].low;
     }

   adx_value = QM_ADX(_Symbol, PERIOD_D1, MathMax(1, adx_period), 1);
   atr_value = QM_ATR(_Symbol, PERIOD_D1, MathMax(1, atr_period), 1);

   return (entry_high > 0.0 &&
           entry_low > 0.0 &&
           entry_high > entry_low &&
           adx_value > 0.0 &&
           atr_value > 0.0);
  }

bool Strategy_BuildStopRequest(const QM_OrderType side,
                               const double stop_price,
                               const double atr_value,
                               const string reason,
                               QM_EntryRequest &req)
  {
   req.type = side;
   req.price = NormalizeDouble(stop_price, _Digits);
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = reason;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = MathMax(3600, PeriodSeconds(PERIOD_D1));

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(bid <= 0.0 || ask <= 0.0 || point <= 0.0 || req.price <= 0.0)
      return false;

   if(side == QM_BUY_STOP)
     {
      if(req.price <= ask + point)
         return false;
      req.sl = NormalizeDouble(req.price - atr_value * atr_trail_mult, _Digits);
      return (req.sl > 0.0 && req.sl < req.price);
     }

   if(side == QM_SELL_STOP)
     {
      if(req.price >= bid - point)
         return false;
      req.sl = NormalizeDouble(req.price + atr_value * atr_trail_mult, _Digits);
      return (req.sl > req.price);
     }

   return false;
  }

bool Strategy_NoTradeFilter()
  {
   if(donchian_lookback < 2)
      return true;
   if(adx_period <= 0 || adx_min < 0.0)
      return true;
   if(atr_period <= 0 || atr_trail_mult <= 0.0)
      return true;
   if(time_exit_bars < 0)
      return true;
   if(!Strategy_SpreadAllowsEntry())
      return true;
   return false;
  }

bool Strategy_CloseOppositeSignal(const double close_last,
                                  const double entry_high,
                                  const double entry_low,
                                  const datetime closed_time)
  {
   const int magic = QM_FrameworkMagic();
   bool closed_any = false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const bool exit_long = (position_type == POSITION_TYPE_BUY && close_last < entry_low);
      const bool exit_short = (position_type == POSITION_TYPE_SELL && close_last > entry_high);
      if(!exit_long && !exit_short)
         continue;

      if(QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL))
        {
         closed_any = true;
         if(!use_stop_and_reverse)
            g_last_no_reverse_bar_time = closed_time;
        }
     }

   return closed_any;
  }

void Strategy_TrailPosition(const ulong ticket)
  {
   if(!PositionSelectByTicket(ticket))
      return;

   const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   const bool is_buy = (position_type == POSITION_TYPE_BUY);
   const double market_price = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                      : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double atr_value = QM_ATR(_Symbol, PERIOD_D1, MathMax(1, atr_period), 1);
   if(open_price <= 0.0 || market_price <= 0.0 || atr_value <= 0.0)
      return;

   const double favorable = is_buy ? (market_price - open_price) : (open_price - market_price);
   if(favorable >= atr_value)
      QM_TM_TrailATR(ticket, atr_period, atr_trail_mult);
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   double close_last = 0.0;
   datetime closed_time = 0;
   double entry_high = 0.0;
   double entry_low = 0.0;
   double adx_value = 0.0;
   double atr_value = 0.0;
   const bool has_state = Strategy_LoadClosedState(close_last,
                                                   closed_time,
                                                   entry_high,
                                                   entry_low,
                                                   adx_value,
                                                   atr_value);

   if(has_state)
      Strategy_CloseOppositeSignal(close_last, entry_high, entry_low, closed_time);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      if(time_exit_bars > 0)
        {
         const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
         const int entry_shift = iBarShift(_Symbol, PERIOD_D1, opened, false); // perf-allowed: one open position.
         if(entry_shift >= time_exit_bars)
           {
            QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
            continue;
           }
        }

      Strategy_TrailPosition(ticket);
     }
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_12844_COMMODITY_TREND_CRUDE";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   double close_last = 0.0;
   datetime closed_time = 0;
   double entry_high = 0.0;
   double entry_low = 0.0;
   double adx_value = 0.0;
   double atr_value = 0.0;
   if(!Strategy_LoadClosedState(close_last, closed_time, entry_high, entry_low, adx_value, atr_value))
      return false;
   if(closed_time == g_last_entry_bar_time || closed_time == g_last_no_reverse_bar_time)
      return false;
   if(Strategy_NoTradeFilter())
      return false;
   if(adx_value <= adx_min)
      return false;
   if(Strategy_HasOpenPosition())
      return false;

   Strategy_CancelOwnedPendingOrders("qm12844_refresh_d1_stops");

   QM_EntryRequest buy_req;
   QM_EntryRequest sell_req;
   bool placed_any = false;
   if(Strategy_BuildStopRequest(QM_BUY_STOP, entry_high, atr_value, "XTI_DONCHIAN_ADX_BUY_STOP", buy_req))
     {
      ulong buy_ticket = 0;
      placed_any = QM_TM_OpenPosition(buy_req, buy_ticket) || placed_any;
     }

   if(Strategy_BuildStopRequest(QM_SELL_STOP, entry_low, atr_value, "XTI_DONCHIAN_ADX_SELL_STOP", sell_req))
     {
      ulong sell_ticket = 0;
      placed_any = QM_TM_OpenPosition(sell_req, sell_ticket) || placed_any;
     }

   if(placed_any)
      g_last_entry_bar_time = closed_time;
   return false;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12844\",\"source\":\"owner_approved_card\"}");
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
   if(QM_FrameworkHandleFridayClose())
      return;

   Strategy_ManageOpenPosition();
   if(Strategy_HasOpenPosition())
      Strategy_CancelOwnedPendingOrders("qm12844_position_open");

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

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

   QM_EntryRequest req;
   Strategy_EntrySignal(req);
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
