#property strict
#property version   "5.0"
#property description "QM5_20007 — Configurable Intraday Engine (Lanes x Gates)"

#include <QM/QM_Common.mqh>

//=============================================================================
// Lane type — selectable via setfile input
//=============================================================================
enum IntraLane
  {
   LANE_MOMENTUM_BAND = 0,   // Noise-area breakout from session open (Gao 2018 / Zarattini-Aziz)
   LANE_ORB           = 1,   // Opening-range breakout after orb_minutes
   LANE_GOLD_BREAKOUT = 2    // XAUUSD daily-open + ATR band breach (EOD flat)
  };

//=============================================================================
// QuantMechanica V5 Framework inputs
//=============================================================================
input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 20007;
input int    qm_magic_slot_offset        = 0;     // 0=GDAXI 1=NDX 2=SP500 3=XAUUSD
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal    = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance  = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours               = 336;
input string qm_news_min_impact                    = "high";
input QM_NewsMode qm_news_mode_legacy              = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

//=============================================================================
// Strategy inputs
//=============================================================================
input group "Strategy"
input IntraLane intraday_lane            = LANE_MOMENTUM_BAND;  // Signal lane; swap per setfile

input group "Session Gate (broker time)"
input int    session_start_hour          = 10;   // Default: DAX open 10:00 broker (EU/US clocks track)
input int    session_end_hour            = 17;   // Stop new entries at this broker hour
input int    eod_flat_hour               = 17;   // Force-flat all positions at this broker hour

input group "Vol Regime Gate"
input int    vol_short_period            = 8;    // Short ATR period
input int    vol_long_period             = 40;   // Long ATR period
input double vol_expand_ratio            = 1.0;  // ATR_short/ATR_long >= ratio = expansion; 0 = gate off

input group "Momentum Band"
input int    mb_atr_period               = 14;   // ATR period for noise band width on _Period
input double mb_band_mult                = 1.0;  // Band width = mult * ATR(mb_atr_period)
input bool   mb_vwap_trail               = true; // Trail SL toward session VWAP

input group "Opening Range Breakout"
input int    orb_minutes                 = 30;   // Opening-range window in minutes
input double orb_buf_mult                = 0.25; // Entry buffer beyond OR extreme = mult * ATR
input double orb_tp_rr                   = 2.0;  // TP at rr x initial R; 0 = no fixed TP

input group "Gold Breakout"
input int    gb_d1_atr_period            = 14;   // D1 ATR period for band
input double gb_atr_mult                 = 1.5;  // Band = daily_open +/- mult * ATR(D1)

input group "Stop"
input double stop_atr_mult               = 1.5;  // Initial SL = mult * ATR(mb_atr_period) from entry

input group "Cost Gate"
input double cost_mult                   = 3.0;  // Expected ATR move must exceed spread by this multiple

//=============================================================================
// Closed-bar cached state — advanced once per bar in AdvanceState_OnNewBar
//=============================================================================
double   g_session_open    = 0.0;
bool     g_in_session      = false;
double   g_cum_tpv         = 0.0;   // cumulative (typical_price * volume) for session VWAP
double   g_cum_vol         = 0.0;   // cumulative volume for session VWAP
double   g_session_vwap    = 0.0;
double   g_orb_high        = 0.0;
double   g_orb_low         = 0.0;
bool     g_orb_formed      = false;
int      g_session_bars    = 0;     // bars elapsed inside session window today
bool     g_vol_regime_ok   = false;
int      g_last_day_key    = 0;     // YYYYMMDD integer — detects new trading day
double   g_daily_open      = 0.0;   // for GOLD_BREAKOUT: current day's D1 open price

//=============================================================================
// Helper: integer date key (YYYYMMDD) from broker datetime
//=============================================================================
int DayKey(const datetime t)
  {
   MqlDateTime mdt;
   TimeToStruct(t, mdt);
   return mdt.year * 10000 + mdt.mon * 100 + mdt.day;
  }

//=============================================================================
// Helper: broker hour (0-23) from datetime
//=============================================================================
int BrokerHour(const datetime t)
  {
   MqlDateTime mdt;
   TimeToStruct(t, mdt);
   return mdt.hour;
  }

//=============================================================================
// AdvanceState_OnNewBar
// Called exactly ONCE per closed bar (inside is_new_bar gate in OnTick).
// Updates all file-scope cached state. Direct iX calls below are
// // perf-allowed: bespoke VWAP accumulation + session-open / daily-open reference.
//=============================================================================
void AdvanceState_OnNewBar()
  {
   const datetime broker_now = TimeCurrent();
   const int day_key  = DayKey(broker_now);
   const int hour_now = BrokerHour(broker_now);

   // New trading day — reset all session state
   if(day_key != g_last_day_key)
     {
      g_last_day_key  = day_key;
      g_session_open  = 0.0;
      g_daily_open    = iOpen(_Symbol, PERIOD_D1, 0); // perf-allowed: daily open for GOLD_BREAKOUT
      g_in_session    = false;
      g_cum_tpv       = 0.0;
      g_cum_vol       = 0.0;
      g_session_vwap  = 0.0;
      g_orb_high      = 0.0;
      g_orb_low       = 0.0;
      g_orb_formed    = false;
      g_session_bars  = 0;
     }

   // Vol regime: ATR_short / ATR_long >= vol_expand_ratio
   const double atr_s = QM_ATR(_Symbol, _Period, vol_short_period, 1);
   const double atr_l = QM_ATR(_Symbol, _Period, vol_long_period,  1);
   if(vol_expand_ratio <= 0.0)
      g_vol_regime_ok = true;
   else
      g_vol_regime_ok = (atr_l > 0.0 && atr_s > 0.0 && (atr_s / atr_l) >= vol_expand_ratio);

   // Outside session window — mark not in session and return
   if(hour_now < session_start_hour || hour_now >= session_end_hour)
     {
      g_in_session = false;
      return;
     }

   // First bar in the session today
   if(!g_in_session)
     {
      g_session_open = iOpen(_Symbol, _Period, 1); // perf-allowed: session open reference
      g_in_session   = true;
      g_session_bars = 1;
     }
   else
     {
      g_session_bars++;
     }

   // Update session VWAP with just-closed bar (typical_price * volume)
   const double h1 = iHigh(_Symbol, _Period, 1);           // perf-allowed: VWAP accumulation
   const double l1 = iLow(_Symbol, _Period, 1);            // perf-allowed: VWAP accumulation
   const double c1 = iClose(_Symbol, _Period, 1);          // perf-allowed: VWAP accumulation
   const double v1 = (double)iVolume(_Symbol, _Period, 1); // perf-allowed: VWAP accumulation
   if(v1 > 0.0)
     {
      const double tp = (h1 + l1 + c1) / 3.0;
      g_cum_tpv     += tp * v1;
      g_cum_vol     += v1;
      g_session_vwap = (g_cum_vol > 0.0) ? (g_cum_tpv / g_cum_vol) : c1;
     }

   // ORB: build opening range during first orb_bars bars of the session
   const int period_secs = PeriodSeconds(_Period);
   const int orb_bars    = (period_secs > 0) ? (orb_minutes * 60 / period_secs) : 2;
   if(g_session_bars <= orb_bars)
     {
      if(g_orb_high == 0.0 || h1 > g_orb_high) g_orb_high = h1;
      if(g_orb_low  == 0.0 || l1 < g_orb_low)  g_orb_low  = l1;
     }
   else if(!g_orb_formed)
     {
      // Mark ORB complete on the first bar AFTER the opening-range window
      g_orb_formed = true;
     }
  }

//=============================================================================
// Strategy_NoTradeFilter
// Returns true to BLOCK trading (wrong session, vol regime not expanding).
// Reads only cached state — O(1) per tick.
//=============================================================================
bool Strategy_NoTradeFilter()
  {
   if(!g_in_session)        return true;  // outside productive session hours
   if(g_session_open <= 0.0) return true; // session reference not captured yet
   if(!g_vol_regime_ok)     return true;  // vol not in expansion regime

   // The tester may model zero spread on .DWX symbols. Only a genuinely
   // positive, wide spread can fail this gate.
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;
   if(ask > bid && cost_mult > 0.0)
     {
      const double expected_move = QM_ATR(_Symbol, _Period, mb_atr_period, 1);
      if(expected_move <= 0.0 || expected_move <= cost_mult * (ask - bid))
         return true;
     }
   return false;
  }

//=============================================================================
// Strategy_EntrySignal
// Populate req and return true to open a position on this closed bar.
// Called only when QM_IsNewBar() == true (is_new_bar latch in OnTick).
// Uses iClose for the closed-bar signal — perf-allowed: per-bar entry computation.
//=============================================================================
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type               = QM_BUY;
   req.price              = 0.0;
   req.sl                 = 0.0;
   req.tp                 = 0.0;
   req.reason             = "";
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   // One bounded position per magic
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: entry signal
   if(close1 <= 0.0 || g_session_open <= 0.0)
      return false;

   //--- LANE: MOMENTUM_BAND ---
   if(intraday_lane == LANE_MOMENTUM_BAND)
     {
      const double atr  = QM_ATR(_Symbol, _Period, mb_atr_period, 1);
      if(atr <= 0.0) return false;
      const double band = mb_band_mult * atr;
      const double ask  = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double bid  = SymbolInfoDouble(_Symbol, SYMBOL_BID);

      if(close1 > g_session_open + band)
        {
         req.type   = QM_BUY;
         req.price  = 0.0;
         req.sl     = QM_StopATR(_Symbol, QM_BUY, ask, mb_atr_period, stop_atr_mult);
         req.tp     = 0.0;     // exit: VWAP trail in ManageOpen + EOD flat
         req.reason = "MB_LONG";
         return true;
        }
      if(close1 < g_session_open - band)
        {
         req.type   = QM_SELL;
         req.price  = 0.0;
         req.sl     = QM_StopATR(_Symbol, QM_SELL, bid, mb_atr_period, stop_atr_mult);
         req.tp     = 0.0;     // exit: VWAP trail in ManageOpen + EOD flat
         req.reason = "MB_SHORT";
         return true;
        }
     }
   //--- LANE: ORB ---
   else if(intraday_lane == LANE_ORB)
     {
      if(!g_orb_formed)                        return false;
      if(g_orb_high <= 0.0 || g_orb_low <= 0.0) return false;

      const double atr = QM_ATR(_Symbol, _Period, mb_atr_period, 1);
      if(atr <= 0.0) return false;
      const double buf = orb_buf_mult * atr;
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

      if(close1 > g_orb_high + buf)
        {
         req.type  = QM_BUY;
         req.price = 0.0;
         req.sl    = g_orb_low - buf;
         req.tp    = (orb_tp_rr > 0.0)
                     ? QM_TakeRR(_Symbol, QM_BUY, ask, req.sl, orb_tp_rr)
                     : 0.0;
         req.reason = "ORB_LONG";
         return true;
        }
      if(close1 < g_orb_low - buf)
        {
         req.type  = QM_SELL;
         req.price = 0.0;
         req.sl    = g_orb_high + buf;
         req.tp    = (orb_tp_rr > 0.0)
                     ? QM_TakeRR(_Symbol, QM_SELL, bid, req.sl, orb_tp_rr)
                     : 0.0;
         req.reason = "ORB_SHORT";
         return true;
        }
     }
   //--- LANE: GOLD_BREAKOUT ---
   else if(intraday_lane == LANE_GOLD_BREAKOUT)
     {
      if(_Symbol != "XAUUSD.DWX") return false; // card: GOLD_BREAKOUT is XAUUSD-only
      if(g_daily_open <= 0.0) return false;
      const double d1_atr = QM_ATR(_Symbol, PERIOD_D1, gb_d1_atr_period, 1);
      if(d1_atr <= 0.0) return false;
      const double band = gb_atr_mult * d1_atr;
      const double ask  = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double bid  = SymbolInfoDouble(_Symbol, SYMBOL_BID);

      if(close1 > g_daily_open + band)
        {
         req.type   = QM_BUY;
         req.price  = 0.0;
         req.sl     = QM_StopATR(_Symbol, QM_BUY, ask, mb_atr_period, stop_atr_mult);
         req.tp     = 0.0;   // exit: EOD flat
         req.reason = "GB_LONG";
         return true;
        }
      if(close1 < g_daily_open - band)
        {
         req.type   = QM_SELL;
         req.price  = 0.0;
         req.sl     = QM_StopATR(_Symbol, QM_SELL, bid, mb_atr_period, stop_atr_mult);
         req.tp     = 0.0;   // exit: EOD flat
         req.reason = "GB_SHORT";
         return true;
        }
     }

   return false;
  }

//=============================================================================
// Strategy_ManageOpenPosition
// Called per-tick; reads only cached state and framework helpers — O(1).
//=============================================================================
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;

      if(intraday_lane == LANE_MOMENTUM_BAND && mb_vwap_trail && g_session_vwap > 0.0)
        {
         const ENUM_POSITION_TYPE ptype  = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         const double             cur_sl = PositionGetDouble(POSITION_SL);
         const double atr_half = 0.5 * QM_ATR(_Symbol, _Period, mb_atr_period, 1);

         if(ptype == POSITION_TYPE_BUY)
           {
            const double vwap_sl = g_session_vwap - atr_half;
            if(cur_sl <= 0.0 || vwap_sl > cur_sl)
               QM_TM_MoveSL(ticket, vwap_sl, "VWAP_trail_L");
           }
         else if(ptype == POSITION_TYPE_SELL)
           {
            const double vwap_sl = g_session_vwap + atr_half;
            if(cur_sl <= 0.0 || vwap_sl < cur_sl)
               QM_TM_MoveSL(ticket, vwap_sl, "VWAP_trail_S");
           }
        }
      else if(intraday_lane == LANE_ORB)
        {
         QM_TM_MoveToBreakEven(ticket, 30, 2);
        }
      else if(intraday_lane == LANE_GOLD_BREAKOUT)
        {
         QM_TM_TrailATR(ticket, gb_d1_atr_period, stop_atr_mult);
        }
     }
  }

//=============================================================================
// Strategy_ExitSignal
// Returns true to force-close all positions (EOD flat).
// Checked per-tick so it triggers on the first tick past eod_flat_hour.
//=============================================================================
bool Strategy_ExitSignal()
  {
   return (BrokerHour(TimeCurrent()) >= eod_flat_hour);
  }

//=============================================================================
// Strategy_NewsFilterHook
// Defer entirely to the 2-axis framework news filter.
//=============================================================================
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

//=============================================================================
// Framework wiring — modified from skeleton for intraday closed-bar cache.
// Key change: QM_IsNewBar() latched once; AdvanceState_OnNewBar() called first
// on new bars so all subsequent hooks read fresh cached state.
//=============================================================================

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

   QM_LogEvent(QM_INFO, "INIT_OK",
               StringFormat("{\"ea\":\"QM5_20007\",\"lane\":%d,\"slot\":%d}",
                            (int)intraday_lane, qm_magic_slot_offset));
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   // Q08 MAE evidence must be sampled before every possible early return.
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;

   if(QM_FrameworkHandleFridayClose())
      return;

   // Latch new-bar state once — QM_IsNewBar() is single-consume per tick
   const bool is_new_bar = QM_IsNewBar();

   // Advance closed-bar cache FIRST so all hooks below see fresh state
   if(is_new_bar)
      AdvanceState_OnNewBar();

   // EOD flat: must run per-tick even outside session to guarantee close
   if(Strategy_ExitSignal())
     {
      const int eod_magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong eod_ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(eod_ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != eod_magic) continue;
         QM_TM_ClosePosition(eod_ticket, QM_EXIT_TIME_STOP);
        }
      return;
     }

   // NoTradeFilter: block if outside session or vol not expanding
   if(Strategy_NoTradeFilter())
      return;

   // Per-tick: manage open position (VWAP trail, BE shift, ATR trail)
   Strategy_ManageOpenPosition();

   // News blackout gates entries only. Position management and the time exit
   // above continue to run during news windows.
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   // Per-bar: entry evaluation only on new closed bar
   if(!is_new_bar)
      return;

   // FW6: emit end-of-day equity snapshot
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
                        const MqlTradeRequest      &request,
                        const MqlTradeResult       &result)
  {
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
