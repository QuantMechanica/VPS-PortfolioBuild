#property strict
#property version   "5.0"
#property description "QM5_10443 MQL5 Trend Momentum Session Filter"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA
// Strategy Card: QM5_10443_mql5-trend-mom
// Source: b8b5125a-c67f-5bbc-baff-33456e08f5b2
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10443;
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
input int    strategy_ema_fast                 = 50;
input int    strategy_ema_slow                 = 200;
input int    strategy_rsi_period               = 14;
input double strategy_rsi_bull_min             = 50.0;
input double strategy_rsi_bull_max             = 70.0;
input double strategy_rsi_bear_min             = 30.0;
input double strategy_rsi_bear_max             = 50.0;
input int    strategy_stoch_k                  = 5;
input int    strategy_stoch_d                  = 3;
input int    strategy_stoch_slowing            = 3;
input int    strategy_sl_pips                  = 50;
input int    strategy_tp_pips                  = 100;
input bool   strategy_session_filter_enabled   = true;
input int    strategy_london_start_hour_broker = 8;
input int    strategy_london_end_hour_broker   = 12;
input int    strategy_ny_start_hour_broker     = 13;
input int    strategy_ny_end_hour_broker       = 17;
input double strategy_ma_deadband_points       = 0.0;

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if(strategy_session_filter_enabled)
     {
      const datetime broker_time = TimeCurrent();
      const bool london = (QM_Sig_Session(broker_time,
                                          strategy_london_start_hour_broker,
                                          strategy_london_end_hour_broker) > 0);
      const bool ny = (QM_Sig_Session(broker_time,
                                      strategy_ny_start_hour_broker,
                                      strategy_ny_end_hour_broker) > 0);
      if(!london && !ny)
         return true;
     }
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

   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) > 0)
      return false;

   if(strategy_ema_fast <= 0 || strategy_ema_slow <= 0)
      return false;
   if(strategy_rsi_period <= 0 || strategy_stoch_k <= 0 || strategy_stoch_d <= 0 || strategy_stoch_slowing <= 0)
      return false;
   if(strategy_sl_pips <= 0 || strategy_tp_pips <= 0)
      return false;

   const int above_fast = QM_Sig_Price_Above_MA(_Symbol,
                                                PERIOD_CURRENT,
                                                strategy_ema_fast,
                                                strategy_ma_deadband_points,
                                                1);
   const int above_slow = QM_Sig_Price_Above_MA(_Symbol,
                                                PERIOD_CURRENT,
                                                strategy_ema_slow,
                                                strategy_ma_deadband_points,
                                                1);

   const double rsi = QM_RSI(_Symbol, PERIOD_CURRENT, strategy_rsi_period, 1);
   const double k_now = QM_Stoch_K(_Symbol,
                                   PERIOD_CURRENT,
                                   strategy_stoch_k,
                                   strategy_stoch_d,
                                   strategy_stoch_slowing,
                                   1);
   const double d_now = QM_Stoch_D(_Symbol,
                                   PERIOD_CURRENT,
                                   strategy_stoch_k,
                                   strategy_stoch_d,
                                   strategy_stoch_slowing,
                                   1);
   const double k_prev = QM_Stoch_K(_Symbol,
                                    PERIOD_CURRENT,
                                    strategy_stoch_k,
                                    strategy_stoch_d,
                                    strategy_stoch_slowing,
                                    2);
   const double d_prev = QM_Stoch_D(_Symbol,
                                    PERIOD_CURRENT,
                                    strategy_stoch_k,
                                    strategy_stoch_d,
                                    strategy_stoch_slowing,
                                    2);

   if(rsi <= 0.0 || k_now < 0.0 || d_now < 0.0 || k_prev < 0.0 || d_prev < 0.0)
      return false;

   int direction = 0;
   const bool bullish_trend = (above_fast > 0 && above_slow > 0);
   const bool bullish_rsi = (rsi >= strategy_rsi_bull_min && rsi <= strategy_rsi_bull_max);
   const bool bullish_stoch_cross = (k_prev <= d_prev && k_now > d_now);
   if(bullish_trend && bullish_rsi && bullish_stoch_cross)
      direction = 1;

   const bool bearish_trend = (above_fast < 0 && above_slow < 0);
   const bool bearish_rsi = (rsi >= strategy_rsi_bear_min && rsi <= strategy_rsi_bear_max);
   const bool bearish_stoch_cross = (k_prev >= d_prev && k_now < d_now);
   if(direction == 0 && bearish_trend && bearish_rsi && bearish_stoch_cross)
      direction = -1;

   if(direction == 0)
      return false;

   const QM_OrderType side = (direction > 0) ? QM_BUY : QM_SELL;
   const double entry = (direction > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopFixedPips(_Symbol, side, entry, strategy_sl_pips);
   const double tp = QM_TakeFixedPips(_Symbol, side, entry, strategy_tp_pips);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type = side;
   req.sl = sl;
   req.tp = tp;
   req.reason = (direction > 0) ? "MQL5_TREND_MOM_LONG" : "MQL5_TREND_MOM_SHORT";
   return true;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, partial close, or break-even management.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   // Card exits are fixed SL/TP plus framework Friday close.
   return false;
  }

// News Filter Hook (callable for P8 News Impact phase)
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring -- do NOT edit below this line unless you know why.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10443_mql5-trend-mom\"}");
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
