#property strict
#property version   "5.0"
#property description "QM5_10655 tv-liq-sweeper — TradingView Liquidity Sweeper ATR Reversal"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_10655 — TradingView Liquidity Sweeper ATR Reversal
// -----------------------------------------------------------------------------
// Source: TradingView "Liquidity Sweeper" (author Mejunda, 2025-09-21).
// Mechanic (H1 baseline, false-breakout reversal after a failed stop-run):
//   - Identify the most recent CONFIRMED swing high / swing low using a
//     fractal-style pivot with `InpSwingLookback` bars on each side.
//   - High sweep (-> SHORT): a bar trades ABOVE the confirmed swing high but
//     CLOSES BACK BELOW it (the sweep bar), then price REMAINS inside the
//     swept range (every subsequent close < swing high) for `InpConfirmBars`
//     closed bars. Entry fires on the bar that completes confirmation.
//   - Low sweep (-> LONG): symmetric below the confirmed swing low.
//   - Stop: InpAtrSlMult * ATR(InpAtrPeriod) from entry. TP: InpRewardRR * R.
//   - One position per symbol/magic; no opposite-signal reversal in baseline.
//
// .DWX invariants honoured:
//   * Sweep detection and confirmation are DECOUPLED ACROSS BARS (sweep bar,
//     then N later confirmation bars) — never required on the same bar.
//   * Swing level computed with correct two-sided lookback on CLOSED bars.
//   * No spread/swap gating (fail-open).
//   * QM_IsNewBar consumed once by the framework before this hook is called.
//   * Bounded per-new-bar scan; raw OHLC reads are structural (perf-allowed)
//     and only run on the closed-bar entry path.
//   * Stops/takes via QM_* price helpers (scale-correct on 5-digit/JPY).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10655;
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
// Bars on EACH side of a pivot required to confirm a swing high/low.
input int    InpSwingLookback           = 20;
// Closed bars price must remain back inside the swept range after the sweep bar.
input int    InpConfirmBars             = 3;
// ATR period and stop multiple for the protective stop.
input int    InpAtrPeriod               = 14;
input double InpAtrSlMult               = 1.5;
// Take-profit reward/risk multiple.
input double InpRewardRR                = 2.0;
// How many bars back from the most recent CLOSED bar to search for a sweep
// bar whose confirmation completes on bar shift 1. Bounds the per-bar scan.
input int    InpSweepSearchBars         = 8;

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick block check. No regime/session filter in the baseline
// (H1 runs 24h with framework news blackout per the card). Never fail-closed
// on zero spread (.DWX quotes ask==bid in the tester).
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Find the price of the most recent CONFIRMED swing high to the LEFT of (and
// including) bar `from_shift`. A confirmed swing high at shift s requires its
// high to be strictly greater than every high within `lookback` bars on each
// side. Scans older bars first to return the nearest-to-now confirmed pivot.
// Returns true and sets out_price / out_shift when found.
bool FindConfirmedSwingHigh(const int from_shift, const int lookback, double &out_price, int &out_shift)
  {
   const int max_back = from_shift + lookback + InpSwingLookback + 200;
   for(int s = from_shift; s <= max_back; ++s)
     {
      const double pivot_high = iHigh(_Symbol, _Period, s);
      if(pivot_high <= 0.0)
         continue;
      bool is_pivot = true;
      for(int k = 1; k <= lookback; ++k)
        {
         const double left_h  = iHigh(_Symbol, _Period, s + k);
         const double right_h = iHigh(_Symbol, _Period, s - k);
         if(left_h <= 0.0 || right_h <= 0.0)
           {
            is_pivot = false;
            break;
           }
         if(left_h >= pivot_high || right_h >= pivot_high)
           {
            is_pivot = false;
            break;
           }
        }
      if(is_pivot)
        {
         out_price = pivot_high;
         out_shift = s;
         return true;
        }
     }
   return false;
  }

// Symmetric: most recent confirmed swing low (strictly lowest within lookback
// on each side).
bool FindConfirmedSwingLow(const int from_shift, const int lookback, double &out_price, int &out_shift)
  {
   const int max_back = from_shift + lookback + InpSwingLookback + 200;
   for(int s = from_shift; s <= max_back; ++s)
     {
      const double pivot_low = iLow(_Symbol, _Period, s);
      if(pivot_low <= 0.0)
         continue;
      bool is_pivot = true;
      for(int k = 1; k <= lookback; ++k)
        {
         const double left_l  = iLow(_Symbol, _Period, s + k);
         const double right_l = iLow(_Symbol, _Period, s - k);
         if(left_l <= 0.0 || right_l <= 0.0)
           {
            is_pivot = false;
            break;
           }
         if(left_l <= pivot_low || right_l <= pivot_low)
           {
            is_pivot = false;
            break;
           }
        }
      if(is_pivot)
        {
         out_price = pivot_low;
         out_shift = s;
         return true;
        }
     }
   return false;
  }

// Build a SHORT entry after a confirmed high sweep that has fully reclaimed.
// Returns true and fills req if the setup completes on the latest closed bar.
bool TryShortSetup(QM_EntryRequest &req)
  {
   const int confirm_shift = 1;                       // last fully closed bar
   const int sweep_min     = confirm_shift + InpConfirmBars;   // earliest sweep bar
   const int sweep_max     = sweep_min + InpSweepSearchBars - 1;

   for(int sweep = sweep_min; sweep <= sweep_max; ++sweep)
     {
      // Confirmed swing high must sit to the LEFT of (older than) the sweep bar.
      double swing_high = 0.0;
      int    swing_shift = 0;
      if(!FindConfirmedSwingHigh(sweep + 1, InpSwingLookback, swing_high, swing_shift))
         continue;

      // Sweep bar: high pierced ABOVE the swing high, close came BACK BELOW it.
      const double sweep_high  = iHigh(_Symbol, _Period, sweep);
      const double sweep_close = iClose(_Symbol, _Period, sweep);
      if(sweep_high <= 0.0 || sweep_close <= 0.0)
         continue;
      if(!(sweep_high > swing_high && sweep_close < swing_high))
         continue;

      // Confirmation: every closed bar AFTER the sweep bar, up to bar 1, must
      // remain back inside the swept range (close strictly below the swing
      // high). This decouples the reversal confirmation from the sweep bar.
      bool reclaimed = true;
      for(int c = sweep - 1; c >= confirm_shift; --c)
        {
         const double cl = iClose(_Symbol, _Period, c);
         const double hi = iHigh(_Symbol, _Period, c);
         if(cl <= 0.0 || hi <= 0.0)
           {
            reclaimed = false;
            break;
           }
         // Reject if price closed back above the swept level (sweep failed)
         // or printed a fresh higher pierce of equal/greater extent.
         if(cl >= swing_high || hi > sweep_high)
           {
            reclaimed = false;
            break;
           }
        }
      if(!reclaimed)
         continue;

      // Entry at market on the new bar; stop = ATR-based; TP = RR multiple.
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATR(_Symbol, QM_SELL, entry, InpAtrPeriod, InpAtrSlMult);
      if(sl <= 0.0)
         return false;
      const double tp = QM_TakeRR(_Symbol, QM_SELL, entry, sl, InpRewardRR);

      req.type   = QM_SELL;
      req.price  = 0.0;     // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "high_sweep_reversal_short";
      return true;
     }
   return false;
  }

// Build a LONG entry after a confirmed low sweep that has fully reclaimed.
bool TryLongSetup(QM_EntryRequest &req)
  {
   const int confirm_shift = 1;
   const int sweep_min     = confirm_shift + InpConfirmBars;
   const int sweep_max     = sweep_min + InpSweepSearchBars - 1;

   for(int sweep = sweep_min; sweep <= sweep_max; ++sweep)
     {
      double swing_low = 0.0;
      int    swing_shift = 0;
      if(!FindConfirmedSwingLow(sweep + 1, InpSwingLookback, swing_low, swing_shift))
         continue;

      const double sweep_low   = iLow(_Symbol, _Period, sweep);
      const double sweep_close = iClose(_Symbol, _Period, sweep);
      if(sweep_low <= 0.0 || sweep_close <= 0.0)
         continue;
      if(!(sweep_low < swing_low && sweep_close > swing_low))
         continue;

      bool reclaimed = true;
      for(int c = sweep - 1; c >= confirm_shift; --c)
        {
         const double cl = iClose(_Symbol, _Period, c);
         const double lo = iLow(_Symbol, _Period, c);
         if(cl <= 0.0 || lo <= 0.0)
           {
            reclaimed = false;
            break;
           }
         if(cl <= swing_low || lo < sweep_low)
           {
            reclaimed = false;
            break;
           }
        }
      if(!reclaimed)
         continue;

      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATR(_Symbol, QM_BUY, entry, InpAtrPeriod, InpAtrSlMult);
      if(sl <= 0.0)
         return false;
      const double tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, InpRewardRR);

      req.type   = QM_BUY;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "low_sweep_reversal_long";
      return true;
     }
   return false;
  }

// Entry — runs once per closed bar (framework gates with QM_IsNewBar). One
// position per symbol/magic; only fire a fresh signal when flat.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;

   if(TryShortSetup(req))
      return true;
   if(TryLongSetup(req))
      return true;
   return false;
  }

// No active trade management in the baseline — fixed ATR stop + RR take handle
// the exit entirely.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary/opposite-signal exit in the baseline; SL/TP do the work.
bool Strategy_ExitSignal()
  {
   return false;
  }

// Defer to the central two-axis news filter.
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
