#property strict
#property version   "5.0"
#property description "QM5_12116 carter-ttm-squeeze-h1"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12116;
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
input int    bb_period             = 20;
input double bb_dev                = 2.0;
input int    kc_period             = 20;
input double kc_atr_mult           = 1.5;
input int    squeeze_min_bars      = 6;
input int    mom_lookback          = 20;
input int    ema_trend_period      = 200;
input double atr_sl_mult           = 1.0;
input double rr_target             = 2.0;
input int    max_spread_points     = 25;

// ----------------------------------------------------------------------
// Helper functions
// ----------------------------------------------------------------------

// ----------------------------------------------------------------------
// TTM Squeeze detection
// ----------------------------------------------------------------------
int g_squeeze_counter = 0;
bool g_squeeze_active = false;
bool g_entry_consumed = false;

bool IsSqueezed(const int shift)
{
   const double bb_upper = QM_BB_Upper(_Symbol, PERIOD_H1, bb_period, bb_dev, shift);
   const double bb_lower = QM_BB_Lower(_Symbol, PERIOD_H1, bb_period, bb_dev, shift);
   const double kc_atr = QM_ATR(_Symbol, PERIOD_H1, kc_period, shift);
   if(bb_upper <= 0 || bb_lower <= 0 || kc_atr <= 0) return false;
   const double ema_mid = QM_EMA(_Symbol, PERIOD_H1, kc_period, shift);
   if(ema_mid <= 0) return false;
   const double kc_upper = ema_mid + kc_atr * kc_atr_mult;
   const double kc_lower = ema_mid - kc_atr * kc_atr_mult;
   return (bb_upper < kc_upper && bb_lower > kc_lower);
}

double TTM_Momentum(const int shift)
{
   // Linear regression proxy of (close - EMA(mid)) over mom_lookback bars
   const double ema_mid = QM_EMA(_Symbol, PERIOD_H1, kc_period, shift + mom_lookback);
   if(ema_mid <= 0) return 0;
   double sum_xy = 0, sum_x = 0, sum_y = 0, sum_xx = 0;
   int n = 0;
   for(int i = 0; i < mom_lookback; i++)
   {
      const double c = iClose(_Symbol, PERIOD_H1, shift + i);
      const double ema = QM_EMA(_Symbol, PERIOD_H1, kc_period, shift + i);
      if(c <= 0 || ema <= 0) continue;
      const double y = c - ema;
      sum_xy += (double)i * y;
      sum_x += (double)i;
      sum_y += y;
      sum_xx += (double)i * (double)i;
      n++;
   }
   if(n < 2) return 0;
   const double slope = (n * sum_xy - sum_x * sum_y) / (n * sum_xx - sum_x * sum_x);
   return slope * mom_lookback;
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
   // Session: 06:00-21:00 broker
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   const int hour = dt.hour;
   if(hour < 6 || hour >= 21) return true;
   return false;

  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Squeeze detection
   if(IsSqueezed(1))
   {
      g_squeeze_counter++;
      if(g_squeeze_counter >= squeeze_min_bars)
         g_squeeze_active = true;
   }
   else
   {
      // Check for release
      if(g_squeeze_active && !g_entry_consumed && g_squeeze_counter >= squeeze_min_bars)
      {
         // Release bar: BB outside Keltner
         const double bb_upper1 = QM_BB_Upper(_Symbol, PERIOD_H1, bb_period, bb_dev, 1);
         const double bb_lower1 = QM_BB_Lower(_Symbol, PERIOD_H1, bb_period, bb_dev, 1);
         const double kc_atr1 = QM_ATR(_Symbol, PERIOD_H1, kc_period, 1);
         if(bb_upper1 > 0 && bb_lower1 > 0 && kc_atr1 > 0)
         {
            const double ema_mid1 = QM_EMA(_Symbol, PERIOD_H1, kc_period, 1);
            if(ema_mid1 > 0)
            {
               const double kc_upper1 = ema_mid1 + kc_atr1 * kc_atr_mult;
               const double kc_lower1 = ema_mid1 - kc_atr1 * kc_atr_mult;
               const bool released_up = (bb_upper1 > kc_upper1);
               const bool released_dn = (bb_lower1 < kc_lower1);

               if(released_up || released_dn)
               {
                  const double mom = TTM_Momentum(1);
                  const double close1 = iClose(_Symbol, PERIOD_H1, 1);
                  const double ema200 = QM_EMA(_Symbol, PERIOD_H1, ema_trend_period, 1);
                  if(close1 <= 0 || ema200 <= 0) { g_squeeze_counter = 0; g_squeeze_active = false; return false; }

                  bool long_signal = false, short_signal = false;
                  if(released_up && mom > 0 && close1 > ema200)
                     long_signal = true;
                  else if(released_dn && mom < 0 && close1 < ema200)
                     short_signal = true;

                  if(long_signal || short_signal)
                  {
                     if(HasPosition()) { g_squeeze_counter = 0; g_squeeze_active = false; return false; }

                     const double atr = QM_ATR(_Symbol, PERIOD_H1, 14, 1);
                     if(atr <= 0) { g_squeeze_counter = 0; g_squeeze_active = false; return false; }

                     const double entry = long_signal ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
                     const double sl = long_signal ? entry - atr * atr_sl_mult : entry + atr * atr_sl_mult;
                     const double tp = long_signal ? entry + (entry - sl) * rr_target : entry - (sl - entry) * rr_target;

                     g_entry_consumed = true;
                     g_squeeze_active = false;
                     g_squeeze_counter = 0;

                     req.type = long_signal ? QM_BUY : QM_SELL;
                     req.price = 0.0;
                     req.sl = sl;
                     req.tp = tp;
                     req.reason = long_signal ? "TTM_LONG" : "TTM_SHORT";
                     req.symbol_slot = qm_magic_slot_offset;
                     req.expiration_seconds = 0;
                     return true;
                  }
               }
            }
         }
      }
      g_squeeze_counter = 0;
      g_squeeze_active = false;
   }
   return false;

  }

void Strategy_ManageOpenPosition()
  {
   if(!HasPosition()) g_entry_consumed = false;

  }

bool Strategy_ExitSignal()
  {
   if(!HasPosition()) return false;
   const int magic = QM_FrameworkMagic();
   const double close1 = iClose(_Symbol, PERIOD_H1, 1);
   if(close1 <= 0) return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;

      const ENUM_POSITION_TYPE pt = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      // Momentum flip exit
      const double mom = TTM_Momentum(1);
      if((pt == POSITION_TYPE_BUY && mom < 0) ||
         (pt == POSITION_TYPE_SELL && mom > 0))
      {
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
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
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12116\",\"strategy\":\"carter-ttm-squeeze-h1\"}");
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

