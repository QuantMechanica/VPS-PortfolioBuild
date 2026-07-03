#property strict
#property version   "5.0"
#property description "QM5_13007 EURNZD persistent-bias time-series momentum"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_13007 - EURNZD Persistent-Bias Time-Series Momentum
// -----------------------------------------------------------------------------
// D1 structural FX sleeve:
//   - first D1 bar of each broker-calendar month only
//   - direction = sign agreement between 126- and 252-D1-bar return windows
//   - disagreement flattens the EA until the next monthly agreement
// Runtime uses MT5 OHLC/broker calendar only; no macro feed, API, ML, or grid.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 13007;
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
input int    strategy_mid_lookback_d1_bars  = 126;
input int    strategy_long_lookback_d1_bars = 252;
input int    strategy_atr_period            = 14;
input double strategy_atr_sl_mult           = 3.0;
input int    strategy_max_spread_points     = 80;

int g_last_rebalance_key = 0;
int g_last_target_state = 0; // -1 short, 0 flat, +1 long at last monthly check.

bool Strategy_IsEurnzdD1()
  {
   return (_Symbol == "EURNZD.DWX" && _Period == PERIOD_D1 && qm_magic_slot_offset == 0);
  }

bool Strategy_IsMonthlyRebalanceBar()
  {
   const int current_key = QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 0);
   const int prior_key = QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 1);
   if(current_key <= 0 || prior_key <= 0)
      return false;
   if(current_key == g_last_rebalance_key)
      return false;
   if(current_key == prior_key)
      return false;

   g_last_rebalance_key = current_key;
   return true;
  }

bool Strategy_CurrentPosition(ulong &ticket, int &direction)
  {
   ticket = 0;
   direction = 0;
   const int magic = QM_FrameworkMagic();

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
      const long pos_type = PositionGetInteger(POSITION_TYPE);
      direction = (pos_type == POSITION_TYPE_BUY) ? 1 : -1;
      return true;
     }
   return false;
  }

bool Strategy_SpreadAllowsEntry()
  {
   if(strategy_max_spread_points <= 0)
      return true;

   const long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(current_spread > 0 && current_spread > strategy_max_spread_points)
      return false;
   return true;
  }

int Strategy_ReturnDirection(const int lookback_bars)
  {
   if(lookback_bars <= 0)
      return 0;

   const double recent_close = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: fixed-shift D1 return sign specified by card.
   const double lookback_close = iClose(_Symbol, PERIOD_D1, 1 + lookback_bars); // perf-allowed: fixed-shift D1 return sign specified by card.
   if(recent_close <= 0.0 || lookback_close <= 0.0)
      return 0;

   if(recent_close > lookback_close)
      return 1;
   if(recent_close < lookback_close)
      return -1;
   return 0;
  }

int Strategy_PersistentBiasDirection()
  {
   const int mid_dir = Strategy_ReturnDirection(strategy_mid_lookback_d1_bars);
   const int long_dir = Strategy_ReturnDirection(strategy_long_lookback_d1_bars);
   if(mid_dir == 0 || long_dir == 0)
      return 0;
   if(mid_dir == long_dir)
      return mid_dir;
   return 0;
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsEurnzdD1())
      return true;
   if(strategy_mid_lookback_d1_bars < 42)
      return true;
   if(strategy_long_lookback_d1_bars <= strategy_mid_lookback_d1_bars)
      return true;
   if(strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   if(strategy_max_spread_points < 0)
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

   if(!Strategy_IsMonthlyRebalanceBar())
      return false;

   const int direction = Strategy_PersistentBiasDirection();

   ulong existing_ticket = 0;
   int existing_direction = 0;
   const bool has_position = Strategy_CurrentPosition(existing_ticket, existing_direction);
   if(direction == 0)
     {
      if(has_position)
         QM_TM_ClosePosition(existing_ticket, QM_EXIT_STRATEGY);
      g_last_target_state = 0;
      return false;
     }

   if(!Strategy_SpreadAllowsEntry())
      return false;

   if(Strategy_CurrentPosition(existing_ticket, existing_direction))
     {
      if(existing_direction == direction)
        {
         g_last_target_state = direction;
         return false;
        }
      if(!QM_TM_ClosePosition(existing_ticket, QM_EXIT_STRATEGY))
         return false;
     }

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   req.price = (direction > 0) ? ask : bid;
   req.sl = QM_StopATR(_Symbol, req.type, req.price, strategy_atr_period, strategy_atr_sl_mult);
   req.tp = 0.0;
   req.symbol_slot = qm_magic_slot_offset;
   req.reason = (direction > 0) ? "EURNZD_TSMOM_PB_LONG" : "EURNZD_TSMOM_PB_SHORT";

   if(req.sl <= 0.0)
      return false;
   if(req.type == QM_BUY && req.sl >= req.price)
      return false;
   if(req.type == QM_SELL && req.sl <= req.price)
      return false;

   g_last_target_state = direction;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, pyramiding, or partial close.
  }

bool Strategy_ExitSignal()
  {
   // Monthly flatten/reversal exits are handled inside Strategy_EntrySignal so
   // the framework consumes QM_IsNewBar() only once per D1 bar.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_13007\",\"ea\":\"eurnzd-tsmom-pb\"}");
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
