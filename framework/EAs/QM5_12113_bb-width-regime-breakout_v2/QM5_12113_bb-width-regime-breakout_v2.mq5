#property strict
#property version   "5.0"
#property description "QM5_12113_v2 bb-width-regime-breakout"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12113;
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
input int    bb_width_lookback     = 100;
input int    squeeze_pct_threshold = 20;
input int    squeeze_latch_bars    = 5;
input int    squeeze_expiry_bars   = 50;
input int    ema_trend_period      = 200;
input double atr_sl_mult           = 1.0;
input double rr_target             = 2.5;
input int    max_spread_points     = 25;
input int    no_trade_first_bars   = 2;

// ----------------------------------------------------------------------
// Helper functions
// ----------------------------------------------------------------------

// ----------------------------------------------------------------------
// BB width rolling percentile + squeeze latch
// ----------------------------------------------------------------------
#define BB_WIDTH_BUF_MAX 256
double g_bb_width_buf[BB_WIDTH_BUF_MAX];
int g_bb_width_idx = 0;
int g_bb_width_count = 0;
bool g_squeeze_latch = false;
int g_squeeze_bars_since_entry = 0;
int g_squeeze_consumed_count = 0;
bool g_squeeze_entry_consumed = false;

double BBPercentile(const double current_width)
{
   if(g_bb_width_count < 1) return 50.0;
   int count_less = 0;
   for(int i = 0; i < g_bb_width_count; i++)
   {
      if(g_bb_width_buf[i] < current_width) count_less++;
   }
   return (double)count_less * 100.0 / (double)g_bb_width_count;
}

void UpdateBBWidth()
{
   const int lookback = MathMin(MathMax(bb_width_lookback, 2), BB_WIDTH_BUF_MAX);
   double upper = QM_BB_Upper(_Symbol, PERIOD_H1, bb_period, bb_dev, 0);
   double lower = QM_BB_Lower(_Symbol, PERIOD_H1, bb_period, bb_dev, 0);
   double mid   = QM_BB_Middle(_Symbol, PERIOD_H1, bb_period, bb_dev, 0);
   if(upper <= 0 || lower <= 0 || mid <= 0) return;
   double width = (upper - lower) / mid;
   g_bb_width_buf[g_bb_width_idx] = width;
   g_bb_width_idx = (g_bb_width_idx + 1) % lookback;
   if(g_bb_width_count < lookback) g_bb_width_count++;
}

string QM_ATR_CacheKey() { return "atr_cache"; }

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
   // No-trade first N bars of session
   const int bars_today = Bars(_Symbol, PERIOD_H1, iTime(_Symbol, PERIOD_D1, 0), TimeCurrent());
   if(bars_today < no_trade_first_bars + 1) return true;
   return false;

  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   UpdateBBWidth();
   const int lookback = MathMin(MathMax(bb_width_lookback, 2), BB_WIDTH_BUF_MAX);
   if(g_bb_width_count < lookback) return false;

   // Squeeze latch
   bool all_squeeze = true;
   for(int i = 1; i <= squeeze_latch_bars; i++)
   {
      double w = (QM_BB_Upper(_Symbol, PERIOD_H1, bb_period, bb_dev, i) -
                  QM_BB_Lower(_Symbol, PERIOD_H1, bb_period, bb_dev, i)) /
                  QM_BB_Middle(_Symbol, PERIOD_H1, bb_period, bb_dev, i);
      double pct = BBPercentile(w);
      if(pct > squeeze_pct_threshold) { all_squeeze = false; break; }
   }
   if(all_squeeze && !g_squeeze_latch && !g_squeeze_entry_consumed)
   {
      g_squeeze_latch = true;
      g_squeeze_bars_since_entry = 0;
   }

   // Expiry
   if(g_squeeze_latch && !g_squeeze_entry_consumed)
   {
      g_squeeze_bars_since_entry++;
      if(g_squeeze_bars_since_entry > squeeze_expiry_bars)
      {
         g_squeeze_latch = false;
         g_squeeze_bars_since_entry = 0;
      }
   }

   if(!g_squeeze_latch) return false;
   if(HasPosition()) return false;

   const double upper1 = QM_BB_Upper(_Symbol, PERIOD_H1, bb_period, bb_dev, 1);
   const double lower1 = QM_BB_Lower(_Symbol, PERIOD_H1, bb_period, bb_dev, 1);
   const double upper2 = QM_BB_Upper(_Symbol, PERIOD_H1, bb_period, bb_dev, 2);
   const double lower2 = QM_BB_Lower(_Symbol, PERIOD_H1, bb_period, bb_dev, 2);
   const double close1 = iClose(_Symbol, PERIOD_H1, 1);
   const double close2 = iClose(_Symbol, PERIOD_H1, 2);
   const double ema200 = QM_EMA(_Symbol, PERIOD_H1, ema_trend_period, 1);
   if(upper1 <= 0 || lower1 <= 0 || close1 <= 0 || ema200 <= 0) return false;

   const double mid1 = QM_BB_Middle(_Symbol, PERIOD_H1, bb_period, bb_dev, 1);
   if(mid1 <= 0) return false;

   bool long_signal = false, short_signal = false;
   if(close1 > upper1 && close2 <= upper2 && close1 > ema200)
      long_signal = true;
   else if(close1 < lower1 && close2 >= lower2 && close1 < ema200)
      short_signal = true;
   else
      return false;

   const double entry = long_signal ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double atr = QM_ATR(_Symbol, PERIOD_H1, 14, 1);
   if(atr <= 0) return false;

   double sl = long_signal ? lower1 : upper1;
   double sl_dist = MathAbs(entry - sl);
   if(sl_dist < atr * atr_sl_mult)
   {
      if(long_signal) sl = entry - atr * atr_sl_mult;
      else sl = entry + atr * atr_sl_mult;
   }

   double tp = long_signal ? entry + sl_dist * rr_target : entry - sl_dist * rr_target;

   g_squeeze_latch = false;
   g_squeeze_entry_consumed = true;
   g_squeeze_bars_since_entry = 0;

   req.type = long_signal ? QM_BUY : QM_SELL;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = long_signal ? "BBW_LONG" : "BBW_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;

  }

void Strategy_ManageOpenPosition()
  {
   // Re-arm squeeze latch after entry is closed
   if(!HasPosition())
   {
      g_squeeze_entry_consumed = false;
   }

  }

bool Strategy_ExitSignal()
  {
   if(!HasPosition()) return false;
   const int magic = QM_FrameworkMagic();
   const double close = iClose(_Symbol, PERIOD_H1, 1);
   const double mid = QM_BB_Middle(_Symbol, PERIOD_H1, bb_period, bb_dev, 1);
   const double upper = QM_BB_Upper(_Symbol, PERIOD_H1, bb_period, bb_dev, 1);
   const double lower = QM_BB_Lower(_Symbol, PERIOD_H1, bb_period, bb_dev, 1);
   if(mid <= 0) return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;

      const ENUM_POSITION_TYPE pt = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      // Mid-band touch exit
      if((pt == POSITION_TYPE_BUY && close <= mid) ||
         (pt == POSITION_TYPE_SELL && close >= mid))
      {
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
         continue;
      }

      // Opposite-band touch
      if((pt == POSITION_TYPE_BUY && close >= upper) ||
         (pt == POSITION_TYPE_SELL && close <= lower))
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
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12113\",\"strategy\":\"bb-width-regime-breakout\"}");
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

