#property strict
#property version   "5.0"
#property description "QM5_12994 IEA OMR WTI shock fade"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12994 - IEA OMR WTI Shock Fade
// -----------------------------------------------------------------------------
// D1 structural WTI sleeve:
//   - uses a mid-month IEA Oil Market Report proxy window
//   - fades ATR-sized D1 shock bars on XTIUSD.DWX
//   - ATR stop/target, max-hold exit, no external runtime data
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12994;
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
input int    strategy_event_start_day       = 10;
input int    strategy_event_end_day         = 18;
input int    strategy_atr_period            = 20;
input double strategy_min_range_atr         = 1.10;
input double strategy_min_body_atr          = 0.35;
input double strategy_close_location_extreme = 0.75;
input double strategy_atr_sl_mult           = 2.5;
input double strategy_atr_tp_mult           = 1.5;
input int    strategy_max_hold_days         = 4;
input int    strategy_max_spread_points     = 1000;

int g_last_signal_month_key = 0;

bool Strategy_IsXtiD1()
  {
   return (_Symbol == "XTIUSD.DWX" && _Period == PERIOD_D1);
  }

int Strategy_MonthKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 100 + dt.mon;
  }

bool Strategy_IsOmrProxyWindow(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (dt.day >= strategy_event_start_day && dt.day <= strategy_event_end_day);
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

void Strategy_CloseTimeExpiredPositions()
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
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
  }

bool Strategy_LoadOmrFadeState(int &direction,
                               double &atr_last,
                               int &signal_month_key)
  {
   direction = 0;
   atr_last = 0.0;
   signal_month_key = 0;

   const datetime event_time = iTime(_Symbol, PERIOD_D1, 1); // perf-allowed: completed D1 event calendar state behind new-bar gate.
   if(event_time <= 0 || !Strategy_IsOmrProxyWindow(event_time))
      return false;

   const double event_open = iOpen(_Symbol, PERIOD_D1, 1);   // perf-allowed: completed D1 event bar.
   const double event_high = iHigh(_Symbol, PERIOD_D1, 1);   // perf-allowed: completed D1 event bar.
   const double event_low = iLow(_Symbol, PERIOD_D1, 1);     // perf-allowed: completed D1 event bar.
   const double event_close = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: completed D1 event bar.
   if(event_open <= 0.0 || event_high <= 0.0 || event_low <= 0.0 || event_close <= 0.0)
      return false;
   if(event_high <= event_low)
      return false;

   atr_last = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr_last <= 0.0)
      return false;

   const double event_range = event_high - event_low;
   const double event_body = MathAbs(event_close - event_open);
   if(event_range < strategy_min_range_atr * atr_last)
      return false;
   if(event_body < strategy_min_body_atr * atr_last)
      return false;

   const double close_location = (event_close - event_low) / event_range;
   const double extreme = MathMax(0.55, MathMin(0.95, strategy_close_location_extreme));

   if(event_close > event_open && close_location >= extreme)
      direction = -1;
   else if(event_close < event_open && close_location <= (1.0 - extreme))
      direction = 1;
   else
      return false;

   signal_month_key = Strategy_MonthKey(event_time);
   return (signal_month_key > 0);
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsXtiD1())
      return true;
   if(qm_magic_slot_offset != 0)
      return true;
   if(strategy_event_start_day < 1 || strategy_event_start_day > 28)
      return true;
   if(strategy_event_end_day < strategy_event_start_day || strategy_event_end_day > 31)
      return true;
   if(strategy_atr_period <= 1)
      return true;
   if(strategy_min_range_atr <= 0.0 || strategy_min_body_atr <= 0.0)
      return true;
   if(strategy_close_location_extreme < 0.55 || strategy_close_location_extreme > 0.95)
      return true;
   if(strategy_atr_sl_mult <= 0.0 || strategy_atr_tp_mult <= 0.0)
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
   req.reason = "QM5_12994_XTI_IEA_OMR_FADE";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(Strategy_HasOpenPosition())
      return false;

   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return false;
     }

   int direction = 0;
   double atr_last = 0.0;
   int signal_month_key = 0;
   if(!Strategy_LoadOmrFadeState(direction, atr_last, signal_month_key))
      return false;
   if(signal_month_key <= 0 || signal_month_key == g_last_signal_month_key)
      return false;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0)
      return false;

   req.sl = QM_StopATRFromValue(_Symbol, req.type, entry_price, atr_last, strategy_atr_sl_mult);
   req.sl = QM_StopRulesNormalizePrice(_Symbol, req.sl);
   if(req.sl <= 0.0)
      return false;
   if(req.type == QM_BUY && req.sl >= entry_price)
      return false;
   if(req.type == QM_SELL && req.sl <= entry_price)
      return false;

   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   req.tp = (req.type == QM_BUY)
            ? NormalizeDouble(entry_price + strategy_atr_tp_mult * atr_last, digits)
            : NormalizeDouble(entry_price - strategy_atr_tp_mult * atr_last, digits);
   req.tp = QM_StopRulesNormalizePrice(_Symbol, req.tp);
   if(req.tp <= 0.0)
      return false;
   if(req.type == QM_BUY && req.tp <= entry_price)
      return false;
   if(req.type == QM_SELL && req.tp >= entry_price)
      return false;

   req.reason = (direction > 0) ? "XTI_IEA_OMR_FADE_LONG" : "XTI_IEA_OMR_FADE_SHORT";
   g_last_signal_month_key = signal_month_key;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   Strategy_CloseTimeExpiredPositions();
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12994\",\"ea\":\"iea-omr-fade\"}");
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
