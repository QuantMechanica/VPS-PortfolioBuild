#property strict
#property version   "5.0"
#property description "QM5_10697 TradingView Session Liquidity Sweep EMA"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10697;
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
input int    strategy_liquidity_lookback = 20;
input int    strategy_ema_period         = 50;
input int    strategy_atr_period         = 14;
input double strategy_atr_stop_mult      = 1.5;
input double strategy_rr_target          = 2.5;
input int    strategy_session_start_hhmm = 930;
input int    strategy_session_end_hhmm   = 1100;
input double strategy_min_sweep_range_atr = 0.5;
input int    strategy_max_spread_points  = 0;

bool Strategy_NoTradeFilter()
  {
   bool has_position = false;
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
      has_position = true;
      break;
     }

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   const int hhmm = dt.hour * 100 + dt.min;
   bool in_session = false;
   if(strategy_session_start_hhmm <= strategy_session_end_hhmm)
      in_session = (hhmm >= strategy_session_start_hhmm && hhmm < strategy_session_end_hhmm);
   else
      in_session = (hhmm >= strategy_session_start_hhmm || hhmm < strategy_session_end_hhmm);

   if(!in_session && !has_position)
      return true;

   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return true;
     }

   return false;
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

   if(strategy_liquidity_lookback < 1 ||
      strategy_ema_period < 1 ||
      strategy_atr_period < 1 ||
      strategy_atr_stop_mult <= 0.0 ||
      strategy_rr_target <= 0.0)
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

   MqlDateTime bar_dt;
   const datetime signal_time = iTime(_Symbol, _Period, 1);
   if(signal_time <= 0)
      return false;
   TimeToStruct(signal_time, bar_dt);
   const int signal_hhmm = bar_dt.hour * 100 + bar_dt.min;
   bool signal_in_session = false;
   if(strategy_session_start_hhmm <= strategy_session_end_hhmm)
      signal_in_session = (signal_hhmm >= strategy_session_start_hhmm && signal_hhmm < strategy_session_end_hhmm);
   else
      signal_in_session = (signal_hhmm >= strategy_session_start_hhmm || signal_hhmm < strategy_session_end_hhmm);
   if(!signal_in_session)
      return false;

   double prior_high = -DBL_MAX;
   double prior_low = DBL_MAX;
   for(int shift = 2; shift <= strategy_liquidity_lookback + 1; ++shift)
     {
      const double bar_high = iHigh(_Symbol, _Period, shift);
      const double bar_low = iLow(_Symbol, _Period, shift);
      if(bar_high <= 0.0 || bar_low <= 0.0)
         return false;
      prior_high = MathMax(prior_high, bar_high);
      prior_low = MathMin(prior_low, bar_low);
     }

   const double high1 = iHigh(_Symbol, _Period, 1);
   const double low1 = iLow(_Symbol, _Period, 1);
   const double close1 = iClose(_Symbol, _Period, 1);
   const double ema1 = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_period, 1);
   const double atr1 = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(high1 <= 0.0 || low1 <= 0.0 || close1 <= 0.0 || ema1 <= 0.0 || atr1 <= 0.0)
      return false;

   if(strategy_min_sweep_range_atr > 0.0 && (high1 - low1) < atr1 * strategy_min_sweep_range_atr)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(low1 < prior_low && close1 > prior_low && close1 > ema1)
     {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = NormalizeDouble(ask - atr1 * strategy_atr_stop_mult, _Digits);
      req.tp = QM_TakeRR(_Symbol, req.type, ask, req.sl, strategy_rr_target);
      req.reason = "TV_SESS_LS_EMA_LONG";
      return (req.sl > 0.0 && req.tp > 0.0);
     }

   if(high1 > prior_high && close1 < prior_high && close1 < ema1)
     {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = NormalizeDouble(bid + atr1 * strategy_atr_stop_mult, _Digits);
      req.tp = QM_TakeRR(_Symbol, req.type, bid, req.sl, strategy_rr_target);
      req.reason = "TV_SESS_LS_EMA_SHORT";
      return (req.sl > 0.0 && req.tp > 0.0);
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, partial close, or pyramiding.
  }

bool Strategy_ExitSignal()
  {
   bool has_position = false;
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
      has_position = true;
      break;
     }
   if(!has_position)
      return false;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   const int hhmm = dt.hour * 100 + dt.min;
   bool in_session = false;
   if(strategy_session_start_hhmm <= strategy_session_end_hhmm)
      in_session = (hhmm >= strategy_session_start_hhmm && hhmm < strategy_session_end_hhmm);
   else
      in_session = (hhmm >= strategy_session_start_hhmm || hhmm < strategy_session_end_hhmm);

   return !in_session;
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
