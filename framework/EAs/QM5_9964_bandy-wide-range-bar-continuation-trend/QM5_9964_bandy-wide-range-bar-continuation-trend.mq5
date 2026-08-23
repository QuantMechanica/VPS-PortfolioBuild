#property strict
#property version   "5.0"
#property description "QM5_9964 Bandy wide-range-bar continuation trend"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9964;
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
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_timeframe             = PERIOD_D1;
input int             strategy_atr_period            = 14;
input double          strategy_wide_range_atr_mult   = 2.0;
input double          strategy_close_position_level = 0.75;
input int             strategy_regime_sma_period     = 200;
input int             strategy_chandelier_lookback   = 22;
input double          strategy_chandelier_atr_mult   = 2.5;
input double          strategy_stop_atr_mult         = 2.5;
input int             strategy_anti_cluster_days     = 3;
input int             strategy_max_hold_bars        = 30;

ulong    g_exit_cache_ticket = 0;
datetime g_exit_cache_bar    = 0;
bool     g_exit_cache_value  = false;

bool Strategy_FindPosition(ulong &ticket,
                           ENUM_POSITION_TYPE &position_type,
                           datetime &opened_at)
  {
   ticket = 0;
   position_type = POSITION_TYPE_BUY;
   opened_at = 0;
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong candidate = PositionGetTicket(i);
      if(candidate == 0 || !PositionSelectByTicket(candidate))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = candidate;
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }
   return false;
  }

bool Strategy_EntryWithinCluster(const QM_OrderType side)
  {
   if(strategy_anti_cluster_days <= 0)
      return false;

   MqlRates cutoff_bar;
   if(!QM_ReadBar(_Symbol, strategy_timeframe, strategy_anti_cluster_days, cutoff_bar))
      return true;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || !HistorySelect(cutoff_bar.time, TimeCurrent()))
      return true;

   for(int i = HistoryDealsTotal() - 1; i >= 0; --i)
     {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;
      if((int)HistoryDealGetInteger(deal, DEAL_MAGIC) != magic)
         continue;
      if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol)
         continue;
      const ENUM_DEAL_ENTRY entry_kind =
         (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY);
      if(entry_kind != DEAL_ENTRY_IN && entry_kind != DEAL_ENTRY_INOUT)
         continue;
      const ENUM_DEAL_TYPE deal_type =
         (ENUM_DEAL_TYPE)HistoryDealGetInteger(deal, DEAL_TYPE);
      if((QM_OrderTypeIsBuy(side) && deal_type == DEAL_TYPE_BUY) ||
         (!QM_OrderTypeIsBuy(side) && deal_type == DEAL_TYPE_SELL))
         return true;
     }
   return false;
  }

int Strategy_ClosedBarsSinceEntry(const datetime opened_at, const int limit)
  {
   if(opened_at <= 0 || limit <= 0)
      return 0;
   const int bar_seconds = PeriodSeconds(strategy_timeframe);
   if(bar_seconds <= 0)
      return 0;

   int count = 0;
   for(int shift = 1; shift <= limit; ++shift)
     {
      MqlRates bar;
      if(!QM_ReadBar(_Symbol, strategy_timeframe, shift, bar))
         break;
      if(bar.time + bar_seconds <= opened_at)
         break;
      count++;
     }
   return count;
  }

bool Strategy_ChandelierExit(const ENUM_POSITION_TYPE position_type)
  {
   if(strategy_chandelier_lookback < 1 || strategy_chandelier_atr_mult <= 0.0)
      return false;

   double highest = -DBL_MAX;
   double lowest = DBL_MAX;
   int bars = 0;
   MqlRates signal_bar;
   if(!QM_ReadBar(_Symbol, strategy_timeframe, 1, signal_bar))
      return false;

   for(int shift = 1; shift <= strategy_chandelier_lookback; ++shift)
     {
      MqlRates bar;
      if(!QM_ReadBar(_Symbol, strategy_timeframe, shift, bar))
         break;
      highest = MathMax(highest, bar.high);
      lowest = MathMin(lowest, bar.low);
      bars++;
     }
   if(bars != strategy_chandelier_lookback || highest <= 0.0 || lowest <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;
   if(position_type == POSITION_TYPE_BUY)
      return signal_bar.close < highest - strategy_chandelier_atr_mult * atr;
   if(position_type == POSITION_TYPE_SELL)
      return signal_bar.close > lowest + strategy_chandelier_atr_mult * atr;
   return false;
  }

bool Strategy_InputsValid()
  {
   return strategy_atr_period >= 1 &&
          strategy_wide_range_atr_mult > 0.0 &&
          strategy_close_position_level > 0.5 &&
          strategy_close_position_level < 1.0 &&
          strategy_regime_sma_period >= 2 &&
          strategy_chandelier_lookback >= 1 &&
          strategy_chandelier_atr_mult > 0.0 &&
          strategy_stop_atr_mult > 0.0 &&
          strategy_anti_cluster_days >= 0 &&
          strategy_max_hold_bars >= 1;
  }

bool Strategy_SignalBarNewsBlocked(const datetime bar_open_broker)
  {
   if(!QM_NewsIsLoaded() &&
      !QM_NewsInit("D:\\QM\\data\\news_calendar",
                   qm_news_stale_max_hours,
                   30,
                   30,
                   qm_news_min_impact))
      return true;
   if(!QM_NewsIsAvailable())
      return true;

   const int bar_seconds = PeriodSeconds(strategy_timeframe);
   if(bar_open_broker <= 0 || bar_seconds <= 0)
      return true;
   const datetime utc_from = QM_BrokerToUTC(bar_open_broker);
   const datetime utc_to = QM_BrokerToUTC(bar_open_broker + bar_seconds);
   if(utc_from <= 0 || utc_to <= utc_from)
      return true;

   const int span_minutes = (int)MathCeil((double)(utc_to - utc_from) / 60.0);
   return QM_NewsInWindow(utc_from, _Symbol, span_minutes, 0, "high");
  }

bool Strategy_NoTradeFilter()
  {
   return ((ENUM_TIMEFRAMES)_Period != strategy_timeframe);
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

   if(!Strategy_InputsValid())
      return false;

   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   datetime opened_at;
   if(Strategy_FindPosition(ticket, position_type, opened_at))
      return false;

   MqlRates signal_bar;
   MqlRates previous_bar;
   if(!QM_ReadBar(_Symbol, strategy_timeframe, 1, signal_bar) ||
      !QM_ReadBar(_Symbol, strategy_timeframe, 2, previous_bar))
      return false;
   if(Strategy_SignalBarNewsBlocked(signal_bar.time))
      return false;

   const double bar_range = signal_bar.high - signal_bar.low;
   if(bar_range <= 0.0 || previous_bar.close <= 0.0)
      return false;
   const double true_range = MathMax(
      bar_range,
      MathMax(MathAbs(signal_bar.high - previous_bar.close),
              MathAbs(signal_bar.low - previous_bar.close)));
   const double atr = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   const double regime = QM_SMA(
      _Symbol, strategy_timeframe, strategy_regime_sma_period, 1, PRICE_CLOSE);
   if(atr <= 0.0 || regime <= 0.0 || true_range < strategy_wide_range_atr_mult * atr)
      return false;

   const double close_position = (signal_bar.close - signal_bar.low) / bar_range;
   QM_OrderType side = QM_BUY;
   if(close_position >= strategy_close_position_level && signal_bar.close > regime)
      side = QM_BUY;
   else if(close_position <= 1.0 - strategy_close_position_level &&
           signal_bar.close < regime)
      side = QM_SELL;
   else
      return false;

   if(Strategy_EntryWithinCluster(side))
      return false;

   const double entry = QM_OrderTypeIsBuy(side)
                        ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;
   const double stop = QM_StopATRFromValue(
      _Symbol, side, entry, atr, strategy_stop_atr_mult);
   if(stop <= 0.0)
      return false;

   req.type = side;
   req.sl = stop;
   req.reason = QM_OrderTypeIsBuy(side)
                ? "WIDE_RANGE_UP_CONTINUATION"
                : "WIDE_RANGE_DOWN_CONTINUATION";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // The card's Chandelier is a next-bar strategy exit, not an intrabar SL rewrite.
  }

bool Strategy_ExitSignal()
  {
   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   datetime opened_at;
   if(!Strategy_FindPosition(ticket, position_type, opened_at))
     {
      g_exit_cache_ticket = 0;
      g_exit_cache_bar = 0;
      g_exit_cache_value = false;
      return false;
     }

   MqlRates signal_bar;
   if(!QM_ReadBar(_Symbol, strategy_timeframe, 1, signal_bar))
      return false;
   if(g_exit_cache_ticket == ticket && g_exit_cache_bar == signal_bar.time)
      return g_exit_cache_value;

   g_exit_cache_ticket = ticket;
   g_exit_cache_bar = signal_bar.time;
   g_exit_cache_value =
      Strategy_ClosedBarsSinceEntry(opened_at, strategy_max_hold_bars) >=
         strategy_max_hold_bars ||
      Strategy_ChandelierExit(position_type);
   return g_exit_cache_value;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

int OnInit()
  {
   if(!Strategy_InputsValid())
      return INIT_PARAMETERS_INCORRECT;
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
   QM_FrameworkTrackOpenPositionMae();
   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
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
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   if(!QM_IsNewBar(_Symbol, strategy_timeframe))
      return;

   QM_EquityStreamOnNewBar();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(
         _Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   QM_EntryRequest req;
   ZeroMemory(req);
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
