#property strict
#property version   "5.0"
#property description "QM5_9300 MQL5 London Pre-Session Breakout (ba57d97a)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_9300 — MQL5 London Pre-Session Breakout
// Card: D:\QM\strategy_farm\artifacts\cards_approved\QM5_9300_mql5-london-break.md
// Source: ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb
//
// Each broker day, measures the 03:00–08:00 pre-London range. At the 08:00
// M15 bar, places a buy stop above the range high and a sell stop below the
// range low. When one fills, the opposing order is cancelled. Remaining
// unfilled orders are cancelled at the session expiry hour. One position
// per magic number at any time (MaxOpenTrades = 1).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 9300;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours     = 336;
input string qm_news_min_impact          = "high";
input QM_NewsMode qm_news_mode_legacy    = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_pre_london_start_hour  = 3;    // Range window start hour (broker time)
input int    strategy_pre_london_end_hour    = 8;    // London open hour — orders placed at this bar
input int    strategy_min_range_points       = 100;  // Min valid range width in points
input int    strategy_max_range_points       = 300;  // Max valid range width in points
input int    strategy_order_offset_points    = 10;   // Stop entry offset beyond range high/low
input int    strategy_stop_loss_points       = 500;  // SL distance in points from entry
input double strategy_rr_ratio               = 1.0;  // TP = SL × RR (1.0 = 1:1)
input int    strategy_session_expiry_hour    = 12;   // Cancel unfilled pending orders at this hour

// --- File-scope strategy state -------------------------------------------------
datetime g_setup_day      = 0;      // Broker-day start when orders were last placed
bool     g_pending_placed = false;  // True if we placed orders this session
ulong    g_buy_ticket     = 0;      // Ticket of the open buy-stop pending order
ulong    g_sell_ticket    = 0;      // Ticket of the open sell-stop pending order

// -------------------------------------------------------------------------------

datetime GetDayStart(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   dt.hour = 0;
   dt.min  = 0;
   dt.sec  = 0;
   return StructToTime(dt);
  }

// --- Trade Filter --------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   return false;
  }

// --- Entry Signal --------------------------------------------------------------
// Called once per new M15 bar (after QM_IsNewBar gate in OnTick).
// Places both the buy stop and sell stop directly via QM_TM_OpenPosition,
// then returns FALSE so the framework does not place a third order.

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Gate: only act on the exact London-open M15 bar (08:00 broker time)
   // perf-allowed: structural timing gate — single O(1) bar-time read
   const datetime bar_t = iTime(_Symbol, _Period, 0);
   if(bar_t <= 0)
      return false;

   MqlDateTime bar_dt;
   TimeToStruct(bar_t, bar_dt);
   if((int)bar_dt.hour != strategy_pre_london_end_hour || bar_dt.min != 0)
      return false;
   if(bar_dt.day_of_week == 0 || bar_dt.day_of_week == 6)
      return false;

   // One setup per broker day
   const datetime today_start = GetDayStart(bar_t);
   if(today_start == g_setup_day)
      return false;

   // Skip if already holding a position for this magic/symbol
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong tk = PositionGetTicket(i);
      if(tk == 0 || !PositionSelectByTicket(tk))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      return false;
     }

   // Scan pre-London M15 bars (03:00–07:45 broker time) to find range H/L
   // perf-allowed: bespoke time-window range scan — bounded at 40 bars, once per day per symbol
   const datetime range_start = today_start + (datetime)(strategy_pre_london_start_hour * 3600);
   const double   point       = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;

   double range_high = -DBL_MAX;
   double range_low  =  DBL_MAX;
   int    bars_found = 0;

   for(int i = 1; i <= 40; ++i)
     {
      const datetime bt = iTime(_Symbol, _Period, i);
      if(bt <= 0 || bt < range_start)
         break;
      if(bt >= bar_t)   // skip any bar at or after London open
         continue;
      const double hi = iHigh(_Symbol, _Period, i);
      const double lo = iLow(_Symbol, _Period, i);
      if(hi <= 0.0 || lo <= 0.0)
         continue;
      if(hi > range_high) range_high = hi;
      if(lo < range_low)  range_low  = lo;
      ++bars_found;
     }

   if(bars_found < 1 || range_high <= 0.0 || range_low >= DBL_MAX)
      return false;

   // Validate range width
   const double range_pts = (range_high - range_low) / point;
   if(range_pts < (double)strategy_min_range_points ||
      range_pts > (double)strategy_max_range_points)
      return false;

   // Compute order levels
   const double offset = strategy_order_offset_points * point;
   const double sl_pts = strategy_stop_loss_points * point;
   const double tp_pts = sl_pts * strategy_rr_ratio;

   const double buy_entry  = NormalizeDouble(range_high + offset, _Digits);
   const double sell_entry = NormalizeDouble(range_low  - offset, _Digits);

   // Place buy stop above the pre-London high
   QM_EntryRequest buy_req;
   buy_req.type               = QM_BUY_STOP;
   buy_req.price              = buy_entry;
   buy_req.sl                 = NormalizeDouble(buy_entry - sl_pts, _Digits);
   buy_req.tp                 = NormalizeDouble(buy_entry + tp_pts, _Digits);
   buy_req.reason             = "LDN_BREAK_BUY";
   buy_req.symbol_slot        = qm_magic_slot_offset;
   buy_req.expiration_seconds = 0;
   g_buy_ticket = 0;
   QM_TM_OpenPosition(buy_req, g_buy_ticket);

   // Place sell stop below the pre-London low
   // (QM_EntryHasOpenPosition checks positions, not pending orders — no duplicate reject)
   QM_EntryRequest sell_req;
   sell_req.type               = QM_SELL_STOP;
   sell_req.price              = sell_entry;
   sell_req.sl                 = NormalizeDouble(sell_entry + sl_pts, _Digits);
   sell_req.tp                 = NormalizeDouble(sell_entry - tp_pts, _Digits);
   sell_req.reason             = "LDN_BREAK_SELL";
   sell_req.symbol_slot        = qm_magic_slot_offset;
   sell_req.expiration_seconds = 0;
   g_sell_ticket = 0;
   QM_TM_OpenPosition(sell_req, g_sell_ticket);

   g_setup_day      = today_start;
   g_pending_placed = (g_buy_ticket > 0 || g_sell_ticket > 0);

   // Return false: both orders already placed above; prevent framework from placing another
   return false;
  }

// --- Trade Management ---------------------------------------------------------
// Called every tick (before new-bar gate). Cancels the opposing pending order
// once one side fills, and cancels all pending orders past the session expiry.

void Strategy_ManageOpenPosition()
  {
   if(!g_pending_placed && g_buy_ticket == 0 && g_sell_ticket == 0)
      return;

   const int      magic = QM_FrameworkMagic();
   const datetime now   = TimeCurrent();

   // Detect filled position to know which opposing order to cancel
   bool has_long  = false;
   bool has_short = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong tk = PositionGetTicket(i);
      if(tk == 0 || !PositionSelectByTicket(tk))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
         has_long  = true;
      else
         has_short = true;
     }

   // Long filled → cancel the sell stop
   if(has_long && g_sell_ticket > 0)
     {
      if(OrderSelect(g_sell_ticket))
         QM_TM_RemovePendingOrder(g_sell_ticket, "OPP_CANCEL_LONG");
      g_sell_ticket = 0;
     }
   // Short filled → cancel the buy stop
   if(has_short && g_buy_ticket > 0)
     {
      if(OrderSelect(g_buy_ticket))
         QM_TM_RemovePendingOrder(g_buy_ticket, "OPP_CANCEL_SHORT");
      g_buy_ticket = 0;
     }

   // No position: cancel remaining pending orders past session expiry hour
   if(!has_long && !has_short)
     {
      MqlDateTime dt;
      TimeToStruct(now, dt);
      if((int)dt.hour >= strategy_session_expiry_hour)
        {
         if(g_buy_ticket > 0)
           {
            if(OrderSelect(g_buy_ticket))
               QM_TM_RemovePendingOrder(g_buy_ticket, "SESSION_EXPIRY");
            g_buy_ticket = 0;
           }
         if(g_sell_ticket > 0)
           {
            if(OrderSelect(g_sell_ticket))
               QM_TM_RemovePendingOrder(g_sell_ticket, "SESSION_EXPIRY");
            g_sell_ticket = 0;
           }
         g_pending_placed = false;
        }
     }

   // Day rollover: clean up stale pending orders from a previous broker day
   if(g_setup_day > 0 && GetDayStart(now) > g_setup_day)
     {
      if(g_buy_ticket > 0)
        {
         if(OrderSelect(g_buy_ticket))
            QM_TM_RemovePendingOrder(g_buy_ticket, "DAY_ROLLOVER");
         g_buy_ticket = 0;
        }
      if(g_sell_ticket > 0)
        {
         if(OrderSelect(g_sell_ticket))
            QM_TM_RemovePendingOrder(g_sell_ticket, "DAY_ROLLOVER");
         g_sell_ticket = 0;
        }
      g_pending_placed = false;
     }
  }

// --- Exit Signal --------------------------------------------------------------

bool Strategy_ExitSignal()
  {
   return false; // Exits via SL/TP and framework Friday close only
  }

// --- News Filter Hook ---------------------------------------------------------

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // Defer to QM_NewsAllowsTrade2 in OnTick
  }

// =============================================================================
// Framework wiring — do NOT edit below this line
// =============================================================================

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_9300\",\"slug\":\"mql5-london-break\"}");
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
                        const MqlTradeRequest     &request,
                        const MqlTradeResult      &result)
  {
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
