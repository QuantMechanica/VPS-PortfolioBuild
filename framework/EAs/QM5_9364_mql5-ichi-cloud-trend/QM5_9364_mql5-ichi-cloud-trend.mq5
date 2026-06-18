#property strict
#property version   "5.0"
#property description "QM5_9364 Ichimoku Cloud Trend with ADX"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails).
// =============================================================================

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

// -----------------------------------------------------------------------------
// Strategy hooks - implemented mechanically from the approved card.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only - runs on every tick.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
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
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }

   if(strategy_tenkan_period <= 0 ||
      strategy_kijun_period <= 0 ||
      strategy_senkou_period <= 0 ||
      strategy_adx_period <= 1 ||
      strategy_atr_period <= 1 ||
      strategy_sl_atr_mult <= 0.0)
      return false;

   double closes[];
   ArraySetAsSeries(closes, true);
   if(CopyClose(_Symbol, _Period, 1, 2, closes) != 2) // perf-allowed: EntrySignal is called only after QM_IsNewBar().
      return false;

   const double close_curr = closes[0];
   const double close_prev = closes[1];
   if(close_curr <= 0.0 || close_prev <= 0.0)
      return false;

   const int cloud_shift_curr = strategy_kijun_period + 1;
   const int cloud_shift_prev = strategy_kijun_period + 2;
   const double span_a_curr = QM_Ichimoku_SenkouSpanA(_Symbol, _Period,
                                                       strategy_tenkan_period,
                                                       strategy_kijun_period,
                                                       strategy_senkou_period,
                                                       cloud_shift_curr);
   const double span_a_prev = QM_Ichimoku_SenkouSpanA(_Symbol, _Period,
                                                       strategy_tenkan_period,
                                                       strategy_kijun_period,
                                                       strategy_senkou_period,
                                                       cloud_shift_prev);
   const double span_b_curr = QM_Ichimoku_SenkouSpanB(_Symbol, _Period,
                                                       strategy_tenkan_period,
                                                       strategy_kijun_period,
                                                       strategy_senkou_period,
                                                       cloud_shift_curr);
   const double adx = QM_ADX(_Symbol, _Period, strategy_adx_period, 1);
   const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(span_a_curr <= 0.0 ||
      span_a_prev <= 0.0 ||
      span_b_curr <= 0.0 ||
      adx < strategy_adx_min ||
      atr <= 0.0)
      return false;

   if(close_prev < close_curr &&
      close_prev > span_a_prev &&
      close_curr > span_a_curr &&
      span_a_curr > span_b_curr)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double sl = MathMin(span_a_curr, span_b_curr) - (strategy_sl_atr_mult * atr);
      if(entry <= 0.0 || sl <= 0.0 || sl >= entry)
         return false;

      req.type = QM_BUY;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, sl);
      req.reason = "ICHI_CLOUD_TREND_BUY";
      return true;
     }

   if(close_prev > close_curr &&
      close_prev < span_a_prev &&
      close_curr < span_a_curr &&
      span_a_curr < span_b_curr)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double sl = MathMax(span_a_curr, span_b_curr) + (strategy_sl_atr_mult * atr);
      if(entry <= 0.0 || sl <= 0.0 || sl <= entry)
         return false;

      req.type = QM_SELL;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, sl);
      req.reason = "ICHI_CLOUD_TREND_SELL";
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, partial, or pyramiding management.
  }

// Return TRUE to close the open position now.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   bool have_position = false;
   ENUM_POSITION_TYPE ptype = POSITION_TYPE_BUY;
   datetime open_time = 0;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      have_position = true;
      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      break;
     }

   if(!have_position)
      return false;

   const int hold_limit_seconds = strategy_max_hold_bars * PeriodSeconds(_Period);
   if(hold_limit_seconds > 0 && (int)(TimeCurrent() - open_time) >= hold_limit_seconds)
      return true;

   if(strategy_tenkan_period <= 0 ||
      strategy_kijun_period <= 0 ||
      strategy_senkou_period <= 0 ||
      strategy_adx_period <= 1)
      return false;

   double closes[];
   ArraySetAsSeries(closes, true);
   if(CopyClose(_Symbol, _Period, 1, 2, closes) != 2) // perf-allowed: O(1) closed-bar exit check.
      return false;

   const double close_curr = closes[0];
   const double close_prev = closes[1];
   if(close_curr <= 0.0 || close_prev <= 0.0)
      return false;

   const int cloud_shift_curr = strategy_kijun_period + 1;
   const int cloud_shift_prev = strategy_kijun_period + 2;
   const double span_a_curr = QM_Ichimoku_SenkouSpanA(_Symbol, _Period,
                                                       strategy_tenkan_period,
                                                       strategy_kijun_period,
                                                       strategy_senkou_period,
                                                       cloud_shift_curr);
   const double span_a_prev = QM_Ichimoku_SenkouSpanA(_Symbol, _Period,
                                                       strategy_tenkan_period,
                                                       strategy_kijun_period,
                                                       strategy_senkou_period,
                                                       cloud_shift_prev);
   const double span_b_curr = QM_Ichimoku_SenkouSpanB(_Symbol, _Period,
                                                       strategy_tenkan_period,
                                                       strategy_kijun_period,
                                                       strategy_senkou_period,
                                                       cloud_shift_curr);
   if(span_a_curr <= 0.0 || span_a_prev <= 0.0 || span_b_curr <= 0.0)
      return false;

   const double adx = QM_ADX(_Symbol, _Period, strategy_adx_period, 1);
   int signal = 0;
   if(adx >= strategy_adx_min)
     {
      if(close_prev < close_curr &&
         close_prev > span_a_prev &&
         close_curr > span_a_curr &&
         span_a_curr > span_b_curr)
         signal = 1;
      else if(close_prev > close_curr &&
              close_prev < span_a_prev &&
              close_curr < span_a_curr &&
              span_a_curr < span_b_curr)
         signal = -1;
     }

   if(ptype == POSITION_TYPE_BUY && signal < 0)
      return true;
   if(ptype == POSITION_TYPE_SELL && signal > 0)
      return true;

   const double cloud_top = MathMax(span_a_curr, span_b_curr);
   const double cloud_bottom = MathMin(span_a_curr, span_b_curr);
   if(ptype == POSITION_TYPE_BUY && close_curr <= cloud_top)
      return true;
   if(ptype == POSITION_TYPE_SELL && close_curr >= cloud_bottom)
      return true;

   return false;
  }

// Optional news-filter override.
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
