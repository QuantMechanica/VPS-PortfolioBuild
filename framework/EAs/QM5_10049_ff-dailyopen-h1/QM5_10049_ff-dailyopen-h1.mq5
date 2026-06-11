#property strict
#property version   "5.0"
#property description "QM5_10049 ForexFactory First-Hour Daily-Open Direction"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA
// Source card: QM5_10049_ff-dailyopen-h1
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10049;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_daily_open_hour_broker = 0;
input int    strategy_daily_open_minute      = 0;
input int    strategy_stop_loss_pips         = 10;
input int    strategy_take_profit_pips       = 10;
input double strategy_max_spread_pips        = 2.0;
input int    strategy_time_stop_hour_broker  = 23;

// No Trade Filter (time, spread, news): spread is the only card-specific
// no-trade gate. Framework handles news, kill-switch, Friday close, and
// duplicate position protection.
bool Strategy_NoTradeFilter()
  {
   if(strategy_max_spread_pips <= 0.0)
      return false;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const double pip = (digits == 3 || digits == 5) ? point * 10.0 : point;
   if(pip <= 0.0 || point <= 0.0)
      return true;

   const int spread_points = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   const double spread_pips = ((double)spread_points * point) / pip;
   return (spread_pips > strategy_max_spread_pips);
  }

// Trade Entry: after the first H1 candle of the broker day closes, trade in
// the direction of that close relative to the current D1 open.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(_Period != PERIOD_H1)
      return false;
   if(strategy_stop_loss_pips <= 0 || strategy_take_profit_pips <= 0)
      return false;

   MqlDateTime now_dt;
   TimeToStruct(TimeCurrent(), now_dt);
   int time_stop_hour = strategy_time_stop_hour_broker;
   if(time_stop_hour < 0)
      time_stop_hour = 0;
   if(time_stop_hour > 23)
      time_stop_hour = 23;
   if(now_dt.hour >= time_stop_hour)
      return false;

   const datetime closed_h1_time = iTime(_Symbol, PERIOD_H1, 1); // perf-allowed: single closed H1 bar timestamp identifies the card's first-hour candle; EntrySignal is framework QM_IsNewBar-gated.
   if(closed_h1_time <= 0)
      return false;

   MqlDateTime closed_dt;
   TimeToStruct(closed_h1_time, closed_dt);
   int open_hour = strategy_daily_open_hour_broker;
   if(open_hour < 0)
      open_hour = 0;
   if(open_hour > 23)
      open_hour = 23;
   int open_minute = strategy_daily_open_minute;
   if(open_minute < 0)
      open_minute = 0;
   if(open_minute > 59)
      open_minute = 59;
   if(closed_dt.hour != open_hour || closed_dt.min != open_minute)
      return false;

   const double daily_open = iOpen(_Symbol, PERIOD_D1, 0); // perf-allowed: card requires broker daily-open price; no QM OHLC reader exists.
   const double first_h1_close = iClose(_Symbol, PERIOD_H1, 1); // perf-allowed: card requires fixed closed first-H1 close; no QM OHLC reader exists.
   if(daily_open <= 0.0 || first_h1_close <= 0.0 || first_h1_close == daily_open)
      return false;

   const QM_OrderType side = (first_h1_close > daily_open) ? QM_BUY : QM_SELL;
   const double entry_price = (side == QM_BUY)
                              ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                              : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry_price <= 0.0)
      return false;

   req.type = side;
   req.sl = QM_StopFixedPips(_Symbol, side, entry_price, strategy_stop_loss_pips);
   req.tp = QM_TakeFixedPips(_Symbol, side, entry_price, strategy_take_profit_pips);
   if(req.sl <= 0.0 || req.tp <= 0.0)
      return false;

   req.reason = (side == QM_BUY) ? "FF_DAILYOPEN_H1_LONG" : "FF_DAILYOPEN_H1_SHORT";
   return true;
  }

// Trade Management: the card specifies no trailing, break-even, partial close,
// or pyramiding.
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close: TP/SL are broker-managed. This hook implements the card's
// end-of-day time stop.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   bool have_position = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
        {
         have_position = true;
         break;
        }
     }

   if(!have_position)
      return false;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int time_stop_hour = strategy_time_stop_hour_broker;
   if(time_stop_hour < 0)
      time_stop_hour = 0;
   if(time_stop_hour > 23)
      time_stop_hour = 23;
   return (dt.hour >= time_stop_hour);
  }

// News Filter Hook: no card-specific news override; framework news settings
// remain callable for P8 News Impact phase.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring -- do NOT edit below this line unless you know why.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10049_ff-dailyopen-h1\"}");
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
