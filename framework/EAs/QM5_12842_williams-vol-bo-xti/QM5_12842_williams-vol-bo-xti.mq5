#property strict
#property version   "5.0"
#property description "QM5_12842 WTI Prior-Range Volatility Expansion"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12842 - WTI Prior-Range Volatility Expansion
// -----------------------------------------------------------------------------
// D1 structural WTI sleeve:
//   - place one buy-stop above the current D1 open by a fraction of the prior
//     completed D1 range
//   - use an ATR hard stop, optional fixed-R target, and max-hold stale exit
// Runtime uses MT5 OHLC/broker state only; no external energy data.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12842;
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
input double strategy_range_mult          = 0.75;
input double strategy_min_range_atr       = 0.35;
input int    strategy_atr_period          = 20;
input double strategy_atr_sl_mult         = 2.50;
input double strategy_take_rr             = 2.00;
input int    strategy_order_expiry_hours  = 20;
input int    strategy_max_hold_days       = 5;
input int    strategy_max_spread_points   = 1000;

int g_last_order_day_key = 0;

bool Strategy_IsXtiD1()
  {
   return (_Symbol == "XTIUSD.DWX" && _Period == PERIOD_D1);
  }

int Strategy_DayKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
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
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      return true;
     }
   return false;
  }

bool Strategy_HasPendingOrder()
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
      return true;
     }
   return false;
  }

void Strategy_CloseExpiredPositions()
  {
   const int magic = QM_FrameworkMagic();
   const datetime now = TimeCurrent();
   const int hold_seconds = MathMax(1, strategy_max_hold_days) * 86400;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened > 0 && now - opened >= hold_seconds)
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
     }
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsXtiD1())
      return true;
   if(qm_magic_slot_offset != 0)
      return true;
   if(strategy_range_mult <= 0.0)
      return true;
   if(strategy_min_range_atr < 0.0)
      return true;
   if(strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   if(strategy_order_expiry_hours <= 0 || strategy_max_hold_days <= 0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "WTI_PRIOR_RANGE_VOL_EXP";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(Strategy_HasOpenPosition() || Strategy_HasPendingOrder())
      return false;

   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return false;
     }

   const datetime current_d1_bar = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: D1 structural date read behind QM_IsNewBar gate.
   if(current_d1_bar <= 0)
      return false;
   const int day_key = Strategy_DayKey(current_d1_bar);
   if(day_key <= 0 || day_key == g_last_order_day_key)
      return false;

   const double current_open = iOpen(_Symbol, PERIOD_D1, 0); // perf-allowed: D1 structural open read behind QM_IsNewBar gate.
   const double prior_high = iHigh(_Symbol, PERIOD_D1, 1); // perf-allowed: D1 structural prior high read behind QM_IsNewBar gate.
   const double prior_low = iLow(_Symbol, PERIOD_D1, 1); // perf-allowed: D1 structural prior low read behind QM_IsNewBar gate.
   if(current_open <= 0.0 || prior_high <= prior_low || prior_low <= 0.0)
      return false;

   const double prior_range = prior_high - prior_low;
   const double atr_last = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(prior_range <= 0.0 || atr_last <= 0.0)
      return false;
   if(strategy_min_range_atr > 0.0 && prior_range < atr_last * strategy_min_range_atr)
      return false;

   double buy_stop = current_open + strategy_range_mult * prior_range;
   buy_stop = QM_StopRulesNormalizePrice(_Symbol, buy_stop);
   if(buy_stop <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(ask <= 0.0)
      return false;

   QM_OrderType entry_type = QM_BUY_STOP;
   double entry_ref = buy_stop;
   if(ask >= buy_stop)
     {
      entry_type = QM_BUY;
      entry_ref = ask;
     }

   const double stop_price = QM_StopATRFromValue(_Symbol, entry_type, entry_ref, atr_last, strategy_atr_sl_mult);
   if(stop_price <= 0.0 || stop_price >= entry_ref)
      return false;

   req.type = entry_type;
   req.price = (entry_type == QM_BUY_STOP) ? buy_stop : 0.0;
   req.sl = stop_price;
   req.tp = (strategy_take_rr > 0.0) ? QM_TakeRR(_Symbol, entry_type, entry_ref, stop_price, strategy_take_rr) : 0.0;
   req.expiration_seconds = (entry_type == QM_BUY_STOP) ? MathMax(1, strategy_order_expiry_hours) * 3600 : 0;
   req.reason = (entry_type == QM_BUY_STOP) ? "WTI_RANGE_EXP_BUY_STOP" : "WTI_RANGE_EXP_MARKET_BUY";

   g_last_order_day_key = day_key;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   Strategy_CloseExpiredPositions();
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12842\",\"ea\":\"williams-vol-bo-xti\"}");
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
