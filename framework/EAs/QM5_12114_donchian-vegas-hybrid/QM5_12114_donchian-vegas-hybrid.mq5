#property strict
#property version   "5.0"
#property description "QM5_12114 donchian-vegas-hybrid"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12114;
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
input int    ema_fast_period        = 144;
input int    ema_slow_period        = 169;
input int    donchian_period        = 20;
input double tunnel_thickness_atr   = 0.3;
input double atr_sl_mult            = 1.5;
input double rr_target              = 2.0;
input int    max_spread_points      = 25;
input int    no_trade_first_bars    = 2;

// ----------------------------------------------------------------------
// Helper functions
// ----------------------------------------------------------------------

// ----------------------------------------------------------------------
// Donchian helpers
// ----------------------------------------------------------------------
double DonchianHigh(const int shift)
{
   double hh = 0;
   for(int i = 1; i <= donchian_period; i++)
   {
      double h = iHigh(_Symbol, PERIOD_H1, shift + i);
      if(h > hh) hh = h;
   }
   return hh;
}

double DonchianLow(const int shift)
{
   double ll = DBL_MAX;
   for(int i = 1; i <= donchian_period; i++)
   {
      double l = iLow(_Symbol, PERIOD_H1, shift + i);
      if(l < ll) ll = l;
   }
   return ll;
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
   const int bars_today = Bars(_Symbol, PERIOD_H1, iTime(_Symbol, PERIOD_D1, 0), TimeCurrent());
   if(bars_today < no_trade_first_bars + 1) return true;
   return false;

  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(HasPosition()) return false;

   // Vegas tunnel
   const double ema144 = QM_EMA(_Symbol, PERIOD_H1, ema_fast_period, 1);
   const double ema169 = QM_EMA(_Symbol, PERIOD_H1, ema_slow_period, 1);
   if(ema144 <= 0 || ema169 <= 0) return false;

   const double tunnel_high = MathMax(ema144, ema169);
   const double tunnel_low = MathMin(ema144, ema169);
   const double tunnel_thick = tunnel_high - tunnel_low;
   const double atr = QM_ATR(_Symbol, PERIOD_H1, 14, 1);
   if(atr <= 0) return false;

   if(tunnel_thick < tunnel_thickness_atr * atr) return false;

   const double close1 = iClose(_Symbol, PERIOD_H1, 1);
   const double close2 = iClose(_Symbol, PERIOD_H1, 2);
   if(close1 <= 0 || close2 <= 0) return false;

   // Donchian(20) as of bar [2] (exclude bar [1])
   const double upperDC = DonchianHigh(2);
   const double lowerDC = DonchianLow(2);
   if(upperDC <= 0 || lowerDC >= DBL_MAX / 2) return false;

   bool long_signal = false, short_signal = false;

   // LONG: above tunnel + Donchian break
   if(close1 > tunnel_high && close1 > upperDC && close2 <= upperDC)
      long_signal = true;

   // SHORT: below tunnel + Donchian break
   if(!long_signal && close1 < tunnel_low && close1 < lowerDC && close2 >= lowerDC)
      short_signal = true;

   if(!long_signal && !short_signal) return false;

   const double entry = long_signal ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // SL at opposite Donchian boundary
   double sl = long_signal ? lowerDC : upperDC;
   double sl_dist = MathAbs(entry - sl);
   if(sl_dist < atr * atr_sl_mult)
   {
      if(long_signal) sl = entry - atr * atr_sl_mult;
      else sl = entry + atr * atr_sl_mult;
   }

   const double tp = long_signal ? entry + (entry - sl) * rr_target : entry - (sl - entry) * rr_target;

   req.type = long_signal ? QM_BUY : QM_SELL;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = long_signal ? "DVH_LONG" : "DVH_SHORT";
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

   const double ema144 = QM_EMA(_Symbol, PERIOD_H1, ema_fast_period, 1);
   const double ema169 = QM_EMA(_Symbol, PERIOD_H1, ema_slow_period, 1);
   if(ema144 <= 0 || ema169 <= 0) return false;

   const double tunnel_high = MathMax(ema144, ema169);
   const double tunnel_low = MathMin(ema144, ema169);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;

      const ENUM_POSITION_TYPE pt = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      // Tunnel re-entry exit
      if((pt == POSITION_TYPE_BUY && close <= tunnel_high) ||
         (pt == POSITION_TYPE_SELL && close >= tunnel_low))
      {
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
         continue;
      }

      // Opposite Donchian break
      const double upperDC = DonchianHigh(2);
      const double lowerDC = DonchianLow(2);
      if((pt == POSITION_TYPE_BUY && close > upperDC) ||
         (pt == POSITION_TYPE_SELL && close < lowerDC))
      {
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
         continue;
      }

      // Time stop: 96 H1 bars (4 trading days)
      const datetime entry_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int bars_held = (int)((TimeCurrent() - entry_time) / PeriodSeconds(PERIOD_H1));
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
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12114\",\"strategy\":\"donchian-vegas-hybrid\"}");
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

