#property strict
#property version   "5.0"
#property description "QM5_1332 Chan London Bollinger Breakout"
// rework v2 2026-06-16 — BB was built from 20 D1 *closes* (band ~2SD of daily closes,
// ~100-250 pip half-width) so the London-morning live price never breached it -> 0 trades.
// Card spec is a time-of-day band: sample the price at the session-start hour on each of
// the previous 20 days. Rebuilt ComputeBB() to sample the H1 close at strategy_sample_hour
// (broker time, same clock as the InSession window) across 20 distinct prior days.

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1332;
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
input int    strategy_bb_lookback        = 20;
input double strategy_bb_std             = 2.0;
input int    strategy_sample_hour        = 9;
input int    strategy_sample_min         = 0;
input int    strategy_session_hours      = 3;
input int    strategy_max_hold_seconds   = 10800;
input double strategy_tp_pips            = 20.0;
input double strategy_sl_pips            = 20.0;
input int    strategy_max_spread_points  = 0;

double g_bb_mid = 0.0, g_bb_upper = 0.0, g_bb_lower = 0.0;
int g_bb_bars = 0;
datetime g_entry_time = 0;
bool g_entered_today = false;

double PointValue()
{
   return SymbolInfoDouble(_Symbol, SYMBOL_POINT);
}

void ComputeBB()
{
   // Time-of-day Bollinger band: collect the H1 close at strategy_sample_hour (broker
   // clock, same as InSession) for each of the previous strategy_bb_lookback distinct
   // days, then SMA +/- strategy_bb_std * stdev. Scanning yesterday backwards keeps the
   // current (in-progress) session out of the band so the breakout is vs prior history.
   g_bb_bars = 0;
   g_bb_mid = g_bb_upper = g_bb_lower = 0.0;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   // ~24 H1 bars/day; pull generous history to span lookback days incl. weekends/holidays.
   const int to_copy = (strategy_bb_lookback + 12) * 30;
   const int got = CopyRates(_Symbol, PERIOD_H1, 1, to_copy, rates);
   if (got <= 0) return;

   double samples[];
   ArrayResize(samples, strategy_bb_lookback);
   int n = 0;
   int last_yday = -1;
   for (int i = 0; i < got && n < strategy_bb_lookback; ++i)
   {
      MqlDateTime bt;
      TimeToStruct(rates[i].time, bt);
      if (bt.hour != strategy_sample_hour) continue;
      // one sample per calendar day; rates are newest-first so first hit per day wins.
      if (bt.day_of_year == last_yday) continue;
      last_yday = bt.day_of_year;
      samples[n++] = rates[i].close;
   }
   if (n < strategy_bb_lookback) return;

   double mean = 0.0;
   for (int i = 0; i < n; ++i) mean += samples[i];
   mean /= (double)n;

   double var = 0.0;
   for (int i = 0; i < n; ++i)
   {
      const double d = samples[i] - mean;
      var += d * d;
   }
   const double sd = MathSqrt(var / (double)(n - 1));

   g_bb_mid = mean;
   g_bb_upper = mean + strategy_bb_std * sd;
   g_bb_lower = mean - strategy_bb_std * sd;
   g_bb_bars = n;
}

bool InSession()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   const int start_mins = strategy_sample_hour * 60 + strategy_sample_min;
   const int end_mins = start_mins + strategy_session_hours * 60;
   const int now_mins = dt.hour * 60 + dt.min;
   return (now_mins >= start_mins && now_mins < end_mins);
}

bool IsNewDay()
{
   static datetime last_day = 0;
   const datetime d0 = iTime(_Symbol, PERIOD_D1, 0);
   if (d0 <= 0) return false;
   if (d0 == last_day) return false;
   last_day = d0;
   g_entered_today = false;
   g_entry_time = 0;
   ComputeBB();
   return true;
}

bool HasPosition()
{
   const int magic = QM_FrameworkMagic();
   for (int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong t = PositionGetTicket(i);
      if (t == 0 || !PositionSelectByTicket(t)) continue;
      if (PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if ((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
      return true;
   }
   return false;
}

void ClosePosition(const QM_ExitReason reason)
{
   const int magic = QM_FrameworkMagic();
   for (int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong t = PositionGetTicket(i);
      if (t == 0 || !PositionSelectByTicket(t)) continue;
      if (PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if ((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
      QM_TM_ClosePosition(t, reason);
   }
}

bool Strategy_NoTradeFilter()
{
   if (strategy_max_spread_points > 0)
   {
      const int sp = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if (sp > strategy_max_spread_points) return true;
   }
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if (dt.day_of_week == 5) return true;
   if (!InSession()) return true;
   return false;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "LONDON_BB";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   IsNewDay();

   if (g_entered_today || HasPosition()) return false;
   if (g_bb_bars < strategy_bb_lookback) return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if (ask <= 0.0 || bid <= 0.0) return false;

   const double point = PointValue();
   if (point <= 0.0) return false;

   QM_OrderType side = QM_BUY;
   string reason = "";
   double entry = 0.0, sl = 0.0, tp = 0.0;

   if (ask >= g_bb_upper)
   {
      side = QM_BUY;
      entry = ask;
      sl = entry - strategy_sl_pips * point;
      tp = entry + strategy_tp_pips * point;
      reason = "LON_BB_BREAK_UP";
   }
   else if (bid <= g_bb_lower)
   {
      side = QM_SELL;
      entry = bid;
      sl = entry + strategy_sl_pips * point;
      tp = entry - strategy_tp_pips * point;
      reason = "LON_BB_BREAK_DN";
   }
   else
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = reason;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   g_entered_today = true;
   g_entry_time = TimeCurrent();
   return true;
}

void Strategy_ManageOpenPosition() {}

bool Strategy_ExitSignal()
{
   if (!HasPosition()) return false;

   if (g_entry_time > 0 && TimeCurrent() - g_entry_time >= strategy_max_hold_seconds)
   {
      ClosePosition(QM_EXIT_TIME_STOP);
      return false;
   }

   if (!InSession())
   {
      ClosePosition(QM_EXIT_FRIDAY_CLOSE);
      return false;
   }
   return false;
}

bool Strategy_NewsFilterHook(const datetime broker_time) { return false; }

int OnInit()
{
   if (!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
                         qm_news_mode_legacy, qm_friday_close_enabled, qm_friday_close_hour_broker,
                         30, 30, qm_news_stale_max_hours, qm_news_min_impact, qm_rng_seed,
                         qm_stress_reject_probability, qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1332\",\"strategy\":\"chan-london-bb-breakout\"}");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason)); QM_FrameworkShutdown(); }

void OnTick()
{
   if (!QM_KillSwitchCheck()) return;
   const datetime broker_now = TimeCurrent();
   if (Strategy_NewsFilterHook(broker_now)) return;
   bool news_allows = true;
   if (qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if (!news_allows) return;
   if (QM_FrameworkHandleFridayClose()) return;
   if (Strategy_NoTradeFilter()) return;
   Strategy_ManageOpenPosition();
   Strategy_ExitSignal();
   if (!QM_IsNewBar()) return;
   QM_EquityStreamOnNewBar();
   QM_EntryRequest req;
   if (Strategy_EntrySignal(req)) { ulong t = 0; QM_TM_OpenPosition(req, t); }
}

void OnTimer() { QM_FrameworkOnTimer(); }
void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result) { QM_FrameworkOnTradeTransaction(trans, request, result); }
double OnTester() { QM_ChartUI_Refresh(); return QM_DefaultObjective(); }
