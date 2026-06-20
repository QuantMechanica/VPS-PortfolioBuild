#property strict
#property version   "5.0"
#property description "QM5_10079 GitHub Victor Algo Ichimoku Kumo Breakout"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10079;
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
input int    strategy_tenkan_period     = 9;
input int    strategy_kijun_period      = 26;
input int    strategy_senkou_b_period   = 52;
input double strategy_stop_percent      = 3.0;

bool HasOpenPositionForMagic()
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
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }

   return false;
  }

bool SelectPositionTypeForMagic(ENUM_POSITION_TYPE &position_type)
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

      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }

   return false;
  }

bool EntryDealDuringPriorTimeframe()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   int lookback_seconds = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   if(lookback_seconds <= 0)
      lookback_seconds = 86400;

   const datetime now = TimeCurrent();
   if(!HistorySelect(now - lookback_seconds, now))
      return false;

   const int deals = HistoryDealsTotal();
   for(int i = 0; i < deals; ++i)
     {
      const ulong deal_ticket = HistoryDealGetTicket(i);
      if(deal_ticket == 0)
         continue;
      if(HistoryDealGetString(deal_ticket, DEAL_SYMBOL) != _Symbol)
         continue;
      if((int)HistoryDealGetInteger(deal_ticket, DEAL_MAGIC) != magic)
         continue;

      const ENUM_DEAL_ENTRY entry_type = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
      if(entry_type == DEAL_ENTRY_IN || entry_type == DEAL_ENTRY_INOUT)
         return true;
     }

   return false;
  }

bool ReadKumo(const int bar_shift, double &span_a, double &span_b)
  {
   if(strategy_tenkan_period <= 0 || strategy_kijun_period <= 0 || strategy_senkou_b_period <= 0)
      return false;

   const int cloud_shift = strategy_kijun_period + bar_shift;
   span_a = QM_Ichimoku_SenkouSpanA(_Symbol, (ENUM_TIMEFRAMES)_Period,
                                    strategy_tenkan_period,
                                    strategy_kijun_period,
                                    strategy_senkou_b_period,
                                    cloud_shift);
   span_b = QM_Ichimoku_SenkouSpanB(_Symbol, (ENUM_TIMEFRAMES)_Period,
                                    strategy_tenkan_period,
                                    strategy_kijun_period,
                                    strategy_senkou_b_period,
                                    cloud_shift);
   return (span_a > 0.0 && span_b > 0.0);
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type               = QM_BUY;
   req.price              = 0.0;
   req.sl                 = 0.0;
   req.tp                 = 0.0;
   req.reason             = "";
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_stop_percent <= 0.0)
      return false;
   if(HasOpenPositionForMagic())
      return false;
   if(EntryDealDuringPriorTimeframe())
      return false;

   double span_a_1 = 0.0;
   double span_b_1 = 0.0;
   double span_a_2 = 0.0;
   double span_b_2 = 0.0;
   if(!ReadKumo(1, span_a_1, span_b_1))
      return false;
   if(!ReadKumo(2, span_a_2, span_b_2))
      return false;

   const double low_1  = iLow(_Symbol, (ENUM_TIMEFRAMES)_Period, 1);   // perf-allowed - no OHLC helper; entry runs inside QM_IsNewBar gate
   const double low_2  = iLow(_Symbol, (ENUM_TIMEFRAMES)_Period, 2);   // perf-allowed - no OHLC helper; entry runs inside QM_IsNewBar gate
   const double high_1 = iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, 1);  // perf-allowed - no OHLC helper; entry runs inside QM_IsNewBar gate
   const double high_2 = iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, 2);  // perf-allowed - no OHLC helper; entry runs inside QM_IsNewBar gate
   if(low_1 <= 0.0 || low_2 <= 0.0 || high_1 <= 0.0 || high_2 <= 0.0)
      return false;

   const bool bullish_kumo = (span_a_1 > span_b_1 && span_a_2 > span_b_2);
   const bool bearish_kumo = (span_a_1 < span_b_1 && span_a_2 < span_b_2);

   const double upper_1 = MathMax(span_a_1, span_b_1);
   const double upper_2 = MathMax(span_a_2, span_b_2);
   const double lower_1 = MathMin(span_a_1, span_b_1);
   const double lower_2 = MathMin(span_a_2, span_b_2);

   QM_OrderType side = QM_BUY;
   string reason = "";
   if(bullish_kumo && low_2 < upper_2 && low_1 > upper_1)
     {
      side = QM_BUY;
      reason = "KUMO_BREAKOUT_LONG";
     }
   else if(bearish_kumo && high_2 > lower_2 && high_1 < lower_1)
     {
      side = QM_SELL;
      reason = "KUMO_BREAKOUT_SHORT";
     }
   else
      return false;

   const double entry = QM_EntryMarketPrice(side);
   if(entry <= 0.0)
      return false;

   const double stop_distance = entry * strategy_stop_percent / 100.0;
   if(stop_distance <= 0.0)
      return false;

   req.type = side;
   req.sl = QM_StopRulesNormalizePrice(_Symbol, (side == QM_BUY) ? entry - stop_distance : entry + stop_distance);
   req.tp = 0.0;
   req.reason = reason;
   return (req.sl > 0.0);
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // Source strategy specifies no trailing, break-even, scale-in, or partial-close rule.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   if(!SelectPositionTypeForMagic(position_type))
      return false;

   double span_a = 0.0;
   double span_b = 0.0;
   if(!ReadKumo(0, span_a, span_b))
      return false;

   const double current_low  = iLow(_Symbol, (ENUM_TIMEFRAMES)_Period, 0);   // perf-allowed - O(1) current-bar exit trigger, no OHLC helper
   const double current_high = iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, 0);  // perf-allowed - O(1) current-bar exit trigger, no OHLC helper
   if(current_low <= 0.0 || current_high <= 0.0)
      return false;

   const double lower = MathMin(span_a, span_b);
   const double upper = MathMax(span_a, span_b);

   if(position_type == POSITION_TYPE_BUY && current_low < lower)
      return true;
   if(position_type == POSITION_TYPE_SELL && current_high > upper)
      return true;

   return false;
  }

// News Filter Hook
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring - do NOT edit below this line unless you know why.
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
