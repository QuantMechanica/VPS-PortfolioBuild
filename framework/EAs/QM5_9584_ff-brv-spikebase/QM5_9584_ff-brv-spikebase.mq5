#property strict
#property version   "5.0"
#property description "QM5_9584 BRV spike-base second-retest continuation"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 9584;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours       = 336;
input string qm_news_min_impact            = "high";
input QM_NewsMode qm_news_mode_legacy      = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled       = true;
input int    qm_friday_close_hour_broker   = 21;

input group "Stress"
input double qm_stress_reject_probability  = 0.0;

input group "Strategy"
input int    strategy_atr_period           = 14;
input double strategy_spike_atr_mult       = 2.5;
input double strategy_min_body_ratio       = 0.60;
input double strategy_zone_atr_mult        = 0.20;
input double strategy_tp_atr_mult          = 0.80;
input double strategy_reward_risk          = 1.20;
input int    strategy_max_hold_bars        = 6;

// A setup advances only on closed M15 bars:
// 0=wait first retest, 1=wait continuation away, 2=wait second retest.
int    g_spike_direction = 0;
int    g_setup_phase     = 0;
double g_zone_low        = 0.0;
double g_zone_high       = 0.0;

bool Strategy_NoTradeFilter()
  {
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const double atr = QM_ATR(_Symbol, PERIOD_M15, strategy_atr_period, 1);
   // perf-allowed: four fixed closed-bar reads implement the bespoke spike body/range.
   const double bar_open  = iOpen(_Symbol, PERIOD_M15, 1);  // perf-allowed: fixed bespoke spike bar
   const double bar_high  = iHigh(_Symbol, PERIOD_M15, 1);  // perf-allowed: fixed bespoke spike bar
   const double bar_low   = iLow(_Symbol, PERIOD_M15, 1);   // perf-allowed: fixed bespoke spike bar
   const double bar_close = iClose(_Symbol, PERIOD_M15, 1); // perf-allowed: fixed bespoke spike bar
   if(atr <= 0.0 || bar_open <= 0.0 || bar_high <= bar_low || bar_close <= 0.0)
      return false;

   const double range = bar_high - bar_low;
   const double body  = MathAbs(bar_close - bar_open);
   if(range > strategy_spike_atr_mult * atr &&
      body / range >= strategy_min_body_ratio &&
      bar_close != bar_open)
     {
      const double zone_width = strategy_zone_atr_mult * atr;
      g_spike_direction = (bar_close > bar_open ? 1 : -1);
      if(g_spike_direction > 0)
        {
         g_zone_low  = bar_open;
         g_zone_high = bar_open + zone_width;
        }
      else
        {
         g_zone_low  = bar_open - zone_width;
         g_zone_high = bar_open;
        }
      g_setup_phase = 0;
      return false;
     }

   if(g_spike_direction == 0 || g_zone_low <= 0.0 || g_zone_high <= g_zone_low)
      return false;

   const bool bullish_retest = (bar_low <= g_zone_high && bar_close > g_zone_high);
   const bool bearish_retest = (bar_high >= g_zone_low && bar_close < g_zone_low);

   if(g_setup_phase == 0)
     {
      if((g_spike_direction > 0 && bullish_retest) ||
         (g_spike_direction < 0 && bearish_retest))
         g_setup_phase = 1;
      return false;
     }

   if(g_setup_phase == 1)
     {
      const bool bullish_continuation =
         (g_spike_direction > 0 && bar_low > g_zone_high);
      const bool bearish_continuation =
         (g_spike_direction < 0 && bar_high < g_zone_low);
      if(bullish_continuation || bearish_continuation)
         g_setup_phase = 2;
      return false;
     }

   const bool entry_long  = (g_spike_direction > 0 && bullish_retest);
   const bool entry_short = (g_spike_direction < 0 && bearish_retest);
   if(!entry_long && !entry_short)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double entry = entry_long ? ask : bid;
   if(entry <= 0.0)
      return false;

   req.type = entry_long ? QM_BUY : QM_SELL;
   req.price = entry;
   req.sl = entry_long
      ? g_zone_low - strategy_zone_atr_mult * atr
      : g_zone_high + strategy_zone_atr_mult * atr;
   const double risk_distance = MathAbs(entry - req.sl);
   if(risk_distance <= 0.0)
      return false;
   const double tp_distance =
      MathMin(strategy_reward_risk * risk_distance, strategy_tp_atr_mult * atr);
   req.tp = entry_long ? entry + tp_distance : entry - tp_distance;
   req.reason = entry_long ? "BRV_SPIKEBASE_LONG" : "BRV_SPIKEBASE_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   g_spike_direction = 0;
   g_setup_phase = 0;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   const int held = QM_TM_HeldPeriodsForMagic(magic, _Symbol, PERIOD_M15);
   if(held >= strategy_max_hold_bars)
      return true;

   // The card's close-through invalidation is evaluated on the last closed bar.
   // perf-allowed: one fixed bespoke structural read; no lookback loop.
   const double last_close = iClose(_Symbol, PERIOD_M15, 1); // perf-allowed: fixed zone invalidation
   if(last_close <= 0.0 || g_zone_low <= 0.0 || g_zone_high <= g_zone_low)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic ||
         PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      const ENUM_POSITION_TYPE type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(type == POSITION_TYPE_BUY)
         return last_close < g_zone_low;
      if(type == POSITION_TYPE_SELL)
         return last_close > g_zone_high;
     }
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED,
                        PORTFOLIO_WEIGHT, qm_news_mode_legacy,
                        qm_friday_close_enabled, qm_friday_close_hour_broker,
                        30, 30, qm_news_stale_max_hours, qm_news_min_impact,
                        qm_rng_seed, qm_stress_reject_probability,
                        qm_news_temporal, qm_news_compliance))
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
         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   if(Strategy_NewsFilterHook(broker_now))
      return;
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal,
                                        qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows || !QM_IsNewBar(_Symbol, PERIOD_M15))
      return;

   QM_EquityStreamOnNewBar();
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
