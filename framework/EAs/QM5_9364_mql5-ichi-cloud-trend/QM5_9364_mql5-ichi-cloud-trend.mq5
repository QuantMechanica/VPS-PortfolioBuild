#property strict
#property version   "5.0"
#property description "QM5_9364 Ichimoku Cloud Trend with ADX"
// Strategy Card: QM5_9364 (mql5-ichi-cloud-trend)
// Source: Stephen Njuki, MQL5 Wizard Techniques Part 73, Pattern 8.
// G0 APPROVED 2026-05-19.

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9364;
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
input int    strategy_tenkan_period     = 9;
input int    strategy_kijun_period      = 26;
input int    strategy_senkou_period     = 52;
input int    strategy_adx_period        = 14;
input double strategy_adx_min           = 25.0;
input int    strategy_atr_period        = 14;
input double strategy_sl_atr_mult       = 1.0;
input int    strategy_max_hold_bars     = 72;

bool GetOurPosition(ENUM_POSITION_TYPE &ptype, datetime &open_time)
  {
   ptype = POSITION_TYPE_BUY;
   open_time = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

bool ReadPatternInputs(const int cloud_shift, double &close_curr, double &close_prev,
                       double &span_a_curr, double &span_a_prev,
                       double &span_b_curr)
  {
   close_curr = iClose(_Symbol, _Period, 1); // perf-allowed: card requires closed-bar Close[0].
   close_prev = iClose(_Symbol, _Period, 2); // perf-allowed: card requires closed-bar Close[1].
   span_a_curr = QM_Ichimoku_SenkouSpanA(_Symbol, _Period,
                                         strategy_tenkan_period,
                                         strategy_kijun_period,
                                         strategy_senkou_period,
                                         cloud_shift);
   span_a_prev = QM_Ichimoku_SenkouSpanA(_Symbol, _Period,
                                         strategy_tenkan_period,
                                         strategy_kijun_period,
                                         strategy_senkou_period,
                                         cloud_shift + 1);
   span_b_curr = QM_Ichimoku_SenkouSpanB(_Symbol, _Period,
                                         strategy_tenkan_period,
                                         strategy_kijun_period,
                                         strategy_senkou_period,
                                         cloud_shift);

   return close_curr > 0.0 && close_prev > 0.0 &&
          span_a_curr > 0.0 && span_a_prev > 0.0 && span_b_curr > 0.0;
  }

int Pattern8Signal()
  {
   const int cloud_shift = strategy_kijun_period + 1;

   double close_curr, close_prev, span_a_curr, span_a_prev, span_b_curr;
   if(!ReadPatternInputs(cloud_shift, close_curr, close_prev,
                         span_a_curr, span_a_prev, span_b_curr))
      return 0;

   const double adx = QM_ADX(_Symbol, _Period, strategy_adx_period, 1);
   if(adx < strategy_adx_min)
      return 0;

   if(close_prev < close_curr &&
      close_prev > span_a_prev &&
      close_curr > span_a_curr &&
      span_a_curr > span_b_curr)
      return 1;

   if(close_prev > close_curr &&
      close_prev < span_a_prev &&
      close_curr < span_a_curr &&
      span_a_curr < span_b_curr)
      return -1;

   return 0;
  }

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

   ENUM_POSITION_TYPE ptype;
   datetime open_time;
   if(GetOurPosition(ptype, open_time))
      return false;

   const int signal = Pattern8Signal();
   if(signal == 0)
      return false;

   const int cloud_shift = strategy_kijun_period + 1;
   const double span_a = QM_Ichimoku_SenkouSpanA(_Symbol, _Period,
                                                 strategy_tenkan_period,
                                                 strategy_kijun_period,
                                                 strategy_senkou_period,
                                                 cloud_shift);
   const double span_b = QM_Ichimoku_SenkouSpanB(_Symbol, _Period,
                                                 strategy_tenkan_period,
                                                 strategy_kijun_period,
                                                 strategy_senkou_period,
                                                 cloud_shift);
   const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(span_a <= 0.0 || span_b <= 0.0 || atr <= 0.0)
      return false;

   if(signal > 0)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double sl = MathMin(span_a, span_b) - strategy_sl_atr_mult * atr;
      if(entry <= 0.0 || sl >= entry)
         return false;

      req.type = QM_BUY;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, sl);
      req.reason = "ICHI_CLOUD_TREND_BUY";
      return true;
     }

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double sl = MathMax(span_a, span_b) + strategy_sl_atr_mult * atr;
   if(entry <= 0.0 || sl <= entry)
      return false;

   req.type = QM_SELL;
   req.sl = QM_StopRulesNormalizePrice(_Symbol, sl);
   req.reason = "ICHI_CLOUD_TREND_SELL";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, partial, or pyramiding management.
  }

bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE ptype;
   datetime open_time;
   if(!GetOurPosition(ptype, open_time))
      return false;

   const int hold_limit_secs = strategy_max_hold_bars * PeriodSeconds(_Period);
   if(hold_limit_secs > 0 && (int)(TimeCurrent() - open_time) >= hold_limit_secs)
      return true;

   const int signal = Pattern8Signal();
   if(ptype == POSITION_TYPE_BUY && signal < 0)
      return true;
   if(ptype == POSITION_TYPE_SELL && signal > 0)
      return true;

   const int cloud_shift = strategy_kijun_period + 1;
   const double close_curr = iClose(_Symbol, _Period, 1); // perf-allowed: cloud re-entry exit uses latest closed close.
   const double span_a = QM_Ichimoku_SenkouSpanA(_Symbol, _Period,
                                                 strategy_tenkan_period,
                                                 strategy_kijun_period,
                                                 strategy_senkou_period,
                                                 cloud_shift);
   const double span_b = QM_Ichimoku_SenkouSpanB(_Symbol, _Period,
                                                 strategy_tenkan_period,
                                                 strategy_kijun_period,
                                                 strategy_senkou_period,
                                                 cloud_shift);
   if(close_curr <= 0.0 || span_a <= 0.0 || span_b <= 0.0)
      return false;

   const double cloud_top = MathMax(span_a, span_b);
   const double cloud_bottom = MathMin(span_a, span_b);
   if(ptype == POSITION_TYPE_BUY && close_curr <= cloud_top)
      return true;
   if(ptype == POSITION_TYPE_SELL && close_curr >= cloud_bottom)
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

   QM_LogEvent(QM_INFO, "INIT_OK",
               StringFormat("{\"card\":\"QM5_9364\",\"ea\":\"mql5-ichi-cloud-trend\","
                            "\"tenkan\":%d,\"kijun\":%d,\"senkou\":%d,\"adx_min\":%.1f}",
                            strategy_tenkan_period, strategy_kijun_period,
                            strategy_senkou_period, strategy_adx_min));
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
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
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
