#property strict
#property version   "5.0"
#property description "QM5_12984 Psaradellis WTI percent filter"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12984 - Psaradellis WTI Percent Filter
// -----------------------------------------------------------------------------
// D1 structural WTI sleeve:
//   - single-symbol XTIUSD.DWX crude-oil CFD
//   - closed-bar percent-filter state machine from the Psaradellis et al.
//     crude-oil technical-rule family
//   - ATR safety stop only; no ML, grids, martingale, external data, or
//     portfolio/live side effects
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12984;
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
input double strategy_filter_pct          = 7.5;
input int    strategy_atr_period          = 20;
input double strategy_sl_atr_mult         = 3.0;
input int    strategy_max_spread_points   = 1000;

double   g_peak = 0.0;
double   g_trough = 0.0;
int      g_signal = 0;
int      g_pending = 0;
datetime g_last_state_bar_time = 0;

bool Strategy_IsXtiD1()
  {
   return (_Symbol == "XTIUSD.DWX" && _Period == PERIOD_D1);
  }

int Strategy_PositionDirection()
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

      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(position_type == POSITION_TYPE_BUY)
         return 1;
      if(position_type == POSITION_TYPE_SELL)
         return -1;
     }
   return 0;
  }

void Strategy_ResetState()
  {
   g_peak = 0.0;
   g_trough = 0.0;
   g_signal = 0;
   g_pending = 0;
   g_last_state_bar_time = 0;
  }

void Strategy_AdvanceStateOnNewBar()
  {
   g_pending = 0;

   const datetime closed_bar_time = iTime(_Symbol, PERIOD_D1, 1); // perf-allowed: single closed-bar timestamp behind new-bar gate.
   if(closed_bar_time <= 0 || closed_bar_time == g_last_state_bar_time)
      return;
   g_last_state_bar_time = closed_bar_time;

   const double close_last = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: single closed-bar close behind new-bar gate.
   if(close_last <= 0.0)
      return;

   if(g_peak <= 0.0)
      g_peak = close_last;
   if(g_trough <= 0.0)
      g_trough = close_last;

   if(close_last > g_peak)
      g_peak = close_last;
   if(close_last < g_trough)
      g_trough = close_last;

   const double filter = strategy_filter_pct / 100.0;
   const double up_trigger = g_trough * (1.0 + filter);
   const double down_trigger = g_peak * (1.0 - filter);

   if(g_trough > 0.0 && close_last >= up_trigger && g_signal != 1)
     {
      g_pending = 1;
      g_signal = 1;
      g_peak = close_last;
      g_trough = close_last;
      return;
     }

   if(g_peak > 0.0 && close_last <= down_trigger && g_signal != -1)
     {
      g_pending = -1;
      g_signal = -1;
      g_trough = close_last;
      g_peak = close_last;
      return;
     }
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsXtiD1())
      return true;
   if(qm_magic_slot_offset != 0)
      return true;
   if(strategy_filter_pct <= 0.0 || strategy_filter_pct > 30.0)
      return true;
   if(strategy_atr_period <= 1 || strategy_sl_atr_mult <= 0.0)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(g_pending == 0)
      return false;

   const int position_direction = Strategy_PositionDirection();
   if(position_direction == g_pending)
     {
      g_pending = 0;
      return false;
     }
   if(position_direction != 0)
      return false;

   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return false;
     }

   const double atr_value = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   req.type = (g_pending > 0) ? QM_BUY : QM_SELL;
   req.price = 0.0;
   req.tp = 0.0;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   req.reason = (g_pending > 0) ? "WTI_FILTER_LONG" : "WTI_FILTER_SHORT";

   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0)
      return false;

   req.sl = QM_StopATRFromValue(_Symbol, req.type, entry_price, atr_value, strategy_sl_atr_mult);
   req.sl = QM_StopRulesNormalizePrice(_Symbol, req.sl);
   if(req.sl <= 0.0)
      return false;
   if(req.type == QM_BUY && req.sl >= entry_price)
      return false;
   if(req.type == QM_SELL && req.sl <= entry_price)
      return false;

   g_pending = 0;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   if(g_pending == 0)
      return false;

   const int position_direction = Strategy_PositionDirection();
   if(position_direction == 0)
      return false;
   return (position_direction != g_pending);
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

   Strategy_ResetState();
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12984\",\"ea\":\"psara-oil-filter\"}");
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

   if(QM_IsNewBar())
     {
      Strategy_AdvanceStateOnNewBar();
      QM_EquityStreamOnNewBar();
     }

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
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
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
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
