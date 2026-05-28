#property strict
#property version   "5.0"
#property description "QM5_1634 mql5-consolid-break"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1634;
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
input int    range_lookback        = 20;
input int    range_min_bars        = 10;
input double range_max_atr         = 1.5;
input double atr_sl_mult           = 1.0;
input double rr_target             = 2.0;
input int    max_spread_points     = 25;
input int    no_trade_first_bars   = 2;

// ----------------------------------------------------------------------
// Helper functions
// ----------------------------------------------------------------------

// ----------------------------------------------------------------------
// Consolidation range detection
// ----------------------------------------------------------------------
double g_consol_high = 0, g_consol_low = 0;
int g_consol_start_bar = 0;
bool g_consol_active = false;

void FindConsolidation()
{
   g_consol_high = 0;
   g_consol_low = DBL_MAX;
   double range_sum = 0;
   int range_count = 0;
   const double atr14 = QM_ATR(_Symbol, PERIOD_H1, 14, 1);
   if(atr14 <= 0) { g_consol_active = false; return; }

   for(int b = 1; b <= range_lookback; b++)
   {
      double h = iHigh(_Symbol, PERIOD_H1, b);
      double l = iLow(_Symbol, PERIOD_H1, b);
      if(h > g_consol_high) g_consol_high = h;
      if(l < g_consol_low) g_consol_low = l;
      range_sum += (h - l);
      range_count++;
   }

   if(range_count < range_min_bars) { g_consol_active = false; return; }
   double avg_range = range_sum / range_count;
   double total_range = g_consol_high - g_consol_low;

   g_consol_active = (total_range < range_max_atr * atr14);
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
   FindConsolidation();
   if(!g_consol_active) return false;

   const double close1 = iClose(_Symbol, PERIOD_H1, 1);
   if(close1 <= 0) return false;

   bool long_signal = false, short_signal = false;
   if(close1 > g_consol_high) long_signal = true;
   else if(close1 < g_consol_low) short_signal = true;
   else return false;

   const double entry = long_signal ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double atr = QM_ATR(_Symbol, PERIOD_H1, 14, 1);
   if(atr <= 0) return false;

   double sl = long_signal ? g_consol_low : g_consol_high;
   double sl_dist = MathAbs(entry - sl);
   if(sl_dist < atr * atr_sl_mult)
   {
      if(long_signal) sl = entry - atr * atr_sl_mult;
      else sl = entry + atr * atr_sl_mult;
   }
   sl_dist = MathAbs(entry - sl);
   double tp = long_signal ? entry + sl_dist * rr_target : entry - sl_dist * rr_target;

   req.type = long_signal ? QM_BUY : QM_SELL;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = long_signal ? "CON_BRK_LONG" : "CON_BRK_SHORT";
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
   const int magic = QM_FrameworkMagic();
   const double close = iClose(_Symbol, PERIOD_H1, 1);
   if(close <= 0) return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;

      const ENUM_POSITION_TYPE pt = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double mid = (g_consol_high + g_consol_low) / 2.0;

      // Re-entry into range (close back past midpoint)
      if((pt == POSITION_TYPE_BUY && close <= mid) ||
         (pt == POSITION_TYPE_SELL && close >= mid))
      {
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
         continue;
      }

      // Time stop: 24 bars
      const datetime entry_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int bars_held = (int)((TimeCurrent() - entry_time) / PeriodSeconds(PERIOD_H1));
      if(bars_held >= 24)
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
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1634\",\"strategy\":\"mql5-consolid-break\"}");
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

