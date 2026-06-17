#property strict
#property version   "5.0"
#property description "QM5_10669 tv-cleighty-bos — BOS pivot break + SMA slope + MACD + VWAP context"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 — QM5_10669 tv-cleighty-bos
// -----------------------------------------------------------------------------
// Card: artifacts/cards_approved/QM5_10669_tv-cleighty-bos.md  (g0_status APPROVED)
// Source: CleightyP "BOS/SMA/MACD/VWAP" TradingView open-source strategy.
//
// Mechanic (paraphrased mechanically from the card):
//   - Detect pivot highs/lows (fractal-style closed-bar pivots).
//   - Break of structure (BOS): a confirmed CLOSE beyond the most recent valid
//     pivot arms an entry on that side. detect-then-arm: the pivot is found on
//     prior bars (STATE), the break is the trigger.
//   - SMA slope alignment on 21/84/252 must agree with the break direction.
//   - Optional SMA stacking filter (fast>mid>slow for longs / inverse shorts).
//   - MACD main-line momentum sign must agree.
//   - VWAP context: price above rolling-VWAP for longs / below for shorts.
//   - Strong-candle confirmation: break bar body >= min fraction of its range.
//   - Re-entry protection: a pivot level already used for an entry is consumed.
//   - Exit: fixed 2R target, or opposite BOS/CHoCH reversal before target.
//   - Stop: swing-based (prior pivot) + 0.25 ATR buffer.
//   - Filters: liquid-session window (broker time), max 2 trades/symbol/day,
//     confirmed-break only (no intrabar).
//
// All strategy state (pivots, armed levels, used levels, VWAP) is recomputed
// ONCE per closed bar in AdvanceStructure_OnNewBar() and read O(1) per tick.
// No per-EA IsNewBar, no raw iATR/iMA/iRSI/iMACD/iBands, no CopyBuffer.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10669;
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
// --- Pivot / BOS structure ---
input int    InpPivotLeft           = 3;       // bars to the left of a pivot
input int    InpPivotRight          = 3;       // bars to the right (confirmation lag)
input int    InpStructureLookback   = 180;     // closed bars scanned for pivots
// --- SMA slope alignment ---
input int    InpSmaFast             = 21;      // fast SMA period
input int    InpSmaMid              = 84;      // mid SMA period
input int    InpSmaSlow             = 252;     // slow SMA period
input int    InpSmaSlopeLookback    = 3;       // bars back to measure SMA slope
input bool   InpRequireSmaStacking  = true;    // require fast>mid>slow (long) / inverse
// --- MACD momentum ---
input int    InpMacdFast            = 12;
input int    InpMacdSlow            = 26;
input int    InpMacdSignal          = 9;
// --- VWAP context ---
input bool   InpUseVwapFilter       = true;    // require price the right side of VWAP
input int    InpVwapLookback        = 96;      // rolling bars for VWAP proxy
// --- Strong candle confirmation ---
input double InpMinBodyFraction     = 0.50;    // break-bar body / range minimum
// --- Stop / target ---
input int    InpStopPivotLookback   = 12;      // bars back for swing stop extreme
input int    InpAtrPeriod           = 14;
input double InpAtrBufferMult       = 0.25;    // ATR buffer added beyond swing
input double InpTargetRR            = 2.0;      // fixed reward:risk
// --- Trade governance ---
input int    InpMaxTradesPerDay     = 2;       // per symbol/magic per day
input bool   InpUseSessionFilter    = true;    // restrict to liquid session window
input int    InpSessionStartHour    = 8;       // broker-time hour, inclusive
input int    InpSessionEndHour      = 20;      // broker-time hour, exclusive

// -----------------------------------------------------------------------------
// File-scope cached structure STATE (advanced once per closed bar).
// -----------------------------------------------------------------------------
// Most-recent confirmed pivots (price levels) and the bar-shift they sit on.
double   g_last_pivot_high       = 0.0;   // most recent confirmed pivot high price
double   g_last_pivot_low        = 0.0;   // most recent confirmed pivot low price
// "Armed" BOS levels — the pivot that price has confirmed-broken on the last
// closed bar (the trigger). 0.0 = no fresh break this bar.
bool     g_bos_long_armed        = false; // closed above pivot high this bar
bool     g_bos_short_armed       = false; // closed below pivot low this bar
double   g_armed_pivot_level     = 0.0;   // the broken pivot level (for SL ref)
// Re-entry protection: the last pivot level already consumed by an entry.
double   g_used_long_level       = 0.0;
double   g_used_short_level      = 0.0;
// Cached confirmations for the current break bar.
bool     g_break_body_ok         = false; // strong-candle confirmation
// Cached filter inputs for the per-tick entry hook.
double   g_vwap_value            = 0.0;
double   g_sma_fast_v            = 0.0;
double   g_sma_mid_v             = 0.0;
double   g_sma_slow_v            = 0.0;
double   g_sma_fast_prev         = 0.0;
double   g_sma_mid_prev          = 0.0;
double   g_sma_slow_prev         = 0.0;
double   g_macd_main_v           = 0.0;
double   g_atr_v                 = 0.0;
double   g_break_close           = 0.0;   // close of the break bar (shift 1)
// Daily trade governance.
datetime g_trade_day             = 0;
int      g_trades_today          = 0;

// -----------------------------------------------------------------------------
// Pivot detection helper — fractal-style confirmed pivot on closed bars.
// A pivot high at shift s requires high[s] strictly >= the InpPivotLeft bars
// to its left (older, larger shift) and > the InpPivotRight bars to its right
// (newer, smaller shift, already closed). Scans from the newest confirmable
// pivot outward; returns the FIRST (most recent) match. perf-allowed: bounded
// O(InpStructureLookback) scan run once per closed bar.
// -----------------------------------------------------------------------------
bool FindLastPivotHigh(const int left, const int right, const int max_scan, double &out_price)
  {
   // Newest bar that can be a confirmed pivot high sits at shift = right + 1
   // (we read closed bars only; shift 0 is the forming bar).
   for(int center = right + 1; center <= max_scan; center++)
     {
      const double c_high = iHigh(_Symbol, _Period, center);   // perf-allowed structural
      if(c_high <= 0.0)
         continue;
      bool is_pivot = true;
      for(int k = 1; k <= left && is_pivot; k++)
        {
         const double h = iHigh(_Symbol, _Period, center + k);
         if(h <= 0.0 || h > c_high)
            is_pivot = false;
        }
      for(int k = 1; k <= right && is_pivot; k++)
        {
         const double h = iHigh(_Symbol, _Period, center - k);
         if(h <= 0.0 || h >= c_high)
            is_pivot = false;
        }
      if(is_pivot)
        {
         out_price = c_high;
         return true;
        }
     }
   return false;
  }

bool FindLastPivotLow(const int left, const int right, const int max_scan, double &out_price)
  {
   for(int center = right + 1; center <= max_scan; center++)
     {
      const double c_low = iLow(_Symbol, _Period, center);     // perf-allowed structural
      if(c_low <= 0.0)
         continue;
      bool is_pivot = true;
      for(int k = 1; k <= left && is_pivot; k++)
        {
         const double l = iLow(_Symbol, _Period, center + k);
         if(l <= 0.0 || l < c_low)
            is_pivot = false;
        }
      for(int k = 1; k <= right && is_pivot; k++)
        {
         const double l = iLow(_Symbol, _Period, center - k);
         if(l <= 0.0 || l <= c_low)
            is_pivot = false;
        }
      if(is_pivot)
        {
         out_price = c_low;
         return true;
        }
     }
   return false;
  }

// Rolling VWAP proxy over InpVwapLookback closed bars using typical price and
// tick volume. No framework VWAP helper exists; this is bespoke structural math
// run once per closed bar (perf-allowed), never per tick.
double ComputeRollingVwap(const int lookback)
  {
   double pv_sum = 0.0;
   double v_sum  = 0.0;
   for(int s = 1; s <= lookback; s++)
     {
      const double h = iHigh(_Symbol, _Period, s);             // perf-allowed structural
      const double l = iLow(_Symbol, _Period, s);
      const double c = iClose(_Symbol, _Period, s);
      if(h <= 0.0 || l <= 0.0 || c <= 0.0)
         continue;
      double vol = (double)iTickVolume(_Symbol, _Period, s);
      if(vol <= 0.0)
         vol = 1.0;
      const double typ = (h + l + c) / 3.0;
      pv_sum += typ * vol;
      v_sum  += vol;
     }
   if(v_sum <= 0.0)
      return 0.0;
   return pv_sum / v_sum;
  }

// -----------------------------------------------------------------------------
// Advance all structure state for the just-closed bar. Called ONCE per new bar
// from OnTick after the framework new-bar gate. Reads closed bars only.
// -----------------------------------------------------------------------------
void AdvanceStructure_OnNewBar()
  {
   g_bos_long_armed    = false;
   g_bos_short_armed   = false;
   g_armed_pivot_level = 0.0;
   g_break_body_ok     = false;

   // --- Most-recent confirmed pivots ---
   double ph = 0.0;
   double pl = 0.0;
   const bool have_ph = FindLastPivotHigh(InpPivotLeft, InpPivotRight, InpStructureLookback, ph);
   const bool have_pl = FindLastPivotLow(InpPivotLeft, InpPivotRight, InpStructureLookback, pl);
   if(have_ph)
      g_last_pivot_high = ph;
   if(have_pl)
      g_last_pivot_low = pl;

   // --- Break of structure on the just-closed bar (shift 1) ---
   const double close_1 = iClose(_Symbol, _Period, 1);
   const double open_1  = iOpen(_Symbol, _Period, 1);
   const double high_1  = iHigh(_Symbol, _Period, 1);
   const double low_1   = iLow(_Symbol, _Period, 1);
   g_break_close = close_1;

   // Strong-candle confirmation: body fraction of full range.
   const double rng = high_1 - low_1;
   const double body = MathAbs(close_1 - open_1);
   g_break_body_ok = (rng > 0.0 && (body / rng) >= InpMinBodyFraction);

   // Detect-then-arm: pivot levels were found on prior bars; the close beyond
   // them on bar 1 is the trigger. Guard against re-using a consumed level.
   if(have_ph && close_1 > g_last_pivot_high &&
      g_last_pivot_high != g_used_long_level)
     {
      g_bos_long_armed    = true;
      g_armed_pivot_level = g_last_pivot_high;
     }
   if(have_pl && close_1 < g_last_pivot_low &&
      g_last_pivot_low != g_used_short_level)
     {
      g_bos_short_armed   = true;
      g_armed_pivot_level = g_last_pivot_low;
     }

   // --- Cached indicator reads (closed bar = shift 1) ---
   g_sma_fast_v  = QM_SMA(_Symbol, _Period, InpSmaFast, 1);
   g_sma_mid_v   = QM_SMA(_Symbol, _Period, InpSmaMid, 1);
   g_sma_slow_v  = QM_SMA(_Symbol, _Period, InpSmaSlow, 1);
   const int back = 1 + InpSmaSlopeLookback;
   g_sma_fast_prev = QM_SMA(_Symbol, _Period, InpSmaFast, back);
   g_sma_mid_prev  = QM_SMA(_Symbol, _Period, InpSmaMid, back);
   g_sma_slow_prev = QM_SMA(_Symbol, _Period, InpSmaSlow, back);
   g_macd_main_v = QM_MACD_Main(_Symbol, _Period, InpMacdFast, InpMacdSlow, InpMacdSignal, 1);
   g_atr_v       = QM_ATR(_Symbol, _Period, InpAtrPeriod, 1);
   g_vwap_value  = ComputeRollingVwap(InpVwapLookback);
  }

// -----------------------------------------------------------------------------
// Slope alignment: all three SMAs rising for longs / falling for shorts.
// -----------------------------------------------------------------------------
bool SmaSlopesAlignedLong()
  {
   return (g_sma_fast_v > g_sma_fast_prev &&
           g_sma_mid_v  > g_sma_mid_prev  &&
           g_sma_slow_v > g_sma_slow_prev);
  }

bool SmaSlopesAlignedShort()
  {
   return (g_sma_fast_v < g_sma_fast_prev &&
           g_sma_mid_v  < g_sma_mid_prev  &&
           g_sma_slow_v < g_sma_slow_prev);
  }

bool SmaStackedLong()
  {
   if(!InpRequireSmaStacking)
      return true;
   return (g_sma_fast_v > g_sma_mid_v && g_sma_mid_v > g_sma_slow_v);
  }

bool SmaStackedShort()
  {
   if(!InpRequireSmaStacking)
      return true;
   return (g_sma_fast_v < g_sma_mid_v && g_sma_mid_v < g_sma_slow_v);
  }

// -----------------------------------------------------------------------------
// Daily trade-count governance.
// -----------------------------------------------------------------------------
void RollTradeDay(const datetime broker_now)
  {
   MqlDateTime dt;
   TimeToStruct(broker_now, dt);
   dt.hour = 0;
   dt.min  = 0;
   dt.sec  = 0;
   const datetime day_key = StructToTime(dt);
   if(day_key != g_trade_day)
     {
      g_trade_day    = day_key;
      g_trades_today = 0;
     }
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick filters: liquid-session window + daily-limit gate.
bool Strategy_NoTradeFilter()
  {
   const datetime broker_now = TimeCurrent();
   RollTradeDay(broker_now);

   if(InpMaxTradesPerDay > 0 && g_trades_today >= InpMaxTradesPerDay)
      return true;

   if(InpUseSessionFilter)
     {
      MqlDateTime dt;
      TimeToStruct(broker_now, dt);
      const int h = dt.hour;
      bool in_session;
      if(InpSessionStartHour <= InpSessionEndHour)
         in_session = (h >= InpSessionStartHour && h < InpSessionEndHour);
      else // wrap-around window
         in_session = (h >= InpSessionStartHour || h < InpSessionEndHour);
      if(!in_session)
         return true;
     }
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(!g_break_body_ok)
      return false;

   // ---- LONG ----
   if(g_bos_long_armed && g_armed_pivot_level > 0.0)
     {
      if(SmaSlopesAlignedLong() && SmaStackedLong() && g_macd_main_v > 0.0)
        {
         bool vwap_ok = true;
         if(InpUseVwapFilter)
            vwap_ok = (g_vwap_value > 0.0 && g_break_close > g_vwap_value);
         if(vwap_ok)
           {
            const double entry = QM_EntryMarketPrice(QM_BUY);
            if(entry > 0.0)
              {
               double sl = QM_StopStructure(_Symbol, QM_BUY, entry, InpStopPivotLookback);
               if(sl > 0.0 && g_atr_v > 0.0)
                  sl = QM_StopRulesNormalizePrice(_Symbol, sl - g_atr_v * InpAtrBufferMult);
               if(sl > 0.0 && sl < entry)
                 {
                  req.type   = QM_BUY;
                  req.price  = 0.0;
                  req.sl     = sl;
                  req.tp     = QM_TakeRR(_Symbol, QM_BUY, entry, sl, InpTargetRR);
                  req.reason = "bos_long";
                  g_used_long_level = g_armed_pivot_level;   // consume the level
                  g_trades_today++;
                  return true;
                 }
              }
           }
        }
     }

   // ---- SHORT ----
   if(g_bos_short_armed && g_armed_pivot_level > 0.0)
     {
      if(SmaSlopesAlignedShort() && SmaStackedShort() && g_macd_main_v < 0.0)
        {
         bool vwap_ok = true;
         if(InpUseVwapFilter)
            vwap_ok = (g_vwap_value > 0.0 && g_break_close < g_vwap_value);
         if(vwap_ok)
           {
            const double entry = QM_EntryMarketPrice(QM_SELL);
            if(entry > 0.0)
              {
               double sl = QM_StopStructure(_Symbol, QM_SELL, entry, InpStopPivotLookback);
               if(sl > 0.0 && g_atr_v > 0.0)
                  sl = QM_StopRulesNormalizePrice(_Symbol, sl + g_atr_v * InpAtrBufferMult);
               if(sl > entry)
                 {
                  req.type   = QM_SELL;
                  req.price  = 0.0;
                  req.sl     = sl;
                  req.tp     = QM_TakeRR(_Symbol, QM_SELL, entry, sl, InpTargetRR);
                  req.reason = "bos_short";
                  g_used_short_level = g_armed_pivot_level;  // consume the level
                  g_trades_today++;
                  return true;
                 }
              }
           }
        }
     }

   return false;
  }

// Fixed RR target + structural stop carry the trade; no active management.
void Strategy_ManageOpenPosition()
  {
  }

// Opposite-signal exit: a confirmed BOS against the open position before the
// 2R target closes it (signal-reversal exit per the card).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && g_bos_short_armed)
         return true;
      if(ptype == POSITION_TYPE_SELL && g_bos_long_armed)
         return true;
     }
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade(...)
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

   // Advance closed-bar structure state ONCE per new bar (single new-bar consume).
   if(QM_IsNewBar())
     {
      AdvanceStructure_OnNewBar();
      QM_EquityStreamOnNewBar();
     }

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
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
        }
      return;
     }

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
