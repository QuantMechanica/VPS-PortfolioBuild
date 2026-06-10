#property strict
#property version   "5.0"
#property description "QuantMechanica V5 — Asian Session Breakout"

#include <QM/QM_Common.mqh>
#include <QM/QM_Signals.mqh>

// =============================================================================
// QM5_9190 — Asian Session Breakout
// -----------------------------------------------------------------------------
// Session box 23:00–03:00 UTC (defaults: 01:00–05:00 broker at UTC+2).
// After box closes: buy-stop above box high or sell-stop below box low,
// depending on MA(50) trend. SL at opposite box edge. TP = entry ± risk×RR.
// All pending orders are cancelled and open positions closed at exit_hour.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9190;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
// FW1 2026-05-23 — Two-axis news filter per Vault Q09.
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
input int    strategy_ma_period            = 50;   // SMA trend-filter period
input int    strategy_asian_start_hour     = 1;    // Asian box start (broker hour; UTC+2 = 23:00 UTC)
input int    strategy_asian_end_hour       = 5;    // Asian box end   (broker hour; UTC+2 = 03:00 UTC)
input int    strategy_exit_hour            = 22;   // Cancel pending + close positions (broker hour)
input int    strategy_breakout_offset_pips = 5;    // Buffer pips outside box for stop entry
input double strategy_rr_ratio             = 2.0;  // TP = (entry–SL distance) × rr_ratio
input int    strategy_max_spread_pips      = 3;    // Spread gate (0 = disabled)

// -----------------------------------------------------------------------------
// File-scope cached state — advanced once per closed bar
// -----------------------------------------------------------------------------
double   g_box_high = 0.0;
double   g_box_low  = DBL_MAX;
datetime g_box_day  = 0;     // Calendar midnight of the trading day for which box is cached

// -----------------------------------------------------------------------------
// Internal helpers
// -----------------------------------------------------------------------------

double Strategy_PipDistance(const double pips)
  {
   if(pips <= 0.0)
      return 0.0;
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return 0.0;
   const int digits     = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const int pip_factor = (digits == 3 || digits == 5) ? 10 : 1;
   return pips * point * pip_factor;
  }

double Strategy_SpreadPips()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask <= bid)
      return DBL_MAX;
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return DBL_MAX;
   const int digits     = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const int pip_factor = (digits == 3 || digits == 5) ? 10 : 1;
   return (ask - bid) / (point * pip_factor);
  }

datetime Strategy_CalendarDay(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   dt.hour = 0; dt.min = 0; dt.sec = 0;
   return StructToTime(dt);
  }

// Determines whether a bar opening at bar_time falls within the Asian session
// window [strategy_asian_start_hour, strategy_asian_end_hour).
// Handles the overnight wrap (e.g. 01:00–05:00 or 23:00–03:00).
bool Strategy_InAsianSession(const datetime bar_time)
  {
   MqlDateTime dt;
   TimeToStruct(bar_time, dt);
   const int h = dt.hour;
   if(strategy_asian_start_hour < strategy_asian_end_hour)
      return (h >= strategy_asian_start_hour && h < strategy_asian_end_hour);
   // Wraps midnight: e.g. 23 <= h OR h < 3
   return (h >= strategy_asian_start_hour || h < strategy_asian_end_hour);
  }

// Computes and caches the Asian session box for today's trading day.
// "Today" = the calendar day whose strategy_asian_end_hour already passed.
// Called once per new closed bar; early-exits if already done for this day.
void Strategy_ComputeBox(const datetime broker_now)
  {
   const datetime today = Strategy_CalendarDay(broker_now);
   if(today == g_box_day)
      return;

   double box_h = -DBL_MAX;  // perf-allowed: bespoke session-box scan
   double box_l =  DBL_MAX;
   int    found = 0;

   // Scan up to 96 M15 bars back (24 hours); session is ≤ 16 bars at M15.
   for(int i = 1; i <= 96; ++i)
     {
      const datetime bar_time = iTime(_Symbol, PERIOD_CURRENT, i);  // perf-allowed
      if(bar_time <= 0)
         break;

      if(!Strategy_InAsianSession(bar_time))
         continue;

      // Restrict to bars belonging to the MOST RECENT completed session.
      // For an overnight window (e.g. 23:00–05:00) the bar may be from
      // yesterday's calendar day — allow both today and yesterday.
      const datetime bar_date = Strategy_CalendarDay(bar_time);
      if(bar_date != today && bar_date != (today - 86400))
         continue;
      const double h = iHigh(_Symbol, PERIOD_CURRENT, i);  // perf-allowed
      const double l = iLow(_Symbol, PERIOD_CURRENT, i);   // perf-allowed
      if(h > 0.0 && l > 0.0 && h >= l)
        {
         if(h > box_h)
            box_h = h;
         if(l < box_l)
            box_l = l;
         ++found;
        }
     }

   if(found >= 4 && box_h > box_l && box_h > 0.0)
     {
      g_box_high = box_h;
      g_box_low  = box_l;
      g_box_day  = today;
     }
  }

bool Strategy_BoxValid()
  {
   return (g_box_high > 0.0 && g_box_low > 0.0 && g_box_high > g_box_low);
  }

bool Strategy_IsInTradingWindow(const datetime broker_now)
  {
   MqlDateTime dt;
   TimeToStruct(broker_now, dt);
   return (dt.hour >= strategy_asian_end_hour && dt.hour < strategy_exit_hour);
  }

bool Strategy_IsAtExitTime(const datetime broker_now)
  {
   MqlDateTime dt;
   TimeToStruct(broker_now, dt);
   return (dt.hour >= strategy_exit_hour);
  }

bool Strategy_HasOurPendingOrder()
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
      const ENUM_ORDER_TYPE ot = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(ot == ORDER_TYPE_BUY_STOP || ot == ORDER_TYPE_SELL_STOP)
         return true;
     }
   return false;
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

// Cancel all our pending stop orders (called at exit hour or on new box day).
void Strategy_CancelOurPendingOrders(const string reason)
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
      const ENUM_ORDER_TYPE ot = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(ot == ORDER_TYPE_BUY_STOP || ot == ORDER_TYPE_SELL_STOP)
         QM_TM_RemovePendingOrder(ticket, reason);
     }
  }

// -----------------------------------------------------------------------------
// Strategy hooks — No Trade Filter
// -----------------------------------------------------------------------------
bool Strategy_NoTradeFilter()
  {
   if(strategy_max_spread_pips > 0 && Strategy_SpreadPips() > (double)strategy_max_spread_pips)
      return true;
   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — Trade Entry
// -----------------------------------------------------------------------------
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const datetime broker_now = TimeCurrent();

   if(!Strategy_IsInTradingWindow(broker_now))
      return false;

   Strategy_ComputeBox(broker_now);
   if(!Strategy_BoxValid())
      return false;

   if(Strategy_HasOurPendingOrder() || Strategy_HasOurOpenPosition())
      return false;

   // MA(50) trend filter: price must be clearly on one side of the MA.
   const int trend = QM_Sig_Price_Above_MA(_Symbol, PERIOD_CURRENT, strategy_ma_period, 0.0, 1);
   if(trend == 0)
      return false;

   const double offset = Strategy_PipDistance(strategy_breakout_offset_pips);
   if(offset <= 0.0)
      return false;

   double          entry_price;
   double          sl_price;
   QM_OrderType    order_type;

   if(trend > 0)
     {
      // Long setup: buy-stop above box high; SL below box low
      order_type  = QM_BUY_STOP;
      entry_price = QM_TM_NormalizePrice(_Symbol, g_box_high + offset);
      sl_price    = QM_TM_NormalizePrice(_Symbol, g_box_low  - offset);
     }
   else
     {
      // Short setup: sell-stop below box low; SL above box high
      order_type  = QM_SELL_STOP;
      entry_price = QM_TM_NormalizePrice(_Symbol, g_box_low  - offset);
      sl_price    = QM_TM_NormalizePrice(_Symbol, g_box_high + offset);
     }

   if(entry_price <= 0.0 || sl_price <= 0.0)
      return false;

   const double risk_dist = MathAbs(entry_price - sl_price);
   if(risk_dist <= 0.0)
      return false;

   double tp_price;
   if(trend > 0)
      tp_price = QM_TM_NormalizePrice(_Symbol, entry_price + risk_dist * strategy_rr_ratio);
   else
      tp_price = QM_TM_NormalizePrice(_Symbol, entry_price - risk_dist * strategy_rr_ratio);

   if(tp_price <= 0.0)
      return false;

   req.type               = order_type;
   req.price              = entry_price;
   req.sl                 = sl_price;
   req.tp                 = tp_price;
   req.reason             = (trend > 0) ? "ASIAN_BOX_BUY_STOP" : "ASIAN_BOX_SELL_STOP";
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;  // GTC — cancelled explicitly at exit_hour

   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — Trade Management
// -----------------------------------------------------------------------------
void Strategy_ManageOpenPosition()
  {
   const datetime broker_now = TimeCurrent();
   // Cancel any stale pending orders at exit time (even before a position is open).
   if(Strategy_IsAtExitTime(broker_now))
      Strategy_CancelOurPendingOrders("daily_exit_time");
  }

// -----------------------------------------------------------------------------
// Strategy hooks — Trade Close
// -----------------------------------------------------------------------------
bool Strategy_ExitSignal()
  {
   return Strategy_IsAtExitTime(TimeCurrent());
  }

// -----------------------------------------------------------------------------
// Strategy hooks — News Filter Hook
// -----------------------------------------------------------------------------
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;  // defer to QM_NewsAllowsTrade(...)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{}");
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
      return;
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
