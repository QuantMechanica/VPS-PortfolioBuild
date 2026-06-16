#property strict
#property version   "5.0"
#property description "QM5_12115 classic-pivot-points-fade-break"
// rework v2 2026-06-16 — fix permanent no-trade: end-of-day guard counted not-yet-existing next-day bars (Bars() stop_time in the future clamps to current bar => total_bars_today==bars_today => filter rejected every bar; same flaw closed every position 1 bar after entry). Replaced with broker-hour-of-day guards.

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12115;
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
input double mode_threshold          = 0.85;
input double skip_day_threshold     = 0.4;
input int    atr_d1_period          = 20;
input double atr_sl_mult            = 1.0;
input double sl_buffer_atr          = 0.3;
input int    max_spread_points      = 25;
input int    no_trade_start_bars    = 1;
input int    no_trade_end_bars      = 1;

// ----------------------------------------------------------------------
// Helper functions
// ----------------------------------------------------------------------

// ----------------------------------------------------------------------
// Classic floor-trader pivot levels (daily)
// ----------------------------------------------------------------------
double g_P, g_R1, g_R2, g_R3, g_S1, g_S2, g_S3;
datetime g_pivot_day = 0;
int g_pivot_mode = 0; // 0=unset, 1=fade, 2=break
bool g_traded_long_today = false;
bool g_traded_short_today = false;
bool g_r2_broken_today = false;
bool g_s2_broken_today = false;

void ComputePivots()
{
   const double prev_h = iHigh(_Symbol, PERIOD_D1, 1);
   const double prev_l = iLow(_Symbol, PERIOD_D1, 1);
   const double prev_c = iClose(_Symbol, PERIOD_D1, 1);
   if(prev_h <= 0 || prev_l <= 0 || prev_c <= 0) return;

   const double range = prev_h - prev_l;
   g_P = (prev_h + prev_l + prev_c) / 3.0;
   g_R1 = 2.0 * g_P - prev_l;
   g_S1 = 2.0 * g_P - prev_h;
   g_R2 = g_P + range;
   g_S2 = g_P - range;
   g_R3 = g_R1 + range;
   g_S3 = g_S1 - range;
   g_pivot_day = iTime(_Symbol, PERIOD_D1, 0);

   // Mode selection
   const double atr_baseline = QM_ATR(_Symbol, PERIOD_D1, atr_d1_period, 1);
   if(atr_baseline <= 0) { g_pivot_mode = 0; return; }
   const double range_ratio = range / atr_baseline;
   if(range_ratio < skip_day_threshold) { g_pivot_mode = 0; return; } // skip
   g_pivot_mode = (range_ratio < mode_threshold) ? 1 : 2; // 1=fade, 2=break

   g_traded_long_today = false;
   g_traded_short_today = false;
   g_r2_broken_today = false;
   g_s2_broken_today = false;
}

bool IsNewDay()
{
   const datetime d0 = iTime(_Symbol, PERIOD_D1, 0);
   if(d0 != g_pivot_day)
   {
      ComputePivots();
      return true;
   }
   return false;
}

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
   // First/last bars of broker day, gated on the broker hour of the current H1
   // bar (the closed bar we act on). The previous Bars(start, next_day_start)
   // count relied on next-day bars that do not exist yet on the forming day, so
   // it clamped to the current count and rejected every bar.
   const datetime day_start = iTime(_Symbol, PERIOD_D1, 0);
   const int hours_into_day = (int)((iTime(_Symbol, PERIOD_H1, 1) - day_start) / 3600);
   if(hours_into_day < no_trade_start_bars) return true;            // first N hours
   if(hours_into_day >= 24 - no_trade_end_bars) return true;        // last N hours
   return false;

  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   IsNewDay(); // ensures pivots computed
   if(g_pivot_mode == 0) return false; // skip day
   if(HasPosition()) return false;

   const double close1 = iClose(_Symbol, PERIOD_H1, 1);
   const double close2 = iClose(_Symbol, PERIOD_H1, 2);
   const double high1 = iHigh(_Symbol, PERIOD_H1, 1);
   const double low1 = iLow(_Symbol, PERIOD_H1, 1);
   if(close1 <= 0 || high1 <= 0 || low1 <= 0) return false;

   bool long_signal = false, short_signal = false;
   double sl = 0, tp = 0;

   if(g_pivot_mode == 1) // Fade mode: S1/R1 fade to P
   {
      if(!g_traded_long_today && low1 <= g_S1 && close1 > g_S1 && close1 > g_S2)
      {
         long_signal = true;
         sl = g_S2 - sl_buffer_atr * QM_ATR(_Symbol, PERIOD_H1, 14, 1);
         tp = g_P;
      }
      if(!long_signal && !g_traded_short_today && high1 >= g_R1 && close1 < g_R1 && close1 < g_R2)
      {
         short_signal = true;
         sl = g_R2 + sl_buffer_atr * QM_ATR(_Symbol, PERIOD_H1, 14, 1);
         tp = g_P;
      }
   }
   else if(g_pivot_mode == 2) // Break mode: S2/R2 break to S3/R3
   {
      if(!g_r2_broken_today && close1 > g_R2 && close2 <= g_R2)
      {
         long_signal = true;
         sl = g_R1;
         tp = g_R3;
         g_r2_broken_today = true;
      }
      if(!long_signal && !g_s2_broken_today && close1 < g_S2 && close2 >= g_S2)
      {
         short_signal = true;
         sl = g_S1;
         tp = g_S3;
         g_s2_broken_today = true;
      }
   }

   if(!long_signal && !short_signal) return false;

   // SL floor
   const double entry = long_signal ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double atr = QM_ATR(_Symbol, PERIOD_H1, 14, 1);
   if(atr <= 0) return false;
   double sl_dist = MathAbs(entry - sl);
   if(sl_dist < atr * atr_sl_mult)
   {
      if(long_signal) sl = entry - atr * atr_sl_mult;
      else sl = entry + atr * atr_sl_mult;
   }

   if(long_signal) g_traded_long_today = true;
   else g_traded_short_today = true;

   req.type = long_signal ? QM_BUY : QM_SELL;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = long_signal ? (g_pivot_mode == 1 ? "CPF_FADE_LONG" : "CPF_BREAK_LONG") :
                              (g_pivot_mode == 1 ? "CPF_FADE_SHORT" : "CPF_BREAK_SHORT");
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

   // End-of-day close, gated on the broker hour of the current H1 bar. The
   // previous Bars(now, next_day_start) count relied on next-day bars that do
   // not exist yet on the forming day, so it read ~1 every bar and closed
   // positions one bar after entry.
   const datetime d0 = iTime(_Symbol, PERIOD_D1, 0);
   const int hours_into_day = (int)((iTime(_Symbol, PERIOD_H1, 1) - d0) / 3600);
   if(hours_into_day >= 23)   // final H1 bar of the broker day
   {
      CloseAll(QM_EXIT_STRATEGY);
      return false;
   }

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;

      const ENUM_POSITION_TYPE pt = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double close = iClose(_Symbol, PERIOD_H1, 1);
      if(close <= 0) continue;
      const double high1 = iHigh(_Symbol, PERIOD_H1, 1);
      const double low1 = iLow(_Symbol, PERIOD_H1, 1);

      // Opposite-direction signal at same level group
      if(g_pivot_mode == 1)
      {
         if((pt == POSITION_TYPE_BUY && high1 >= g_R1) ||
            (pt == POSITION_TYPE_SELL && low1 <= g_S1))
         {
            QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
            continue;
         }
      }
      else if(g_pivot_mode == 2)
      {
         if((pt == POSITION_TYPE_BUY && close < g_R1) ||
            (pt == POSITION_TYPE_SELL && close > g_S1))
         {
            QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
            continue;
         }
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
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12115\",\"strategy\":\"classic-pivot-points-fade-break\"}");
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

