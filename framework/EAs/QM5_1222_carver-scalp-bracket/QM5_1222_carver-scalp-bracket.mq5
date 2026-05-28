#property strict
#property version   "5.0"
#property description "QM5_1222 Carver Intraday Range Bracket Scalper"

#include <QM/QM_Common.mqh>
#include <Trade/Trade.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1222;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours     = 336;
input string qm_news_min_impact          = "high";
input QM_NewsMode qm_news_mode_legacy    = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_signal_tf       = PERIOD_M1;
input int             strategy_session_start_h = 16;
input int             strategy_session_start_m = 30;
input int             strategy_soft_close_h    = 22;
input int             strategy_soft_close_m    = 30;
input int             strategy_hard_close_h    = 22;
input int             strategy_hard_close_m    = 55;
input int             strategy_warmup_minutes  = 30;
input int             strategy_horizon_seconds = 900;
input double          strategy_entry_f         = 0.75;
input double          strategy_stop_k          = 0.87;
input double          strategy_max_spread_r    = 0.20;
input int             strategy_min_stop_ticks  = 10;
input int             strategy_slippage_points = 20;

#define QM5_1222_SYMBOL_COUNT 3

const string STRATEGY_SYMBOLS[QM5_1222_SYMBOL_COUNT] = {"SP500.DWX", "NDX.DWX", "WS30.DWX"};

CTrade  g_trade;
int     g_last_setup_bar_key = 0;
int     g_last_flat_cleanup_key = 0;

int Strategy_CurrentSymbolSlot()
  {
   for(int i = 0; i < QM5_1222_SYMBOL_COUNT; ++i)
      if(_Symbol == STRATEGY_SYMBOLS[i])
         return qm_magic_slot_offset + i;
   return -1;
  }

int Strategy_DateKey(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

int Strategy_MinutesOfDay(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.hour * 60 + dt.min;
  }

int Strategy_BarKey(const datetime value)
  {
   return Strategy_DateKey(value) * 10000 + Strategy_MinutesOfDay(value);
  }

int Strategy_SessionStartMinute()
  {
   return strategy_session_start_h * 60 + strategy_session_start_m;
  }

int Strategy_SoftCloseMinute()
  {
   return strategy_soft_close_h * 60 + strategy_soft_close_m;
  }

int Strategy_HardCloseMinute()
  {
   return strategy_hard_close_h * 60 + strategy_hard_close_m;
  }

bool Strategy_IsEntryWindow(const datetime broker_time)
  {
   const int minute = Strategy_MinutesOfDay(broker_time);
   const int start_minute = Strategy_SessionStartMinute() + MathMax(strategy_warmup_minutes, 0);
   return (minute >= start_minute && minute < Strategy_SoftCloseMinute());
  }

bool Strategy_IsHardClose(const datetime broker_time)
  {
   return (Strategy_MinutesOfDay(broker_time) >= Strategy_HardCloseMinute());
  }

int Strategy_Magic()
  {
   const int slot = Strategy_CurrentSymbolSlot();
   if(slot < 0)
      return 0;
   return QM_Magic(qm_ea_id, slot);
  }

double Strategy_TickSize()
  {
   double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick_size <= 0.0)
      tick_size = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   return tick_size;
  }

double Strategy_RoundToTick(const double price)
  {
   const double tick_size = Strategy_TickSize();
   if(price <= 0.0 || tick_size <= 0.0)
      return 0.0;
   return NormalizeDouble(MathRound(price / tick_size) * tick_size, _Digits);
  }

bool Strategy_HasOpenPosition(ulong &ticket, ENUM_POSITION_TYPE &type)
  {
   ticket = 0;
   type = POSITION_TYPE_BUY;

   const int magic = Strategy_Magic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong pos_ticket = PositionGetTicket(i);
      if(pos_ticket == 0 || !PositionSelectByTicket(pos_ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = pos_ticket;
      type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }

   return false;
  }

bool Strategy_IsBracketOrderType(const ENUM_ORDER_TYPE type)
  {
   return (type == ORDER_TYPE_BUY_LIMIT || type == ORDER_TYPE_SELL_LIMIT);
  }

int Strategy_PendingOrderCount()
  {
   int count = 0;
   const int magic = Strategy_Magic();
   if(magic <= 0)
      return 0;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(Strategy_IsBracketOrderType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         ++count;
     }
   return count;
  }

bool Strategy_CancelPendingOrders()
  {
   bool ok = true;
   const int magic = Strategy_Magic();
   if(magic <= 0)
      return false;

   g_trade.SetExpertMagicNumber(magic);
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(!Strategy_IsBracketOrderType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         continue;
      if(!g_trade.OrderDelete(ticket))
         ok = false;
     }

   return ok;
  }

bool Strategy_RangeWindow(double &range_price)
  {
   range_price = 0.0;
   const int tf_seconds = PeriodSeconds(strategy_signal_tf);
   if(tf_seconds <= 0 || strategy_horizon_seconds <= 0)
      return false;

   const int bars_needed = MathMax(1, (int)MathCeil((double)strategy_horizon_seconds / (double)tf_seconds));
   if(Bars(_Symbol, strategy_signal_tf) <= bars_needed + 2)
      return false;

   double high = -DBL_MAX;
   double low = DBL_MAX;
   for(int shift = 1; shift <= bars_needed; ++shift)
     {
      const double h = iHigh(_Symbol, strategy_signal_tf, shift);
      const double l = iLow(_Symbol, strategy_signal_tf, shift);
      if(h <= 0.0 || l <= 0.0 || h < l)
         return false;
      high = MathMax(high, h);
      low = MathMin(low, l);
     }

   range_price = high - low;
   return (range_price > 0.0);
  }

bool Strategy_SpreadOk(const double range_price)
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || range_price <= 0.0)
      return false;
   return ((ask - bid) <= strategy_max_spread_r * range_price);
  }

double Strategy_DailyNetProfit()
  {
   const datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   const datetime start = StructToTime(dt);
   if(!HistorySelect(start, now))
      return 0.0;

   double total = 0.0;
   const int magic = Strategy_Magic();
   for(int i = HistoryDealsTotal() - 1; i >= 0; --i)
     {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;
      if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol)
         continue;
      if((int)HistoryDealGetInteger(deal, DEAL_MAGIC) != magic)
         continue;
      const ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_INOUT)
         continue;
      total += HistoryDealGetDouble(deal, DEAL_PROFIT);
      total += HistoryDealGetDouble(deal, DEAL_SWAP);
      total += HistoryDealGetDouble(deal, DEAL_COMMISSION);
     }
   return total;
  }

bool Strategy_DailyLossLimitHit()
  {
   if(RISK_FIXED <= 0.0)
      return false;
   return (Strategy_DailyNetProfit() <= -3.0 * RISK_FIXED);
  }

bool Strategy_NoTradeFilter()
  {
   if(Strategy_CurrentSymbolSlot() < 0)
      return true;
   if(strategy_signal_tf == PERIOD_D1)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "carver_scalp_bracket";
   req.symbol_slot = Strategy_CurrentSymbolSlot();
   req.expiration_seconds = 0;
   return false;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

bool Strategy_PlaceBracket()
  {
   const int magic = Strategy_Magic();
   if(magic <= 0 || Strategy_DailyLossLimitHit())
      return false;

   double range_price = 0.0;
   if(!Strategy_RangeWindow(range_price))
      return false;
   if(!Strategy_SpreadOk(range_price))
      return false;

   const double tick_size = Strategy_TickSize();
   if(tick_size <= 0.0 || strategy_stop_k <= strategy_entry_f || strategy_entry_f <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double mid = 0.5 * (ask + bid);
   const double half_range = 0.5 * range_price;
   const double buy_price = Strategy_RoundToTick(mid - half_range * strategy_entry_f);
   const double sell_price = Strategy_RoundToTick(mid + half_range * strategy_entry_f);
   const double long_stop = Strategy_RoundToTick(mid - half_range * strategy_stop_k);
   const double short_stop = Strategy_RoundToTick(mid + half_range * strategy_stop_k);
   if(buy_price <= 0.0 || sell_price <= 0.0 || long_stop <= 0.0 || short_stop <= 0.0)
      return false;
   if(!(long_stop < buy_price && buy_price < sell_price && sell_price < short_stop))
      return false;

   const double stop_distance = MathAbs(buy_price - long_stop);
   if(stop_distance < MathMax(strategy_min_stop_ticks, 1) * tick_size)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;

   const double lots = QM_LotsForRisk(_Symbol, stop_distance / point);
   if(lots <= 0.0)
      return false;

   g_trade.SetExpertMagicNumber(magic);
   g_trade.SetDeviationInPoints(strategy_slippage_points);

   const bool buy_ok = g_trade.BuyLimit(lots, buy_price, _Symbol, long_stop, 0.0, ORDER_TIME_GTC, 0, "carver_bracket_buy");
   if(!buy_ok)
      return false;

   const bool sell_ok = g_trade.SellLimit(lots, sell_price, _Symbol, short_stop, 0.0, ORDER_TIME_GTC, 0, "carver_bracket_sell");
   if(!sell_ok)
     {
      Strategy_CancelPendingOrders();
      return false;
     }

   return true;
  }

void Strategy_HardClose()
  {
   Strategy_CancelPendingOrders();

   const int magic = Strategy_Magic();
   if(magic <= 0)
      return;

   g_trade.SetExpertMagicNumber(magic);
   g_trade.SetDeviationInPoints(strategy_slippage_points);
   for(int i = PositionsTotal() - 1; i >= 0; --i)
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

   string symbols[QM5_1222_SYMBOL_COUNT] = {"SP500.DWX", "NDX.DWX", "WS30.DWX"};
   QM_SymbolGuardInit(symbols);
   QM_BasketWarmupHistory(symbols, strategy_signal_tf, MathMax(200, strategy_horizon_seconds / MathMax(PeriodSeconds(strategy_signal_tf), 60) + 50));

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1222_carver-scalp-bracket\"}");
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

   if(Strategy_IsHardClose(broker_now))
     {
      Strategy_HardClose();
      return;
     }

   Strategy_ManageOpenPosition();

   ulong ticket = 0;
   ENUM_POSITION_TYPE type = POSITION_TYPE_BUY;
   const bool has_position = Strategy_HasOpenPosition(ticket, type);
   const int pending_count = Strategy_PendingOrderCount();

   if(!has_position && pending_count == 1)
     {
      const int cleanup_key = Strategy_BarKey(broker_now);
      if(cleanup_key != g_last_flat_cleanup_key)
        {
         Strategy_CancelPendingOrders();
         g_last_flat_cleanup_key = cleanup_key;
        }
     }

   if(!QM_IsNewBar(_Symbol, strategy_signal_tf))
      return;

   QM_EquityStreamOnNewBar();
   if(!Strategy_IsEntryWindow(broker_now))
      return;

   if(has_position || Strategy_PendingOrderCount() > 0)
      return;

   const datetime bar_time = iTime(_Symbol, strategy_signal_tf, 1);
   const int bar_key = Strategy_BarKey(bar_time);
   if(bar_key <= 0 || bar_key == g_last_setup_bar_key)
      return;

   if(Strategy_PlaceBracket())
      g_last_setup_bar_key = bar_key;
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
