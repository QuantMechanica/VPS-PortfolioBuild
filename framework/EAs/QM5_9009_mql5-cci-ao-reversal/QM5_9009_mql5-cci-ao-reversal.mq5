#property strict
#property version   "5.0"
#property description "QM5_9009 mql5-cci-ao-reversal"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9009;
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
input int    cci_signal_period      = 20;
input int    cci_trend_period       = 24;
input int    cci_buy_threshold      = -90;
input int    cci_sell_threshold     = 130;
input int    max_spread_points      = 20;
input int    cci_sl_points          = 300;
input int    cci_tp_points          = 200;

// ----------------------------------------------------------------------
// Helper functions
// ----------------------------------------------------------------------

// ----------------------------------------------------------------------
// Awesome Oscillator handle
// ----------------------------------------------------------------------
int g_ao_handle = INVALID_HANDLE;

double QM_AO(const int shift)
{
   if(g_ao_handle == INVALID_HANDLE)
   {
      g_ao_handle = iAO(_Symbol, PERIOD_M5);
      if(g_ao_handle == INVALID_HANDLE) return 0;
   }
   double buf[1];
   if(CopyBuffer(g_ao_handle, 0, shift, 1, buf) != 1) return 0;
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
   return false;

  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(HasPosition()) return false;

   const double cci_sig1 = QM_CCI(_Symbol, PERIOD_M5, cci_signal_period, 1);
   const double cci_sig2 = QM_CCI(_Symbol, PERIOD_M5, cci_signal_period, 2);
   const double cci_trend1 = QM_CCI(_Symbol, PERIOD_H1, cci_trend_period, 1);
   if(cci_sig1 <= -9999 || cci_sig2 <= -9999 || cci_trend1 <= -9999) return false;

   const double ao1 = QM_AO(1);
   const double ao2 = QM_AO(2);
   if(ao1 == 0 || ao2 == 0) return false;

   bool long_signal = false, short_signal = false;

   // BUY: CCI crosses up through -90, AO rising
   if(cci_sig2 <= cci_buy_threshold && cci_sig1 > cci_buy_threshold && ao1 > ao2 && cci_trend1 > -114 && cci_trend1 < 134)
      long_signal = true;

   // SELL: CCI crosses down through +130, AO falling
   if(!long_signal && cci_sig2 >= cci_sell_threshold && cci_sig1 < cci_sell_threshold && ao1 < ao2 && cci_trend1 > -114 && cci_trend1 < 134)
      short_signal = true;

   if(!long_signal && !short_signal) return false;

   const double entry = long_signal ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double sl = long_signal ? entry - cci_sl_points * _Point : entry + cci_sl_points * _Point;
   const double tp = long_signal ? entry + cci_tp_points * _Point : entry - cci_tp_points * _Point;

   req.type = long_signal ? QM_BUY : QM_SELL;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = long_signal ? "CCI_AO_LONG" : "CCI_AO_SHORT";
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

   const double cci_sig1 = QM_CCI(_Symbol, PERIOD_M5, cci_signal_period, 1);
   const double ao1 = QM_AO(1);
   const double ao2 = QM_AO(2);
   if(cci_sig1 <= -9999 || ao1 == 0 || ao2 == 0) return false;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;

      const ENUM_POSITION_TYPE pt = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      // Opposite confirmed signal
      bool opposite = false;
      if(pt == POSITION_TYPE_BUY)
      {
         if(cci_sig1 > cci_sell_threshold && ao1 < ao2) opposite = true;
      }
      else
      {
         if(cci_sig1 < cci_buy_threshold && ao1 > ao2) opposite = true;
      }

      if(opposite)
      {
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
         continue;
      }

      // Time stop: 96 M5 bars (~8 hours)
      const datetime entry_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int bars_held = (int)((TimeCurrent() - entry_time) / PeriodSeconds(PERIOD_M5));
      if(bars_held >= 96)
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
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_9009\",\"strategy\":\"mql5-cci-ao-reversal\"}");
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

