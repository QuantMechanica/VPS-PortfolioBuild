#property strict
#property version   "5.0"
#property description "QM5_10932 Grimes Volatility Shock Bracket"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10932;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_timeframe          = PERIOD_D1;
input int             strategy_return_std_period  = 20;
input int             strategy_atr_period         = 20;
input double          strategy_z_threshold        = 2.0;
input double          strategy_tr_atr_mult        = 1.5;
input double          strategy_entry_buffer_atr   = 0.10;
input double          strategy_stop_buffer_atr    = 0.10;
input double          strategy_target_r_mult      = 1.50;
input double          strategy_breakeven_r        = 1.00;
input int             strategy_pending_bars       = 2;
input int             strategy_max_hold_bars      = 5;
input int             strategy_trade_cooldown_bars = 10;
input double          strategy_max_stop_atr_mult  = 4.50;
input double          strategy_spread_stop_fraction = 0.08;

ulong    g_active_ticket = 0;
double   g_active_entry = 0.0;
double   g_active_initial_r = 0.0;
double   g_active_midpoint = 0.0;
bool     g_active_is_long = false;
bool     g_active_be_done = false;
bool     g_exit_due = false;

bool Strategy_IsPendingStopType(const ENUM_ORDER_TYPE order_type)
  {
   return (order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_SELL_STOP);
  }

bool Strategy_SelectPosition(ulong &ticket,
                             ENUM_POSITION_TYPE &ptype,
                             double &open_price,
                             double &sl,
                             datetime &open_time)
  {
   ticket = 0;
   ptype = POSITION_TYPE_BUY;
   open_price = 0.0;
   sl = 0.0;
   open_time = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

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
      sl = PositionGetDouble(POSITION_SL);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }
   return false;
  }

bool Strategy_HasPendingStops()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(Strategy_IsPendingStopType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         return true;
     }
   return false;
  }

void Strategy_RemovePendingStops(const string reason)
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(!Strategy_IsPendingStopType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         continue;
      QM_TM_RemovePendingOrder(ticket, reason);
     }
  }

void Strategy_RemoveExpiredPendingStops()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || strategy_pending_bars <= 0)
      return;

   const int expiry_seconds = strategy_pending_bars * PeriodSeconds(strategy_timeframe);
   if(expiry_seconds <= 0)
      return;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(!Strategy_IsPendingStopType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         continue;

      const datetime setup_time = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
      if(setup_time > 0 && TimeCurrent() - setup_time >= expiry_seconds)
         QM_TM_RemovePendingOrder(ticket, "volshock_pending_expired");
     }
  }

void Strategy_ResetPositionTracking()
  {
   g_active_ticket = 0;
   g_active_entry = 0.0;
   g_active_initial_r = 0.0;
   g_active_is_long = false;
   g_active_be_done = false;
  }

void Strategy_EnsurePositionTracking(const ulong ticket,
                                     const ENUM_POSITION_TYPE ptype,
                                     const double open_price,
                                     const double sl)
  {
   if(ticket == g_active_ticket)
      return;

   g_active_ticket = ticket;
   g_active_entry = open_price;
   g_active_initial_r = MathAbs(open_price - sl);
   g_active_is_long = (ptype == POSITION_TYPE_BUY);
   g_active_be_done = false;
  }

double Strategy_TrueRange(const MqlRates &rates[], const int idx)
  {
   const double hl = rates[idx].high - rates[idx].low;
   const double hc = MathAbs(rates[idx].high - rates[idx + 1].close);
   const double lc = MathAbs(rates[idx].low - rates[idx + 1].close);
   return MathMax(hl, MathMax(hc, lc));
  }

bool Strategy_ReturnShock(const MqlRates &rates[], const double atr, double &z_return)
  {
   z_return = 0.0;
   if(strategy_return_std_period < 2 || atr <= 0.0)
      return false;

   double sum = 0.0;
   double sum_sq = 0.0;
   for(int i = 1; i <= strategy_return_std_period; ++i)
     {
      const double r = rates[i].close - rates[i + 1].close;
      sum += r;
      sum_sq += r * r;
     }

   const double mean = sum / strategy_return_std_period;
   double variance = (sum_sq / strategy_return_std_period) - mean * mean;
   if(variance < 0.0 && variance > -1e-12)
      variance = 0.0;
   if(variance <= 0.0)
      return false;

   const double last_return = rates[0].close - rates[1].close;
   z_return = MathAbs(last_return) / MathSqrt(variance);
   const double tr = Strategy_TrueRange(rates, 0);
   return (z_return >= strategy_z_threshold && tr >= strategy_tr_atr_mult * atr);
  }

bool Strategy_HasRecentFilledTrade(const datetime since_time)
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || since_time <= 0)
      return false;
   if(!HistorySelect(since_time, TimeCurrent()))
      return false;

   const int deals = HistoryDealsTotal();
   for(int i = deals - 1; i >= 0; --i)
     {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;
      if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol)
         continue;
      if((int)HistoryDealGetInteger(deal, DEAL_MAGIC) != magic)
         continue;
      if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY) == DEAL_ENTRY_IN)
         return true;
     }
   return false;
  }

void Strategy_UpdateExitStateOnClosedBar(const MqlRates &rates[])
  {
   g_exit_due = false;

   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   double open_price, sl;
   datetime open_time;
   if(!Strategy_SelectPosition(ticket, ptype, open_price, sl, open_time))
      return;

   Strategy_EnsurePositionTracking(ticket, ptype, open_price, sl);

   if(strategy_max_hold_bars > 0 && open_time > 0)
     {
      const int hold_seconds = strategy_max_hold_bars * PeriodSeconds(strategy_timeframe);
      if(hold_seconds > 0 && TimeCurrent() - open_time >= hold_seconds)
        {
         g_exit_due = true;
         return;
        }
     }

   if(g_active_midpoint <= 0.0)
      return;

   if(ptype == POSITION_TYPE_BUY && rates[0].close < g_active_midpoint)
      g_exit_due = true;
   if(ptype == POSITION_TYPE_SELL && rates[0].close > g_active_midpoint)
      g_exit_due = true;
  }

bool Strategy_BuildStopRequest(const QM_OrderType type,
                               const double entry,
                               const double sl,
                               const double tp,
                               const int expiration_seconds,
                               const string reason,
                               QM_EntryRequest &req)
  {
   req.type = type;
   req.price = NormalizeDouble(entry, _Digits);
   req.sl = NormalizeDouble(sl, _Digits);
   req.tp = NormalizeDouble(tp, _Digits);
   req.reason = reason;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = expiration_seconds;

   if(req.price <= 0.0 || req.sl <= 0.0 || req.tp <= 0.0)
      return false;
   if(type == QM_BUY_STOP && (req.sl >= req.price || req.tp <= req.price))
      return false;
   if(type == QM_SELL_STOP && (req.sl <= req.price || req.tp >= req.price))
      return false;
   return true;
  }

// No Trade Filter (time, spread, news). Central news and Friday-close guards run
// before this hook; spread is evaluated against candidate stop distance in entry.
bool Strategy_NoTradeFilter()
  {
   if(strategy_timeframe != PERIOD_D1)
      return true;
   if(strategy_return_std_period < 2 ||
      strategy_atr_period < 2 ||
      strategy_z_threshold <= 0.0 ||
      strategy_tr_atr_mult <= 0.0 ||
      strategy_entry_buffer_atr < 0.0 ||
      strategy_stop_buffer_atr < 0.0 ||
      strategy_target_r_mult <= 0.0 ||
      strategy_breakeven_r <= 0.0 ||
      strategy_pending_bars < 1 ||
      strategy_max_hold_bars < 1 ||
      strategy_trade_cooldown_bars < 1 ||
      strategy_max_stop_atr_mult <= 0.0 ||
      strategy_spread_stop_fraction <= 0.0)
      return true;
   return false;
  }

// Trade Entry: D1 volatility-shock stop-entry bracket. One peer order is
// submitted inside the hook because the framework hook returns one request.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const int needed = MathMax(strategy_return_std_period + 2, strategy_trade_cooldown_bars + 1);
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, strategy_timeframe, 1, needed, rates); // perf-allowed: bounded D1 shock/cooldown window, caller is QM_IsNewBar-gated.
   if(copied < needed)
      return false;
   ArraySetAsSeries(rates, true);

   Strategy_UpdateExitStateOnClosedBar(rates);
   Strategy_RemoveExpiredPendingStops();

   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   double open_price, current_sl;
   datetime open_time;
   if(Strategy_SelectPosition(ticket, ptype, open_price, current_sl, open_time))
      return false;
   Strategy_ResetPositionTracking();

   if(Strategy_HasPendingStops())
      return false;
   if(Strategy_HasRecentFilledTrade(rates[strategy_trade_cooldown_bars].time))
      return false;

   const double atr = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   double z_return = 0.0;
   if(!Strategy_ReturnShock(rates, atr, z_return))
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask < bid)
      return false;

   const double buy_entry = rates[0].high + strategy_entry_buffer_atr * atr;
   const double sell_entry = rates[0].low - strategy_entry_buffer_atr * atr;
   const double buy_sl = rates[0].low - strategy_stop_buffer_atr * atr;
   const double sell_sl = rates[0].high + strategy_stop_buffer_atr * atr;
   const double buy_r = buy_entry - buy_sl;
   const double sell_r = sell_sl - sell_entry;
   if(buy_r <= 0.0 || sell_r <= 0.0)
      return false;
   if(buy_r > strategy_max_stop_atr_mult * atr || sell_r > strategy_max_stop_atr_mult * atr)
      return false;

   const double spread = ask - bid;
   if(spread > strategy_spread_stop_fraction * MathMin(buy_r, sell_r))
      return false;
   if(buy_entry <= ask || sell_entry >= bid)
      return false;

   const int expiry_seconds = strategy_pending_bars * PeriodSeconds(strategy_timeframe);
   if(expiry_seconds <= 0)
      return false;

   const double buy_tp = buy_entry + strategy_target_r_mult * buy_r;
   const double sell_tp = sell_entry - strategy_target_r_mult * sell_r;
   QM_EntryRequest buy_req;
   if(!Strategy_BuildStopRequest(QM_BUY_STOP, buy_entry, buy_sl, buy_tp, expiry_seconds, "grimes_volshock_buy_stop", buy_req))
      return false;
   if(!Strategy_BuildStopRequest(QM_SELL_STOP, sell_entry, sell_sl, sell_tp, expiry_seconds, "grimes_volshock_sell_stop", req))
      return false;

   g_active_midpoint = 0.5 * (rates[0].high + rates[0].low);

   ulong buy_ticket = 0;
   return QM_TM_OpenPosition(buy_req, buy_ticket);
  }

// Trade Management: OCO cancellation and breakeven at 1R.
void Strategy_ManageOpenPosition()
  {
   Strategy_RemoveExpiredPendingStops();

   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   double open_price, sl;
   datetime open_time;
   if(!Strategy_SelectPosition(ticket, ptype, open_price, sl, open_time))
     {
      Strategy_ResetPositionTracking();
      return;
     }

   Strategy_RemovePendingStops("volshock_oco_peer_cancel");
   Strategy_EnsurePositionTracking(ticket, ptype, open_price, sl);
   if(g_active_initial_r <= 0.0 || strategy_breakeven_r <= 0.0)
      return;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(bid <= 0.0 || ask <= 0.0 || point <= 0.0)
      return;

   const double exit_price = g_active_is_long ? bid : ask;
   const double moved = g_active_is_long ? (exit_price - g_active_entry)
                                         : (g_active_entry - exit_price);
   if(moved < strategy_breakeven_r * g_active_initial_r || g_active_be_done)
      return;

   const double be = NormalizeDouble(g_active_entry, _Digits);
   const bool improves = (sl <= 0.0) ||
                         (g_active_is_long ? (be > sl + point * 0.5)
                                           : (be < sl - point * 0.5));
   if(improves && QM_TM_MoveSL(ticket, be, "volshock_breakeven_1r"))
      g_active_be_done = true;
  }

// Trade Close: max hold or adverse close through the shock midpoint.
bool Strategy_ExitSignal()
  {
   if(!g_exit_due)
      return false;

   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   double open_price, sl;
   datetime open_time;
   if(!Strategy_SelectPosition(ticket, ptype, open_price, sl, open_time))
     {
      g_exit_due = false;
      return false;
     }
   return true;
  }

// News Filter Hook (callable for P8/P9 news-impact phases). No custom news
// override beyond the central V5 two-axis news filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line unless you know why.
// -----------------------------------------------------------------------------

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_10932_grimes-volshock\"}");
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
