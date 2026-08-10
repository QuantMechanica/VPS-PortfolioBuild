#property strict
#property version   "5.0"
#property description "QM5_20075 Camarilla Inner-Pivot Fade (H1/M15 intraday)"
// Strategy Card: QM5_20075 (camarilla-inner-pivot-fade), G0 APPROVED.
// Source lineage: 6e967762-b26d-59a3-b076-35c17f2e7c36 (ForexFactory community
// Camarilla Equation cluster). Recovered from QM5_1261. INNER-pivot variant:
// fades the tight H1/L1 band around the prior close toward the mid pivot P
// (distinct from the OUTER-pivot sibling QM5_1232 S3/R3 fade + S4/R4 breakout).

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — Camarilla Inner-Pivot Fade (intraday)
// -----------------------------------------------------------------------------
// Daily closed-form Camarilla levels are computed ONCE per broker day from the
// prior D1 bar's H/L/C and cached (H1/L1/H2/L2/H3/L3, mid-pivot P, and the two
// hard-stop prices). The prior closed M15 bar's High/Low are cached once per
// M15 bar for the inner-fade gate. The per-tick path only compares the current
// Bid/Ask to those cached levels inside the 06:00-18:00 broker-time window.
//
// LONG  : Bid <= L1 AND prior closed M15 Low  > L2. Market buy. TP=P,
//         SL=L2-frac*(L2-L3) (below L2, ~halfway to L3).
// SHORT : Ask >= H1 AND prior closed M15 High < H2. Market sell. TP=P,
//         SL=H2+frac*(H3-H2) (above H2, ~halfway to H3).
// Exits : broker-side TP at pivot P; broker-side hard SL; EOD force-flatten at
//         21:00 broker-time; and an opposite-pivot soft exit when an hourly bar
//         CLOSES beyond the far inner band (long close>H2 / short close<L2).
//
// Framework corset: the per-tick path is O(1) (cached-level comparisons + a
// spread gate). All bar reads (D1/M15/H1 H/L/C) sit behind per-timeframe
// QM_IsNewBar() gates and are tagged // perf-allowed (bespoke pivot math, not a
// reimplementable indicator). Everything is broker/server-time native
// (TimeCurrent() + D1 bar boundary == broker midnight), so no UTC/DST
// conversion is needed for the pivot day-boundary or the trade window.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 20075;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_trade_start_hour  = 6;     // Card: no new entries before 06:00 broker-time.
input int    strategy_trade_end_hour    = 18;    // Card: no new entries at/after 18:00 broker-time.
input int    strategy_eod_flatten_hour  = 21;    // Card: force-flatten open positions at/after 21:00 broker-time.
input double strategy_sl_gap_frac       = 0.5;   // Card: SL fraction of the (L2,L3)/(H2,H3) gap (P3 {0.25,0.5,0.75,1.0}).
input int    strategy_spread_cap_pts    = 20;    // Card: spread cap (points); only blocks a genuinely wide spread.
input bool   strategy_opp_break_exit    = true;  // Card: tertiary opposite-pivot soft exit (P3-toggleable).

// -----------------------------------------------------------------------------
// File-scope cached state.
// -----------------------------------------------------------------------------
// Daily Camarilla levels (advanced once per new D1 bar = broker midnight).
bool   g_levels_valid = false;
double g_cam_H1 = 0.0, g_cam_L1 = 0.0;   // inner band (touch/entry).
double g_cam_H2 = 0.0, g_cam_L2 = 0.0;   // mid band (inner-fade gate + soft exit).
double g_cam_H3 = 0.0, g_cam_L3 = 0.0;   // outer-of-inner band (hard-stop anchor).
double g_cam_P  = 0.0;                    // floor pivot (H+L+C)/3 = take-profit target.
double g_long_sl  = 0.0;                  // LONG hard stop price.
double g_short_sl = 0.0;                  // SHORT hard stop price.

// Prior closed M15 bar's extremes (advanced once per new M15 bar) for the gate.
bool   g_m15_valid = false;
double g_m15_low  = 0.0;
double g_m15_high = 0.0;

// Open-position tracking for the intraday exits.
int    g_pos_dir   = 0;      // 0 flat / +1 long / -1 short.
bool   g_soft_exit = false;  // set on an hourly close beyond the opposite inner band.

// -----------------------------------------------------------------------------
// Per-bar advance functions (each behind its own QM_IsNewBar cadence gate).
// -----------------------------------------------------------------------------

// Recompute the daily Camarilla level set from the prior completed D1 bar.
void AdvanceDailyPivots()
  {
   const double H = iHigh(_Symbol, PERIOD_D1, 1);  // perf-allowed: prior-day high for Camarilla pivots (once/day).
   const double L = iLow(_Symbol, PERIOD_D1, 1);   // perf-allowed: prior-day low for Camarilla pivots (once/day).
   const double C = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: prior-day close for Camarilla pivots (once/day).
   const double rng = H - L;
   if(H <= 0.0 || L <= 0.0 || C <= 0.0 || rng <= 0.0)
     {
      g_levels_valid = false;
      return;
     }

   // Closed-form Camarilla multipliers (fixed constants, R4: no adaptivity).
   g_cam_H1 = C + rng * 1.1 / 12.0;
   g_cam_L1 = C - rng * 1.1 / 12.0;
   g_cam_H2 = C + rng * 1.1 / 6.0;
   g_cam_L2 = C - rng * 1.1 / 6.0;
   g_cam_H3 = C + rng * 1.1 / 4.0;
   g_cam_L3 = C - rng * 1.1 / 4.0;
   g_cam_P  = (H + L + C) / 3.0;

   // Hard stops just beyond the mid band, a fraction into the (L2,L3)/(H2,H3) gap.
   g_long_sl  = g_cam_L2 - strategy_sl_gap_frac * (g_cam_L2 - g_cam_L3); // below L2.
   g_short_sl = g_cam_H2 + strategy_sl_gap_frac * (g_cam_H3 - g_cam_H2); // above H2.

   g_levels_valid = true;
  }

// Cache the prior closed M15 bar's extremes for the inner-fade gate.
void AdvanceM15Gate()
  {
   const double low1  = iLow(_Symbol, PERIOD_M15, 1);  // perf-allowed: prior M15 closed-bar low (inner-fade gate).
   const double high1 = iHigh(_Symbol, PERIOD_M15, 1); // perf-allowed: prior M15 closed-bar high (inner-fade gate).
   if(low1 <= 0.0 || high1 <= 0.0)
     {
      g_m15_valid = false;
      return;
     }
   g_m15_low  = low1;
   g_m15_high = high1;
   g_m15_valid = true;
  }

// Evaluate the opposite-pivot soft exit on each closed hourly bar.
void AdvanceHourly()
  {
   if(g_pos_dir == 0 || !g_levels_valid || !strategy_opp_break_exit)
      return;
   const double h1_close = iClose(_Symbol, PERIOD_H1, 1); // perf-allowed: hourly close for opposite-pivot soft exit.
   if(h1_close <= 0.0)
      return;
   // Card tertiary exit: long closes out if an hourly bar closes above H2;
   // short closes out if an hourly bar closes below L2.
   if(g_pos_dir > 0 && h1_close > g_cam_H2)
      g_soft_exit = true;
   if(g_pos_dir < 0 && h1_close < g_cam_L2)
      g_soft_exit = true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks.
// -----------------------------------------------------------------------------

// No Trade Filter — spread gate only. Never fail-closed on zero modeled spread
// (.DWX invariant #1): block only a genuinely wide spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;
   const double cap = strategy_spread_cap_pts * point;
   if(ask > 0.0 && bid > 0.0 && ask > bid && (ask - bid) > cap)
      return true;
   return false;
  }

// Trade Entry — per-tick intrabar touch of the inner band, gated by the prior
// M15 close and the 06:00-18:00 broker-time window. Reads cached levels only.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(!g_levels_valid || !g_m15_valid)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;
   // One position per symbol per magic.
   if(g_pos_dir != 0 || QM_TM_OpenPositionCount(magic) > 0)
      return false;

   // Trade window: 06:00-18:00 broker-time, Mon-Fri (server time is broker time).
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.day_of_week < 1 || dt.day_of_week > 5)
      return false;
   if(dt.hour < strategy_trade_start_hour || dt.hour >= strategy_trade_end_hour)
      return false;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return false;

   // LONG: Bid touches L1 while the prior M15 low is still above L2.
   if(bid <= g_cam_L1 && g_m15_low > g_cam_L2)
     {
      const double sl = QM_StopRulesNormalizePrice(_Symbol, g_long_sl);
      const double tp = QM_StopRulesNormalizePrice(_Symbol, g_cam_P);
      // Valid long geometry only: SL below entry, TP (pivot P) above entry.
      if(sl > 0.0 && sl < ask && tp > ask)
        {
         req.type = QM_BUY;
         req.price = 0.0;
         req.sl = sl;
         req.tp = tp;
         req.reason = "CAM_L1_FADE_LONG";
         req.symbol_slot = qm_magic_slot_offset;
         req.expiration_seconds = 0;
         g_pos_dir = 1;
         g_soft_exit = false;
         return true;
        }
      return false;
     }

   // SHORT: Ask touches H1 while the prior M15 high is still below H2.
   if(ask >= g_cam_H1 && g_m15_high < g_cam_H2)
     {
      const double sl = QM_StopRulesNormalizePrice(_Symbol, g_short_sl);
      const double tp = QM_StopRulesNormalizePrice(_Symbol, g_cam_P);
      // Valid short geometry only: SL above entry, TP (pivot P) below entry.
      if(sl > bid && tp > 0.0 && tp < bid)
        {
         req.type = QM_SELL;
         req.price = 0.0;
         req.sl = sl;
         req.tp = tp;
         req.reason = "CAM_H1_FADE_SHORT";
         req.symbol_slot = qm_magic_slot_offset;
         req.expiration_seconds = 0;
         g_pos_dir = -1;
         g_soft_exit = false;
         return true;
        }
      return false;
     }

   return false;
  }

// Trade Management — no trailing/BE/partial in the baseline (card §Stop Loss is a
// fixed SL/TP). Reconcile the cached direction against live open positions so the
// exit/entry state stays correct after a broker-side SL/TP fill.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic > 0 && QM_TM_OpenPositionCount(magic) == 0)
     {
      g_pos_dir = 0;
      g_soft_exit = false;
     }
  }

// Trade Close — reads the once-per-bar soft-exit flag plus the O(1) EOD-flatten
// time check. Broker-side TP (pivot P) and hard SL ride independently.
bool Strategy_ExitSignal()
  {
   if(g_pos_dir == 0)
      return false;
   if(g_soft_exit)
      return true;
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.hour >= strategy_eod_flatten_hour)
      return true; // EOD force-flatten (intraday-only; no overnight risk).
   return false;
  }

// News Filter Hook — defer to the central QM_NewsAllowsTrade gate (off for P2).
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line unless you know why. OnTick is
// adapted for the intraday per-tick-touch entry (SOP Intraday Discipline): the
// cached state advances on each timeframe's QM_IsNewBar cadence, management and
// exits run every tick, and the entry hook runs per tick reading cached levels.
// -----------------------------------------------------------------------------

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy,           // legacy back-compat
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,                            // pause-before (legacy hint)
                        30,                            // pause-after (legacy hint)
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,              // FW1 Axis A
                        qm_news_compliance))           // FW1 Axis B
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_20075_camarilla-inner-pivot-fade\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   // Q08 evidence lifecycle: sample floating P&L before any per-tick guard can
   // return.
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(QM_FrameworkHandleFridayClose())
      return;

   // Advance cached state on each timeframe's own cadence (independent latches).
   if(QM_IsNewBar(_Symbol, PERIOD_D1))
     {
      AdvanceDailyPivots();
      QM_EquityStreamOnNewBar();
     }
   if(QM_IsNewBar(_Symbol, PERIOD_M15))
      AdvanceM15Gate();
   if(QM_IsNewBar(_Symbol, PERIOD_H1))
      AdvanceHourly();

   // Management + rule-based exits run EVERY tick, through news/spread windows.
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

   // ---- entry path (gates NEW entries only; never management/exits above) ----
   if(Strategy_NewsFilterHook(broker_now))
      return;
   if(Strategy_NoTradeFilter())
      return;

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   QM_EntryRequest req;
   ZeroMemory(req);
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
