#property strict
#property version   "5.0"
#property description "QM5_12549 Turtle System 2 - 55-day Donchian breakout, N-unit sizing, pyramiding D1"

#include <QM/QM_Common.mqh>

// ============================================================================
// QM5_12549 - Turtle System 2 (Faith 2007, Appendix A)
// 55-day Donchian channel breakout; ATR/N unit sizing; pyramid up to 4 units
// at 1/2N intervals; 2N trailing stop converging on all units; 20-day channel
// exit; no System 1 skip rule.
//
// Pyramid magic scheme: each unit uses slot = qm_magic_slot_offset + unit_idx.
// Register 4 consecutive slots per symbol instance in magic_numbers.csv.
// ============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                      = 12549;
input int    qm_magic_slot_offset          = 0;
input uint   qm_rng_seed                   = 42;

input group "Risk"
input double RISK_PERCENT                  = 0.0;
input double RISK_FIXED                    = 1000.0;
input double PORTFOLIO_WEIGHT              = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours               = 336;
input string qm_news_min_impact                    = "high";
input QM_NewsMode qm_news_mode_legacy              = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled       = true;
input int    qm_friday_close_hour_broker   = 21;

input group "Stress"
input double qm_stress_reject_probability  = 0.0;

input group "Strategy"
input int    strategy_entry_period         = 55;   // Donchian breakout lookback (S2 = 55)
input int    strategy_exit_period          = 20;   // Channel exit lookback (S2 = 20)
input double strategy_n_stop_mult         = 2.0;  // ATR multiple for initial/trailing stop
input double strategy_n_pyramid_mult      = 0.5;  // ATR multiple between pyramid adds
input int    strategy_max_units            = 4;    // Maximum pyramid units per instrument

// ----------------------------------------------------------------------------
// File-scope cached Donchian + ATR state - updated once per closed D1 bar
// ----------------------------------------------------------------------------
double   g_n                = 0.0;   // Current Wilder ATR (N value) at last closed bar
double   g_donch_long       = 0.0;   // HHV of entry_period bars before bar[1] (long breakout)
double   g_donch_short      = 0.0;   // LLV of entry_period bars before bar[1] (short breakout)
double   g_exit_long_level  = 0.0;   // LLV of exit_period closed bars (long channel exit)
double   g_exit_short_level = 0.0;   // HHV of exit_period closed bars (short channel exit)

// Position state — restored from open positions on EA restart
int      g_units            = 0;     // Current open unit count (0-4)
double   g_last_add_price   = 0.0;   // Fill price of the most recently opened unit
double   g_current_stop     = 0.0;   // Trailing stop shared by all units
int      g_dir              = 0;     // 1=long, -1=short, 0=flat

// ----------------------------------------------------------------------------
// Internal helpers
// ----------------------------------------------------------------------------

int UnitMagic(const int unit_idx)
  {
   const int slot = qm_magic_slot_offset + unit_idx;
   if(!QM_MagicRegistered(qm_ea_id, slot))
      return -1;
   return QM_Magic(qm_ea_id, slot);
  }

bool IsOurPosition(const int pos_magic)
  {
   for(int unit_idx = 0; unit_idx < strategy_max_units; ++unit_idx)
     {
      const int unit_magic = UnitMagic(unit_idx);
      if(unit_magic > 0 && pos_magic == unit_magic)
         return true;
     }
   return false;
  }

int CountOurPositions()
  {
   int cnt = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      ulong tk = PositionGetTicket(i);
      if(tk == 0 || !PositionSelectByTicket(tk)) continue;
      if(IsOurPosition((int)PositionGetInteger(POSITION_MAGIC))) cnt++;
     }
   return cnt;
  }

void CloseAllUnits()
  {
   int closed = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      ulong tk = PositionGetTicket(i);
      if(tk == 0 || !PositionSelectByTicket(tk)) continue;
      if(!IsOurPosition((int)PositionGetInteger(POSITION_MAGIC))) continue;
      closed++;
      QM_TM_ClosePosition(tk, QM_EXIT_STRATEGY);
     }
   g_units = 0;
   g_dir = 0;
   g_last_add_price = 0.0;
   g_current_stop = 0.0;
  }

void UpdateAllStops(const double new_stop)
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      ulong tk = PositionGetTicket(i);
      if(tk == 0 || !PositionSelectByTicket(tk)) continue;
      if(!IsOurPosition((int)PositionGetInteger(POSITION_MAGIC))) continue;
      if(MathAbs(PositionGetDouble(POSITION_SL) - new_stop) > _Point)
         QM_TM_MoveSL(tk, new_stop, "turtle_pyramid_stop_convergence");
     }
  }

// Advance closed-bar state - called exactly once per QM_IsNewBar() == true.
void AdvanceState_OnNewBar()
  {
   // N = Wilder-smooth ATR from framework (handles warmup)
   g_n = QM_ATR(_Symbol, PERIOD_D1, 20, 1);

   // Donchian entry channel: HHV/LLV of strategy_entry_period bars BEFORE bar[1]
   // (bars[2..entry_period+1] relative to bar[0] = current forming bar)
   // perf-allowed: bespoke structural Donchian channel — no framework equivalent
   double hh = iHigh(_Symbol, PERIOD_D1, 2); // perf-allowed
   double ll = iLow(_Symbol, PERIOD_D1, 2);  // perf-allowed
   for(int i = 3; i <= strategy_entry_period + 1; i++)
     {
      double h = iHigh(_Symbol, PERIOD_D1, i); // perf-allowed
      double l = iLow(_Symbol, PERIOD_D1, i);  // perf-allowed
      if(h > hh) hh = h;
      if(l < ll) ll = l;
     }
   g_donch_long  = hh;
   g_donch_short = ll;

   // Channel exit level: LLV/HHV of strategy_exit_period most recent closed bars (bars[1..exit_period])
   // perf-allowed: bespoke structural lookback — no framework equivalent
   double eh = iHigh(_Symbol, PERIOD_D1, 1); // perf-allowed
   double el = iLow(_Symbol, PERIOD_D1, 1);  // perf-allowed
   for(int i = 2; i <= strategy_exit_period; i++)
     {
      double h = iHigh(_Symbol, PERIOD_D1, i); // perf-allowed
      double l = iLow(_Symbol, PERIOD_D1, i);  // perf-allowed
      if(h > eh) eh = h;
      if(l < el) el = l;
     }
   g_exit_long_level  = el;  // Long exits when bid drops to/below this
   g_exit_short_level = eh;  // Short exits when ask rises to/above this

   // Sync unit count: stop-outs between bars will reduce actual position count
   int real_count = CountOurPositions();
   if(g_dir != 0 && real_count < g_units)
     {
      if(real_count == 0)
        {
         // All units stopped out; System 2 has no skip rule.
         g_units = 0;
         g_dir = 0;
         g_last_add_price = 0.0;
         g_current_stop = 0.0;
        }
      else
        {
         g_units = real_count; // Partial stop-out is rare with converging stops.
        }
     }
  }

// ----------------------------------------------------------------------------
// Strategy hooks — implement the five required sections
// ----------------------------------------------------------------------------

// No Trade Filter - no additional filter beyond news/friday-close
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Entry Signal - called on new D1 bar when flat (g_dir == 0)
// Detects 55-day Donchian breakout and fills entry request
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(g_dir != 0) return false;
   if(g_n <= 0.0) return false;

   // Check bar[1] (last closed bar) against prior entry_period bars
   const double bar1_high = iHigh(_Symbol, PERIOD_D1, 1); // perf-allowed
   const double bar1_low  = iLow(_Symbol, PERIOD_D1, 1);  // perf-allowed
   const bool long_break  = (bar1_high > g_donch_long);
   const bool short_break = (bar1_low  < g_donch_short);
   if(!long_break && !short_break) return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(long_break)
     {
      const double sl = ask - strategy_n_stop_mult * g_n;
      if(sl <= 0.0 || (ask - sl) < _Point) return false;
      req.type         = QM_BUY;
      req.price        = ask;
      req.sl           = sl;
      req.tp           = 0.0;
      req.symbol_slot  = qm_magic_slot_offset;  // Unit 0 base slot
      req.reason       = "turtle_s2_long_entry";
     }
   else
     {
      const double sl = bid + strategy_n_stop_mult * g_n;
      if((sl - bid) < _Point) return false;
      req.type         = QM_SELL;
      req.price        = bid;
      req.sl           = sl;
      req.tp           = 0.0;
      req.symbol_slot  = qm_magic_slot_offset;  // Unit 0 base slot
      req.reason       = "turtle_s2_short_entry";
     }
   return true;
  }

// Trade Management - called every tick when positions are open
// Handles: Friday close (all units), 20-day channel exit, pyramid adds
void Strategy_ManageOpenPosition()
  {
   if(g_dir == 0 || g_n <= 0.0) return;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   // Friday close: explicitly close ALL units (framework only closes base magic)
   if(qm_friday_close_enabled && QM_FrameworkFridayCloseNow(TimeCurrent()))
     {
      CloseAllUnits();
      return;
     }

   // 20-day channel exit (all units exit simultaneously)
   if(g_dir == 1  && bid <= g_exit_long_level)  { CloseAllUnits(); return; }
   if(g_dir == -1 && ask >= g_exit_short_level) { CloseAllUnits(); return; }

   // Pyramid add: add one unit per 1/2N of favorable move from last fill
   if(g_units < strategy_max_units)
     {
      const bool add_long  = (g_dir == 1  && ask >= g_last_add_price + strategy_n_pyramid_mult * g_n);
      const bool add_short = (g_dir == -1 && bid <= g_last_add_price - strategy_n_pyramid_mult * g_n);

      if(add_long || add_short)
        {
         const double new_stop = add_long
            ? (ask - strategy_n_stop_mult * g_n)
            : (bid + strategy_n_stop_mult * g_n);

         if((add_long  && (ask - new_stop) >= _Point) ||
            (add_short && (new_stop - bid) >= _Point))
           {
            QM_EntryRequest add_req;
            ZeroMemory(add_req);
            if(add_long)
              {
               add_req.type        = QM_BUY;
               add_req.price       = ask;
               add_req.sl          = new_stop;
               add_req.tp          = 0.0;
               add_req.symbol_slot = qm_magic_slot_offset + g_units;  // Next unit slot
               add_req.reason      = "turtle_pyramid_add";
              }
            else
              {
               add_req.type        = QM_SELL;
               add_req.price       = bid;
               add_req.sl          = new_stop;
               add_req.tp          = 0.0;
               add_req.symbol_slot = qm_magic_slot_offset + g_units;
               add_req.reason      = "turtle_pyramid_add";
              }

            ulong add_ticket = 0;
            const bool ok = QM_TM_OpenPosition(add_req, add_ticket);
            if(ok && add_ticket > 0)
              {
               g_units++;
               g_last_add_price = add_long ? ask : bid;
               g_current_stop   = new_stop;
               // Converge ALL unit stops to 2N from the newest entry
               UpdateAllStops(new_stop);
              }
           }
        }
     }
  }

// Exit Signal - 20-day channel exit and pyramid add are handled in ManageOpenPosition
bool Strategy_ExitSignal()
  {
   return false;
  }

// News Filter Hook - defer to framework 2-axis news filter
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// ----------------------------------------------------------------------------
// Framework wiring - standard framework lifecycle, extended for pyramid state
// ----------------------------------------------------------------------------

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

   // Restore pyramid position state from open positions
   g_units = 0; g_dir = 0; g_last_add_price = 0.0; g_current_stop = 0.0;
   double highest_fill = 0.0;
   double lowest_fill  = DBL_MAX;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      ulong tk = PositionGetTicket(i);
      if(tk == 0 || !PositionSelectByTicket(tk)) continue;
      if(!IsOurPosition((int)PositionGetInteger(POSITION_MAGIC))) continue;
      g_units++;
      ENUM_POSITION_TYPE pt = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(g_dir == 0) g_dir = (pt == POSITION_TYPE_BUY) ? 1 : -1;
      double fill = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl   = PositionGetDouble(POSITION_SL);
      if(g_dir == 1 && fill >= highest_fill)
        {
         highest_fill = fill;
         g_current_stop = sl;
        }
      if(g_dir == -1 && fill <= lowest_fill)
        {
         lowest_fill = fill;
         g_current_stop = sl;
        }
     }
   if(g_dir == 1)  g_last_add_price = highest_fill;
   if(g_dir == -1) g_last_add_price = lowest_fill;

   QM_LogEvent(QM_INFO, "INIT_OK", StringFormat("{\"units\":%d,\"dir\":%d}",
               g_units, g_dir));
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

   // 2-axis news check (FW1)
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   // Per-tick: pyramid management, exit check, and custom friday close.
   // Strategy_ManageOpenPosition handles friday close for all pyramid units;
   // we still call QM_FrameworkHandleFridayClose to keep the framework log correct.
   Strategy_ManageOpenPosition();
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // Per-tick discretionary exit (handled in ManageOpenPosition; always false here)
   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   // Per-closed-bar: advance channel state and evaluate initial entry
   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();
   AdvanceState_OnNewBar();

   // Only open initial unit when flat
   if(g_dir == 0)
     {
      QM_EntryRequest req;
      ZeroMemory(req);
      if(Strategy_EntrySignal(req))
        {
         ulong out_ticket = 0;
         const bool ok = QM_TM_OpenPosition(req, out_ticket);
         if(ok && out_ticket > 0)
           {
            g_dir            = (req.type == QM_BUY) ? 1 : -1;
            g_units          = 1;
            g_last_add_price = req.price;
            g_current_stop   = req.sl;
           }
        }
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
