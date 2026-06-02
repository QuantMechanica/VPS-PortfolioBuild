#property strict
#property version   "5.0"
#property description "QM5_10712 TradingView ICT Session Breakout Retest v2"
// v2: fresh implementation; v1 source was never committed to git.
// Root cause of v1 ONINIT_FAILED: EA_MAGIC_NOT_REGISTERED (ea_id 10712
// was absent from magic_numbers.csv). Fix: entries added 2026-06-02 via
// update_magic_resolver.py; v2 builds from approved card spec.
// Card: QM5_10712_tv-ict-retest — ICT session break→reentry→retest,
// pip-based stops on FX, ATR-based on indices/metals.

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10712;
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
input int    strategy_session_boundary_hhmm = 800;
input int    strategy_day_end_flat_hhmm     = 2100;
input double strategy_sl_pips               = 10.0;
input double strategy_tp_pips               = 20.0;
input double strategy_sl_atr_mult           = 1.0;
input double strategy_tp_atr_mult           = 2.0;
input double strategy_reentry_pips          = 5.0;
input int    strategy_min_bars_after_break  = 3;
input int    strategy_atr_period            = 14;

int    g_day_key           = 0;
double g_session_high      = 0.0;
double g_session_low       = 0.0;
double g_prev_high         = 0.0;
double g_prev_low          = 0.0;
bool   g_boundary_done     = false;
bool   g_setup_long        = false;
bool   g_setup_short       = false;
int    g_bars_since_break  = 0;
double g_reentry_line      = 0.0;
bool   g_trade_fired_today = false;

int Strategy_HhmmToMinutes(const int hhmm)
  {
   const int hh = hhmm / 100;
   const int mm = hhmm % 100;
   if(hh < 0 || hh > 23 || mm < 0 || mm > 59) return -1;
   return hh * 60 + mm;
  }

int Strategy_HhmmFromTime(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 100 + dt.min;
  }

int Strategy_DayKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

bool Strategy_IsNonFx()
  {
   const string sym = _Symbol;
   return (StringFind(sym, "XAU")  >= 0 ||
           StringFind(sym, "DAX")  >= 0 ||
           StringFind(sym, "GDA")  >= 0 ||
           StringFind(sym, "NDX")  >= 0 ||
           StringFind(sym, "WS30") >= 0 ||
           StringFind(sym, "SPX")  >= 0);
  }

void Strategy_ResetDay(const int dk)
  {
   g_day_key           = dk;
   g_session_high      = 0.0;
   g_session_low       = 0.0;
   g_boundary_done     = false;
   g_setup_long        = false;
   g_setup_short       = false;
   g_bars_since_break  = 0;
   g_reentry_line      = 0.0;
   g_trade_fired_today = false;
  }

void Strategy_ResetSetup()
  {
   g_setup_long       = false;
   g_setup_short      = false;
   g_bars_since_break = 0;
   g_reentry_line     = 0.0;
  }

bool Strategy_HasOurOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0) return false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong tk = PositionGetTicket(i);
      if(tk == 0 || !PositionSelectByTicket(tk)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
      return true;
     }
   return false;
  }

double Strategy_PipsToPrice(const double pips)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0) return 0.0;
   return pips * 10.0 * point;
  }

bool Strategy_BuildDistances(double &sl_dist, double &tp_dist)
  {
   if(Strategy_IsNonFx())
     {
      const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
      if(atr <= 0.0) return false;
      sl_dist = strategy_sl_atr_mult * atr;
      tp_dist = strategy_tp_atr_mult * atr;
     }
   else
     {
      sl_dist = Strategy_PipsToPrice(strategy_sl_pips);
      tp_dist = Strategy_PipsToPrice(strategy_tp_pips);
     }
   return (sl_dist > 0.0 && tp_dist > 0.0);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   const datetime now = TimeCurrent();
   const int dk = Strategy_DayKey(now);
   if(dk != g_day_key)
      Strategy_ResetDay(dk);

   if(Strategy_HasOurOpenPosition()) return false;
   if(g_trade_fired_today) return true;

   const int hhmm  = Strategy_HhmmFromTime(now);
   const int now_m = Strategy_HhmmToMinutes(hhmm);
   const int end_m = Strategy_HhmmToMinutes(strategy_day_end_flat_hhmm);
   if(now_m >= 0 && end_m >= 0 && now_m >= end_m) return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type               = QM_BUY;
   req.price              = 0.0;
   req.sl                 = 0.0;
   req.tp                 = 0.0;
   req.reason             = "";
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(Strategy_HasOurOpenPosition()) return false;
   if(g_trade_fired_today) return false;

   MqlRates bar[1];
   if(CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 1, 1, bar) != 1)  // perf-allowed: single closed bar for session/break logic
      return false;

   const int bar_hhmm = Strategy_HhmmFromTime(bar[0].time);
   const int bar_m    = Strategy_HhmmToMinutes(bar_hhmm);
   const int bound_m  = Strategy_HhmmToMinutes(strategy_session_boundary_hhmm);
   const int end_m    = Strategy_HhmmToMinutes(strategy_day_end_flat_hhmm);

   const int dk = Strategy_DayKey(bar[0].time);
   if(dk != g_day_key)
      Strategy_ResetDay(dk);

   if(!g_boundary_done && bar_m < bound_m)
     {
      if(g_session_high <= 0.0 || bar[0].high > g_session_high)
         g_session_high = bar[0].high;
      if(g_session_low <= 0.0  || bar[0].low  < g_session_low)
         g_session_low  = bar[0].low;
      return false;
     }

   if(!g_boundary_done && bar_m >= bound_m)
     {
      if(g_session_high > 0.0 && g_session_low > 0.0 && g_session_high > g_session_low)
        {
         g_prev_high     = g_session_high;
         g_prev_low      = g_session_low;
         g_boundary_done = true;
         g_session_high  = 0.0;
         g_session_low   = 0.0;
        }
      return false;
     }

   if(!g_boundary_done || g_prev_high <= 0.0 || g_prev_low <= 0.0)
      return false;

   if(!g_setup_long && !g_setup_short)
     {
      const bool long_break  = (bar[0].open < g_prev_high && bar[0].close > g_prev_high);
      const bool short_break = (bar[0].open > g_prev_low  && bar[0].close < g_prev_low);
      if(long_break)
        {
         g_setup_long       = true;
         g_bars_since_break = 0;
         g_reentry_line     = g_prev_high;
        }
      else if(short_break)
        {
         g_setup_short      = true;
         g_bars_since_break = 0;
         g_reentry_line     = g_prev_low;
        }
      return false;
     }

   g_bars_since_break++;

   if(g_setup_long  && bar[0].close < g_prev_low)  { Strategy_ResetSetup(); return false; }
   if(g_setup_short && bar[0].close > g_prev_high) { Strategy_ResetSetup(); return false; }
   if(end_m >= 0 && bar_m >= end_m) { Strategy_ResetSetup(); return false; }

   if(g_bars_since_break < strategy_min_bars_after_break)
      return false;

   if(g_setup_long)
     {
      const double reentry_threshold = g_reentry_line + Strategy_PipsToPrice(strategy_reentry_pips);
      if(bar[0].low > reentry_threshold)   return false;
      if(bar[0].close <= g_reentry_line)  return false;
     }
   else
     {
      const double reentry_threshold = g_reentry_line - Strategy_PipsToPrice(strategy_reentry_pips);
      if(bar[0].high < reentry_threshold)  return false;
      if(bar[0].close >= g_reentry_line)  return false;
     }

   double sl_dist = 0.0, tp_dist = 0.0;
   if(!Strategy_BuildDistances(sl_dist, tp_dist)) return false;

   const bool want_long = g_setup_long;
   const double entry   = want_long ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                    : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0) return false;

   const double sl = want_long ? entry - sl_dist : entry + sl_dist;
   const double tp = want_long ? entry + tp_dist : entry - tp_dist;

   req.type        = want_long ? QM_BUY : QM_SELL;
   req.price       = 0.0;
   req.sl          = QM_StopRulesNormalizePrice(_Symbol, sl);
   req.tp          = QM_StopRulesNormalizePrice(_Symbol, tp);
   req.reason      = want_long ? "TV_ICT_RETEST_LONG" : "TV_ICT_RETEST_SHORT";
   req.symbol_slot = qm_magic_slot_offset;

   g_trade_fired_today = true;
   Strategy_ResetSetup();
   return true;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   if(!Strategy_HasOurOpenPosition()) return false;
   const int hhmm  = Strategy_HhmmFromTime(TimeCurrent());
   const int now_m = Strategy_HhmmToMinutes(hhmm);
   const int end_m = Strategy_HhmmToMinutes(strategy_day_end_flat_hhmm);
   return (now_m >= 0 && end_m >= 0 && now_m >= end_m);
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line.
// -----------------------------------------------------------------------------

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,
                        30,
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,
                        qm_news_compliance))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{}");
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
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong tk = PositionGetTicket(i);
         if(!PositionSelectByTicket(tk)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         QM_TM_ClosePosition(tk, QM_EXIT_STRATEGY);
        }
     }

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
     {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
     }
  }

void OnTimer()
  {
   QM_FrameworkOnTimer();
  }

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest     &request,
                        const MqlTradeResult      &result)
  {
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
