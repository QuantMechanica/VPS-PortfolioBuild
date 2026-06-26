#property strict
#property version   "5.0"
#property description "QM5_11319 TC M5 System #11 - H4 EMA bias + M5 momentum stack"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA
// Strategy Card: QM5_11319_tc-m5-11-mtf-ema-rsi-stoch-macd
// Source: Thomas Carter, 20 Forex Trading Strategies (5 Minute Time Frame),
//         5 Min Trading System #11, pages 28-29.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11319;
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
input int    strategy_h4_ema_fast       = 5;
input int    strategy_h4_ema_slow       = 10;
input int    strategy_m5_ema_fast       = 5;
input int    strategy_m5_ema_slow       = 10;
input int    strategy_rsi_period        = 14;
input double strategy_rsi_midline       = 50.0;
input int    strategy_stoch_k           = 5;
input int    strategy_stoch_d           = 3;
input int    strategy_stoch_slowing     = 3;
input double strategy_stoch_long_cap    = 80.0;
input double strategy_stoch_short_floor = 20.0;
input int    strategy_macd_fast         = 12;
input int    strategy_macd_slow         = 26;
input int    strategy_macd_signal       = 9;
input int    strategy_stop_pips         = 25;
input int    strategy_take_pips         = 25;

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// No Trade Filter: the card defines no extra time/spread/session filter beyond
// framework news, Friday close, kill-switch, and H4 trend-bias entry state.
bool Strategy_NoTradeFilter()
  {
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

   if(strategy_h4_ema_fast <= 0 || strategy_h4_ema_slow <= 0 ||
      strategy_m5_ema_fast <= 0 || strategy_m5_ema_slow <= 0 ||
      strategy_rsi_period <= 0 || strategy_stoch_k <= 0 ||
      strategy_stoch_d <= 0 || strategy_stoch_slowing <= 0 ||
      strategy_macd_fast <= 0 || strategy_macd_slow <= 0 ||
      strategy_macd_signal <= 0 || strategy_stop_pips <= 0 ||
      strategy_take_pips <= 0)
      return false;

   const ENUM_TIMEFRAMES exec_tf = (ENUM_TIMEFRAMES)_Period;

   const double h4_ema_fast = QM_EMA(_Symbol, PERIOD_H4, strategy_h4_ema_fast, 1);
   const double h4_ema_slow = QM_EMA(_Symbol, PERIOD_H4, strategy_h4_ema_slow, 1);
   if(h4_ema_fast <= 0.0 || h4_ema_slow <= 0.0)
      return false;

   const double ema_fast_1 = QM_EMA(_Symbol, exec_tf, strategy_m5_ema_fast, 1);
   const double ema_slow_1 = QM_EMA(_Symbol, exec_tf, strategy_m5_ema_slow, 1);
   const double ema_fast_2 = QM_EMA(_Symbol, exec_tf, strategy_m5_ema_fast, 2);
   const double ema_slow_2 = QM_EMA(_Symbol, exec_tf, strategy_m5_ema_slow, 2);
   if(ema_fast_1 <= 0.0 || ema_slow_1 <= 0.0 || ema_fast_2 <= 0.0 || ema_slow_2 <= 0.0)
      return false;

   const double rsi_1 = QM_RSI(_Symbol, exec_tf, strategy_rsi_period, 1, PRICE_CLOSE);
   if(rsi_1 <= 0.0)
      return false;

   const double stoch_k_1 = QM_Stoch_K(_Symbol, exec_tf,
                                       strategy_stoch_k,
                                       strategy_stoch_d,
                                       strategy_stoch_slowing,
                                       1);
   const double stoch_k_2 = QM_Stoch_K(_Symbol, exec_tf,
                                       strategy_stoch_k,
                                       strategy_stoch_d,
                                       strategy_stoch_slowing,
                                       2);
   if(stoch_k_1 < 0.0 || stoch_k_2 < 0.0)
      return false;

   const double macd_main_1 = QM_MACD_Main(_Symbol, exec_tf,
                                           strategy_macd_fast,
                                           strategy_macd_slow,
                                           strategy_macd_signal,
                                           1,
                                           PRICE_CLOSE);
   const double macd_sig_1 = QM_MACD_Signal(_Symbol, exec_tf,
                                            strategy_macd_fast,
                                            strategy_macd_slow,
                                            strategy_macd_signal,
                                            1,
                                            PRICE_CLOSE);
   const double macd_main_2 = QM_MACD_Main(_Symbol, exec_tf,
                                           strategy_macd_fast,
                                           strategy_macd_slow,
                                           strategy_macd_signal,
                                           2,
                                           PRICE_CLOSE);
   const double macd_sig_2 = QM_MACD_Signal(_Symbol, exec_tf,
                                            strategy_macd_fast,
                                            strategy_macd_slow,
                                            strategy_macd_signal,
                                            2,
                                            PRICE_CLOSE);
   const double hist_1 = macd_main_1 - macd_sig_1;
   const double hist_2 = macd_main_2 - macd_sig_2;

   const bool long_bias = (h4_ema_fast > h4_ema_slow);
   const bool short_bias = (h4_ema_fast < h4_ema_slow);
   const bool long_cross = (ema_fast_2 <= ema_slow_2 && ema_fast_1 > ema_slow_1);
   const bool short_cross = (ema_fast_2 >= ema_slow_2 && ema_fast_1 < ema_slow_1);
   const bool long_stoch = (stoch_k_1 > stoch_k_2 && stoch_k_1 < strategy_stoch_long_cap);
   const bool short_stoch = (stoch_k_1 < stoch_k_2 && stoch_k_1 > strategy_stoch_short_floor);
   const bool long_macd = ((hist_2 <= 0.0 && hist_1 > 0.0) ||
                           (hist_1 < 0.0 && hist_1 > hist_2));
   const bool short_macd = ((hist_2 >= 0.0 && hist_1 < 0.0) ||
                            (hist_1 > 0.0 && hist_1 < hist_2));

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(long_bias && long_cross && rsi_1 > strategy_rsi_midline && long_stoch && long_macd)
     {
      const double entry = ask;
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = QM_StopFixedPips(_Symbol, req.type, entry, strategy_stop_pips);
      req.tp = QM_TakeFixedPips(_Symbol, req.type, entry, strategy_take_pips);
      req.reason = "TC_M5_11_LONG";
      return (req.sl > 0.0 && req.tp > 0.0);
     }

   if(short_bias && short_cross && rsi_1 < strategy_rsi_midline && short_stoch && short_macd)
     {
      const double entry = bid;
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = QM_StopFixedPips(_Symbol, req.type, entry, strategy_stop_pips);
      req.tp = QM_TakeFixedPips(_Symbol, req.type, entry, strategy_take_pips);
      req.reason = "TC_M5_11_SHORT";
      return (req.sl > 0.0 && req.tp > 0.0);
     }

   return false;
  }

// Trade Management: the card specifies fixed SL/TP only, with no trailing,
// break-even, partial close, scale-in, or time stop.
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close: the card has no discretionary indicator exit; positions close by
// SL/TP or framework-level Friday/news/kill-switch handling.
bool Strategy_ExitSignal()
  {
   return false;
  }

// News Filter Hook: no strategy-specific news suppression beyond framework mode.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line unless you know why.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_11319\",\"strategy\":\"tc_m5_11_mtf_ema_rsi_stoch_macd\"}");
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
