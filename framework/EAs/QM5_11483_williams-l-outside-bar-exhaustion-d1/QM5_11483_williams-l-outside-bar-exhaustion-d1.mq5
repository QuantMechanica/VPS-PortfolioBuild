#property strict
#property version   "5.0"
#property description "QM5_11483 Williams-L Outside Bar Exhaustion Reversal D1"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11483;
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
input int    strategy_stop_pips         = 200;
input int    strategy_max_hold_bars     = 5;
input double strategy_spread_cap_pips   = 25.0;
input int    strategy_direction_mode    = 0;     // 0=both, 1=long only, 2=short only

ulong g_profit_exit_checked_ticket = 0;

double Strategy_PipDistance()
  {
   return QM_StopRulesPipsToPriceDistance(_Symbol, 1);
  }

bool Strategy_IsFriday(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return (dt.day_of_week == 5);
  }

bool Strategy_SelectOurPosition(ulong &ticket,
                                ENUM_POSITION_TYPE &position_type,
                                datetime &opened_at,
                                double &net_profit)
  {
   ticket = 0;
   position_type = POSITION_TYPE_BUY;
   opened_at = 0;
   net_profit = 0.0;

   const int magic = QM_FrameworkMagic();
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
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      net_profit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      return true;
     }

   return false;
  }

bool Strategy_NoTradeFilter()
  {
   const double pip = Strategy_PipDistance();
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(pip <= 0.0 || ask <= 0.0 || bid <= 0.0 || ask < bid)
      return true;

   const double spread_pips = (ask - bid) / pip;
   return (spread_pips > strategy_spread_cap_pips);
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_stop_pips <= 0)
      return false;

   ulong existing_ticket;
   ENUM_POSITION_TYPE existing_type;
   datetime existing_open;
   double existing_profit;
   if(Strategy_SelectOurPosition(existing_ticket, existing_type, existing_open, existing_profit))
      return false;

   const datetime signal_time = iTime(_Symbol, PERIOD_D1, 1); // perf-allowed: fixed closed-bar day-of-week read; no QM_Time helper exists.
   if(signal_time <= 0 || Strategy_IsFriday(signal_time))
      return false;

   const double high_1 = iHigh(_Symbol, PERIOD_D1, 1);   // perf-allowed: fixed closed-bar outside-bar high; no QM_High helper exists.
   const double low_1 = iLow(_Symbol, PERIOD_D1, 1);     // perf-allowed: fixed closed-bar outside-bar low; no QM_Low helper exists.
   const double close_1 = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: fixed closed-bar exhaustion close; no QM_Close helper exists.
   const double high_2 = iHigh(_Symbol, PERIOD_D1, 2);   // perf-allowed: fixed closed-bar prior high; no QM_High helper exists.
   const double low_2 = iLow(_Symbol, PERIOD_D1, 2);     // perf-allowed: fixed closed-bar prior low; no QM_Low helper exists.

   if(high_1 <= 0.0 || low_1 <= 0.0 || close_1 <= 0.0 || high_2 <= 0.0 || low_2 <= 0.0)
      return false;
   if(!(high_1 > high_2 && low_1 < low_2))
      return false;

   if(close_1 < low_2 && strategy_direction_mode != 2)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double sl = QM_StopFixedPips(_Symbol, QM_BUY, entry, strategy_stop_pips);
      if(entry <= 0.0 || sl <= 0.0)
         return false;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = sl;
      req.tp = 0.0;
      req.reason = "WILLIAMS_OUTSIDE_BAR_BEAR_EXHAUSTION_LONG";
      return true;
     }

   if(close_1 > high_2 && strategy_direction_mode != 1)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double sl = QM_StopFixedPips(_Symbol, QM_SELL, entry, strategy_stop_pips);
      if(entry <= 0.0 || sl <= 0.0)
         return false;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = sl;
      req.tp = 0.0;
      req.reason = "WILLIAMS_OUTSIDE_BAR_BULL_EXHAUSTION_SHORT";
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, pyramiding, or partial-close logic.
  }

bool Strategy_ExitSignal()
  {
   if(strategy_max_hold_bars <= 0)
      return false;

   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   datetime opened_at;
   double net_profit;
   if(!Strategy_SelectOurPosition(ticket, position_type, opened_at, net_profit))
     {
      g_profit_exit_checked_ticket = 0;
      return false;
     }

   const int bars_held = iBarShift(_Symbol, PERIOD_D1, opened_at, false); // perf-allowed: O(1) D1 hold-time count for card exit.
   if(bars_held < 0)
      return false;

   if(bars_held >= strategy_max_hold_bars)
      return true;

   if(bars_held == 1 && g_profit_exit_checked_ticket != ticket)
     {
      g_profit_exit_checked_ticket = ticket;
      return (net_profit > 0.0);
     }

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_11483\",\"source_id\":\"729c9425-1ec7-5842-a8b8-3db326d892e5\"}");
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
