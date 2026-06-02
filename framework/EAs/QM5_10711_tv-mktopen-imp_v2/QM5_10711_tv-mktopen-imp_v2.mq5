#property strict
#property version   "5.0"
#property description "QM5_10711 TradingView Market Open Impulse v2"
// v2: fresh implementation; v1 source was never committed to git.
// Root cause of v1 ONINIT_FAILED: EA_MAGIC_NOT_REGISTERED (ea_id 10711
// was absent from magic_numbers.csv). Fix: entries added 2026-06-02 via
// update_magic_resolver.py; v2 builds from approved card spec.
// Card: QM5_10711_tv-mktopen-imp — ATR impulse entry at session open,
// 3R TP, SL=opposite extreme of impulse candle, force-close at session end.

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10711;
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
input int    strategy_session_start_hhmm  = 1430;
input int    strategy_session_end_hhmm    = 2000;
input int    strategy_atr_period          = 14;
input double strategy_atr_impulse_factor  = 1.5;
input double strategy_max_spike_factor    = 4.0;
input double strategy_rr_target           = 3.0;
input double strategy_max_spread_pct_of_sl = 0.15;
input bool   strategy_breakeven_enabled   = false;
input double strategy_breakeven_rr        = 1.5;

int    g_session_day_key    = 0;
bool   g_trade_fired_today  = false;
double g_entry_price_local  = 0.0;
bool   g_long_entry_local   = false;

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

void Strategy_ResetDayIfNeeded(const datetime t)
  {
   const int dk = Strategy_DayKey(t);
   if(dk != g_session_day_key)
     {
      g_session_day_key  = dk;
      g_trade_fired_today = false;
     }
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

bool Strategy_SpreadAllowed(const double sl_distance)
  {
   if(strategy_max_spread_pct_of_sl <= 0.0 || sl_distance <= 0.0) return true;
   const double point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double spread = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(point <= 0.0 || spread < 0.0) return false;
   return spread <= strategy_max_spread_pct_of_sl * sl_distance;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   Strategy_ResetDayIfNeeded(TimeCurrent());
   if(Strategy_HasOurOpenPosition()) return false;
   if(g_trade_fired_today) return true;
   const int hhmm   = Strategy_HhmmFromTime(TimeCurrent());
   const int now_m  = Strategy_HhmmToMinutes(hhmm);
   const int open_m = Strategy_HhmmToMinutes(strategy_session_start_hhmm);
   const int end_m  = Strategy_HhmmToMinutes(strategy_session_end_hhmm);
   if(now_m < 0 || open_m < 0 || end_m < 0) return true;
   if(now_m < open_m || now_m >= end_m) return true;
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

   Strategy_ResetDayIfNeeded(TimeCurrent());

   MqlRates bar[1];
   if(CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 1, 1, bar) != 1)  // perf-allowed: single closed bar for impulse check
      return false;

   const int bar_hhmm = Strategy_HhmmFromTime(bar[0].time);
   const int bar_m    = Strategy_HhmmToMinutes(bar_hhmm);
   const int open_m   = Strategy_HhmmToMinutes(strategy_session_start_hhmm);
   const int end_m    = Strategy_HhmmToMinutes(strategy_session_end_hhmm);
   if(bar_m < 0 || open_m < 0 || end_m < 0) return false;
   if(bar_m < open_m || bar_m >= end_m) return false;

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(atr <= 0.0) return false;

   const double tr = bar[0].high - bar[0].low;
   if(tr < strategy_atr_impulse_factor * atr) return false;
   if(tr > strategy_max_spike_factor    * atr) return false;

   const double midpoint  = (bar[0].high + bar[0].low) * 0.5;
   const bool   want_long  = (bar[0].close > midpoint && bar[0].close > bar[0].open);
   const bool   want_short = (bar[0].close < midpoint && bar[0].close < bar[0].open);
   if(!want_long && !want_short) return false;

   const double sl_raw = want_long ? bar[0].low : bar[0].high;
   const double entry  = want_long ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                   : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0 || sl_raw <= 0.0) return false;
   if(want_long  && sl_raw >= entry) return false;
   if(!want_long && sl_raw <= entry) return false;

   const double sl_distance = MathAbs(entry - sl_raw);
   if(!Strategy_SpreadAllowed(sl_distance)) return false;

   const double tp = QM_TakeRR(_Symbol, want_long ? QM_BUY : QM_SELL, entry, sl_raw, strategy_rr_target);
   if(tp <= 0.0) return false;
   if(want_long  && tp <= entry) return false;
   if(!want_long && tp >= entry) return false;

   req.type        = want_long ? QM_BUY : QM_SELL;
   req.price       = 0.0;
   req.sl          = QM_StopRulesNormalizePrice(_Symbol, sl_raw);
   req.tp          = QM_StopRulesNormalizePrice(_Symbol, tp);
   req.reason      = want_long ? "TV_MKTOPEN_IMP_LONG" : "TV_MKTOPEN_IMP_SHORT";
   req.symbol_slot = qm_magic_slot_offset;

   g_trade_fired_today = true;
   g_entry_price_local = entry;
   g_long_entry_local  = want_long;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   if(!strategy_breakeven_enabled) return;
   if(!Strategy_HasOurOpenPosition()) return;
   if(g_entry_price_local <= 0.0) return;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong tk = PositionGetTicket(i);
      if(tk == 0 || !PositionSelectByTicket(tk)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
      const double pos_sl   = PositionGetDouble(POSITION_SL);
      const double pos_open = PositionGetDouble(POSITION_PRICE_OPEN);
      const double sl_dist  = MathAbs(pos_open - pos_sl);
      if(sl_dist <= 0.0) break;
      const double price = g_long_entry_local ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                              : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double be_trigger = strategy_breakeven_rr * sl_dist;
      if(g_long_entry_local  && price >= pos_open + be_trigger)
         QM_TM_MoveToBreakEven(tk, 0, 0);
      else if(!g_long_entry_local && price <= pos_open - be_trigger)
         QM_TM_MoveToBreakEven(tk, 0, 0);
      break;
     }
  }

bool Strategy_ExitSignal()
  {
   if(!Strategy_HasOurOpenPosition()) return false;
   const int hhmm  = Strategy_HhmmFromTime(TimeCurrent());
   const int now_m = Strategy_HhmmToMinutes(hhmm);
   const int end_m = Strategy_HhmmToMinutes(strategy_session_end_hhmm);
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
