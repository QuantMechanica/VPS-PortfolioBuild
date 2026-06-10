#property strict
#property version   "5.0"
#property description "QM5_9301 Supply-Demand Impulse Retest (mql5-sd-retest)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_9301 — Supply & Demand Impulse Retest
// Card: D:\QM\strategy_farm\artifacts\cards_approved\QM5_9301_mql5-sd-retest.md
// Source: Allan Munene Mutiiria, MQL5 Articles 2025-10-03
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9301;
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
input int    strategy_lookback            = 20;   // bars to scan for candidate zones
input int    strategy_consolidation_bars  = 3;    // bars per consolidation cluster
input int    strategy_impulse_check_bars  = 3;    // bars after cluster to confirm impulse
input double strategy_impulse_multiplier  = 1.0;  // impulse must exceed zone_range * this
input int    strategy_zone_extension_bars = 50;   // zone expires after this many bars
input int    strategy_zone_min_pts        = 50;   // minimum zone width in points
input int    strategy_zone_max_pts        = 500;  // maximum zone width in points
input int    strategy_max_zones           = 8;    // maximum concurrent tracked zones
input int    strategy_atr_period          = 14;   // ATR period for stop-loss buffer
input double strategy_atr_sl_mult         = 1.0;  // SL = zone edge +/- ATR * this
input double strategy_tp_rr               = 2.0;  // TP = entry +/- (entry - SL) * this

// --------------------------------------------------------------------------
// Zone state — cached per closed bar
// --------------------------------------------------------------------------

struct SD_Zone
  {
   double   zone_high;
   double   zone_low;
   double   zone_range_pts;  // width in symbol points
   bool     is_supply;       // true = supply (short), false = demand (long)
   bool     traded;          // NoRetrade: zone used
   int      age_bars;
  };

SD_Zone g_zones[8];  // static array, index 0..g_n_zones-1
int     g_n_zones  = 0;
double  g_atr_cache = 0.0;

// --------------------------------------------------------------------------
// Zone helpers
// --------------------------------------------------------------------------

void SD_RemoveZone(int idx)
  {
   if(idx < 0 || idx >= g_n_zones)
      return;
   for(int i = idx; i < g_n_zones - 1; ++i)
      g_zones[i] = g_zones[i + 1];
   g_n_zones--;
  }

bool SD_ZoneExists(double zh, double zl)
  {
   const double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(pt <= 0.0)
      return false;
   const double tol = pt * 3.0;
   for(int i = 0; i < g_n_zones; ++i)
      if(MathAbs(g_zones[i].zone_high - zh) < tol &&
         MathAbs(g_zones[i].zone_low  - zl) < tol)
         return true;
   return false;
  }

bool SD_AddZone(double zh, double zl, double range_pts, bool is_supply)
  {
   if(g_n_zones >= strategy_max_zones || g_n_zones >= 8)
      return false;
   if(SD_ZoneExists(zh, zl))
      return false;
   g_zones[g_n_zones].zone_high      = zh;
   g_zones[g_n_zones].zone_low       = zl;
   g_zones[g_n_zones].zone_range_pts = range_pts;
   g_zones[g_n_zones].is_supply      = is_supply;
   g_zones[g_n_zones].traded         = false;
   g_zones[g_n_zones].age_bars       = 0;
   g_n_zones++;
   return true;
  }

// --------------------------------------------------------------------------
// Per-new-bar state advance — called from Strategy_EntrySignal (new-bar gate)
// --------------------------------------------------------------------------

void AdvanceState_OnNewBar()
  {
   const double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(pt <= 0.0)
      return;

   // Refresh ATR from last closed bar
   g_atr_cache = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);

   // Age and expire zones
   for(int i = g_n_zones - 1; i >= 0; --i)
     {
      g_zones[i].age_bars++;
      if(g_zones[i].age_bars > strategy_zone_extension_bars || g_zones[i].traded)
        {
         SD_RemoveZone(i);
         continue;
        }
      // Invalidate zone broken by a strong close through it
      if(g_atr_cache > 0.0)
        {
         const double cl1 = iClose(_Symbol, _Period, 1); // perf-allowed: single bar read for zone invalidation
         if(!g_zones[i].is_supply && cl1 < g_zones[i].zone_low - g_atr_cache * 0.5)
           {
            SD_RemoveZone(i);
            continue;
           }
         if(g_zones[i].is_supply && cl1 > g_zones[i].zone_high + g_atr_cache * 0.5)
           {
            SD_RemoveZone(i);
            continue;
           }
        }
     }

   // Scan for new zones
   // Need at least consolidation_bars + impulse_check_bars bars of history
   const int min_start = strategy_consolidation_bars + strategy_impulse_check_bars + 1;
   if(strategy_lookback < min_start)
      return;

   for(int i = strategy_lookback; i >= min_start; --i)
     {
      // Consolidation cluster: bars [i, i + consolidation_bars - 1]
      double zh = -DBL_MAX, zl = DBL_MAX;
      bool   ok = true;
      for(int k = 0; k < strategy_consolidation_bars; ++k)
        {
         const int shift = i + k;
         const double hi = iHigh(_Symbol, _Period, shift); // perf-allowed: zone consolidation scan
         const double lo = iLow(_Symbol, _Period, shift);  // perf-allowed: zone consolidation scan
         if(hi <= 0.0 || lo <= 0.0) { ok = false; break; }
         if(hi > zh) zh = hi;
         if(lo < zl) zl = lo;
        }
      if(!ok || zh <= zl)
         continue;

      const double range_pts = (zh - zl) / pt;
      if(range_pts < (double)strategy_zone_min_pts ||
         range_pts > (double)strategy_zone_max_pts)
         continue;

      // Impulse check: bars [i-1, i - impulse_check_bars] (toward current)
      const double impulse_dist = range_pts * strategy_impulse_multiplier * pt;
      bool imp_up = false, imp_dn = false;
      for(int j = 1; j <= strategy_impulse_check_bars; ++j)
        {
         const int shift = i - j;
         if(shift < 1)
            break;
         const double cl = iClose(_Symbol, _Period, shift); // perf-allowed: impulse check scan
         if(cl <= 0.0)
            continue;
         if(cl > zh + impulse_dist)
            imp_up = true;
         if(cl < zl - impulse_dist)
            imp_dn = true;
        }

      // Impulse up → demand zone (price broke up from consolidation, now may retest from above)
      if(imp_up)
         SD_AddZone(zh, zl, range_pts, false);
      // Impulse down → supply zone
      if(imp_dn)
         SD_AddZone(zh, zl, range_pts, true);
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
   // Advance zone state on each new bar (this function is new-bar gated)
   AdvanceState_OnNewBar();

   req.symbol_slot = qm_magic_slot_offset;

   if(g_n_zones == 0 || g_atr_cache <= 0.0)
      return false;

   // One active position per magic — framework-enforced but double-checked here
   const int magic = QM_FrameworkMagic();
   for(int p = PositionsTotal() - 1; p >= 0; --p)
     {
      const ulong t = PositionGetTicket(p);
      if(!PositionSelectByTicket(t))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }
   const double cl1 = iClose(_Symbol, _Period, 1); // perf-allowed: zone retest check on last closed bar
   const double hi1 = iHigh(_Symbol, _Period, 1); // perf-allowed: zone retest check on last closed bar
   const double lo1 = iLow(_Symbol, _Period, 1);  // perf-allowed: zone retest check on last closed bar
   const double pt  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(cl1 <= 0.0 || pt <= 0.0)
      return false;

   for(int i = 0; i < g_n_zones; ++i)
     {
      if(g_zones[i].traded)
         continue;

      const double zh = g_zones[i].zone_high;
      const double zl = g_zones[i].zone_low;

      // Bar must touch the zone
      if(lo1 > zh || hi1 < zl)
         continue;

      if(!g_zones[i].is_supply)
        {
         // Demand zone — long entry: close[1] inside or above zone (not through zone_low)
         if(cl1 >= zl)
           {
            const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            if(ask <= 0.0)
               continue;
            const double sl     = zl - g_atr_cache * strategy_atr_sl_mult;
            const double sl_dist = ask - sl;
            if(sl_dist <= 0.0)
               continue;
            const double tp = ask + sl_dist * strategy_tp_rr;

            req.type        = QM_BUY;
            req.price       = 0.0;
            req.sl          = sl;
            req.tp          = tp;
            req.reason      = "SD_DEMAND_RETEST";

            g_zones[i].traded = true;
            return true;
           }
        }
      else
        {
         // Supply zone — short entry: close[1] inside or below zone (not through zone_high)
         if(cl1 <= zh)
           {
            const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            if(bid <= 0.0)
               continue;
            const double sl     = zh + g_atr_cache * strategy_atr_sl_mult;
            const double sl_dist = sl - bid;
            if(sl_dist <= 0.0)
               continue;
            const double tp = bid - sl_dist * strategy_tp_rr;

            req.type        = QM_SELL;
            req.price       = 0.0;
            req.sl          = sl;
            req.tp          = tp;
            req.reason      = "SD_SUPPLY_RETEST";

            g_zones[i].traded = true;
            return true;
           }
        }
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Card: no trailing stop or break-even — SL/TP handle exit
  }

bool Strategy_ExitSignal()
  {
   // Early exit if an opposite validated zone is retested
   if(g_n_zones == 0)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   bool has_pos     = false;
   bool pos_is_long = false;
   for(int p = PositionsTotal() - 1; p >= 0; --p)
     {
      const ulong t = PositionGetTicket(p);
      if(!PositionSelectByTicket(t))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      pos_is_long = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      has_pos     = true;
      break;
     }
   if(!has_pos)
      return false;
   const double cl1 = iClose(_Symbol, _Period, 1); // perf-allowed: opposite zone exit check on last closed bar
   const double hi1 = iHigh(_Symbol, _Period, 1); // perf-allowed: opposite zone exit check on last closed bar
   const double lo1 = iLow(_Symbol, _Period, 1);  // perf-allowed: opposite zone exit check on last closed bar
   if(cl1 <= 0.0)
      return false;

   for(int i = 0; i < g_n_zones; ++i)
     {
      if(g_zones[i].traded)
         continue;
      const double zh = g_zones[i].zone_high;
      const double zl = g_zones[i].zone_low;
      if(lo1 > zh || hi1 < zl)
         continue;

      // Long position + supply zone retest → exit long
      if(pos_is_long && g_zones[i].is_supply && cl1 <= zh)
         return true;
      // Short position + demand zone retest → exit short
      if(!pos_is_long && !g_zones[i].is_supply && cl1 >= zl)
         return true;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"mql5-sd-retest\",\"ea\":\"QM5_9301\"}");
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
