#property strict
#property version   "5.0"
#property description "QM5_9585 ForexFactory Craig Harris Stochastic Angle M15"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9585;
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
input int    strategy_fast_stoch_k            = 8;
input int    strategy_slow_stoch_k            = 14;
input int    strategy_stoch_d                 = 3;
input int    strategy_stoch_slowing           = 3;
input double strategy_stoch_angle_points      = 12.0;
input int    strategy_m15_ema_period          = 20;
input int    strategy_h1_ema_period           = 50;
input int    strategy_swing_lookback_bars     = 5;
input int    strategy_atr_period              = 14;
input double strategy_structure_atr_buffer    = 0.20;
input double strategy_take_profit_rr          = 1.50;
input int    strategy_time_stop_bars          = 12;
input int    strategy_session_start_hour      = 9;
input int    strategy_session_end_hour        = 18;
input double strategy_max_spread_pips         = 3.0;
input bool   strategy_adr_filter_enabled      = true;
input int    strategy_adr_period              = 13;
input double strategy_adr_exhaustion_fraction = 1.0;

bool HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

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

bool SelectOurPosition(ENUM_POSITION_TYPE &position_type, datetime &open_time)
  {
   position_type = POSITION_TYPE_BUY;
   open_time = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

bool BrokerHourInSession(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);

   const int start_hour = strategy_session_start_hour;
   const int end_hour = strategy_session_end_hour;
   if(start_hour == end_hour)
      return true;
   if(start_hour < end_hour)
      return (dt.hour >= start_hour && dt.hour < end_hour);
   return (dt.hour >= start_hour || dt.hour < end_hour);
  }

double PipFactor()
  {
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   return (digits == 3 || digits == 5) ? 10.0 : 1.0;
  }

bool SpreadTooWide()
  {
   if(strategy_max_spread_pips <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   if(ask > bid)
     {
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      const double pip = point * PipFactor();
      if(pip <= 0.0)
         return false;
      const double spread_pips = (ask - bid) / pip;
      if(spread_pips > strategy_max_spread_pips)
         return true;
     }

   return false;
  }

bool StochLongState(const int k_period)
  {
   const double k1 = QM_Stoch_K(_Symbol, PERIOD_M15, k_period, strategy_stoch_d, strategy_stoch_slowing, 1);
   const double k2 = QM_Stoch_K(_Symbol, PERIOD_M15, k_period, strategy_stoch_d, strategy_stoch_slowing, 2);
   const double k3 = QM_Stoch_K(_Symbol, PERIOD_M15, k_period, strategy_stoch_d, strategy_stoch_slowing, 3);
   const double d1 = QM_Stoch_D(_Symbol, PERIOD_M15, k_period, strategy_stoch_d, strategy_stoch_slowing, 1);
   if(k1 <= 0.0 || k2 <= 0.0 || k3 <= 0.0 || d1 <= 0.0)
      return false;
   return (k1 > k2 && k2 > k3 && k1 > d1 && (k1 - k3) >= strategy_stoch_angle_points);
  }

bool StochShortState(const int k_period)
  {
   const double k1 = QM_Stoch_K(_Symbol, PERIOD_M15, k_period, strategy_stoch_d, strategy_stoch_slowing, 1);
   const double k2 = QM_Stoch_K(_Symbol, PERIOD_M15, k_period, strategy_stoch_d, strategy_stoch_slowing, 2);
   const double k3 = QM_Stoch_K(_Symbol, PERIOD_M15, k_period, strategy_stoch_d, strategy_stoch_slowing, 3);
   const double d1 = QM_Stoch_D(_Symbol, PERIOD_M15, k_period, strategy_stoch_d, strategy_stoch_slowing, 1);
   if(k1 <= 0.0 || k2 <= 0.0 || k3 <= 0.0 || d1 <= 0.0)
      return false;
   return (k1 < k2 && k2 < k3 && k1 < d1 && (k3 - k1) >= strategy_stoch_angle_points);
  }

bool StochCrossDown(const int k_period)
  {
   const double k1 = QM_Stoch_K(_Symbol, PERIOD_M15, k_period, strategy_stoch_d, strategy_stoch_slowing, 1);
   const double d1 = QM_Stoch_D(_Symbol, PERIOD_M15, k_period, strategy_stoch_d, strategy_stoch_slowing, 1);
   const double k2 = QM_Stoch_K(_Symbol, PERIOD_M15, k_period, strategy_stoch_d, strategy_stoch_slowing, 2);
   const double d2 = QM_Stoch_D(_Symbol, PERIOD_M15, k_period, strategy_stoch_d, strategy_stoch_slowing, 2);
   return (k2 >= d2 && k1 < d1);
  }

bool StochCrossUp(const int k_period)
  {
   const double k1 = QM_Stoch_K(_Symbol, PERIOD_M15, k_period, strategy_stoch_d, strategy_stoch_slowing, 1);
   const double d1 = QM_Stoch_D(_Symbol, PERIOD_M15, k_period, strategy_stoch_d, strategy_stoch_slowing, 1);
   const double k2 = QM_Stoch_K(_Symbol, PERIOD_M15, k_period, strategy_stoch_d, strategy_stoch_slowing, 2);
   const double d2 = QM_Stoch_D(_Symbol, PERIOD_M15, k_period, strategy_stoch_d, strategy_stoch_slowing, 2);
   return (k2 <= d2 && k1 > d1);
  }

bool AdrExhaustionBlocks(const QM_OrderType type)
  {
   if(!strategy_adr_filter_enabled)
      return false;

   double adr = 0.0;
   if(!QM_StopRulesReadADRValue(_Symbol, strategy_adr_period, adr) || adr <= 0.0)
      return false;

   const double day_high = iHigh(_Symbol, PERIOD_D1, 0); // perf-allowed: O(1) D1 range read for card ADR exhaustion filter.
   const double day_low = iLow(_Symbol, PERIOD_D1, 0);   // perf-allowed: O(1) D1 range read for card ADR exhaustion filter.
   const double day_open = iOpen(_Symbol, PERIOD_D1, 0); // perf-allowed: O(1) D1 direction read for counter-trend exhaustion filter.
   if(day_high <= 0.0 || day_low <= 0.0 || day_open <= 0.0 || day_high <= day_low)
      return false;

   const double current_range = day_high - day_low;
   if(current_range < adr * strategy_adr_exhaustion_fraction)
      return false;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double current_price = QM_OrderTypeIsBuy(type) ? ask : bid;
   if(current_price <= 0.0)
      return false;

   if(QM_OrderTypeIsBuy(type) && current_price < day_open)
      return true;
   if(!QM_OrderTypeIsBuy(type) && current_price > day_open)
      return true;

   return false;
  }

bool BuildMarketRequest(const QM_OrderType type, const string reason, QM_EntryRequest &req)
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double entry_price = QM_OrderTypeIsBuy(type) ? ask : bid;
   const double atr = QM_ATR(_Symbol, PERIOD_M15, strategy_atr_period, 1);
   if(entry_price <= 0.0 || atr <= 0.0)
      return false;

   const double structure_stop = QM_StopStructure(_Symbol, type, entry_price, strategy_swing_lookback_bars);
   if(structure_stop <= 0.0)
      return false;

   double sl = 0.0;
   if(QM_OrderTypeIsBuy(type))
      sl = QM_StopRulesNormalizePrice(_Symbol, structure_stop - (strategy_structure_atr_buffer * atr));
   else
      sl = QM_StopRulesNormalizePrice(_Symbol, structure_stop + (strategy_structure_atr_buffer * atr));
   if(sl <= 0.0)
      return false;
   if(QM_OrderTypeIsBuy(type) && sl >= entry_price)
      return false;
   if(!QM_OrderTypeIsBuy(type) && sl <= entry_price)
      return false;

   const double tp = QM_TakeRR(_Symbol, type, entry_price, sl, strategy_take_profit_rr);
   if(tp <= 0.0)
      return false;

   req.type = type;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = reason;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// No Trade Filter: time and spread entry blocking; news is delegated to the framework hook below.
bool Strategy_NoTradeFilter()
  {
   if(HasOpenPosition())
      return false;
   if(!BrokerHourInSession(TimeCurrent()))
      return true;
   if(SpreadTooWide())
      return true;
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

   if(!BrokerHourInSession(TimeCurrent()) || SpreadTooWide())
      return false;

   const bool long_signal =
      StochLongState(strategy_fast_stoch_k) &&
      StochLongState(strategy_slow_stoch_k) &&
      QM_Sig_Price_Above_MA(_Symbol, PERIOD_M15, strategy_m15_ema_period, 0.0, 1) > 0 &&
      QM_Sig_Price_Above_MA(_Symbol, PERIOD_H1, strategy_h1_ema_period, 0.0, 1) > 0;

   if(long_signal && !AdrExhaustionBlocks(QM_BUY))
      return BuildMarketRequest(QM_BUY, "CH_STOCH_LONG", req);

   const bool short_signal =
      StochShortState(strategy_fast_stoch_k) &&
      StochShortState(strategy_slow_stoch_k) &&
      QM_Sig_Price_Above_MA(_Symbol, PERIOD_M15, strategy_m15_ema_period, 0.0, 1) < 0 &&
      QM_Sig_Price_Above_MA(_Symbol, PERIOD_H1, strategy_h1_ema_period, 0.0, 1) < 0;

   if(short_signal && !AdrExhaustionBlocks(QM_SELL))
      return BuildMarketRequest(QM_SELL, "CH_STOCH_SHORT", req);

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, partial close, or scale-in logic.
  }

bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE position_type;
   datetime open_time;
   if(!SelectOurPosition(position_type, open_time))
      return false;

   const int stop_seconds = strategy_time_stop_bars * PeriodSeconds(PERIOD_M15);
   if(stop_seconds > 0 && open_time > 0 && (TimeCurrent() - open_time) >= stop_seconds)
      return true;

   if(position_type == POSITION_TYPE_BUY)
     {
      if(StochCrossDown(strategy_fast_stoch_k) || StochCrossDown(strategy_slow_stoch_k))
         return true;
     }
   else if(position_type == POSITION_TYPE_SELL)
     {
      if(StochCrossUp(strategy_fast_stoch_k) || StochCrossUp(strategy_slow_stoch_k))
         return true;
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
