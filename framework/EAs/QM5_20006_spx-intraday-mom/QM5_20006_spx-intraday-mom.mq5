#property strict
#property version   "5.0"
#property description "QM5_20006 SPX Intraday Momentum (last half-hour, FTMO V3 Role 3)"
// Strategy Card: QM5_20006_spx-intraday-mom.md, G0 APPROVED 2026-07-19.
// Source: Gao/Han/Li/Zhou 2018 JFE 129:394-414 (DOI 10.1016/j.jfineco.2018.05.009);
// Zarattini/Aziz/Barbon 2024 SFI 24-97 (SSRN 4824172); Bogousslavsky 2016 JF (DOI 10.1111/jofi.12480).

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 20006;
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
input double strategy_signal_vol_mult   = 0.5;   // Card §4+§8: magnitude filter multiplier vs median(|r_fh|).
input int    strategy_vol_lookback      = 20;    // Card §4+§8: trailing sessions used for the median baseline.
input double strategy_stop_atr_mult     = 2.0;   // Card §4+§8: catastrophe stop = mult * ATR(M30,14) from entry.
input double strategy_fh_vol_mult       = 1.0;   // Card §4+§8: first-half-hour realized-vol filter (fh bar range vs trailing median); 0.0 = off (unconditional control).

// -----------------------------------------------------------------------------
// Strategy state / helpers
// -----------------------------------------------------------------------------
// Backward session-anchor scan depth. SP500.DWX is a ~23h CFD grid: 46 M30
// bars per trading day (01:00-23:30 broker), NOT a 13-bar cash-session grid.
// v2 fix 2026-07-21: v1's fixed 800-bar scan could never reach the 21 sessions
// the default lookback needs (~1043 bars; sweep max lookback 30 needs ~1581),
// so the entry gate never fired (Q02 zero-trade draft defect). Depth is now
// derived from the requested session count (64 bars/session upper bound covers
// half-days + holiday slack); hard cap keeps the once-per-day scan bounded.
#define STRATEGY_SCAN_BARS_MAX 4096

int Hhmm(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (dt.hour * 100 + dt.min);
  }

bool SameBrokerDate(const datetime a, const datetime b)
  {
   MqlDateTime da, db;
   TimeToStruct(a, da);
   TimeToStruct(b, db);
   return (da.year == db.year && da.mon == db.mon && da.day == db.day);
  }

// Card §4: r_fh[s] = Close(17:00 broker, session s) / PrevSessionClose(23:00
// broker) - 1. Bar-open-time pattern search (not a fixed shift count) so the
// lookup is robust to weekends/holidays. Each first-half-hour anchor (16:30
// bar) is paired with the nearest OLDER 22:30-open bar (its close = the 23:00
// session close), so half-days lacking a 22:30 bar cannot desynchronise the
// pairing (v2 fix). Also emits the first-half-hour bar range (high-low)/close
// per session for the realized-vol filter (Card §4 primary variant).
// out index 0 = today's session, 1..n_needed-1 = trailing history.
bool ComputeSessionSeries(const int n_needed, double &out_rfh[], double &out_fh_range[])
  {
   const int pc_wanted = n_needed + 4;        // spare prior-close anchors for half-day gaps
   int scan_bars = (n_needed + 6) * 64;       // ~46 bars/session + slack; see header note
   if(scan_bars > STRATEGY_SCAN_BARS_MAX)
      scan_bars = STRATEGY_SCAN_BARS_MAX;

   int fh_shifts[];
   int pc_shifts[];
   ArrayResize(fh_shifts, 0);
   ArrayResize(pc_shifts, 0);
   int fh_found = 0;
   int pc_found = 0;
   for(int i = 1; i < scan_bars && (fh_found < n_needed || pc_found < pc_wanted); ++i)
     {
      const datetime bt = iTime(_Symbol, PERIOD_CURRENT, i); // perf-allowed: bounded backward session-anchor scan, gated to run once/day at the 22:30-broker decision tick only (Card §4).
      if(bt <= 0)
         break;
      const int hm = Hhmm(bt);
      if(hm == 1630 && fh_found < n_needed)
        {
         ArrayResize(fh_shifts, fh_found + 1);
         fh_shifts[fh_found] = i;
         ++fh_found;
        }
      else if(hm == 2230 && pc_found < pc_wanted)
        {
         ArrayResize(pc_shifts, pc_found + 1);
         pc_shifts[pc_found] = i;
         ++pc_found;
        }
     }
   if(fh_found < n_needed || pc_found == 0)
      return false; // session data incomplete (Card §4 skip condition).

   // Card §6: today's signal requires today's own 16:30-17:00 bar (short /
   // late-open holiday sessions are skipped, not traded on stale anchors).
   const datetime bar0_open = iTime(_Symbol, PERIOD_CURRENT, 0);           // perf-allowed: framework new-bar gate guarantees this reads the freshly-opened decision bar once/day.
   const datetime fh0_open  = iTime(_Symbol, PERIOD_CURRENT, fh_shifts[0]); // perf-allowed: session-anchor timestamp paired with the bounded scan above.
   if(!SameBrokerDate(bar0_open, fh0_open))
      return false; // no first-half-hour bar today (Card §6 short-session skip).

   ArrayResize(out_rfh, n_needed);
   ArrayResize(out_fh_range, n_needed);
   int p = 0;
   for(int s = 0; s < n_needed; ++s)
     {
      while(p < pc_found && pc_shifts[p] <= fh_shifts[s])
         ++p; // nearest prev-session-close anchor strictly older than this session's first half-hour.
      if(p >= pc_found)
         return false; // ran out of prior-close anchors (Card §4 skip condition).
      const double c_fh = iClose(_Symbol, PERIOD_CURRENT, fh_shifts[s]); // perf-allowed: session-anchor close paired with the bounded scan above.
      const double c_pc = iClose(_Symbol, PERIOD_CURRENT, pc_shifts[p]); // perf-allowed: session-anchor close paired with the bounded scan above.
      const double h_fh = iHigh(_Symbol, PERIOD_CURRENT, fh_shifts[s]);  // perf-allowed: first-half-hour bar range for the realized-vol filter (Card §4).
      const double l_fh = iLow(_Symbol, PERIOD_CURRENT, fh_shifts[s]);   // perf-allowed: first-half-hour bar range for the realized-vol filter (Card §4).
      if(c_fh <= 0.0 || c_pc <= 0.0 || h_fh < l_fh)
         return false;
      out_rfh[s]      = (c_fh / c_pc) - 1.0;
      out_fh_range[s] = (h_fh - l_fh) / c_fh;
     }
   return true;
  }

double MedianAbs(const double &values[], const int count)
  {
   if(count <= 0)
      return 0.0;
   double tmp[];
   ArrayResize(tmp, count);
   for(int i = 0; i < count; ++i)
      tmp[i] = MathAbs(values[i]);
   ArraySort(tmp);
   if(count % 2 == 1)
      return tmp[count / 2];
   return (tmp[count / 2 - 1] + tmp[count / 2]) / 2.0;
  }

bool Strategy_NoTradeFilter()
  {
   // Card §6: Fridays skipped entirely. No overnight/cross-day position ever
   // exists in this EA (every trade opens 22:30 and is flat by 22:59 the same
   // day), so blocking the whole Friday session here cannot strand an open
   // position without management.
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return (dt.day_of_week == 5);
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   // Card §4: decision happens once, at 22:30 broker (last-half-hour open) —
   // i.e. exactly on the closed-bar tick where the newly opened bar's open
   // time is 22:30. Caller guarantees QM_IsNewBar() == true.
   const datetime bar0_open = iTime(_Symbol, PERIOD_CURRENT, 0); // perf-allowed: framework new-bar gate guarantees this reads the freshly-opened bar exactly once.
   if(bar0_open <= 0 || Hhmm(bar0_open) != 2230)
      return false;

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const int n_needed = strategy_vol_lookback + 1;
   double rfh_series[];
   double fh_range_series[];
   if(!ComputeSessionSeries(n_needed, rfh_series, fh_range_series))
      return false; // session data incomplete (Card §4 skip condition).

   const double r_fh = rfh_series[0];
   double hist[];
   ArrayResize(hist, strategy_vol_lookback);
   for(int i = 0; i < strategy_vol_lookback; ++i)
      hist[i] = rfh_series[i + 1];
   const double median_abs = MedianAbs(hist, strategy_vol_lookback);
   if(median_abs <= 0.0)
      return false;

   // Card §4: magnitude filter -- |r_fh| >= vol_mult * median(|r_fh|, lookback).
   if(MathAbs(r_fh) < strategy_signal_vol_mult * median_abs)
      return false;

   // Card §4 primary variant: first-half-hour realized-vol conditioning.
   // Gao/Han/Li/Zhou 2018: the economics live in the high-vol terciles; the
   // unconditional sign rule is dead OOS post-2013. Mechanism attribution:
   // Baltussen/Da/Lammers/Martens 2021 (gamma-hedging demand, SSRN 3760365).
   // Range-vs-trailing-median is our pre-registered structural adaptation:
   // self-referencing, no fitted absolute threshold (Q08 neighborhood-safe).
   if(strategy_fh_vol_mult > 0.0)
     {
      double range_hist[];
      ArrayResize(range_hist, strategy_vol_lookback);
      for(int i = 0; i < strategy_vol_lookback; ++i)
         range_hist[i] = fh_range_series[i + 1];
      const double median_range = MedianAbs(range_hist, strategy_vol_lookback);
      if(median_range <= 0.0)
         return false;
      if(fh_range_series[0] < strategy_fh_vol_mult * median_range)
         return false;
     }

   const double atr_m30 = QM_ATR(_Symbol, PERIOD_CURRENT, 14, 1);
   if(atr_m30 <= 0.0)
      return false;

   const bool is_long = (r_fh > 0.0);
   const double entry_price = is_long ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry_price <= 0.0)
      return false;

   req.type = is_long ? QM_BUY : QM_SELL;
   req.price = 0.0;
   req.sl = QM_StopATRFromValue(_Symbol, req.type, entry_price, atr_m30, strategy_stop_atr_mult); // Card §4: catastrophe stop, non-alpha.
   req.tp = 0.0; // Card §5: no fixed target, exit is time-based.
   req.reason = "spx_intraday_mom_lasthalfhour";
   return (req.sl > 0.0);
  }

void Strategy_ManageOpenPosition()
  {
   // Card §7: no trailing / partial / BE logic.
  }

bool Strategy_ExitSignal()
  {
   // Card §5: time exit at 22:59 broker (one minute before cash close), always
   // flat overnight. Evaluated every tick (not bar-gated) since 22:59 does not
   // align to the M30 bar grid.
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   const int hhmm = dt.hour * 100 + dt.min;
   return (hhmm >= 2259);
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // Card §6: framework news filter stays ON, no override requested.
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line unless you know why.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_20006\",\"ea\":\"spx-intraday-mom\"}");
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
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
        }
     }

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

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
