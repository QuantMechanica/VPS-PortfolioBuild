#property strict
#property version   "5.0"
#property description "QM5_10600 MQL5 Narrowest Range Breakout"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10600;
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
input ENUM_TIMEFRAMES strategy_timeframe    = PERIOD_H4;
input int    strategy_bars_in_range         = 7;
input int    strategy_check_period          = 20;
input int    strategy_order_indent_points   = 10;
input double strategy_tp_range_mult         = 1.0;
input int    strategy_atr_period            = 14;
input double strategy_catastrophic_atr_mult = 2.0;
input int    strategy_max_spread_points     = 0;

double g_strategy_active_range_high = 0.0;
double g_strategy_active_range_low = 0.0;
bool   g_strategy_has_active_range = false;

bool Strategy_IsOurStopOrderType(const ENUM_ORDER_TYPE order_type)
  {
   return (order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_SELL_STOP);
  }

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
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

int Strategy_PendingStopCount()
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
      if(Strategy_IsOurStopOrderType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         ++count;
     }
   return count;
  }

void Strategy_RemovePendingStops(const string reason)
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
      if(!Strategy_IsOurStopOrderType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         continue;
      QM_TM_RemovePendingOrder(ticket, reason);
     }
  }

bool Strategy_CurrentSpreadOK()
  {
   if(strategy_max_spread_points <= 0)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || ask < bid || point <= 0.0)
      return false;

   return ((ask - bid) / point <= (double)strategy_max_spread_points);
  }

bool Strategy_RangeBounds(const int start_shift,
                          const int bars,
                          double &range_high,
                          double &range_low,
                          double &range_width)
  {
   range_high = -DBL_MAX;
   range_low = DBL_MAX;
   range_width = 0.0;

   if(start_shift < 1 || bars < 1)
      return false;

   for(int shift = start_shift; shift < start_shift + bars; ++shift)
     {
      const double high = iHigh(_Symbol, strategy_timeframe, shift);
      const double low = iLow(_Symbol, strategy_timeframe, shift);
      if(high <= 0.0 || low <= 0.0 || high <= low)
         return false;

      range_high = MathMax(range_high, high);
      range_low = MathMin(range_low, low);
     }

   if(range_high <= range_low)
      return false;

   range_width = range_high - range_low;
   return (range_width > 0.0);
  }

bool Strategy_FindLatestNarrowestRange(double &range_high, double &range_low, double &range_width)
  {
   range_high = 0.0;
   range_low = 0.0;
   range_width = 0.0;

   const int bars = MathMax(1, strategy_bars_in_range);
   const int checks = MathMax(1, strategy_check_period);
   if(Bars(_Symbol, strategy_timeframe) < bars + checks + 2)
      return false;

   double latest_high = 0.0;
   double latest_low = 0.0;
   double latest_width = 0.0;
   if(!Strategy_RangeBounds(1, bars, latest_high, latest_low, latest_width))
      return false;

   double narrowest_width = latest_width;
   int narrowest_shift = 1;
   for(int start_shift = 2; start_shift <= checks; ++start_shift)
     {
      double candidate_high = 0.0;
      double candidate_low = 0.0;
      double candidate_width = 0.0;
      if(!Strategy_RangeBounds(start_shift, bars, candidate_high, candidate_low, candidate_width))
         return false;

      if(candidate_width < narrowest_width)
        {
         narrowest_width = candidate_width;
         narrowest_shift = start_shift;
        }
     }

   if(narrowest_shift != 1)
      return false;

   range_high = latest_high;
   range_low = latest_low;
   range_width = latest_width;
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
   req.expiration_seconds = 0;
  }

bool Strategy_BuildStopRequest(const QM_OrderType type,
                               const double entry,
                               const double opposite_boundary,
                               const double range_width,
                               const double fallback_sl_distance,
                               QM_EntryRequest &req)
  {
   Strategy_InitRequest(req);
   req.type = type;
   req.price = QM_TM_NormalizePrice(_Symbol, entry);

   const bool is_buy = (type == QM_BUY_STOP);
   double sl = opposite_boundary;
   if(is_buy && sl >= req.price)
      sl = req.price - fallback_sl_distance;
   if(!is_buy && sl <= req.price)
      sl = req.price + fallback_sl_distance;

   req.sl = QM_TM_NormalizePrice(_Symbol, sl);
   req.tp = QM_TM_NormalizePrice(_Symbol,
                                 is_buy ? (req.price + strategy_tp_range_mult * range_width)
                                        : (req.price - strategy_tp_range_mult * range_width));
   req.reason = is_buy ? "QM5_10600_NARROWRNG_BUY_STOP" : "QM5_10600_NARROWRNG_SELL_STOP";

   if(req.price <= 0.0 || req.sl <= 0.0 || req.tp <= 0.0)
      return false;
   if(is_buy && (req.sl >= req.price || req.tp <= req.price))
      return false;
   if(!is_buy && (req.sl <= req.price || req.tp >= req.price))
      return false;

   return true;
  }

// No Trade Filter: time, spread, news.
bool Strategy_NoTradeFilter()
  {
   if(_Period != strategy_timeframe)
      return true;
   if(strategy_bars_in_range < 1 || strategy_check_period < 1)
      return true;
   if(strategy_order_indent_points < 0 || strategy_tp_range_mult <= 0.0)
      return true;
   if(strategy_atr_period < 1 || strategy_catastrophic_atr_mult <= 0.0)
      return true;

   return !Strategy_CurrentSpreadOK();
  }

// Trade Entry: place the narrow-range buy-stop/sell-stop bracket.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   Strategy_InitRequest(req);

   if(Strategy_HasOpenPosition())
      return false;

   double range_high = 0.0;
   double range_low = 0.0;
   double range_width = 0.0;
   if(!Strategy_FindLatestNarrowestRange(range_high, range_low, range_width))
      return false;

   if(g_strategy_has_active_range &&
      MathAbs(range_high - g_strategy_active_range_high) < _Point * 0.5 &&
      MathAbs(range_low - g_strategy_active_range_low) < _Point * 0.5 &&
      Strategy_PendingStopCount() > 0)
      return false;

   Strategy_RemovePendingStops("new_narrowest_range_signal");

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   const double fallback_sl_distance = (atr > 0.0) ? strategy_catastrophic_atr_mult * atr : range_width;
   const double indent = (double)strategy_order_indent_points * point;

   const double buy_entry = range_high + indent;
   const double sell_entry = range_low - indent;
   if(buy_entry <= 0.0 || sell_entry <= 0.0 || buy_entry <= sell_entry)
      return false;

   QM_EntryRequest buy_req;
   QM_EntryRequest sell_req;
   if(!Strategy_BuildStopRequest(QM_BUY_STOP, buy_entry, range_low, range_width, fallback_sl_distance, buy_req))
      return false;
   if(!Strategy_BuildStopRequest(QM_SELL_STOP, sell_entry, range_high, range_width, fallback_sl_distance, sell_req))
      return false;

   ulong buy_ticket = 0;
   if(!QM_TM_OpenPosition(buy_req, buy_ticket))
      return false;

   ulong sell_ticket = 0;
   if(!QM_TM_OpenPosition(sell_req, sell_ticket))
     {
      Strategy_RemovePendingStops("bracket_pair_incomplete");
      return false;
     }

   g_strategy_active_range_high = range_high;
   g_strategy_active_range_low = range_low;
   g_strategy_has_active_range = true;
   return false;
  }

// Trade Management: cancel the untriggered side after one stop order fills.
void Strategy_ManageOpenPosition()
  {
   if(Strategy_HasOpenPosition())
      Strategy_RemovePendingStops("opposite_order_after_fill");
  }

// Trade Close: exits are broker SL/TP plus framework Friday close.
bool Strategy_ExitSignal()
  {
   return false;
  }

// News Filter Hook: central FW1 news filter handles configured blackout mode.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10600\",\"ea\":\"mql5-narrowrng\"}");
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

   if(!QM_IsNewBar(_Symbol, strategy_timeframe))
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
