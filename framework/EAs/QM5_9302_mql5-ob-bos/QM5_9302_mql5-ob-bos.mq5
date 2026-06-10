#property strict
#property version   "5.0"
#property description "QM5_9302 — Order Block BOS Inducement (M15)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_9302 — Order Block / Break-of-Structure / Inducement
// Card: D:\QM\strategy_farm\artifacts\cards_approved\QM5_9302_mql5-ob-bos.md
// Source: Allan Munene Mutiiria, MQL5 Articles 2026-04-28
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9302;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal      = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance    = QM_NEWS_COMPLIANCE_DXZ;
input int                      qm_news_stale_max_hours = 336;
input string                   qm_news_min_impact    = "high";
input QM_NewsMode              qm_news_mode_legacy   = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_ob_lookback       = 10;   // bars to scan back for OB candle
input int    strategy_ema_period_h1     = 50;   // H1 EMA period for trend filter
input int    strategy_atr_period        = 14;   // ATR(14) for SL buffer
input double strategy_atr_sl_mult       = 1.0;  // SL = OB edge +/- ATR * mult
input double strategy_tp_rr             = 2.0;  // TP = entry +/- (entry-SL) * rr
input int    strategy_max_hold_bars     = 96;   // max hold in M15 bars before forced exit

// --------------------------------------------------------------------------
// OB zone state — cached per closed bar
// --------------------------------------------------------------------------

#define MAX_OB_ZONES 5

struct OB_Zone
  {
   double   high;
   double   low;
   bool     is_demand;   // true = bullish OB (long), false = bearish OB (short)
   bool     traded;      // one-trade-per-zone gate
   datetime ob_time;     // OB candle open time for dedup
  };

OB_Zone  g_ob[MAX_OB_ZONES];
int      g_n_ob         = 0;
double   g_atr_cache    = 0.0;
double   g_h1_ema_cache = 0.0;

// --------------------------------------------------------------------------
// Zone helpers
// --------------------------------------------------------------------------

void OB_Remove(const int idx)
  {
   if(idx < 0 || idx >= g_n_ob) return;
   for(int i = idx; i < g_n_ob - 1; ++i)
      g_ob[i] = g_ob[i + 1];
   g_n_ob--;
  }

bool OB_Exists(const datetime t)
  {
   for(int i = 0; i < g_n_ob; ++i)
      if(g_ob[i].ob_time == t) return true;
   return false;
  }

void OB_Add(const double zh, const double zl, const bool is_demand, const datetime t)
  {
   if(g_n_ob >= MAX_OB_ZONES || OB_Exists(t)) return;
   g_ob[g_n_ob].high      = zh;
   g_ob[g_n_ob].low       = zl;
   g_ob[g_n_ob].is_demand = is_demand;
   g_ob[g_n_ob].traded    = false;
   g_ob[g_n_ob].ob_time   = t;
   g_n_ob++;
  }

// --------------------------------------------------------------------------
// Per-new-bar state advance — called from Strategy_EntrySignal
// --------------------------------------------------------------------------

void AdvanceState_OnNewBar()
  {
   g_atr_cache    = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   g_h1_ema_cache = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_period_h1, 1);

   // Invalidate zones mitigated by last closed bar
   const double cl1 = iClose(_Symbol, _Period, 1); // perf-allowed: per-bar mitigation check
   if(cl1 > 0.0)
     {
      for(int i = g_n_ob - 1; i >= 0; --i)
        {
         if(g_ob[i].traded) { OB_Remove(i); continue; }
         if(g_ob[i].is_demand && cl1 < g_ob[i].low)  { OB_Remove(i); continue; }
         if(!g_ob[i].is_demand && cl1 > g_ob[i].high) { OB_Remove(i); continue; }
        }
     }

   // Scan for new OB zones (O(lb^2) bounded; lb <= 20 so at most ~400 bar reads per new bar)
   const int lb = MathMin(strategy_ob_lookback, 20);
   if(lb < 2) return;

   for(int i = lb; i >= 2; --i)
     {
      const double o_ob = iOpen(_Symbol,  _Period, i);   // perf-allowed: OB structural scan
      const double h_ob = iHigh(_Symbol,  _Period, i);   // perf-allowed: OB structural scan
      const double l_ob = iLow(_Symbol,   _Period, i);   // perf-allowed: OB structural scan
      const double c_ob = iClose(_Symbol, _Period, i);   // perf-allowed: OB structural scan
      if(o_ob <= 0.0 || h_ob <= l_ob) continue;

      // Pre-OB reference (one bar older than OB = swing pivot)
      const double h_pre = iHigh(_Symbol, _Period, i + 1); // perf-allowed: pre-OB pivot
      const double l_pre = iLow(_Symbol,  _Period, i + 1); // perf-allowed: pre-OB pivot
      if(h_pre <= 0.0) continue;
      const datetime t_ob = iTime(_Symbol, _Period, i); // perf-allowed: zone dedup timestamp
      if(OB_Exists(t_ob)) continue;

      if(c_ob < o_ob)
        {
         // Bearish OB candle → potential bullish demand zone (last push-down before BOS up)
         // BOS up: a close above h_pre in bars [i-1 .. 1]
         bool bos_found  = false;
         int  bos_shift  = i;
         for(int j = i - 1; j >= 1; --j)
           {
            const double c_j = iClose(_Symbol, _Period, j); // perf-allowed: BOS scan
            if(c_j > h_pre) { bos_found = true; bos_shift = j; break; }
           }
         if(!bos_found) continue;

         // Inducement: a lower low than l_ob between OB and BOS candle
         bool ind_found = false;
         for(int j = i - 1; j > bos_shift; --j)
           {
            const double l_j = iLow(_Symbol, _Period, j); // perf-allowed: inducement check
            if(l_j < l_ob) { ind_found = true; break; }
           }
         // If no room between OB and BOS (adjacent bars), treat as immediate BOS = valid
         if(!ind_found && (i - bos_shift) <= 1) ind_found = true;
         if(!ind_found) continue;

         // Zone unmitigated: no close below l_ob from OB to now
         bool mitigated = false;
         for(int j = i - 1; j >= 1; --j)
           {
            const double c_j = iClose(_Symbol, _Period, j); // perf-allowed: mitigation check
            if(c_j < l_ob) { mitigated = true; break; }
           }
         if(mitigated) continue;

         OB_Add(h_ob, l_ob, true, t_ob);
        }
      else if(c_ob > o_ob)
        {
         // Bullish OB candle → potential bearish supply zone (last push-up before BOS down)
         // BOS down: a close below l_pre in bars [i-1 .. 1]
         bool bos_found  = false;
         int  bos_shift  = i;
         for(int j = i - 1; j >= 1; --j)
           {
            const double c_j = iClose(_Symbol, _Period, j); // perf-allowed: BOS scan
            if(c_j < l_pre) { bos_found = true; bos_shift = j; break; }
           }
         if(!bos_found) continue;

         // Inducement: a higher high than h_ob between OB and BOS candle
         bool ind_found = false;
         for(int j = i - 1; j > bos_shift; --j)
           {
            const double h_j = iHigh(_Symbol, _Period, j); // perf-allowed: inducement check
            if(h_j > h_ob) { ind_found = true; break; }
           }
         if(!ind_found && (i - bos_shift) <= 1) ind_found = true;
         if(!ind_found) continue;

         // Zone unmitigated: no close above h_ob from OB to now
         bool mitigated = false;
         for(int j = i - 1; j >= 1; --j)
           {
            const double c_j = iClose(_Symbol, _Period, j); // perf-allowed: mitigation check
            if(c_j > h_ob) { mitigated = true; break; }
           }
         if(mitigated) continue;

         OB_Add(h_ob, l_ob, false, t_ob);
        }
     }
  }

// --------------------------------------------------------------------------
// Strategy hooks
// --------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Advance per-bar state (guaranteed new bar by framework OnTick gate)
   AdvanceState_OnNewBar();

   req.symbol_slot = qm_magic_slot_offset;

   if(g_atr_cache <= 0.0) return false;

   // One active position per magic
   const int magic = QM_FrameworkMagic();
   for(int p = PositionsTotal() - 1; p >= 0; --p)
     {
      const ulong t = PositionGetTicket(p);
      if(!PositionSelectByTicket(t)) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic) return false;
     }

   // H1 trend filter
   const double cl1 = iClose(_Symbol, _Period, 1); // perf-allowed: trend + retest check on last closed bar
   const double hi1 = iHigh(_Symbol,  _Period, 1); // perf-allowed
   const double lo1 = iLow(_Symbol,   _Period, 1); // perf-allowed
   if(cl1 <= 0.0) return false;

   const bool trend_bull = (g_h1_ema_cache > 0.0 && cl1 > g_h1_ema_cache);
   const bool trend_bear = (g_h1_ema_cache > 0.0 && cl1 < g_h1_ema_cache);

   for(int i = 0; i < g_n_ob; ++i)
     {
      if(g_ob[i].traded) continue;
      const double zh = g_ob[i].high;
      const double zl = g_ob[i].low;

      // Last closed bar must touch the zone
      if(lo1 > zh || hi1 < zl) continue;

      if(g_ob[i].is_demand && trend_bull)
        {
         // Long: retest of demand OB with H1 bullish trend; close[1] still above zone_low
         if(cl1 >= zl)
           {
            const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            if(ask <= 0.0) continue;
            const double sl      = zl - g_atr_cache * strategy_atr_sl_mult;
            const double sl_dist = ask - sl;
            if(sl_dist <= 0.0) continue;
            const double tp = ask + sl_dist * strategy_tp_rr;

            req.type   = QM_BUY;
            req.price  = 0.0;
            req.sl     = sl;
            req.tp     = tp;
            req.reason = "OB_DEMAND_BOS_IND";

            g_ob[i].traded = true;
            return true;
           }
        }
      else if(!g_ob[i].is_demand && trend_bear)
        {
         // Short: retest of supply OB with H1 bearish trend; close[1] still below zone_high
         if(cl1 <= zh)
           {
            const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            if(bid <= 0.0) continue;
            const double sl      = zh + g_atr_cache * strategy_atr_sl_mult;
            const double sl_dist = sl - bid;
            if(sl_dist <= 0.0) continue;
            const double tp = bid - sl_dist * strategy_tp_rr;

            req.type   = QM_SELL;
            req.price  = 0.0;
            req.sl     = sl;
            req.tp     = tp;
            req.reason = "OB_SUPPLY_BOS_IND";

            g_ob[i].traded = true;
            return true;
           }
        }
     }
   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Card: no trailing stop or break-even — fixed SL/TP handle exit
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0) return false;

   bool     has_pos      = false;
   bool     pos_is_long  = false;
   datetime pos_open_time = 0;

   for(int p = PositionsTotal() - 1; p >= 0; --p)
     {
      const ulong t = PositionGetTicket(p);
      if(!PositionSelectByTicket(t)) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
      pos_is_long   = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      pos_open_time = (datetime)PositionGetInteger(POSITION_TIME);
      has_pos       = true;
      break;
     }
   if(!has_pos) return false;

   // Max hold: 96 M15 bars
   const int bars_held = (int)((TimeCurrent() - pos_open_time) / PeriodSeconds(_Period));
   if(bars_held >= strategy_max_hold_bars) return true;

   // Opposite validated OB retest → early exit
   if(g_n_ob > 0)
     {
      const double cl1 = iClose(_Symbol, _Period, 1); // perf-allowed: opposite OB exit check
      const double hi1 = iHigh(_Symbol,  _Period, 1); // perf-allowed
      const double lo1 = iLow(_Symbol,   _Period, 1); // perf-allowed
      if(cl1 > 0.0)
        {
         for(int i = 0; i < g_n_ob; ++i)
           {
            if(g_ob[i].traded) continue;
            const double zh = g_ob[i].high;
            const double zl = g_ob[i].low;
            if(lo1 > zh || hi1 < zl) continue;
            // Long + supply zone → exit
            if(pos_is_long && !g_ob[i].is_demand && cl1 <= zh) return true;
            // Short + demand zone → exit
            if(!pos_is_long && g_ob[i].is_demand && cl1 >= zl) return true;
           }
        }
     }
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to framework QM_NewsAllowsTrade2
  }

// --------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line unless you know why.
// --------------------------------------------------------------------------

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"mql5-ob-bos\",\"ea\":\"QM5_9302\"}");
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
