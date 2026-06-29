#property strict
#property version   "5.0"
#property description "QM5_12784 Williams Pro-Go XTI Flow Crossover"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12784 - Williams Pro-Go XTI Flow Crossover
// -----------------------------------------------------------------------------
// D1 structural WTI flow sleeve:
//   - public line: prior close -> current open
//   - pro line: current open -> current close
//   - trade XTIUSD.DWX when the smoothed pro line crosses the public line
// Runtime uses MT5 OHLC/broker spread only; no external energy data.
// =============================================================================

enum StrategySignalMode
  {
   STRATEGY_SIGNAL_SIGNED_VALUE = 0,
   STRATEGY_SIGNAL_SIGN_ONLY    = 1
  };

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12784;
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
input int                strategy_flow_ma_period    = 14;
input StrategySignalMode strategy_signal_mode       = STRATEGY_SIGNAL_SIGNED_VALUE;
input int                strategy_atr_period        = 20;
input double             strategy_atr_sl_mult       = 3.0;
input int                strategy_max_hold_days     = 12;
input int                strategy_max_spread_points = 1000;

bool Strategy_IsXtiD1()
  {
   return (_Symbol == "XTIUSD.DWX" && _Period == PERIOD_D1);
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

bool Strategy_SpreadAllowsEntry()
  {
   if(strategy_max_spread_points <= 0)
      return true;
   const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (spread_points <= strategy_max_spread_points);
  }

double Strategy_NormalizeFlowValue(const double raw_value)
  {
   if(strategy_signal_mode == STRATEGY_SIGNAL_SIGN_ONLY)
     {
      if(raw_value > 0.0)
         return 1.0;
      if(raw_value < 0.0)
         return -1.0;
      return 0.0;
     }
   return raw_value;
  }

bool Strategy_FlowChange(const bool pro_line, const int shift, double &value)
  {
   const double open_value = iOpen(_Symbol, PERIOD_D1, shift); // perf-allowed: bounded D1 Pro-Go line calculation behind new-bar gate.
   const double close_value = iClose(_Symbol, PERIOD_D1, shift); // perf-allowed: bounded D1 Pro-Go line calculation behind new-bar gate.
   const double prior_close = iClose(_Symbol, PERIOD_D1, shift + 1); // perf-allowed: bounded D1 Pro-Go line calculation behind new-bar gate.
   if(open_value <= 0.0 || close_value <= 0.0 || prior_close <= 0.0)
      return false;

   const double raw_value = pro_line ? (close_value - open_value) : (open_value - prior_close);
   value = Strategy_NormalizeFlowValue(raw_value);
   return true;
  }

bool Strategy_FlowLine(const bool pro_line, const int start_shift, double &line_value)
  {
   if(strategy_flow_ma_period <= 1)
      return false;

   double sum = 0.0;
   for(int i = 0; i < strategy_flow_ma_period; ++i)
     {
      double value = 0.0;
      if(!Strategy_FlowChange(pro_line, start_shift + i, value))
         return false;
      sum += value;
     }

   line_value = sum / (double)strategy_flow_ma_period;
   return true;
  }

bool Strategy_LoadFlowState(double &pro_current,
                            double &public_current,
                            double &pro_previous,
                            double &public_previous,
                            double &atr_value)
  {
   const int warmup_bars = strategy_flow_ma_period + strategy_atr_period + 5;
   const int bars = Bars(_Symbol, PERIOD_D1); // perf-allowed: bounded D1 warmup check behind new-bar gate.
   if(bars < warmup_bars)
      return false;

   if(!Strategy_FlowLine(true, 1, pro_current))
      return false;
   if(!Strategy_FlowLine(false, 1, public_current))
      return false;
   if(!Strategy_FlowLine(true, 2, pro_previous))
      return false;
   if(!Strategy_FlowLine(false, 2, public_previous))
      return false;

   atr_value = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   return (atr_value > 0.0);
  }

int Strategy_CrossDirection()
  {
   double pro_current = 0.0;
   double public_current = 0.0;
   double pro_previous = 0.0;
   double public_previous = 0.0;
   double atr_value = 0.0;
   if(!Strategy_LoadFlowState(pro_current,
                              public_current,
                              pro_previous,
                              public_previous,
                              atr_value))
      return 0;

   if(pro_previous <= public_previous && pro_current > public_current)
      return 1;
   if(pro_previous >= public_previous && pro_current < public_current)
      return -1;
   return 0;
  }

void Strategy_CloseManagedPositions()
  {
   const int magic = QM_FrameworkMagic();
   const datetime now = TimeCurrent();
   int hold_days = strategy_max_hold_days;
   if(hold_days < 1)
      hold_days = 1;
   const long hold_seconds = (long)hold_days * 86400;
   const int cross_direction = Strategy_CrossDirection();

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      bool should_close = false;
      if(pos_type == POSITION_TYPE_BUY && cross_direction < 0)
         should_close = true;
      if(pos_type == POSITION_TYPE_SELL && cross_direction > 0)
         should_close = true;

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened > 0 && (long)(now - opened) >= hold_seconds)
         should_close = true;

      if(should_close)
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsXtiD1())
      return true;
   if(qm_magic_slot_offset != 0)
      return true;
   if(strategy_flow_ma_period < 5 || strategy_flow_ma_period > 80)
      return true;
   if(strategy_atr_period < 5 || strategy_atr_period > 120)
      return true;
   if(strategy_atr_sl_mult <= 0.0)
      return true;
   if(strategy_max_hold_days <= 0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_12784_PROGO_XTI";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(Strategy_HasOpenPosition())
      return false;
   if(!Strategy_SpreadAllowsEntry())
      return false;

   double pro_current = 0.0;
   double public_current = 0.0;
   double pro_previous = 0.0;
   double public_previous = 0.0;
   double atr_value = 0.0;
   if(!Strategy_LoadFlowState(pro_current,
                              public_current,
                              pro_previous,
                              public_previous,
                              atr_value))
      return false;

   QM_OrderType side = QM_BUY;
   if(pro_previous <= public_previous && pro_current > public_current)
      side = QM_BUY;
   else if(pro_previous >= public_previous && pro_current < public_current)
      side = QM_SELL;
   else
      return false;

   req.type = side;
   req.reason = (side == QM_BUY) ? "PROGO_XTI_FLOW_CROSS_LONG" : "PROGO_XTI_FLOW_CROSS_SHORT";

   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0)
      return false;

   req.sl = QM_StopATRFromValue(_Symbol, req.type, entry_price, atr_value, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;
   if(req.type == QM_BUY && req.sl >= entry_price)
      return false;
   if(req.type == QM_SELL && req.sl <= entry_price)
      return false;

   return true;
  }

void Strategy_ManageOpenPosition()
  {
   Strategy_CloseManagedPositions();
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12784\",\"ea\":\"progo-xti\"}");
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

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();
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
