#property strict
#property version   "5.0"
#property description "QM5_10151 TradingView EMA VWAP Scalper"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10151;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours    = 336;
input string qm_news_min_impact         = "high";
input QM_NewsMode qm_news_mode_legacy   = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_signal_tf = PERIOD_M5;
input int    strategy_fast_ema_period    = 9;
input int    strategy_slow_ema_period    = 21;
input int    strategy_atr_period         = 14;
input double strategy_atr_sl_mult        = 1.5;
input double strategy_atr_tp_mult        = 2.0;
input bool   strategy_reversal_exit      = true;
input bool   strategy_trailing_enabled   = false;
input double strategy_trail_activate_atr = 1.0;
input double strategy_trail_atr_mult     = 1.0;
input int    strategy_session_start_hhmm = 1300;
input int    strategy_session_end_hhmm   = 2200;
input int    strategy_max_spread_points  = 250;

int    g_vwap_day_key = -1;
double g_vwap_pv = 0.0;
double g_vwap_volume = 0.0;
double g_session_vwap = 0.0;
double g_last_atr = 0.0;
int    g_last_valid_signal = 0;

int StrategyDateKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

int StrategyHhmm(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 100 + dt.min;
  }

bool StrategyInHhmmWindow(const int hhmm, const int start_hhmm, const int end_hhmm)
  {
   if(start_hhmm == end_hhmm)
      return true;
   if(start_hhmm < end_hhmm)
      return (hhmm >= start_hhmm && hhmm < end_hhmm);
   return (hhmm >= start_hhmm || hhmm < end_hhmm);
  }

void StrategyResetVwap(const int day_key)
  {
   g_vwap_day_key = day_key;
   g_vwap_pv = 0.0;
   g_vwap_volume = 0.0;
   g_session_vwap = 0.0;
  }

void StrategyAdvanceVwapOnClosedBar()
  {
   const datetime bar_time = iTime(_Symbol, strategy_signal_tf, 1);
   if(bar_time <= 0)
      return;

   const int day_key = StrategyDateKey(bar_time);
   if(day_key != g_vwap_day_key)
      StrategyResetVwap(day_key);

   if(!StrategyInHhmmWindow(StrategyHhmm(bar_time), strategy_session_start_hhmm, strategy_session_end_hhmm))
      return;

   const double high = iHigh(_Symbol, strategy_signal_tf, 1);
   const double low = iLow(_Symbol, strategy_signal_tf, 1);
   const double close = iClose(_Symbol, strategy_signal_tf, 1);
   double volume = (double)iVolume(_Symbol, strategy_signal_tf, 1);
   if(high <= 0.0 || low <= 0.0 || close <= 0.0)
      return;
   if(volume <= 0.0)
      volume = 1.0;

   const double typical = (high + low + close) / 3.0;
   g_vwap_pv += typical * volume;
   g_vwap_volume += volume;
   if(g_vwap_volume > 0.0)
      g_session_vwap = g_vwap_pv / g_vwap_volume;
  }

bool StrategySelectOurPosition(ENUM_POSITION_TYPE &position_type, double &open_price, ulong &ticket)
  {
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

      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      ticket = candidate;
      return true;
     }

   return false;
  }

int StrategyClosedBarSignal()
  {
   const double fast_now = QM_EMA(_Symbol, strategy_signal_tf, strategy_fast_ema_period, 1);
   const double fast_prev = QM_EMA(_Symbol, strategy_signal_tf, strategy_fast_ema_period, 2);
   const double slow_now = QM_EMA(_Symbol, strategy_signal_tf, strategy_slow_ema_period, 1);
   const double slow_prev = QM_EMA(_Symbol, strategy_signal_tf, strategy_slow_ema_period, 2);
   const double close_now = iClose(_Symbol, strategy_signal_tf, 1);
   if(fast_now <= 0.0 || fast_prev <= 0.0 || slow_now <= 0.0 ||
      slow_prev <= 0.0 || close_now <= 0.0 || g_session_vwap <= 0.0)
      return 0;

   if(fast_prev <= slow_prev && fast_now > slow_now && close_now > g_session_vwap)
      return 1;
   if(fast_prev >= slow_prev && fast_now < slow_now && close_now < g_session_vwap)
      return -1;
   return 0;
  }

double StrategyEntryPrice(const QM_OrderType side)
  {
   return QM_OrderTypeIsBuy(side) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                  : SymbolInfoDouble(_Symbol, SYMBOL_BID);
  }

bool Strategy_NoTradeFilter()
  {
   if(!StrategyInHhmmWindow(StrategyHhmm(TimeCurrent()), strategy_session_start_hhmm, strategy_session_end_hhmm))
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return true;

   const int spread_points = (int)MathRound((ask - bid) / point);
   return (strategy_max_spread_points > 0 && spread_points > strategy_max_spread_points);
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

   StrategyAdvanceVwapOnClosedBar();
   g_last_atr = QM_ATR(_Symbol, strategy_signal_tf, MathMax(1, strategy_atr_period), 1);
   g_last_valid_signal = StrategyClosedBarSignal();
   if(g_last_valid_signal == 0 || g_last_atr <= 0.0)
      return false;

   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   double open_price = 0.0;
   ulong ticket = 0;
   if(StrategySelectOurPosition(position_type, open_price, ticket))
      return false;

   const QM_OrderType side = (g_last_valid_signal > 0) ? QM_BUY : QM_SELL;
   const double entry = StrategyEntryPrice(side);
   if(entry <= 0.0)
      return false;

   const double sl_distance = g_last_atr * strategy_atr_sl_mult;
   const double tp_distance = g_last_atr * strategy_atr_tp_mult;
   if(sl_distance <= 0.0 || tp_distance <= 0.0)
      return false;

   req.type = side;
   req.sl = QM_StopRulesStopFromDistance(_Symbol, side, entry, sl_distance);
   req.tp = strategy_trailing_enabled ? 0.0 : QM_StopRulesTakeFromDistance(_Symbol, side, entry, tp_distance);
   req.reason = (side == QM_BUY) ? "EMA_VWAP_SCALP_LONG" : "EMA_VWAP_SCALP_SHORT";

   return (req.sl > 0.0 && (strategy_trailing_enabled || req.tp > 0.0));
  }

void Strategy_ManageOpenPosition()
  {
   if(!strategy_trailing_enabled || g_last_atr <= 0.0)
      return;

   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   double open_price = 0.0;
   ulong ticket = 0;
   if(!StrategySelectOurPosition(position_type, open_price, ticket))
      return;

   const bool is_buy = (position_type == POSITION_TYPE_BUY);
   const double market_price = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                      : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(market_price <= 0.0 || open_price <= 0.0)
      return;

   const double favorable = is_buy ? (market_price - open_price) : (open_price - market_price);
   if(favorable >= g_last_atr * strategy_trail_activate_atr)
      QM_TM_TrailATR(ticket, MathMax(1, strategy_atr_period), strategy_trail_atr_mult);
  }

bool Strategy_ExitSignal()
  {
   if(!strategy_reversal_exit || g_last_valid_signal == 0)
      return false;

   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   double open_price = 0.0;
   ulong ticket = 0;
   if(!StrategySelectOurPosition(position_type, open_price, ticket))
      return false;

   if(position_type == POSITION_TYPE_BUY && g_last_valid_signal < 0)
      return true;
   if(position_type == POSITION_TYPE_SELL && g_last_valid_signal > 0)
      return true;
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
