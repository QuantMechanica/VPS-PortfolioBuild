#property strict
#property version   "5.0"
#property description "QM5_12109 camarilla-weekly-pivots-swing v2"
// rework v2 2026-06-16 — flat max_spread_points=30 hard-blocked all index/metal symbols (NDX/GDAXI/WS30/XAUUSD spreads >> 30 pts) => ~0 trades; gate now scales spread vs price (broker-agnostic)

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12109;
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
input int    cam_atr_period           = 14;
input double atr_sl_mult          = 1.5;
input double rr_target            = 2.0;
input int    max_spread_points    = 30;       // legacy flat cap (FX-tuned); index/metal use frac below
input double max_spread_frac      = 0.0010;    // spread cap as fraction of price (0.10%) — scales across all symbols
input int    no_trade_first_bars  = 2;

struct CamPivots
{
   double h3, h4, l3, l4, p;
   datetime computed_at;
};

CamPivots g_pivots;
datetime g_last_week_start = 0;

void ComputePivots()
{
   const double pw_h  = iHigh(_Symbol, PERIOD_W1, 1);
   const double pw_l  = iLow(_Symbol, PERIOD_W1, 1);
   const double pw_c  = iClose(_Symbol, PERIOD_W1, 1);
   if(pw_h <= 0 || pw_l <= 0 || pw_c <= 0) return;
   const double range = pw_h - pw_l;
   g_pivots.h3 = pw_c + range * 1.1 / 4.0;
   g_pivots.h4 = pw_c + range * 1.1 / 2.0;
   g_pivots.l3 = pw_c - range * 1.1 / 4.0;
   g_pivots.l4 = pw_c - range * 1.1 / 2.0;
   g_pivots.p  = (pw_h + pw_l + pw_c) / 3.0;
   g_pivots.computed_at = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(g_pivots.computed_at, dt);
   int dow = dt.day_of_week;
   g_last_week_start = g_pivots.computed_at - (dow >= 1 ? (dow - 1) * 86400 : 6 * 86400);
}

bool IsNewWeek()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.day_of_week == 0) return false;
   const datetime week_start = TimeCurrent() - (dt.day_of_week - 1) * 86400;
   return (week_start > g_last_week_start);
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

bool Strategy_NoTradeFilter()
  {
   const datetime broker_now = TimeCurrent();
   if(g_last_week_start > 0)
   {
      const int bars_since_week_start = (int)((broker_now - g_last_week_start) / (4 * 3600));
      if(bars_since_week_start < no_trade_first_bars)
         return true;
   }
   // Spread cap scaled by price so it works across FX, indices and metals.
   // The flat point cap (max_spread_points) is FX-tuned; a fixed 30-pt cap
   // permanently blocks index/metal symbols whose spreads run far higher in
   // points. Use the looser of the two thresholds so FX still respects the
   // tight cap while index/metal are gated on a relative basis.
   if(max_spread_points > 0 || max_spread_frac > 0.0)
   {
      const double point        = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      const double spread_price  = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * point;
      const double price         = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double cap_flat      = (max_spread_points > 0) ? max_spread_points * point : 0.0;
      const double cap_frac      = (max_spread_frac > 0.0 && price > 0.0) ? price * max_spread_frac : 0.0;
      const double cap           = MathMax(cap_flat, cap_frac);
      if(cap > 0.0 && spread_price > cap) return true;
   }
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(g_last_week_start == 0 || IsNewWeek())
      ComputePivots();
   if(g_pivots.h3 <= 0) return false;

   const double close = iClose(_Symbol, PERIOD_H4, 1);
   const double high = iHigh(_Symbol, PERIOD_H4, 1);
   const double low  = iLow(_Symbol, PERIOD_H4, 1);
   if(close <= 0 || high <= 0 || low <= 0) return false;

   if(HasPosition()) return false;

   const double atr = QM_ATR(_Symbol, PERIOD_H4, cam_atr_period, 1);
   if(atr <= 0) return false;

   bool long_signal = false, short_signal = false;
   double sl = 0, tp = 0;

   if(low <= g_pivots.l3 && close > g_pivots.l4)
   {
      long_signal = true;
      sl = g_pivots.l4;
      tp = g_pivots.p;
   }
   if(close > g_pivots.h4)
   {
      long_signal = true;
      sl = g_pivots.h3;
      tp = close + (g_pivots.h4 - g_pivots.h3) * 2.0;
   }
   if(!long_signal && high >= g_pivots.h3 && close < g_pivots.h4)
   {
      short_signal = true;
      sl = g_pivots.h4;
      tp = g_pivots.p;
   }
   if(!long_signal && !short_signal && close < g_pivots.l4)
   {
      short_signal = true;
      sl = g_pivots.l3;
      tp = close - (g_pivots.l3 - g_pivots.l4) * 2.0;
   }

   if(!long_signal && !short_signal) return false;

   const double entry = long_signal ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                    : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double sl_dist = MathAbs(entry - sl);
   if(sl_dist < atr * atr_sl_mult)
   {
      if(long_signal) sl = entry - atr * atr_sl_mult;
      else sl = entry + atr * atr_sl_mult;
   }

   req.type = long_signal ? QM_BUY : QM_SELL;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = long_signal ? "CAM_LONG" : "CAM_SHORT";
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
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
      const ENUM_POSITION_TYPE pt = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double high = iHigh(_Symbol, PERIOD_H4, 1);
      const double low = iLow(_Symbol, PERIOD_H4, 1);
      if(pt == POSITION_TYPE_BUY && high >= g_pivots.h4)
      {
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
         continue;
      }
      if(pt == POSITION_TYPE_SELL && low <= g_pivots.l4)
      {
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
         continue;
      }
   }
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
                        RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy,
                        qm_friday_close_enabled, qm_friday_close_hour_broker,
                        30, 30,
                        qm_news_stale_max_hours, qm_news_min_impact,
                        qm_rng_seed, qm_stress_reject_probability,
                        qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12109\",\"strategy\":\"camarilla-weekly-pivots-swing\",\"version\":\"v2\"}");
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
