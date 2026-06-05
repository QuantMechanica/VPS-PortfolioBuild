#property strict
#property version   "5.0"
#property description "QM5_10813 TradingView GM8 ADX EMA Trend"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10813;
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
input int    strategy_gm_ma_period      = 8;
input int    strategy_ema_filter_period = 59;
input int    strategy_adx_period        = 14;
input double strategy_adx_threshold     = 20.0;
input int    strategy_atr_period        = 14;
input double strategy_atr_sl_mult       = 2.0;
input bool   strategy_slope_filter      = false;
input bool   strategy_max_bars_exit     = true;
input int    strategy_max_bars_m30      = 160;
input int    strategy_max_bars_h1       = 120;
input bool   strategy_trail_after_1r    = false;
input double strategy_trail_atr_mult    = 3.0;

int Strategy_MaxBarsForPeriod()
  {
   if(_Period == PERIOD_M30)
      return strategy_max_bars_m30;
   return strategy_max_bars_h1;
  }

bool Strategy_HasOurPosition(ulong &ticket, ENUM_POSITION_TYPE &position_type)
  {
   ticket = 0;
   position_type = POSITION_TYPE_BUY;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

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
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }

   return false;
  }

int Strategy_Direction(const int shift)
  {
   if(strategy_gm_ma_period <= 0 || strategy_ema_filter_period <= 0 ||
      strategy_adx_period <= 0 || strategy_adx_threshold <= 0.0)
      return 0;

   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   const double close_bar = QM_SMA(_Symbol, tf, 1, shift, PRICE_CLOSE);
   const double gm_ma = QM_SMA(_Symbol, tf, strategy_gm_ma_period, shift, PRICE_CLOSE);
   const double ema_filter = QM_EMA(_Symbol, tf, strategy_ema_filter_period, shift, PRICE_CLOSE);
   const double adx = QM_ADX(_Symbol, tf, strategy_adx_period, shift);
   if(close_bar <= 0.0 || gm_ma <= 0.0 || ema_filter <= 0.0 || adx <= 0.0)
      return 0;
   if(adx <= strategy_adx_threshold)
      return 0;

   if(strategy_slope_filter)
     {
      const double gm_prev = QM_SMA(_Symbol, tf, strategy_gm_ma_period, shift + 1, PRICE_CLOSE);
      const double ema_prev = QM_EMA(_Symbol, tf, strategy_ema_filter_period, shift + 1, PRICE_CLOSE);
      if(gm_prev <= 0.0 || ema_prev <= 0.0)
         return 0;
      const bool both_up = (gm_ma > gm_prev && ema_filter > ema_prev);
      const bool both_down = (gm_ma < gm_prev && ema_filter < ema_prev);
      if(!both_up && !both_down)
         return 0;
      if(close_bar > gm_ma && close_bar > ema_filter && both_up)
         return 1;
      if(close_bar < gm_ma && close_bar < ema_filter && both_down)
         return -1;
      return 0;
     }

   if(close_bar > gm_ma && close_bar > ema_filter)
      return 1;
   if(close_bar < gm_ma && close_bar < ema_filter)
      return -1;
   return 0;
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0)
      return false;

   ulong existing_ticket = 0;
   ENUM_POSITION_TYPE existing_type = POSITION_TYPE_BUY;
   if(Strategy_HasOurPosition(existing_ticket, existing_type))
      return false;

   const int direction = Strategy_Direction(1);
   if(direction == 0)
      return false;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   const double entry = QM_EntryMarketPrice(req.type);
   if(entry <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, req.type, entry, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;
   if(req.type == QM_BUY && req.sl >= entry)
      return false;
   if(req.type == QM_SELL && req.sl <= entry)
      return false;

   req.reason = (direction > 0) ? "GM8_ADX_EMA_LONG" : "GM8_ADX_EMA_SHORT";
   return true;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   if(!strategy_trail_after_1r || strategy_trail_atr_mult <= 0.0 ||
      strategy_atr_period <= 0)
      return;

   ulong ticket = 0;
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   if(!Strategy_HasOurPosition(ticket, position_type))
      return;
   if(!PositionSelectByTicket(ticket))
      return;

   const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   const double sl = PositionGetDouble(POSITION_SL);
   if(open_price <= 0.0 || sl <= 0.0)
      return;

   const double risk = MathAbs(open_price - sl);
   if(risk <= 0.0)
      return;

   const bool is_buy = (position_type == POSITION_TYPE_BUY);
   const double mark = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                              : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(mark <= 0.0)
      return;

   const bool reached_1r = is_buy ? (mark >= open_price + risk)
                                  : (mark <= open_price - risk);
   if(reached_1r)
      QM_TM_TrailATR(ticket, strategy_atr_period, strategy_trail_atr_mult);
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   ulong ticket = 0;
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   if(!Strategy_HasOurPosition(ticket, position_type))
      return false;
   if(!PositionSelectByTicket(ticket))
      return false;

   const int direction = Strategy_Direction(1);
   if(position_type == POSITION_TYPE_BUY && direction < 0)
      return true;
   if(position_type == POSITION_TYPE_SELL && direction > 0)
      return true;

   if(!strategy_max_bars_exit)
      return false;

   const int max_bars = Strategy_MaxBarsForPeriod();
   const int period_seconds = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   if(max_bars <= 0 || period_seconds <= 0)
      return false;

   const datetime opened_at = (datetime)PositionGetInteger(POSITION_TIME);
   if(opened_at <= 0)
      return false;

   return ((TimeCurrent() - opened_at) >= (max_bars * period_seconds));
  }

// News Filter Hook
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(broker_time <= 0)
      return false;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_10813_tv-gm8-adx\"}");
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
