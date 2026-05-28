#property strict
#property version   "5.0"
#property description "QM5_9007 mql5-adx-sar"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9007;
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
input int    adx_period            = 7;
input double adx_di_threshold      = 0.34;
input double par_sar_step          = 0.02;
input double par_sar_max           = 0.2;
input double atr_sl_mult           = 1.5;
input double rr_target             = 2.0;
input int    max_spread_points     = 25;
input int    no_trade_first_bars   = 2;

// ----------------------------------------------------------------------
// Helper functions
// ----------------------------------------------------------------------

// ----------------------------------------------------------------------
// Parabolic SAR handle
// ----------------------------------------------------------------------
int g_sar_handle = INVALID_HANDLE;

double QM_SAR(const string sym, const ENUM_TIMEFRAMES tf, int shift)
{
   if(g_sar_handle == INVALID_HANDLE)
   {
      g_sar_handle = iSAR(sym, tf, par_sar_step, par_sar_max);
      if(g_sar_handle == INVALID_HANDLE) return 0;
   }
   double buf[1];
   if(CopyBuffer(g_sar_handle, 0, shift, 1, buf) != 1) return 0;
   return buf[0];
}



// ----------------------------------------------------------------------
// Shared helpers
// ----------------------------------------------------------------------
bool HasPosition()
{
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
      return true;
   }
   return false;
}

void CloseAll(const QM_ExitReason reason)
{
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
      QM_TM_ClosePosition(ticket, reason);
   }
}


// ----------------------------------------------------------------------
// Strategy hooks
// ----------------------------------------------------------------------
bool Strategy_NoTradeFilter()
  {
   if(max_spread_points > 0)
   {
      const int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread > max_spread_points) return true;
   }
   const int bars_today = Bars(_Symbol, PERIOD_H1, iTime(_Symbol, PERIOD_D1, 0), TimeCurrent());
   if(bars_today < no_trade_first_bars + 1) return true;
   return false;

  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(HasPosition()) return false;

   const double pdi1 = QM_ADX_PlusDI(_Symbol, PERIOD_H1, adx_period, 1);
   const double pdi2 = QM_ADX_PlusDI(_Symbol, PERIOD_H1, adx_period, 2);
   const double ndi1 = QM_ADX_MinusDI(_Symbol, PERIOD_H1, adx_period, 1);
   const double ndi2 = QM_ADX_MinusDI(_Symbol, PERIOD_H1, adx_period, 2);
   if(pdi1 <= 0 || ndi1 <= 0) return false;

   const double high0 = iHigh(_Symbol, PERIOD_H1, 0);
   const double low0 = iLow(_Symbol, PERIOD_H1, 0);
   const double sar0 = QM_SAR(_Symbol, PERIOD_H1, 0);
   const double sar1 = QM_SAR(_Symbol, PERIOD_H1, 1);
   if(sar0 <= 0 || sar1 <= 0) return false;

   // BUY: +DI crossed above -DI, +DI rising, ratio rising, price above SAR
   bool long_signal = false, short_signal = false;
   if(pdi2 <= ndi2 && pdi1 > ndi1 + adx_di_threshold && pdi1 > pdi2 && low0 > sar1)
      long_signal = true;
   if(!long_signal && pdi2 >= ndi2 && pdi1 < ndi1 - adx_di_threshold && pdi1 < pdi2 && high0 < sar1)
      short_signal = true;

   if(!long_signal && !short_signal) return false;

   const double entry = long_signal ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double atr = QM_ATR(_Symbol, PERIOD_H1, 14, 1);
   if(atr <= 0) return false;

   double sl = long_signal ? entry - atr * atr_sl_mult : entry + atr * atr_sl_mult;
   double tp = long_signal ? entry + (entry - sl) * rr_target : entry - (sl - entry) * rr_target;

   req.type = long_signal ? QM_BUY : QM_SELL;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = long_signal ? "ADX_SAR_LONG" : "ADX_SAR_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;

  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   if(!HasPosition()) return false;

   const double pdi1 = QM_ADX_PlusDI(_Symbol, PERIOD_H1, adx_period, 1);
   const double ndi1 = QM_ADX_MinusDI(_Symbol, PERIOD_H1, adx_period, 1);
   const double adx = QM_ADX(_Symbol, PERIOD_H1, adx_period, 1);
   const double close1 = iClose(_Symbol, PERIOD_H1, 1);
   if(pdi1 <= 0 || ndi1 <= 0 || close1 <= 0) return false;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;

      const ENUM_POSITION_TYPE pt = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      // Signal weakening: DI convergence or ADX falling
      bool weaken = false;
      if(pt == POSITION_TYPE_BUY)
      {
         if(pdi1 < ndi1 + adx_di_threshold) weaken = true;
      }
      else
      {
         if(ndi1 < pdi1 + adx_di_threshold) weaken = true;
      }

      if(weaken || adx < 20)
      {
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
         continue;
      }

      // Time stop: 48 bars
      const datetime entry_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int bars_held = (int)((TimeCurrent() - entry_time) / PeriodSeconds(PERIOD_H1));
      if(bars_held >= 48)
      {
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
         continue;
      }
   }
   return false;

  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// ----------------------------------------------------------------------
// Framework wiring
// ----------------------------------------------------------------------
int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy,
                        qm_friday_close_enabled, qm_friday_close_hour_broker,
                        30, 30,
                        qm_news_stale_max_hours, qm_news_min_impact,
                        qm_rng_seed, qm_stress_reject_probability,
                        qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_9007\",\"strategy\":\"mql5-adx-sar\"}");
   return INIT_SUCCEEDED;
  }


void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {{
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
   Strategy_ExitSignal();
   if(!QM_IsNewBar()) return;
   QM_EquityStreamOnNewBar();
   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
   {{
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
   }}
  }}


void OnTimer() {{ QM_FrameworkOnTimer(); }}
void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
  {{ QM_FrameworkOnTradeTransaction(trans, request, result); }}
double OnTester() {{ QM_ChartUI_Refresh(); return QM_DefaultObjective(); }}

