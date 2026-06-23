#property strict
#property version   "5.0"
#property description "QM5_11227 ft-rsmooth - Reinforced Smooth Scalp"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11227;
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
input ENUM_TIMEFRAMES strategy_resample_tf = PERIOD_M5;
input int    strategy_resample_sma_period  = 50;
input int    strategy_stoch_k_period       = 5;
input int    strategy_stoch_d_period       = 3;
input int    strategy_stoch_slowing        = 3;
input int    strategy_mfi_period           = 14;
input double strategy_buy_mfi              = 22.0;
input double strategy_buy_fastd            = 30.0;
input int    strategy_adx_period           = 14;
input double strategy_buy_adx              = 32.0;
input int    strategy_ema_exit_period      = 5;
input int    strategy_cci_period           = 20;
input double strategy_sell_fastd           = 79.0;
input double strategy_sell_fastk           = 70.0;
input double strategy_sell_cci             = 183.0;
input int    strategy_atr_period           = 14;
input double strategy_sl_atr_mult          = 1.0;
input double strategy_roi_target_pct       = 2.0;
input double strategy_disaster_stop_pct    = 10.0;
input double strategy_spread_pct_of_stop   = 4.0;
input int    strategy_warmup_bars          = 260;

bool Strategy_NoTradeFilter()
  {
   if(Bars(_Symbol, _Period) < strategy_warmup_bars) // perf-allowed: O(1) warmup check
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0 || strategy_sl_atr_mult <= 0.0)
      return true;

   const double stop_distance = atr_value * strategy_sl_atr_mult;
   if(stop_distance <= 0.0)
      return true;

   const double spread = ask - bid;
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

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

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(Bars(_Symbol, _Period) < strategy_warmup_bars) // perf-allowed: O(1) warmup check
      return false;

   const long volume_1 = iVolume(_Symbol, _Period, 1); // perf-allowed: source volume>0 closed-bar gate
   if(volume_1 <= 0)
      return false;

   const double close_1 = iClose(_Symbol, _Period, 1); // perf-allowed: source close vs M5 SMA state
   if(close_1 <= 0.0)
      return false;

   const double resample_sma = QM_SMA(_Symbol, strategy_resample_tf, strategy_resample_sma_period, 1);
   if(resample_sma <= 0.0 || !(resample_sma < close_1))
      return false;

   const double mfi = QM_MFI(_Symbol, _Period, strategy_mfi_period, 1);
   if(mfi <= 0.0 || !(mfi < strategy_buy_mfi))
      return false;

   const double fastd_1 = QM_Stoch_D(_Symbol, _Period, strategy_stoch_k_period,
                                     strategy_stoch_d_period, strategy_stoch_slowing, 1);
   if(fastd_1 <= 0.0 || !(fastd_1 < strategy_buy_fastd))
      return false;

   const double adx = QM_ADX(_Symbol, _Period, strategy_adx_period, 1);
   if(adx <= 0.0 || !(adx > strategy_buy_adx))
      return false;

   const double fastk_1 = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k_period,
                                     strategy_stoch_d_period, strategy_stoch_slowing, 1);
   const double fastk_2 = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k_period,
                                     strategy_stoch_d_period, strategy_stoch_slowing, 2);
   const double fastd_2 = QM_Stoch_D(_Symbol, _Period, strategy_stoch_k_period,
                                     strategy_stoch_d_period, strategy_stoch_slowing, 2);
   if(fastk_1 <= 0.0 || fastk_2 <= 0.0 || fastd_2 <= 0.0)
      return false;
   if(!(fastk_2 <= fastd_2 && fastk_1 > fastd_1))
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   double sl = QM_StopATR(_Symbol, QM_BUY, entry, strategy_atr_period, strategy_sl_atr_mult);
   if(sl <= 0.0)
      return false;

   if(strategy_disaster_stop_pct > 0.0)
     {
      const double disaster_sl = QM_StopRulesNormalizePrice(_Symbol, entry * (1.0 - strategy_disaster_stop_pct / 100.0));
      if(disaster_sl > 0.0 && sl < disaster_sl)
         sl = disaster_sl;
     }

   const double tp = QM_StopRulesNormalizePrice(_Symbol, entry * (1.0 + strategy_roi_target_pct / 100.0));
   if(tp <= entry || sl >= entry)
      return false;

   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = "ft_rsmooth_long";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   const long volume_1 = iVolume(_Symbol, _Period, 1); // perf-allowed: source volume>0 closed-bar gate
   if(volume_1 <= 0)
      return false;

   const double open_1 = iOpen(_Symbol, _Period, 1); // perf-allowed: source open>EMA(high) closed-bar rule
   if(open_1 <= 0.0)
      return false;

   const double ema_high = QM_EMA(_Symbol, _Period, strategy_ema_exit_period, 1, PRICE_HIGH);
   if(ema_high <= 0.0 || !(open_1 > ema_high))
      return false;

   const double fastd_1 = QM_Stoch_D(_Symbol, _Period, strategy_stoch_k_period,
                                     strategy_stoch_d_period, strategy_stoch_slowing, 1);
   const double fastk_1 = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k_period,
                                     strategy_stoch_d_period, strategy_stoch_slowing, 1);
   if(fastd_1 <= 0.0 || fastk_1 <= 0.0)
      return false;
   if(!(fastd_1 > strategy_sell_fastd))
      return false;
   if(!(fastk_1 > strategy_sell_fastk))
      return false;

   const double cci = QM_CCI(_Symbol, _Period, strategy_cci_period, 1);
   if(!(cci > strategy_sell_cci))
      return false;

   return true;
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
