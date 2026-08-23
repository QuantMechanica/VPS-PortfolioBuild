#property strict
#property version   "5.0"
#property description "QM5_9910 Bandy TEMA ADX Crossover Trend"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_9910
// Strategy: Bandy TEMA-Crossover + ADX-Confirmation Trend (Long/Short)
// Source: Howard B. Bandy, Quantitative Technical Analysis, Blue Owl Press, 2015
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 9910;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours       = 336;
input string qm_news_min_impact            = "high";
input QM_NewsMode qm_news_mode_legacy      = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_tema_fast          = 8;
input int    strategy_tema_slow          = 21;
input int    strategy_adx_period         = 14;
input double strategy_adx_threshold      = 20.0;
input int    strategy_atr_period         = 14;
input double strategy_trail_atr_mult     = 2.0;
input double strategy_catastrophic_atr_mult = 5.0;
input int    strategy_time_stop_bars     = 60;

// -----------------------------------------------------------------------------
// TEMA pooled-handle reader (MT5 iTEMA has no iMA mode; reuse framework pool).
// -----------------------------------------------------------------------------
int Strategy_IndTEMA(const string sym,
                     const ENUM_TIMEFRAMES tf,
                     const int period,
                     const ENUM_APPLIED_PRICE price = PRICE_CLOSE)
  {
   const string key = StringFormat("TEMA|%s|%d|%d|%d", sym, (int)tf, period, (int)price);
   int h = QM_IndicatorsLookup(key);
   if(h != INVALID_HANDLE)
      return h;
   h = iTEMA(sym, tf, period, 0, price);
   return QM_IndicatorsRegister(key, h);
  }

double Strategy_TEMA(const string sym,
                     const ENUM_TIMEFRAMES tf,
                     const int period,
                     const int shift = 1,
                     const ENUM_APPLIED_PRICE price = PRICE_CLOSE)
  {
   return QM_IndicatorReadBuffer(Strategy_IndTEMA(sym, tf, period, price), 0, shift);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   if((ENUM_TIMEFRAMES)_Period != PERIOD_D1)
      return true;

   return (strategy_tema_fast < 1 ||
           strategy_tema_slow <= strategy_tema_fast ||
           strategy_adx_period < 1 ||
           strategy_adx_threshold <= 0.0 ||
           strategy_atr_period < 1 ||
           strategy_trail_atr_mult <= 0.0 ||
           strategy_catastrophic_atr_mult <= 0.0 ||
           strategy_time_stop_bars < 1);
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type               = QM_BUY;
   req.price              = 0.0;
   req.sl                 = 0.0;
   req.tp                 = 0.0;
   req.reason             = "";
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) > 0)
      return false;

   const double tema_f1 = Strategy_TEMA(_Symbol, PERIOD_D1, strategy_tema_fast, 1);
   const double tema_s1 = Strategy_TEMA(_Symbol, PERIOD_D1, strategy_tema_slow, 1);
   const double tema_f2 = Strategy_TEMA(_Symbol, PERIOD_D1, strategy_tema_fast, 2);
   const double tema_s2 = Strategy_TEMA(_Symbol, PERIOD_D1, strategy_tema_slow, 2);
   const double adx_val = QM_ADX(_Symbol, PERIOD_D1, strategy_adx_period, 1);

   if(tema_f1 <= 0.0 || tema_s1 <= 0.0 || tema_f2 <= 0.0 || tema_s2 <= 0.0 || adx_val <= 0.0)
      return false;

   if(adx_val < strategy_adx_threshold)
      return false;

   int direction = 0;
   if(tema_f1 > tema_s1 && tema_f2 <= tema_s2)
      direction = 1;
   else if(tema_f1 < tema_s1 && tema_f2 >= tema_s2)
      direction = -1;
   else
      return false;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   const double entry = (direction > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double atr_val = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr_val <= 0.0)
      return false;

   const double sl_price = QM_StopATRFromValue(_Symbol, req.type, entry, atr_val, strategy_trail_atr_mult);
   if(sl_price <= 0.0)
      return false;
   if(req.type == QM_BUY  && sl_price >= entry)
      return false;
   if(req.type == QM_SELL && sl_price <= entry)
      return false;

   req.sl     = sl_price;
   req.reason = (direction > 0) ? "BANDY_TEMA_ADX_LONG" : "BANDY_TEMA_ADX_SHORT";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      QM_TM_TrailATR(ticket, strategy_atr_period, strategy_trail_atr_mult);
     }
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   if(!QM_IsNewCalendarPeriod(PERIOD_D1, _Symbol))
      return false;

   const int held_bars = QM_TM_HeldPeriodsForMagic((long)magic, _Symbol, PERIOD_D1, TimeCurrent());
   if(held_bars >= strategy_time_stop_bars)
      return true;

   const double tema_f1 = Strategy_TEMA(_Symbol, PERIOD_D1, strategy_tema_fast, 1);
   const double tema_s1 = Strategy_TEMA(_Symbol, PERIOD_D1, strategy_tema_slow, 1);
   if(tema_f1 <= 0.0 || tema_s1 <= 0.0)
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

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(pos_type == POSITION_TYPE_BUY)
        {
         if(tema_f1 < tema_s1)
            return true;
        }
      else if(pos_type == POSITION_TYPE_SELL)
        {
         if(tema_f1 > tema_s1)
            return true;
        }
     }

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring
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
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
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

   if(Strategy_NewsFilterHook(broker_now))
      return;

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req);
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
