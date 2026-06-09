#property strict
#property version   "5.0"
#property description "QM5_10187 TradingView VWAP RSI Scalper"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10187;
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
input int    strategy_rsi_period         = 3;
input double strategy_rsi_oversold       = 20.0;
input double strategy_rsi_overbought     = 80.0;
input int    strategy_ema_period         = 50;
input int    strategy_atr_period         = 14;
input double strategy_atr_sl_mult        = 1.0;
input double strategy_atr_tp_mult        = 2.0;
input int    strategy_session_start_hhmm = 1400;
input int    strategy_session_end_hhmm   = 2100;
input int    strategy_max_trades_per_day = 3;
input double strategy_max_spread_atr_frac = 0.15;

int    g_vwap_day_key = -1;
double g_vwap_pv = 0.0;
double g_vwap_volume = 0.0;
double g_session_vwap = 0.0;
int    g_trade_day_key = -1;
int    g_trades_today = 0;
double g_cached_atr = 0.0;

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

bool StrategyInSession(const datetime t)
  {
   const int hhmm = StrategyHhmm(t);
   if(strategy_session_start_hhmm == strategy_session_end_hhmm)
      return true;
   if(strategy_session_start_hhmm < strategy_session_end_hhmm)
      return (hhmm >= strategy_session_start_hhmm && hhmm < strategy_session_end_hhmm);
   return (hhmm >= strategy_session_start_hhmm || hhmm < strategy_session_end_hhmm);
  }

void StrategyResetVwap(const int day_key)
  {
   g_vwap_day_key = day_key;
   g_vwap_pv = 0.0;
   g_vwap_volume = 0.0;
   g_session_vwap = 0.0;
  }

void StrategyResetDailyTradeCount(const datetime t)
  {
   const int day_key = StrategyDateKey(t);
   if(day_key == g_trade_day_key)
      return;
   g_trade_day_key = day_key;
   g_trades_today = 0;
  }

bool StrategySelectOurPosition(ENUM_POSITION_TYPE &position_type, ulong &ticket)
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
      ticket = candidate;
      return true;
     }

   return false;
  }

bool StrategyHasOpenPosition()
  {
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   ulong ticket = 0;
   return StrategySelectOurPosition(position_type, ticket);
  }

bool StrategySpreadAllowed(const double atr_value)
  {
   if(atr_value <= 0.0 || strategy_atr_sl_mult <= 0.0 ||
      strategy_max_spread_atr_frac <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask <= bid)
      return false;

   const double stop_distance = atr_value * strategy_atr_sl_mult;
   return ((ask - bid) <= stop_distance * strategy_max_spread_atr_frac);
  }

void StrategyAdvanceVwapOnClosedBar()
  {
   // perf-allowed: session VWAP is bespoke structural state, advanced once
   // per framework new-bar call from a single closed bar.
   const datetime bar_time = iTime(_Symbol, strategy_signal_tf, 1); // perf-allowed: session VWAP uses one closed bar after framework new-bar gating.
   if(bar_time <= 0)
      return;

   const int day_key = StrategyDateKey(bar_time);
   if(day_key != g_vwap_day_key)
      StrategyResetVwap(day_key);

   if(!StrategyInSession(bar_time))
      return;

   const double high_price = iHigh(_Symbol, strategy_signal_tf, 1); // perf-allowed: session VWAP uses one closed bar after framework new-bar gating.
   const double low_price = iLow(_Symbol, strategy_signal_tf, 1); // perf-allowed: session VWAP uses one closed bar after framework new-bar gating.
   const double close_price = iClose(_Symbol, strategy_signal_tf, 1); // perf-allowed: session VWAP uses one closed bar after framework new-bar gating.
   if(high_price <= 0.0 || low_price <= 0.0 || close_price <= 0.0)
      return;

   double tick_volume = (double)iVolume(_Symbol, strategy_signal_tf, 1); // perf-allowed: session VWAP uses one closed bar after framework new-bar gating.
   if(tick_volume <= 0.0)
      tick_volume = 1.0;

   const double typical_price = (high_price + low_price + close_price) / 3.0;
   g_vwap_pv += typical_price * tick_volume;
   g_vwap_volume += tick_volume;
   if(g_vwap_volume > 0.0)
      g_session_vwap = g_vwap_pv / g_vwap_volume;
  }

void StrategyPrepareRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

bool Strategy_NoTradeFilter()
  {
   // No Trade Filter (time, spread, news): news is handled by framework;
   // this hook blocks new entries outside session while allowing session-end
   // closes for existing positions to continue through Strategy_ExitSignal.
   if(!StrategyHasOpenPosition() && !StrategyInSession(TimeCurrent()))
      return true;

   if(!StrategyHasOpenPosition() && g_cached_atr > 0.0 &&
      !StrategySpreadAllowed(g_cached_atr))
      return true;

   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   StrategyPrepareRequest(req);
   StrategyAdvanceVwapOnClosedBar();

   // perf-allowed: read only the most recent closed bar for the VWAP/RSI/EMA
   // setup after the framework has gated this function to a new bar.
   const datetime bar_time = iTime(_Symbol, strategy_signal_tf, 1); // perf-allowed: session VWAP signal reads one closed bar after framework new-bar gating.
   if(bar_time <= 0)
      return false;

   StrategyResetDailyTradeCount(bar_time);
   if(!StrategyInSession(bar_time))
      return false;
   if(g_trades_today >= strategy_max_trades_per_day)
      return false;
   if(StrategyHasOpenPosition())
      return false;
   if(g_session_vwap <= 0.0)
      return false;

   const double close_price = iClose(_Symbol, strategy_signal_tf, 1); // perf-allowed: session VWAP signal reads one closed bar after framework new-bar gating.
   const double rsi = QM_RSI(_Symbol, strategy_signal_tf, strategy_rsi_period, 1);
   const double ema = QM_EMA(_Symbol, strategy_signal_tf, strategy_ema_period, 1);
   const double atr = QM_ATR(_Symbol, strategy_signal_tf, strategy_atr_period, 1);
   g_cached_atr = atr;

   if(close_price <= 0.0 || rsi <= 0.0 || ema <= 0.0 || atr <= 0.0)
      return false;
   if(!StrategySpreadAllowed(atr))
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(rsi <= strategy_rsi_oversold &&
      close_price > g_session_vwap &&
      close_price > ema)
     {
      req.type = QM_BUY;
      req.sl = QM_StopRulesStopFromDistance(_Symbol, QM_BUY, ask, atr * strategy_atr_sl_mult);
      req.tp = QM_StopRulesTakeFromDistance(_Symbol, QM_BUY, ask, atr * strategy_atr_tp_mult);
      req.reason = "TV_VWAP_RSI_SCALP_LONG";
      if(req.sl > 0.0 && req.tp > 0.0)
        {
         g_trades_today++;
         return true;
        }
     }

   if(rsi >= strategy_rsi_overbought &&
      close_price < g_session_vwap &&
      close_price < ema)
     {
      req.type = QM_SELL;
      req.sl = QM_StopRulesStopFromDistance(_Symbol, QM_SELL, bid, atr * strategy_atr_sl_mult);
      req.tp = QM_StopRulesTakeFromDistance(_Symbol, QM_SELL, bid, atr * strategy_atr_tp_mult);
      req.reason = "TV_VWAP_RSI_SCALP_SHORT";
      if(req.sl > 0.0 && req.tp > 0.0)
        {
         g_trades_today++;
         return true;
        }
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Trade Management: card baseline has fixed bracket exits only; no
   // breakeven, trailing stop, partial close, or pyramiding.
  }

bool Strategy_ExitSignal()
  {
   // Trade Close: close all strategy positions at session end. SL/TP bracket
   // exits are attached immediately at entry by Strategy_EntrySignal.
   if(StrategyInSession(TimeCurrent()))
      return false;
   return StrategyHasOpenPosition();
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   // News Filter Hook: no custom override; central framework news rules apply.
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
