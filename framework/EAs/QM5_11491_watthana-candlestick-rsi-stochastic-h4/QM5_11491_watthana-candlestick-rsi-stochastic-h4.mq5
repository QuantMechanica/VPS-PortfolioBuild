#property strict
#property version   "5.0"
#property description "QM5_11491 watthana-candlestick-rsi-stochastic-h4"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11491;
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
input int    strategy_ema_period          = 50;
input int    strategy_ema_slope_bars      = 5;
input double strategy_shadow_mult         = 2.0;
input int    strategy_rsi_period          = 14;
input double strategy_rsi_os              = 30.0;
input double strategy_rsi_ob              = 70.0;
input int    strategy_stoch_k             = 5;
input int    strategy_stoch_d             = 3;
input int    strategy_stoch_slow          = 3;
input double strategy_stoch_os            = 20.0;
input double strategy_stoch_ob            = 80.0;
input int    strategy_atr_period          = 14;
input double strategy_sl_atr_mult         = 2.0;
input double strategy_tp_atr_mult         = 3.0;
input int    strategy_spread_cap_pips     = 20;

// Return TRUE to BLOCK trading this tick. Keep this cheap because it runs on
// every tick before the framework reaches management, exit, or entry logic.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double spread = ask - bid;
   const double cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_spread_cap_pips);
   if(spread > 0.0 && cap > 0.0 && spread > cap)
      return true;

   return false;
  }

// Caller guarantees QM_IsNewBar() == true. Trade the last completed H4 bar.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   MqlDateTime broker_dt;
   TimeToStruct(TimeCurrent(), broker_dt);
   if(broker_dt.day_of_week == 5)
      return false;

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(strategy_ema_period <= 0 || strategy_ema_slope_bars <= 0 ||
      strategy_rsi_period <= 0 || strategy_atr_period <= 0 ||
      strategy_stoch_k <= 0 || strategy_stoch_d <= 0 || strategy_stoch_slow <= 0 ||
      strategy_shadow_mult <= 0.0 || strategy_sl_atr_mult <= 0.0 ||
      strategy_tp_atr_mult <= 0.0)
      return false;

   const double open1 = iOpen(_Symbol, _Period, 1);   // perf-allowed: candlestick pattern OHLC
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: candlestick pattern OHLC
   const double high1 = iHigh(_Symbol, _Period, 1);   // perf-allowed: candlestick pattern OHLC
   const double low1 = iLow(_Symbol, _Period, 1);     // perf-allowed: candlestick pattern OHLC
   if(open1 <= 0.0 || close1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0)
      return false;

   const double body = MathAbs(close1 - open1);
   if(body <= 0.0)
      return false;

   const double upper_shadow = high1 - MathMax(open1, close1);
   const double lower_shadow = MathMin(open1, close1) - low1;
   const double required_shadow = strategy_shadow_mult * body;
   const bool long_shadow_pattern = (lower_shadow >= required_shadow ||
                                     upper_shadow >= required_shadow);
   if(!long_shadow_pattern)
      return false;

   const double ema_now = QM_EMA(_Symbol, _Period, strategy_ema_period, 1);
   const double ema_back = QM_EMA(_Symbol, _Period, strategy_ema_period,
                                  1 + strategy_ema_slope_bars);
   if(ema_now <= 0.0 || ema_back <= 0.0)
      return false;

   const bool trend_down = (ema_now < ema_back);
   const bool trend_up = (ema_now > ema_back);
   if(!trend_down && !trend_up)
      return false;

   const double rsi = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1, PRICE_CLOSE);
   const double stoch_k = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k,
                                     strategy_stoch_d, strategy_stoch_slow, 1);
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(rsi <= 0.0 || stoch_k <= 0.0 || atr_value <= 0.0)
      return false;

   QM_OrderType side = QM_BUY;
   if(trend_down && rsi < strategy_rsi_os && stoch_k < strategy_stoch_os)
     {
      side = QM_BUY;
      req.reason = "hammer_rsi_stoch_long";
     }
   else if(trend_up && rsi > strategy_rsi_ob && stoch_k > strategy_stoch_ob)
     {
      side = QM_SELL;
      req.reason = "shootingstar_rsi_stoch_short";
     }
   else
      return false;

   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, side, entry, atr_value, strategy_sl_atr_mult);
   const double tp = QM_TakeATRFromValue(_Symbol, side, entry, atr_value, strategy_tp_atr_mult);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   return true;
  }

// Card specifies no break-even, trailing, partial close, or pyramiding.
void Strategy_ManageOpenPosition()
  {
  }

// Paper exit: close when the opposite full confluence appears.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   if(strategy_ema_period <= 0 || strategy_ema_slope_bars <= 0 ||
      strategy_rsi_period <= 0 || strategy_stoch_k <= 0 ||
      strategy_stoch_d <= 0 || strategy_stoch_slow <= 0 ||
      strategy_shadow_mult <= 0.0)
      return false;

   const double open1 = iOpen(_Symbol, _Period, 1);   // perf-allowed: opposite candlestick pattern OHLC
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: opposite candlestick pattern OHLC
   const double high1 = iHigh(_Symbol, _Period, 1);   // perf-allowed: opposite candlestick pattern OHLC
   const double low1 = iLow(_Symbol, _Period, 1);     // perf-allowed: opposite candlestick pattern OHLC
   if(open1 <= 0.0 || close1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0)
      return false;

   const double body = MathAbs(close1 - open1);
   if(body <= 0.0)
      return false;

   const double upper_shadow = high1 - MathMax(open1, close1);
   const double lower_shadow = MathMin(open1, close1) - low1;
   const double required_shadow = strategy_shadow_mult * body;
   if(lower_shadow < required_shadow && upper_shadow < required_shadow)
      return false;

   const double ema_now = QM_EMA(_Symbol, _Period, strategy_ema_period, 1);
   const double ema_back = QM_EMA(_Symbol, _Period, strategy_ema_period,
                                  1 + strategy_ema_slope_bars);
   const double rsi = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1, PRICE_CLOSE);
   const double stoch_k = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k,
                                     strategy_stoch_d, strategy_stoch_slow, 1);
   if(ema_now <= 0.0 || ema_back <= 0.0 || rsi <= 0.0 || stoch_k <= 0.0)
      return false;

   const bool long_signal = (ema_now < ema_back &&
                             rsi < strategy_rsi_os &&
                             stoch_k < strategy_stoch_os);
   const bool short_signal = (ema_now > ema_back &&
                              rsi > strategy_rsi_ob &&
                              stoch_k > strategy_stoch_ob);
   if(!long_signal && !short_signal)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const long pos_type = PositionGetInteger(POSITION_TYPE);
      if(pos_type == POSITION_TYPE_BUY && short_signal)
         return true;
      if(pos_type == POSITION_TYPE_SELL && long_signal)
         return true;
     }

   return false;
  }

// Defer to the central framework news filter.
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
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
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
