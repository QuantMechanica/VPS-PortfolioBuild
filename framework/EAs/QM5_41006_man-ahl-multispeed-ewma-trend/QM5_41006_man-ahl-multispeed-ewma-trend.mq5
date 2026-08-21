#property strict
#property version   "5.0"
#property description "QM5_41006 Man AHL Multi-Speed EWMA Trend"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_41006
// Man AHL Multi-Speed EWMA Composite Trend Engine
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 41006;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.5;
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
input double InpForecastThreshold       = 0.35;   // Minimum composite score threshold to enter
input int    InpVolWindow               = 60;     // Realized volatility normalizer ATR window
input int    InpAtrSlPeriod             = 14;     // Stop loss ATR period
input double InpAtrSlMult               = 2.5;    // Stop loss ATR multiplier
input double InpSpreadAtrMult           = 1.8;    // Max spread as multiple of D1 ATR(14)

// -----------------------------------------------------------------------------
// Helper math
// -----------------------------------------------------------------------------

double CalculateForecast(const int shift)
{
   const double sigma = QM_ATR(_Symbol, PERIOD_D1, InpVolWindow, shift);
   if(sigma <= 0.0)
      return 0.0;

   const int pairs_fast[6] = {2, 4, 8, 16, 32, 64};
   const int pairs_slow[6] = {8, 16, 32, 64, 128, 256};

   double sum = 0.0;
   for(int k = 0; k < 6; ++k)
   {
      const double ema_f = QM_EMA(_Symbol, PERIOD_D1, pairs_fast[k], shift);
      const double ema_s = QM_EMA(_Symbol, PERIOD_D1, pairs_slow[k], shift);
      sum += (ema_f - ema_s) / sigma;
   }

   return (sum / 6.0);
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask > 0.0 && bid > 0.0 && ask > bid)
   {
      const double atr = QM_ATR(_Symbol, PERIOD_D1, 14, 1);
      if(atr > 0.0 && (ask - bid) > InpSpreadAtrMult * atr)
         return true;
   }

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if((dt.hour == 23 && dt.min >= 55) || (dt.hour == 0 && dt.min < 5))
      return true;

   return false;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double s1 = CalculateForecast(1);
   const double s2 = CalculateForecast(2);

   const double atr = QM_ATR(_Symbol, PERIOD_D1, InpAtrSlPeriod, 1);
   if(atr <= 0.0)
      return false;

   // Long: S_t crosses above +InpForecastThreshold
   if(s1 >= InpForecastThreshold && s2 < InpForecastThreshold)
   {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(ask <= 0.0)
         return false;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = ask - InpAtrSlMult * atr;
      req.tp = 0.0;
      req.reason = "MAN_AHL_EWMA_BUY";
      req.symbol_slot = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
   }

   // Short: S_t crosses below -InpForecastThreshold
   if(s1 <= -InpForecastThreshold && s2 > -InpForecastThreshold)
   {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid <= 0.0)
         return false;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = bid + InpAtrSlMult * atr;
      req.tp = 0.0;
      req.reason = "MAN_AHL_EWMA_SELL";
      req.symbol_slot = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
   }

   return false;
}

void Strategy_ManageOpenPosition() {}

bool Strategy_ExitSignal()
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const double s1 = CalculateForecast(1);

   const int total = PositionsTotal();
   for(int i = 0; i < total; ++i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && s1 <= 0.0)
         return true;
      if(ptype == POSITION_TYPE_SELL && s1 >= 0.0)
         return true;
   }

   return false;
}

bool Strategy_NewsFilterHook(const datetime broker_time) { return false; }

// -----------------------------------------------------------------------------
// Framework wiring
// -----------------------------------------------------------------------------

int OnInit()
{
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy, qm_friday_close_enabled, qm_friday_close_hour_broker,
                        30, 30, qm_news_stale_max_hours, qm_news_min_impact, qm_rng_seed,
                        qm_stress_reject_probability, qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_41006\",\"ea\":\"man-ahl-multispeed-ewma-trend\"}");
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

   if(!QM_KillSwitchCheck()) return;
   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now)) return;
   if(QM_FrameworkHandleFridayClose()) return;
   if(Strategy_NoTradeFilter()) return;

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
   {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
      {
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
      }
   }

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows) return;

   if(!QM_IsNewBar()) return;
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req);
   if(Strategy_EntrySignal(req))
   {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
   }
}

void OnTimer() { QM_FrameworkOnTimer(); }
void OnTradeTransaction(const MqlTradeTransaction &t, const MqlTradeRequest &r, const MqlTradeResult &res)
{
   QM_FrameworkOnTradeTransaction(t, r, res);
}

double OnTester()
{
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
}
