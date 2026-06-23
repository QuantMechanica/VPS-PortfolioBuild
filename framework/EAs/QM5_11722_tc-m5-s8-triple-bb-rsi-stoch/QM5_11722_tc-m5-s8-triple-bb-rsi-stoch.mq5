#property strict
#property version   "5.0"
#property description "QM5_11722 tc-m5-s8-triple-bb-rsi-stoch"

#include <QM/QM_Common.mqh>

// QuantMechanica V5 EA - Carter M5 Strategy #8.
// Only strategy inputs and the five Strategy_* hooks below are EA-specific.

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11722;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_bb_period          = 50;
input double strategy_bb_entry_dev       = 2.0;
input double strategy_bb_stop_dev        = 3.0;
input double strategy_bb_outer_dev       = 4.0;
input int    strategy_rsi_period         = 3;
input double strategy_rsi_long_level     = 20.0;
input double strategy_rsi_short_level    = 80.0;
input int    strategy_stoch_k            = 6;
input int    strategy_stoch_d            = 3;
input int    strategy_stoch_slow         = 3;
input double strategy_stoch_long_setup   = 20.0;
input double strategy_stoch_short_setup  = 80.0;
input double strategy_stoch_long_confirm = 40.0;
input double strategy_stoch_short_confirm= 60.0;
input int    strategy_sl_cap_pips        = 15;

// Return TRUE to block trading this tick. The card has no extra session,
// spread, or regime filter beyond the framework news and Friday-close gates.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(_Period != PERIOD_M5)
      return false;

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const double bb2_lower_setup = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_entry_dev, 2);
   const double bb2_upper_setup = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_entry_dev, 2);
   const double bb2_lower_confirm = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_entry_dev, 1);
   const double bb2_upper_confirm = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_entry_dev, 1);
   const double bb3_lower_confirm = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_stop_dev, 1);
   const double bb3_upper_confirm = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_stop_dev, 1);
   const double target_mid = QM_SMA(_Symbol, _Period, strategy_bb_period, 1);

   if(bb2_lower_setup <= 0.0 || bb2_upper_setup <= 0.0 ||
      bb2_lower_confirm <= 0.0 || bb2_upper_confirm <= 0.0 ||
      bb3_lower_confirm <= 0.0 || bb3_upper_confirm <= 0.0 ||
      target_mid <= 0.0)
      return false;

   const double rsi_setup = QM_RSI(_Symbol, _Period, strategy_rsi_period, 2);
   const double rsi_confirm = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   const double stoch_k_setup = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 2);
   const double stoch_d_setup = QM_Stoch_D(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 2);
   const double stoch_k_confirm = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 1);
   const double stoch_d_confirm = QM_Stoch_D(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 1);

   if(rsi_setup <= 0.0 || rsi_confirm <= 0.0 ||
      stoch_k_setup < 0.0 || stoch_d_setup < 0.0 ||
      stoch_k_confirm < 0.0 || stoch_d_confirm < 0.0)
      return false;

   const double setup_low = iLow(_Symbol, _Period, 2);       // perf-allowed: closed setup bar low
   const double setup_high = iHigh(_Symbol, _Period, 2);     // perf-allowed: closed setup bar high
   const double confirm_close = iClose(_Symbol, _Period, 1); // perf-allowed: closed confirmation bar close
   if(setup_low <= 0.0 || setup_high <= 0.0 || confirm_close <= 0.0)
      return false;

   const double cap_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_cap_pips);

   const bool long_setup = (setup_low <= bb2_lower_setup) &&
                           (rsi_setup < strategy_rsi_long_level) &&
                           (stoch_k_setup < strategy_stoch_long_setup);
   const bool long_confirm = (confirm_close > bb2_lower_confirm) &&
                             (rsi_confirm > strategy_rsi_long_level) &&
                             (stoch_k_confirm >= strategy_stoch_long_confirm || stoch_k_confirm > stoch_d_confirm);
   if(long_setup && long_confirm)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;

      double sl = bb3_lower_confirm;
      if(cap_distance > 0.0 && entry - sl > cap_distance)
         sl = entry - cap_distance;
      if(sl <= 0.0 || sl >= entry || target_mid <= entry)
         return false;

      req.type = QM_BUY;
      req.sl = QM_TM_NormalizePrice(_Symbol, sl);
      req.tp = QM_TM_NormalizePrice(_Symbol, target_mid);
      req.reason = "tc_m5_s8_long";
      return true;
     }

   const bool short_setup = (setup_high >= bb2_upper_setup) &&
                            (rsi_setup > strategy_rsi_short_level) &&
                            (stoch_k_setup > strategy_stoch_short_setup);
   const bool short_confirm = (confirm_close < bb2_upper_confirm) &&
                              (rsi_confirm < strategy_rsi_short_level) &&
                              (stoch_k_confirm <= strategy_stoch_short_confirm || stoch_k_confirm < stoch_d_confirm);
   if(short_setup && short_confirm)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;

      double sl = bb3_upper_confirm;
      if(cap_distance > 0.0 && sl - entry > cap_distance)
         sl = entry + cap_distance;
      if(sl <= entry || target_mid >= entry)
         return false;

      req.type = QM_SELL;
      req.sl = QM_TM_NormalizePrice(_Symbol, sl);
      req.tp = QM_TM_NormalizePrice(_Symbol, target_mid);
      req.reason = "tc_m5_s8_short";
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
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
