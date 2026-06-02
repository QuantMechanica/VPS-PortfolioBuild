#property strict
#property version   "5.0"
#property description "QM5_10163_v2 TradingView RSI MACD Long Only — V2 rebuild"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10163;
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
input ENUM_TIMEFRAMES strategy_signal_tf          = PERIOD_H1;
input int             strategy_rsi_period         = 14;
input double          strategy_rsi_midline        = 50.0;
input int             strategy_macd_fast          = 12;
input int             strategy_macd_slow          = 26;
input int             strategy_macd_signal        = 9;
input bool            strategy_require_macd_gt0   = true;
input bool            strategy_use_ema_filter     = true;
input int             strategy_ema_period         = 200;
input bool            strategy_use_oversold_ctx   = false;
input int             strategy_oversold_lookback  = 20;
input double          strategy_oversold_level     = 30.0;
input int             strategy_atr_period         = 14;
input double          strategy_sl_percent         = 1.5;
input double          strategy_tp_percent         = 3.0;
input double          strategy_min_sl_atr_mult    = 1.0;

bool Strategy_NoTradeFilter()
  {
   if(strategy_rsi_period <= 0 ||
      strategy_macd_fast <= 0 ||
      strategy_macd_slow <= strategy_macd_fast ||
      strategy_macd_signal <= 0 ||
      strategy_ema_period <= 0 ||
      strategy_atr_period <= 0 ||
      strategy_sl_percent <= 0.0 ||
      strategy_tp_percent <= 0.0 ||
      strategy_min_sl_atr_mult < 0.0 ||
      strategy_oversold_lookback < 0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "TV_RSI_MACD_LONG";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) > 0)
      return false;

   const double close_1 = iClose(_Symbol, strategy_signal_tf, 1);
   if(close_1 <= 0.0)
      return false;

   if(strategy_use_ema_filter)
     {
      const double ema_1 = QM_EMA(_Symbol, strategy_signal_tf, strategy_ema_period, 1, PRICE_CLOSE);
      if(ema_1 <= 0.0 || close_1 <= ema_1)
         return false;
     }

   if(strategy_use_oversold_ctx)
     {
      bool oversold_seen = false;
      const int lookback = MathMax(1, strategy_oversold_lookback);
      for(int shift = 1; shift <= lookback; ++shift)
        {
         const double rsi_ctx = QM_RSI(_Symbol, strategy_signal_tf, strategy_rsi_period, shift, PRICE_CLOSE);
         if(rsi_ctx > 0.0 && rsi_ctx < strategy_oversold_level)
           {
            oversold_seen = true;
            break;
           }
        }
      if(!oversold_seen)
         return false;
     }

   const double rsi_1 = QM_RSI(_Symbol, strategy_signal_tf, strategy_rsi_period, 1, PRICE_CLOSE);
   const double rsi_2 = QM_RSI(_Symbol, strategy_signal_tf, strategy_rsi_period, 2, PRICE_CLOSE);
   const double macd_1 = QM_MACD_Main(_Symbol, strategy_signal_tf, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1, PRICE_CLOSE);
   const double macd_2 = QM_MACD_Main(_Symbol, strategy_signal_tf, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 2, PRICE_CLOSE);
   const double sig_1 = QM_MACD_Signal(_Symbol, strategy_signal_tf, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1, PRICE_CLOSE);
   const double sig_2 = QM_MACD_Signal(_Symbol, strategy_signal_tf, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 2, PRICE_CLOSE);

   if(rsi_1 <= 0.0 || rsi_2 <= 0.0)
      return false;
   if(strategy_require_macd_gt0 && macd_1 <= 0.0)
      return false;

   const bool rsi_cross_up = (rsi_2 <= strategy_rsi_midline && rsi_1 > strategy_rsi_midline);
   const bool macd_cross_up = (macd_2 <= sig_2 && macd_1 > sig_1);
   const bool entry_a = (rsi_cross_up && macd_1 > sig_1);
   const bool entry_b = (macd_cross_up && rsi_1 >= strategy_rsi_midline);
   if(!entry_a && !entry_b)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || point <= 0.0)
      return false;

   double sl_distance = ask * strategy_sl_percent / 100.0;
   const double atr_1 = QM_ATR(_Symbol, strategy_signal_tf, strategy_atr_period, 1);
   if(atr_1 > 0.0)
      sl_distance = MathMax(sl_distance, atr_1 * strategy_min_sl_atr_mult);

   if(sl_distance <= point)
      return false;

   req.price = 0.0;
   req.sl = NormalizeDouble(ask - sl_distance, _Digits);
   req.tp = NormalizeDouble(ask * (1.0 + strategy_tp_percent / 100.0), _Digits);
   req.reason = entry_a ? "TV_RSI_CROSS_MACD_LONG" : "TV_MACD_CROSS_RSI_LONG";
   return true;
  }

void Strategy_ManageOpenPosition() { }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double rsi_1 = QM_RSI(_Symbol, strategy_signal_tf, strategy_rsi_period, 1, PRICE_CLOSE);
   const double rsi_2 = QM_RSI(_Symbol, strategy_signal_tf, strategy_rsi_period, 2, PRICE_CLOSE);
   const double macd_1 = QM_MACD_Main(_Symbol, strategy_signal_tf, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1, PRICE_CLOSE);
   const double macd_2 = QM_MACD_Main(_Symbol, strategy_signal_tf, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 2, PRICE_CLOSE);
   const double sig_1 = QM_MACD_Signal(_Symbol, strategy_signal_tf, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1, PRICE_CLOSE);
   const double sig_2 = QM_MACD_Signal(_Symbol, strategy_signal_tf, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 2, PRICE_CLOSE);

   const bool rsi_cross_down = (rsi_2 >= strategy_rsi_midline && rsi_1 < strategy_rsi_midline);
   const bool macd_cross_down = (macd_2 >= sig_2 && macd_1 < sig_1 && (macd_1 - sig_1) <= 0.0);
   if(rsi_cross_down || macd_cross_down)
      return true;
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED,
                        PORTFOLIO_WEIGHT, qm_news_mode_legacy, qm_friday_close_enabled,
                        qm_friday_close_hour_broker, 30, 30, qm_news_stale_max_hours,
                        qm_news_min_impact, qm_rng_seed, qm_stress_reject_probability,
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
   if(!QM_KillSwitchCheck()) return;
   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now)) return;
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows) return;
   if(QM_FrameworkHandleFridayClose()) return;
   if(Strategy_NoTradeFilter()) return;
   Strategy_ManageOpenPosition();
   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }
   if(!QM_IsNewBar()) return;
   QM_EquityStreamOnNewBar();
   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
     {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
     }
  }

void OnTimer() { QM_FrameworkOnTimer(); }

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
