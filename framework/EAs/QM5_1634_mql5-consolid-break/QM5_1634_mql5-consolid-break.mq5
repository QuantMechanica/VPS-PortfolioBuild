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

// ----------------------------------------------------------------------
// Helper functions
// ----------------------------------------------------------------------

// ----------------------------------------------------------------------
// Consolidation range detection
// ----------------------------------------------------------------------
double g_consol_high = 0, g_consol_low = 0;
bool g_consol_active = false;

void FindConsolidation()
{
   g_consol_high = 0;
   g_consol_low = 0;
   g_consol_active = false;

   // Shift 2 keeps the breakout bar out of both the range and the volatility
   // baseline used to classify that preceding range.
   const double atr14 = QM_ATR(_Symbol, PERIOD_H1, 14, 2);
   if(atr14 <= 0) { g_consol_active = false; return; }

   // The signal is close[1], so the consolidation window must end at bar 2.
   // Including bar 1 in its own high/low made close[1] > range high (or below
   // range low) impossible and starved every entry.
   double scan_high = 0.0;
   double scan_low = DBL_MAX;
   for(int b = 2; b <= range_lookback + 1; b++)
   {
      const double h = iHigh(_Symbol, PERIOD_H1, b); // perf-allowed: bounded structural OHLC scan, called only after QM_IsNewBar.
      const double l = iLow(_Symbol, PERIOD_H1, b);  // perf-allowed: bounded structural OHLC scan, called only after QM_IsNewBar.
      if(h <= 0.0 || l <= 0.0 || h < l)
        {
         g_consol_active = false;
         return;
        }
      if(h > scan_high) scan_high = h;
      if(l < scan_low) scan_low = l;

      const int candidate_bars = b - 1;
      if(candidate_bars < range_min_bars)
         continue;

      // Scale each candidate window to its own multi-bar volatility baseline.
      // Comparing a multi-bar high-low directly with one ATR is the DWX
      // zero-trade class. Retain the longest qualifying contiguous suffix.
      const double total_range = scan_high - scan_low;
      const double multi_bar_atr = atr14 * MathSqrt((double)candidate_bars);
      if(total_range > 0.0 && total_range <= range_max_atr * multi_bar_atr)
        {
         g_consol_high = scan_high;
         g_consol_low = scan_low;
         g_consol_active = true;
        }
   }
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
   if(_Period != PERIOD_H1)
      return true;
   if(range_lookback < 2 || range_min_bars < 2 ||
      range_min_bars > range_lookback || range_max_atr <= 0.0 ||
      atr_sl_mult <= 0.0 || rr_target <= 0.0)
      return true;
   return false;

  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(HasPosition()) return false;
   FindConsolidation();
   if(!g_consol_active) return false;

   const double close1 = iClose(_Symbol, PERIOD_H1, 1); // perf-allowed: one closed-bar structural breakout read after QM_IsNewBar.
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
   const double close = iClose(_Symbol, PERIOD_H1, 1); // perf-allowed: O(1) closed-bar exit reference.
   if(close <= 0) return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;

      // The entry scan leaves the triggering range in memory. After an EA or
      // terminal restart that state is intentionally absent, so skip only the
      // optional midpoint exit instead of treating DBL_MAX as a real range.
      if(g_consol_active)
        {
         const ENUM_POSITION_TYPE pt = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         const double mid = (g_consol_high + g_consol_low) / 2.0;
         if((pt == POSITION_TYPE_BUY && close <= mid) ||
            (pt == POSITION_TYPE_SELL && close >= mid))
            return true;
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
  {
   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;
   if(Strategy_NoTradeFilter())
      return;

   // Management and exits remain live through news windows. The news gate
   // below suppresses new entries only.
   Strategy_ManageOpenPosition();
   if(Strategy_ExitSignal())
     {
      CloseAll(QM_EXIT_STRATEGY);
      return;
     }

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


void OnTimer() { QM_FrameworkOnTimer(); }
void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
  { QM_FrameworkOnTradeTransaction(trans, request, result); }
double OnTester() { QM_ChartUI_Refresh(); return QM_DefaultObjective(); }

