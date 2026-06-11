#property strict
#property version   "5.0"
#property description "QM5_9518 mql5-l1-adx — ADX DI crossover entry with L1 trend slope exit filter"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_9518_mql5-l1-adx
// Entry: +DI crosses above -DI (long) or below -DI (short) with ADX > threshold.
// Exit:  opposite DI crossover gated by SMMA trend slope confirming reversal
//        (L1 trend proxy: card calls for fixed-lambda L1 slope sign at exit).
// Stop:  ATR-based catastrophic stop.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9518;
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
input int    strategy_adx_period        = 14;
input double strategy_adx_trend_level   = 25.0;  // ADX must exceed this for a valid entry
input int    strategy_l1_period         = 20;     // SMMA period proxying L1 trend slope at exit
input int    strategy_atr_period        = 14;     // ATR period for catastrophic stop
input double strategy_atr_sl_mult       = 2.0;    // ATR multiplier for stop distance

// -- No Trade Filter ----------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   return false;
  }

// -- Entry Signal -------------------------------------------------------------

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type             = QM_BUY;
   req.price            = 0.0;
   req.sl               = 0.0;
   req.tp               = 0.0;
   req.reason           = "";
   req.symbol_slot      = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const double adx_cur    = QM_ADX(_Symbol, PERIOD_CURRENT, strategy_adx_period, 1);
   const double plus_cur   = QM_ADX_PlusDI(_Symbol, PERIOD_CURRENT, strategy_adx_period, 1);
   const double minus_cur  = QM_ADX_MinusDI(_Symbol, PERIOD_CURRENT, strategy_adx_period, 1);
   const double plus_prev  = QM_ADX_PlusDI(_Symbol, PERIOD_CURRENT, strategy_adx_period, 2);
   const double minus_prev = QM_ADX_MinusDI(_Symbol, PERIOD_CURRENT, strategy_adx_period, 2);

   if(adx_cur <= 0.0 || plus_cur <= 0.0 || minus_cur <= 0.0) return false;
   if(adx_cur < strategy_adx_trend_level)                     return false;

   const bool long_cross  = (plus_prev <= minus_prev) && (plus_cur > minus_cur);
   const bool short_cross = (plus_prev >= minus_prev) && (plus_cur < minus_cur);
   if(!long_cross && !short_cross) return false;

   if(long_cross)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      req.type   = QM_BUY;
      req.price  = 0.0;  // framework resolves ask
      req.sl     = QM_StopATR(_Symbol, QM_BUY, entry, strategy_atr_period, strategy_atr_sl_mult);
      req.reason = "ADX_DI_LONG";
     }
   else
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      req.type   = QM_SELL;
      req.price  = 0.0;  // framework resolves bid
      req.sl     = QM_StopATR(_Symbol, QM_SELL, entry, strategy_atr_period, strategy_atr_sl_mult);
      req.reason = "ADX_DI_SHORT";
     }

   if(req.sl <= 0.0) return false;
   return true;
  }

// -- Trade Management ---------------------------------------------------------

void Strategy_ManageOpenPosition()
  {
   // SL-only management; no trailing or partial close.
  }

// -- Exit Signal --------------------------------------------------------------

bool Strategy_ExitSignal()
  {
   // Identify open position direction for this EA
   const int magic = QM_FrameworkMagic();
   long pos_type = -1;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetInteger(POSITION_MAGIC) == (long)magic)
        { pos_type = PositionGetInteger(POSITION_TYPE); break; }
     }
   if(pos_type < 0) return false;

   const double plus_cur   = QM_ADX_PlusDI(_Symbol, PERIOD_CURRENT, strategy_adx_period, 1);
   const double minus_cur  = QM_ADX_MinusDI(_Symbol, PERIOD_CURRENT, strategy_adx_period, 1);
   const double plus_prev  = QM_ADX_PlusDI(_Symbol, PERIOD_CURRENT, strategy_adx_period, 2);
   const double minus_prev = QM_ADX_MinusDI(_Symbol, PERIOD_CURRENT, strategy_adx_period, 2);

   // L1 trend proxy: SMMA slope sign (shift 1 = last closed, shift 2 = bar before)
   const double l1_cur  = QM_SMMA(_Symbol, PERIOD_CURRENT, strategy_l1_period, 1);
   const double l1_prev = QM_SMMA(_Symbol, PERIOD_CURRENT, strategy_l1_period, 2);
   if(l1_cur <= 0.0 || l1_prev <= 0.0) return false;

   if(pos_type == (long)POSITION_TYPE_BUY)
     {
      // Close long: DI- crosses above DI+ AND L1 trend is declining (slope negative)
      const bool opp_cross = (minus_prev <= plus_prev) && (minus_cur > plus_cur);
      const bool l1_down   = (l1_cur < l1_prev);
      return (opp_cross && l1_down);
     }
   else
     {
      // Close short: DI+ crosses above DI- AND L1 trend is rising (slope positive)
      const bool opp_cross = (plus_prev <= minus_prev) && (plus_cur > minus_cur);
      const bool l1_up     = (l1_cur > l1_prev);
      return (opp_cross && l1_up);
     }
  }

// -- News Filter Hook ---------------------------------------------------------

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
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != (long)magic) continue;
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
