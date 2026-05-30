#property strict
#property version   "5.0"
#property description "QM5_10340 FX VWAP ADX Exhaustion Reversion"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails). The framework provides:
//
//   - QM_IsNewBar(sym="", tf=PERIOD_CURRENT)  — closed-bar gate
//   - QM_ATR / QM_EMA / QM_SMA / QM_RSI / QM_MACD_Main / QM_MACD_Signal /
//     QM_ADX / QM_ADX_PlusDI / QM_ADX_MinusDI /
//     QM_BB_Upper / QM_BB_Middle / QM_BB_Lower    (from QM_Indicators.mqh)
//   - QM_TM_OpenPosition(req, ticket) / QM_TM_ClosePosition(ticket, reason)
//   - QM_TM_MoveToBreakEven / QM_TM_TrailATR / QM_TM_TrailStep / QM_TM_PartialClose
//   - QM_LotsForRisk(symbol, sl_points)        — risk model lot sizing
//   - QM_StopFixedPips / QM_StopATR / QM_StopStructure / QM_StopVolatility
//   - QM_FrameworkHandleFridayClose / QM_KillSwitchCheck / QM_NewsAllowsTrade
//
// DO NOT
//   - Write per-EA IsNewBar() — use QM_IsNewBar()
//   - Call iATR / iMA / iRSI / iMACD / iADX / iBands or CopyBuffer directly —
//     use the QM_* readers above. The framework pools handles and releases them
//     on shutdown.
//   - CopyRates over warmup windows on every tick. If you genuinely need raw
//     bar arrays, gate by QM_IsNewBar so the work runs once per closed bar.
//   - Hand-edit framework/include/QM/QM_MagicResolver.mqh. After adding rows
//     to magic_numbers.csv, run:
//         python framework/scripts/update_magic_resolver.py
//     This is idempotent and preserves all rows.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10340;
input int    qm_magic_slot_offset       = 0;
// FW3: Q07 Multi-Seed uses one of the canonical seeds (42, 17, 99, 7, 2026).
// All other phases use 42 by default. Stress / noise dimensions read from
// this single seed so reproducibility is guaranteed across re-runs.
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
// FW1 2026-05-23 — Two-axis news filter per Vault Q09.
//   AXIS A (temporal): per-event behaviour. Default mode 3 = pause 30min pre+post.
//   AXIS B (compliance): prop-firm blackout overlay. Default DXZ = no extra rules.
// A trade is allowed only if BOTH axes allow. See Vault `Q09 News Impact Mode`.
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
// Legacy single-mode input kept for back-compat with pre-FW1 setfiles.
// New EAs use qm_news_temporal + qm_news_compliance above and leave this OFF.
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
// FW2 2026-05-23 — only populated by Q05 MED / Q06 HARSH stress setfiles.
// Default 0.0 = no rejection (Q02/Q03/Q04/Q07/Q08/Q09/Q10/Q13 backtests).
// Q06 HARSH sets to 0.10 (10% of entries randomly dropped before broker send,
// deterministic per qm_rng_seed). MED slip/spread/commission live in the
// tester groups file, not as EA inputs.
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_atr_period        = 14;
input int    strategy_adx_period        = 14;
input double strategy_adx_threshold     = 25.0;
input double strategy_vwap_dev_atr      = 0.75;
input double strategy_stop_atr_mult     = 1.00;
input double strategy_extension_atr     = 0.50;
input int    strategy_max_hold_bars     = 6;
input int    strategy_skip_open_minutes = 30;
input int    strategy_liquid_start_hour = 7;
input int    strategy_liquid_end_hour   = 21;
input int    strategy_spread_lookback   = 96;

double   g_session_vwap_latest     = 0.0;
double   g_last_prior_high         = 0.0;
double   g_last_prior_low          = 0.0;
double   g_entry_adx               = 0.0;
double   g_entry_atr               = 0.0;
double   g_entry_session_high      = 0.0;
double   g_entry_session_low       = 0.0;
datetime g_entry_time              = 0;
int      g_entry_direction         = 0;

int Strategy_DayKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

int Strategy_MinutesAfterMidnight(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 60 + dt.min;
  }

bool Strategy_InSession(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   if(strategy_liquid_start_hour == strategy_liquid_end_hour)
      return true;
   if(strategy_liquid_start_hour < strategy_liquid_end_hour)
      return (dt.hour >= strategy_liquid_start_hour && dt.hour < strategy_liquid_end_hour);
   return (dt.hour >= strategy_liquid_start_hour || dt.hour < strategy_liquid_end_hour);
  }

bool Strategy_FindPriorDayExtremes(const int current_day, double &prior_high, double &prior_low)
  {
   prior_high = -DBL_MAX;
   prior_low = DBL_MAX;
   int prior_day = 0;

   for(int shift = 1; shift <= 288; ++shift)
     {
      const datetime bt = iTime(_Symbol, _Period, shift);
      if(bt <= 0)
         break;
      const int day = Strategy_DayKey(bt);
      if(day == current_day)
         continue;
      if(prior_day == 0)
         prior_day = day;
      if(day != prior_day)
         break;

      const double hi = iHigh(_Symbol, _Period, shift);
      const double lo = iLow(_Symbol, _Period, shift);
      if(hi > 0.0)
         prior_high = MathMax(prior_high, hi);
      if(lo > 0.0)
         prior_low = MathMin(prior_low, lo);
     }

   return (prior_day != 0 && prior_high > 0.0 && prior_low > 0.0 && prior_high > prior_low);
  }

bool Strategy_CalcSessionVwap(const int current_day, double &session_vwap)
  {
   double pv_sum = 0.0;
   double volume_sum = 0.0;

   for(int shift = 1; shift <= 144; ++shift)
     {
      const datetime bt = iTime(_Symbol, _Period, shift);
      if(bt <= 0)
         break;
      if(Strategy_DayKey(bt) != current_day)
         break;

      const double hi = iHigh(_Symbol, _Period, shift);
      const double lo = iLow(_Symbol, _Period, shift);
      const double close = iClose(_Symbol, _Period, shift);
      const long tick_volume = iVolume(_Symbol, _Period, shift);
      if(hi <= 0.0 || lo <= 0.0 || close <= 0.0 || tick_volume <= 0)
         continue;

      const double typical = (hi + lo + close) / 3.0;
      const double volume = (double)tick_volume;
      pv_sum += typical * volume;
      volume_sum += volume;
     }

   if(volume_sum <= 0.0)
      return false;
   session_vwap = pv_sum / volume_sum;
   return (session_vwap > 0.0);
  }

bool Strategy_SpreadAllowed()
  {
   const int lookback = MathMax(10, MathMin(strategy_spread_lookback, 256));
   double spreads[256];
   int count = 0;

   for(int shift = 1; shift <= lookback; ++shift)
     {
      const int sp = (int)iSpread(_Symbol, _Period, shift);
      if(sp <= 0)
         continue;
      spreads[count] = (double)sp;
      count++;
     }

   if(count < 10)
      return true;

   for(int i = 1; i < count; ++i)
     {
      const double key = spreads[i];
      int j = i - 1;
      while(j >= 0 && spreads[j] > key)
        {
         spreads[j + 1] = spreads[j];
         j--;
        }
      spreads[j + 1] = key;
     }

   const int pct_idx = MathMin(count - 1, (int)MathFloor((count - 1) * 0.80));
   const double threshold = spreads[pct_idx];
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;

   const double current_spread_points = (ask - bid) / point;
   return (current_spread_points <= threshold);
  }

bool Strategy_HasOurPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   const datetime broker_now = TimeCurrent();
   if(!Strategy_InSession(broker_now))
      return true;
   if(Strategy_MinutesAfterMidnight(broker_now) < strategy_skip_open_minutes)
      return true;
   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   static int  last_session_day = 0;
   static bool trade_taken_session = false;

   const datetime bar_time = iTime(_Symbol, _Period, 1);
   if(bar_time <= 0)
      return false;

   const int current_day = Strategy_DayKey(bar_time);
   if(current_day != last_session_day)
     {
      last_session_day = current_day;
      trade_taken_session = false;
     }

   if(trade_taken_session || Strategy_HasOurPosition())
      return false;
   if(!Strategy_InSession(bar_time))
      return false;
   if(Strategy_MinutesAfterMidnight(bar_time) < strategy_skip_open_minutes)
      return false;
   if(!Strategy_SpreadAllowed())
      return false;

   double prior_high = 0.0;
   double prior_low = 0.0;
   if(!Strategy_FindPriorDayExtremes(current_day, prior_high, prior_low))
      return false;

   double session_vwap = 0.0;
   if(!Strategy_CalcSessionVwap(current_day, session_vwap))
      return false;
   g_session_vwap_latest = session_vwap;
   g_last_prior_high = prior_high;
   g_last_prior_low = prior_low;

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   const double adx_now = QM_ADX(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_adx_period, 1);
   const double adx_prev = QM_ADX(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_adx_period, 2);
   const double close = iClose(_Symbol, _Period, 1);
   const double high = iHigh(_Symbol, _Period, 1);
   const double low = iLow(_Symbol, _Period, 1);
   if(atr <= 0.0 || adx_now <= 0.0 || adx_prev <= 0.0 || close <= 0.0 || high <= 0.0 || low <= 0.0)
      return false;
   if(!(adx_prev > strategy_adx_threshold && adx_now < adx_prev))
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double spread_price = ask - bid;
   const double stop_dist = atr * strategy_stop_atr_mult;
   if(stop_dist <= 0.0 || spread_price <= 0.0 || stop_dist < 4.0 * spread_price)
      return false;

   const double vwap_dev_atr = (close - session_vwap) / atr;
   if(high >= prior_high && vwap_dev_atr >= strategy_vwap_dev_atr)
     {
      req.type = QM_SELL;
      req.sl = bid + stop_dist;
      req.reason = "FX_VWAP_ADX_SHORT";
      trade_taken_session = true;
      g_entry_adx = adx_now;
      g_entry_atr = atr;
      g_entry_session_high = prior_high;
      g_entry_session_low = prior_low;
      g_entry_time = bar_time;
      g_entry_direction = -1;
      return true;
     }

   if(low <= prior_low && vwap_dev_atr <= -strategy_vwap_dev_atr)
     {
      req.type = QM_BUY;
      req.sl = ask - stop_dist;
      req.reason = "FX_VWAP_ADX_LONG";
      trade_taken_session = true;
      g_entry_adx = adx_now;
      g_entry_atr = atr;
      g_entry_session_high = prior_high;
      g_entry_session_low = prior_low;
      g_entry_time = bar_time;
      g_entry_direction = 1;
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, partial close, scale-in, or averaging.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      const int bars_held = (int)MathFloor((double)(TimeCurrent() - opened) / (double)PeriodSeconds((ENUM_TIMEFRAMES)_Period));
      if(bars_held >= strategy_max_hold_bars)
         return true;

      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(g_session_vwap_latest > 0.0)
        {
         if(ptype == POSITION_TYPE_BUY && bid >= g_session_vwap_latest)
            return true;
         if(ptype == POSITION_TYPE_SELL && ask <= g_session_vwap_latest)
            return true;
        }

      const double adx_now = QM_ADX(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_adx_period, 1);
      if(g_entry_adx > 0.0 && g_entry_atr > 0.0 && adx_now > g_entry_adx)
        {
         if(ptype == POSITION_TYPE_BUY && bid < g_entry_session_low - strategy_extension_atr * g_entry_atr)
            return true;
         if(ptype == POSITION_TYPE_SELL && ask > g_entry_session_high + strategy_extension_atr * g_entry_atr)
            return true;
        }
     }

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // high-impact news windows are handled by the framework news axes.
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
   // FW1 — 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults.
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

   // Per-tick: trade management can adjust SL/TP on open positions.
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit (e.g. time stop). Separate from SL/TP.
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

   // Per-closed-bar: entry-signal evaluation. Gating here avoids 99% of
   // per-tick recompute mistakes — EntrySignal sees one new closed bar per
   // call, not every incoming tick.
   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
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
   // FW4: feeds closing-deal net-profits to the KS kill-switch.
   // No-op outside Q13 (when no baseline.json exists).
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
