#property strict
#property version   "5.0"
#property description "QM5_10096 GitHub EMA Pullback Stop Entry"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_10096 gh-ema-pullstop
// Source: Umair Khan Jadoon / umairkj, GitHub auto-trading-bot.mq5
// Card:   artifacts/cards_approved/QM5_10096_gh-ema-pullstop.md
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 10096;
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
input int    strategy_fast_ema_period    = 8;      // Source EMA fast line.
input int    strategy_slow_ema_period    = 21;     // Source EMA slow line.
input int    strategy_breakout_lookback  = 5;      // Highest close window for buy-stop entry.
input int    strategy_sl_buffer_points   = 3;      // Source 0.00003 converted to points.
input int    strategy_tp_points          = 100;    // Source 0.00100 converted to points.
input int    strategy_pending_expiry_bars = 10;    // Source-counted stale pending cleanup.

ulong g_pending_ticket = 0;
int   g_pending_bars   = 0;

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

double Strategy_NormalizePrice(const double price)
  {
   if(price <= 0.0)
      return 0.0;
   return NormalizeDouble(price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
  }

bool Strategy_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol)
         return true;
     }
   return false;
  }

bool Strategy_IsOurPendingBuyStop(const ulong ticket)
  {
   if(ticket == 0 || !OrderSelect(ticket))
      return false;
   if(OrderGetString(ORDER_SYMBOL) != _Symbol)
      return false;
   if((long)OrderGetInteger(ORDER_MAGIC) != QM_FrameworkMagic())
      return false;
   return ((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_STOP);
  }

bool Strategy_FindPendingBuyStop(ulong &ticket)
  {
   ticket = 0;
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong candidate = OrderGetTicket(i);
      if(candidate == 0)
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((long)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE) != ORDER_TYPE_BUY_STOP)
         continue;
      ticket = candidate;
      return true;
     }
   return false;
  }

bool Strategy_HasTrackedPending()
  {
   if(Strategy_IsOurPendingBuyStop(g_pending_ticket))
      return true;

   ulong ticket = 0;
   if(!Strategy_FindPendingBuyStop(ticket))
     {
      g_pending_ticket = 0;
      g_pending_bars = 0;
      return false;
     }

   if(g_pending_ticket != ticket)
     {
      g_pending_ticket = ticket;
      g_pending_bars = 0;
     }
   return true;
  }

void Strategy_CancelTrackedPending(const string reason)
  {
   if(g_pending_ticket != 0)
      QM_TM_RemovePendingOrder(g_pending_ticket, reason);
   g_pending_ticket = 0;
   g_pending_bars = 0;
  }

double Strategy_HighestClose(const int lookback)
  {
   if(lookback <= 0)
      return 0.0;

   double highest = -DBL_MAX;
   for(int shift = 1; shift <= lookback; ++shift)
     {
      const double close_price = iClose(_Symbol, _Period, shift); // perf-allowed: bounded 5-bar close scan for card breakout level.
      if(close_price <= 0.0)
         return 0.0;
      highest = MathMax(highest, close_price);
     }
   return highest;
  }

double Strategy_MinBuyStopEntry(const double ask)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || ask <= 0.0)
      return 0.0;

   const int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const double min_distance = (double)MathMax(stops_level, 0) * point;
   return ask + min_distance + point;
  }

bool Strategy_PlaceBuyStop(const double entry, const double sl, const double tp)
  {
   QM_EntryRequest req;
   req.type = QM_BUY_STOP;
   req.price = entry;
   req.sl = sl;
   req.tp = tp;
   req.reason = "EMA Buy Order";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   ulong ticket = 0;
   const bool ok = QM_TM_OpenPosition(req, ticket);
   if(ok && ticket > 0)
     {
      g_pending_ticket = ticket;
      g_pending_bars = 0;
     }
   return ok;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// No Trade Filter — no card-specific filter beyond framework news/Friday/kill-switch.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Trade Entry — long-only EMA 8/21 pullback into a buy stop.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(Strategy_HasTrackedPending())
     {
      g_pending_bars++;
      if(g_pending_bars >= strategy_pending_expiry_bars)
         Strategy_CancelTrackedPending("ema_pullstop_pending_expired");
      return false;
     }

   if(Strategy_HasOpenPosition())
      return false;

   if(strategy_fast_ema_period <= 0 ||
      strategy_slow_ema_period <= 0 ||
      strategy_breakout_lookback <= 0 ||
      strategy_sl_buffer_points <= 0 ||
      strategy_tp_points <= 0)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(point <= 0.0 || ask <= 0.0)
      return false;

   const double ema_fast = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_fast_ema_period, 1);
   const double ema_slow = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_slow_ema_period, 1);
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar pullback close from card.
   if(ema_fast <= 0.0 || ema_slow <= 0.0 || close1 <= 0.0)
      return false;

   if(!(ema_fast > ema_slow && close1 < ema_slow && close1 <= ema_fast))
      return false;

   double entry = Strategy_HighestClose(strategy_breakout_lookback);
   if(entry <= 0.0)
      return false;

   const double min_entry = Strategy_MinBuyStopEntry(ask);
   if(min_entry <= 0.0)
      return false;
   if(entry < min_entry)
      entry = min_entry;
   entry = Strategy_NormalizePrice(entry);

   double sl = Strategy_NormalizePrice(close1 - (double)strategy_sl_buffer_points * point);
   double tp = Strategy_NormalizePrice(entry + (double)strategy_tp_points * point);
   if(entry <= 0.0 || sl <= 0.0 || tp <= 0.0 || sl >= entry || tp <= entry)
      return false;

   const int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const double min_distance = (double)MathMax(stops_level, 0) * point;
   if(min_distance > 0.0)
     {
      if(entry - sl < min_distance)
         sl = Strategy_NormalizePrice(entry - min_distance - point);
      if(tp - entry < min_distance)
         tp = Strategy_NormalizePrice(entry + min_distance + point);
     }

   Strategy_PlaceBuyStop(entry, sl, tp);
   return false;
  }

// Trade Management — no card-authorized trailing, BE, partial, or TP modification.
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close — positions close through fixed SL/TP and framework Friday close.
bool Strategy_ExitSignal()
  {
   return false;
  }

// News Filter Hook — defer to framework two-axis news filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line
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
                        const MqlTradeRequest      &request,
                        const MqlTradeResult       &result)
  {
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
