#property strict
#property version   "5.0"
#property description "FF Roadmap ADR Counter M5 — completed-ADR reversal, QM5_9917"

#include <QM/QM_Common.mqh>

// =============================================================================
// Input groups
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 9917;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours              = 336;
input string qm_news_min_impact                   = "high";
input QM_NewsMode qm_news_mode_legacy             = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_adr_period          = 14;    // ADR lookback in D1 bars
input double strategy_adr_completion_pct  = 0.95;  // minimum completed ADR fraction
input int    strategy_rsi_period          = 14;    // RSI period (M5)
input int    strategy_ema_fast            = 8;     // EMA fast period (M5)
input int    strategy_ema_slow            = 200;   // EMA slow period (M5) — TP reference
input int    strategy_touch_window_bars   = 5;     // max M5 bars after touch to look for reversal
input int    strategy_rsi_window_bars     = 4;     // bars back to check RSI cross
input double strategy_entry_buffer_atr   = 0.10;  // max entry distance beyond ADR (× ATR)
input double strategy_sl_buffer_atr      = 0.25;  // SL buffer beyond extreme (× ATR)
input double strategy_sl_min_atr         = 0.70;  // reject if SL < this × ATR
input double strategy_sl_max_atr         = 2.80;  // reject if SL > this × ATR
input double strategy_exit_breach_atr    = 0.20;  // exit if bar closes beyond ADR by this × ATR
input int    strategy_time_stop_bars     = 36;    // time stop in M5 bars
input double strategy_tp_r_multiple     = 1.40;   // hard TP at this R multiple
input double strategy_m30_expand_atr    = 1.00;   // M30 expansion filter threshold (× ATR M30)
input int    strategy_session_start_h   = 9;      // session start hour (broker time)
input int    strategy_session_end_h     = 21;     // session end hour (broker time)

// =============================================================================
// File-scope state (advanced once per closed M5 bar in AdvanceState_OnNewBar)
// =============================================================================

static double   g_daily_open      = 0.0;
static double   g_adr_14          = 0.0;
static double   g_adr_high        = 0.0;
static double   g_adr_low         = 0.0;
static double   g_today_high      = 0.0;
static double   g_today_low       = 1e18;
static bool     g_low_touched     = false;   // ADR low touched this day
static bool     g_high_touched    = false;   // ADR high touched this day
static int      g_bars_since_low  = 999;     // M5 bars since ADR low touch
static int      g_bars_since_high = 999;     // M5 bars since ADR high touch
static int      g_bars_held       = 0;       // M5 bars position has been open
static bool     g_force_exit      = false;   // set when bar-close exit condition met

// =============================================================================
// Helpers
// =============================================================================

bool HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong tk = PositionGetTicket(i);
      if(!PositionSelectByTicket(tk)) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic) return true;
     }
   return false;
  }

ENUM_POSITION_TYPE GetOpenPositionType()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong tk = PositionGetTicket(i);
      if(!PositionSelectByTicket(tk)) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
     }
   return (ENUM_POSITION_TYPE)-1;
  }

// Check if last 3 M30 bars' closes are expanding away from the ADR boundary.
bool IsM30Expanding(const bool is_long)
  {
   const double atr_m30 = QM_ATR(_Symbol, PERIOD_M30, 14, 1);
   if(atr_m30 <= 0.0) return false;
   const double c1 = iClose(_Symbol, PERIOD_M30, 1); // perf-allowed: structural ADR filter
   const double c3 = iClose(_Symbol, PERIOD_M30, 3); // perf-allowed
   if(c1 <= 0.0 || c3 <= 0.0) return false;
   if(is_long)
      return (c3 - c1) > strategy_m30_expand_atr * atr_m30; // price dropped > 1 ATR
   else
      return (c1 - c3) > strategy_m30_expand_atr * atr_m30; // price rose > 1 ATR
  }

// RSI crossed above lo_level from below hi_trigger_below within last N bars
// (for long confirmation: crossed above 35 from below 30)
bool RsiCrossedUp(const double from_below, const double to_above)
  {
   for(int i = 1; i <= strategy_rsi_window_bars; i++)
     {
      const double rsi_now  = QM_RSI(_Symbol, PERIOD_M5, strategy_rsi_period, i);
      const double rsi_prev = QM_RSI(_Symbol, PERIOD_M5, strategy_rsi_period, i + 1);
      if(rsi_now >= to_above && rsi_prev < from_below) return true;
     }
   return false;
  }

bool RsiCrossedDown(const double from_above, const double to_below)
  {
   for(int i = 1; i <= strategy_rsi_window_bars; i++)
     {
      const double rsi_now  = QM_RSI(_Symbol, PERIOD_M5, strategy_rsi_period, i);
      const double rsi_prev = QM_RSI(_Symbol, PERIOD_M5, strategy_rsi_period, i + 1);
      if(rsi_now <= to_below && rsi_prev > from_above) return true;
     }
   return false;
  }

void AdvanceState_OnNewBar()
  {
   // -- Daily reset --
   if(QM_IsNewBar(_Symbol, PERIOD_D1))
     {
      g_daily_open    = iOpen(_Symbol, PERIOD_D1, 0);  // perf-allowed
      g_adr_14        = QM_ATR(_Symbol, PERIOD_D1, strategy_adr_period, 1);
      g_adr_high      = g_daily_open + g_adr_14;
      g_adr_low       = g_daily_open - g_adr_14;
      g_today_high    = iHigh(_Symbol, PERIOD_D1, 0);  // perf-allowed
      g_today_low     = iLow(_Symbol, PERIOD_D1, 0);   // perf-allowed
      g_low_touched   = false;
      g_high_touched  = false;
      g_bars_since_low  = 999;
      g_bars_since_high = 999;
     }
   else
     {
      // Update intraday extremes with just-closed M5 bar
      const double m5_high = iHigh(_Symbol, PERIOD_M5, 1); // perf-allowed
      const double m5_low  = iLow(_Symbol, PERIOD_M5, 1);  // perf-allowed
      if(m5_high > g_today_high) g_today_high = m5_high;
      if(m5_low  < g_today_low)  g_today_low  = m5_low;
     }

   // -- Touch detection on just-closed M5 bar --
   const double m5_low1  = iLow(_Symbol, PERIOD_M5, 1);  // perf-allowed
   const double m5_high1 = iHigh(_Symbol, PERIOD_M5, 1); // perf-allowed

   if(m5_low1 <= g_adr_low && g_adr_low > 0.0)
     {
      g_low_touched     = true;
      g_bars_since_low  = 0;
     }
   if(m5_high1 >= g_adr_high && g_adr_high > 0.0)
     {
      g_high_touched    = true;
      g_bars_since_high = 0;
     }

   // Advance touch counters
   if(g_low_touched  && g_bars_since_low  < 999) g_bars_since_low++;
   if(g_high_touched && g_bars_since_high < 999) g_bars_since_high++;

   // -- Position tracking: bars held + exit flags --
   if(!HasOpenPosition())
     {
      g_bars_held  = 0;
      g_force_exit = false;
      return;
     }
   g_bars_held++;

   const ENUM_POSITION_TYPE ptype = GetOpenPositionType();
   const double close1 = iClose(_Symbol, PERIOD_M5, 1); // perf-allowed
   const double atr_m5 = QM_ATR(_Symbol, PERIOD_M5, strategy_rsi_period, 1);
   const double ema200 = QM_EMA(_Symbol, PERIOD_M5, strategy_ema_slow, 1);

   if(ptype == POSITION_TYPE_BUY)
     {
      // Breach: bar closed below ADR low by more than threshold
      if(close1 < g_adr_low - strategy_exit_breach_atr * atr_m5) g_force_exit = true;
      // EMA200 TP: bar closed above EMA200
      if(ema200 > 0.0 && close1 >= ema200) g_force_exit = true;
      // Daily open TP: bar closed above daily open
      if(g_daily_open > 0.0 && close1 >= g_daily_open) g_force_exit = true;
     }
   else if(ptype == POSITION_TYPE_SELL)
     {
      // Breach: bar closed above ADR high by more than threshold
      if(close1 > g_adr_high + strategy_exit_breach_atr * atr_m5) g_force_exit = true;
      // EMA200 TP: bar closed below EMA200
      if(ema200 > 0.0 && close1 <= ema200) g_force_exit = true;
      // Daily open TP: bar closed below daily open
      if(g_daily_open > 0.0 && close1 <= g_daily_open) g_force_exit = true;
     }
  }

// =============================================================================
// Strategy hooks
// =============================================================================

bool Strategy_NoTradeFilter()
  {
   // Session filter: London open through NY lunch (broker hours)
   const datetime now = TimeCurrent();
   const int hour = (int)(now % 86400) / 3600;
   if(hour < strategy_session_start_h || hour >= strategy_session_end_h)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Advance bar state first (per-bar work)
   AdvanceState_OnNewBar();

   // Must have valid ADR levels
   if(g_adr_14 <= 0.0 || g_daily_open <= 0.0) return false;

   // Only one position per magic-symbol
   if(HasOpenPosition()) return false;

   const double atr_m5  = QM_ATR(_Symbol, PERIOD_M5, strategy_rsi_period, 1);
   if(atr_m5 <= 0.0) return false;

   // Today's range must be >= completion threshold
   const double today_range = g_today_high - g_today_low;
   if(today_range < strategy_adr_completion_pct * g_adr_14) return false;
   const double close1 = iClose(_Symbol, PERIOD_M5, 1); // perf-allowed
   const double ema8   = QM_EMA(_Symbol, PERIOD_M5, strategy_ema_fast, 1);

   // --- LONG SETUP ---
   if(g_low_touched && g_bars_since_low >= 1 && g_bars_since_low <= strategy_touch_window_bars)
     {
      // Bar closed back above ADR low
      if(close1 > g_adr_low)
        {
         // Entry close not below ADR low by more than buffer
         if(close1 >= g_adr_low - strategy_entry_buffer_atr * atr_m5)
           {
            // RSI or EMA confirmation
            const bool rsi_ok = RsiCrossedUp(30.0, 35.0);
            const bool ema_ok = (ema8 > 0.0 && close1 > ema8);
            if(rsi_ok || ema_ok)
              {
               // M30 expansion filter
               if(!IsM30Expanding(true))
                 {
                  // Compute SL: lowest low since touch - buffer
                  double lowest_low = g_today_low;
                  for(int k = 1; k <= g_bars_since_low; k++)
                    {
                     const double lo = iLow(_Symbol, PERIOD_M5, k); // perf-allowed
                     if(lo < lowest_low) lowest_low = lo;
                    }
                  const double sl_dist = (close1 - (lowest_low - strategy_sl_buffer_atr * atr_m5));
                  if(sl_dist >= strategy_sl_min_atr * atr_m5 && sl_dist <= strategy_sl_max_atr * atr_m5)
                    {
                     const double ask   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                     const double sl_px = ask - sl_dist;
                     // TP: min(daily_open, entry + 1.4R) if daily_open is above entry
                     double tp_px = ask + strategy_tp_r_multiple * sl_dist;
                     if(g_daily_open > ask && g_daily_open < tp_px)
                        tp_px = g_daily_open;
                     req.type         = QM_BUY;
                     req.price        = ask;
                     req.sl           = NormalizeDouble(sl_px, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
                     req.tp           = NormalizeDouble(tp_px, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
                     req.reason       = "ADR_COUNTER_LONG";
                     req.symbol_slot  = qm_magic_slot_offset;
                     return true;
                    }
                 }
              }
           }
        }
     }

   // --- SHORT SETUP ---
   if(g_high_touched && g_bars_since_high >= 1 && g_bars_since_high <= strategy_touch_window_bars)
     {
      // Bar closed back below ADR high
      if(close1 < g_adr_high)
        {
         if(close1 <= g_adr_high + strategy_entry_buffer_atr * atr_m5)
           {
            const bool rsi_ok = RsiCrossedDown(70.0, 65.0);
            const bool ema_ok = (ema8 > 0.0 && close1 < ema8);
            if(rsi_ok || ema_ok)
              {
               if(!IsM30Expanding(false))
                 {
                  double highest_high = g_today_high;
                  for(int k = 1; k <= g_bars_since_high; k++)
                    {
                     const double hi = iHigh(_Symbol, PERIOD_M5, k); // perf-allowed
                     if(hi > highest_high) highest_high = hi;
                    }
                  const double sl_dist = ((highest_high + strategy_sl_buffer_atr * atr_m5) - close1);
                  if(sl_dist >= strategy_sl_min_atr * atr_m5 && sl_dist <= strategy_sl_max_atr * atr_m5)
                    {
                     const double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                     const double sl_px = bid + sl_dist;
                     double tp_px = bid - strategy_tp_r_multiple * sl_dist;
                     if(g_daily_open < bid && g_daily_open > tp_px)
                        tp_px = g_daily_open;
                     req.type         = QM_SELL;
                     req.price        = bid;
                     req.sl           = NormalizeDouble(sl_px, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
                     req.tp           = NormalizeDouble(tp_px, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
                     req.reason       = "ADR_COUNTER_SHORT";
                     req.symbol_slot  = qm_magic_slot_offset;
                     return true;
                    }
                 }
              }
           }
        }
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // SL/TP set at entry. No trailing needed for this mean-reversion strategy.
  }

bool Strategy_ExitSignal()
  {
   if(!HasOpenPosition()) return false;
   return (g_force_exit || g_bars_held >= strategy_time_stop_bars);
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// =============================================================================
// Framework wiring — do NOT edit below this line unless you know why.
// =============================================================================

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
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket))
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
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
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
