#property strict
#property version   "5.0"
#property description "QM5_11107 bma-band-fade — EarnForex BMA percentage-band re-entry fade (H4)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11107 bma-band-fade
// -----------------------------------------------------------------------------
// Source: EarnForex "BMA / Band Moving Average" (GitHub https://github.com/EarnForex/BMA).
// Card: artifacts/cards_approved/QM5_11107_bma-band-fade.md (g0_status APPROVED).
//
// Mechanics (mean-reversion fade, closed-bar reads at shift 1):
//   Middle band  : SMA(ma_period) of close (source default 49).
//   Upper band   : MA * (100 + band_pct) / 100   (source default band_pct = 2).
//   Lower band   : MA * (100 - band_pct) / 100.
//   Long EVENT   : the closed trigger bar (shift 1) closes back ABOVE the lower
//                  band, AND at least one of the prior re_entry_lookback closed
//                  bars (shifts 2..N) closed BELOW its own lower band.
//   Short EVENT  : mirror — trigger bar closes back BELOW the upper band after a
//                  prior bar closed above its own upper band.
//   Slope filter : the MA slope over slope_bars must be flat or only mildly
//                  WITH the fade (i.e. against a strongly-with-trend slope we
//                  skip). Reject if |MA[1]-MA[slope_bars+1]| exceeds
//                  slope_atr_mult * ATR AND the slope runs the SAME way as the
//                  price extreme being faded (i.e. fading INTO a strong trend).
//   Stop loss    : entry +/- sl_atr_mult * ATR(atr_period) (card P2 = 2.0 * ATR14).
//   Exit         : price closes back through the middle MA band, OR the position
//                  has been open for >= max_hold_bars closed H4 bars (time stop).
//
// .DWX invariants honoured: fail-OPEN spread guard (zero modeled spread passes),
// no swap gate, gapless-CFD safe (uses closed prices, not gaps), no external feed.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11107;
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
input int    strategy_ma_period          = 49;    // BMA middle-band SMA period (source default)
input double strategy_band_pct           = 2.0;   // percentage band half-width (source default)
input int    strategy_re_entry_lookback  = 5;     // closed bars to scan for the prior band breach
input int    strategy_atr_period         = 14;    // ATR period (stop sizing + slope scale)
input double strategy_sl_atr_mult        = 2.0;   // hard stop distance = mult * ATR (card P2)
input int    strategy_slope_bars         = 5;     // MA slope window for the trend filter
input double strategy_slope_atr_mult     = 0.5;   // max with-trend MA slope tolerated (in ATR)
input int    strategy_max_hold_bars      = 20;    // time-stop: close after N closed H4 bars

// File-scope state for the time stop. Records the bar-open time of the bar on
// which the current position was opened so we can count completed bars held.
datetime g_entry_bar_time = 0;

// -----------------------------------------------------------------------------
// Helpers (closed-bar reads only; called from the QM_IsNewBar-gated path or O(1)).
// -----------------------------------------------------------------------------

// SMA-based band triplet at a given closed-bar shift.
void BandsAtShift(const int shift, double &mid, double &upper, double &lower)
  {
   mid   = QM_SMA(_Symbol, _Period, strategy_ma_period, shift);
   upper = mid * (100.0 + strategy_band_pct) / 100.0;
   lower = mid * (100.0 - strategy_band_pct) / 100.0;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. No spread guard needed beyond fail-open: this fade
// strategy has no spread-sensitive micro-edge, so we never block on spread.
// (Blocking on .DWX zero modeled spread would starve every entry.)
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it
   return false;    // fail-open: never block on spread for a mean-reversion fade
  }

// Mean-reversion fade entry. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Trigger-bar (shift 1) bands and close.
   double mid1, upper1, lower1;
   BandsAtShift(1, mid1, upper1, lower1);
   if(mid1 <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   // MA slope over the window: MA[1] minus MA[slope_bars+1].
   const double ma_recent = mid1;
   const double ma_older  = QM_SMA(_Symbol, _Period, strategy_ma_period, strategy_slope_bars + 1);
   if(ma_older <= 0.0)
      return false;
   const double slope = ma_recent - ma_older;             // >0 = MA rising
   const double slope_cap = strategy_slope_atr_mult * atr_value;

   // ----- LONG fade: trigger bar closed back above its lower band, after a
   //       prior bar (within lookback) closed below its lower band. -----
   bool long_setup = false;
   if(close1 > lower1)
     {
      for(int s = 2; s <= strategy_re_entry_lookback + 1; ++s)
        {
         double mids, ups, los;
         BandsAtShift(s, mids, ups, los);
         if(mids <= 0.0)
            continue;
         const double cs = iClose(_Symbol, _Period, s); // perf-allowed: single closed-bar read
         if(cs <= 0.0)
            continue;
         if(cs < los)
           {
            long_setup = true;
            break;
           }
        }
     }
   // Slope filter for a long fade: we fade a dip back up. Reject only if the MA
   // is sloping strongly DOWN (fading into a strong downtrend), beyond the cap.
   if(long_setup && slope < -slope_cap)
      long_setup = false;

   // ----- SHORT fade: trigger bar closed back below its upper band, after a
   //       prior bar (within lookback) closed above its upper band. -----
   bool short_setup = false;
   if(close1 < upper1)
     {
      for(int s = 2; s <= strategy_re_entry_lookback + 1; ++s)
        {
         double mids, ups, los;
         BandsAtShift(s, mids, ups, los);
         if(mids <= 0.0)
            continue;
         const double cs = iClose(_Symbol, _Period, s); // perf-allowed: single closed-bar read
         if(cs <= 0.0)
            continue;
         if(cs > ups)
           {
            short_setup = true;
            break;
           }
        }
     }
   // Slope filter for a short fade: reject only if MA slopes strongly UP
   // (fading into a strong uptrend), beyond the cap.
   if(short_setup && slope > slope_cap)
      short_setup = false;

   // If both fire (rare), prefer none — ambiguous regime, stay flat.
   if(long_setup && short_setup)
      return false;
   if(!long_setup && !short_setup)
      return false;

   const QM_OrderType side = long_setup ? QM_BUY : QM_SELL;

   const double entry = (side == QM_BUY)
                        ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, side, entry, atr_value, strategy_sl_atr_mult);
   if(sl <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = 0.0;   // no fixed TP; exit is middle-band reversion or time stop
   req.reason = long_setup ? "bma_band_fade_long" : "bma_band_fade_short";

   // Record entry bar time for the time stop. The position opens on this newly
   // closed bar (shift 0 open time).
   g_entry_bar_time = iTime(_Symbol, _Period, 0); // perf-allowed: single bar-open read
   return true;
  }

// No active trade management beyond the fixed ATR stop. Middle-band and time-stop
// exits live in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Exit: price reverts through the middle MA band, OR the time stop fires.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   // Determine current position direction (this EA holds at most one per magic).
   const int magic = QM_FrameworkMagic();
   long pos_type = -1;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      pos_type = PositionGetInteger(POSITION_TYPE);
      break;
     }
   if(pos_type < 0)
      return false;

   const double mid1 = QM_SMA(_Symbol, _Period, strategy_ma_period, 1);
   if(mid1 <= 0.0)
      return false;
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   // Middle-band reversion exit: long faded up exits when close reverts to/above
   // the middle band; short exits when close reverts to/below the middle band.
   if(pos_type == POSITION_TYPE_BUY && close1 >= mid1)
      return true;
   if(pos_type == POSITION_TYPE_SELL && close1 <= mid1)
      return true;

   // Time stop: close after max_hold_bars completed H4 bars since entry.
   if(g_entry_bar_time > 0)
     {
      const datetime bar_now = iTime(_Symbol, _Period, 0); // perf-allowed: single bar-open read
      if(bar_now > g_entry_bar_time)
        {
         const int secs_per_bar = PeriodSeconds(_Period);
         if(secs_per_bar > 0)
           {
            const int bars_held = (int)((bar_now - g_entry_bar_time) / secs_per_bar);
            if(bars_held >= strategy_max_hold_bars)
               return true;
           }
        }
     }

   return false;
  }

// Defer to the central news filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
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
      g_entry_bar_time = 0;
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
