#property strict
#property version   "5.0"
#property description "QM5_10875 NexusTrade 200-Day SMA Large-Cap Rebalance (D1-native)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_10875 — NexusTrade 200-Day SMA Large-Cap Rebalance
// -----------------------------------------------------------------------------
// Source: Austin Starks / NexusTrade, "How I used this well-known technical
//   indicator to beat the market by more than 100%" (2025-08-15).
// Card: artifacts/cards_approved/QM5_10875_nt-200sma-rebal.md (g0_status: APPROVED).
//
// Mechanic (single-symbol port; one position per symbol/magic — NOT a basket):
//   - D1-native. Long-only mean reversion with a periodic rebalance cadence.
//   - The source rule is a 30-calendar-day rebalance. The .DWX tester yields 0
//     bars on MN1, so cadence is expressed as a D1-bar proxy: ~21 D1 bars per
//     ~30 calendar days (REBAL_INTERVAL_BARS). The cadence counter advances ONCE
//     per closed D1 bar (the framework consumes QM_IsNewBar() before the hook,
//     so the per-bar increment lives in the hooks — no per-EA timestamp gate).
//   - Entry: on a rebalance bar, if FLAT and close(1) < SMA(close,200) → open long.
//   - Carry: an existing long with gain < CARRY_GAIN_PCT is simply held.
//   - Rebalance exit: on a rebalance bar, close the long if
//       close(1) >= SMA200 AND gain >= CARRY_GAIN_PCT.
//   - Catastrophic stop: fixed ATR stop entry - ATR_STOP_MULT * ATR(D1, ATR_PERIOD)
//     placed at entry (framework-managed SL on the order).
//   - Warm-up: needs >= 220 D1 bars (SMA200 + headroom).
//
// Framework sizes lots (QM_LotsForRisk via QM_TM_OpenPosition). Closed-bar reads
// only (shift 1). Strict MQL5.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10875;
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
// Rebalance cadence as a D1-bar proxy for the source's 30-calendar-day interval
// (~21 D1 trading bars per ~30 calendar days). P3 may sweep {20, 30, 60}-day
// equivalents (~14, 21, 42 D1 bars).
input int    REBAL_INTERVAL_BARS        = 21;
// Trend filter: simple moving average length on D1 close. Card baseline 200.
input int    SMA_PERIOD                 = 200;
// Profit-retention threshold (percent). Hold while gain < this; rebalance-exit
// only when gain >= this AND price has reclaimed the SMA. Card baseline 10%.
input double CARRY_GAIN_PCT             = 10.0;
// Catastrophic ATR stop. Card baseline ATR(20) * 3.0.
input int    ATR_PERIOD                 = 20;
input double ATR_STOP_MULT              = 3.0;
// Minimum warm-up bars before any evaluation (SMA200 + headroom). Card: >= 220.
input int    MIN_WARMUP_BARS            = 220;

// -----------------------------------------------------------------------------
// Rebalance cadence — derived DETERMINISTICALLY from the closed D1 bar's
// calendar bucket, with NO file-scope new-bar state and NO per-EA new-bar
// reimplementation. The source rule rebalances every ~30 calendar days; we
// bucket the closed bar's open-day by REBAL_INTERVAL_BARS calendar-day-
// equivalents (1 D1 bar ~= 1 trading day; ~21 D1 bars ~= ~30 calendar days,
// but a calendar-day bucket is monotonic and order-independent so entry and
// exit on the SAME physical bar always agree). A "rebalance bar" is the first
// closed D1 bar of a new bucket — detected by comparing the closed bar (shift 1)
// bucket to the prior closed bar (shift 2) bucket. This reads bar timestamps
// purely for arithmetic; it does not gate trading on new-bar detection (the
// framework's single QM_IsNewBar consume still owns the per-bar cadence).
// -----------------------------------------------------------------------------
#define QM_SECONDS_PER_DAY 86400

// Calendar-day bucket of a D1 bar at the given shift. Bucket width scales the
// REBAL_INTERVAL_BARS (D1-trading-bar) input to ~calendar days via 30/21.
long BarRebalBucket(const int shift)
  {
   // perf-allowed: single closed-bar open-time read for calendar-bucket math
   // (O(1), no loop, no QM_* reader exposes raw bar open time).
   const datetime bt = iTime(_Symbol, PERIOD_D1, shift);
   if(bt <= 0)
      return -1;
   const int interval_bars = (REBAL_INTERVAL_BARS > 0) ? REBAL_INTERVAL_BARS : 21;
   // Map ~21 trading bars -> ~30 calendar days. Round to nearest, min 1.
   long bucket_days = (long)MathRound((double)interval_bars * 30.0 / 21.0);
   if(bucket_days < 1)
      bucket_days = 1;
   const long day_index = (long)bt / QM_SECONDS_PER_DAY;
   return day_index / bucket_days;
  }

// True when the current closed bar (shift 1) is the first bar of a new
// rebalance bucket relative to the prior closed bar (shift 2).
bool IsRebalanceBar()
  {
   const long cur  = BarRebalBucket(1);
   const long prev = BarRebalBucket(2);
   if(cur < 0 || prev < 0)
      return false;
   return (cur != prev);
  }

// Open-position gain percent for this EA's magic on the current symbol.
// Returns true and fills gain_pct when a long position exists.
bool CurrentLongGainPct(double &gain_pct)
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if(PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY)
         continue;
      const double entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
      // perf-allowed: single closed-bar close read (O(1)) for gain math.
      const double last_close  = iClose(_Symbol, PERIOD_D1, 1);
      if(entry_price <= 0.0 || last_close <= 0.0)
         return false;
      gain_pct = 100.0 * (last_close - entry_price) / entry_price;
      return true;
     }
   return false;
  }

// Enough D1 history to evaluate SMA200 + warm-up headroom.
bool WarmupReady()
  {
   const int need = (MIN_WARMUP_BARS > SMA_PERIOD + 1) ? MIN_WARMUP_BARS : (SMA_PERIOD + 1);
   return (Bars(_Symbol, PERIOD_D1) >= need);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick block check. No regime/session gate for this D1 strategy.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Per-closed-bar entry evaluation (caller guarantees QM_IsNewBar()==true).
// Evaluate the rebalance-entry rule against the last closed D1 bar.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(!WarmupReady())
      return false;

   // Long-only: do not open if a position already exists for this magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Entry only fires on a rebalance decision bar.
   if(!IsRebalanceBar())
      return false;

   const double sma200     = QM_SMA(_Symbol, PERIOD_D1, SMA_PERIOD, 1, PRICE_CLOSE);
   // perf-allowed: single closed-bar close read (O(1)) for SMA comparison.
   const double last_close = iClose(_Symbol, PERIOD_D1, 1);
   if(sma200 <= 0.0 || last_close <= 0.0)
      return false;

   // Mean-reversion long: price below the long trend average.
   if(last_close >= sma200)
      return false;

   req.type   = QM_BUY;
   req.price  = 0.0;  // market fill at send
   req.tp     = 0.0;  // no fixed TP; exit via rebalance rule / ATR stop
   req.reason = "nt_200sma_rebal_long";

   // Fixed catastrophic ATR stop at entry. Use last-close as the stop reference
   // price (framework fills at market; SL distance is what matters).
   const double sl = QM_StopATR(_Symbol, QM_BUY, last_close, ATR_PERIOD, ATR_STOP_MULT);
   req.sl = sl; // 0.0 if ATR unavailable -> framework treats as no SL

   return true;
  }

// No per-tick trade management (no trailing / break-even for this strategy).
void Strategy_ManageOpenPosition()
  {
  }

// Scheduled rebalance exit: on a rebalance bar, close the long when price has
// reclaimed the SMA AND the retained gain has reached the carry threshold.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;
   if(!IsRebalanceBar())
      return false;
   if(!WarmupReady())
      return false;

   const double sma200     = QM_SMA(_Symbol, PERIOD_D1, SMA_PERIOD, 1, PRICE_CLOSE);
   // perf-allowed: single closed-bar close read (O(1)) for SMA comparison.
   const double last_close = iClose(_Symbol, PERIOD_D1, 1);
   if(sma200 <= 0.0 || last_close <= 0.0)
      return false;

   double gain_pct = 0.0;
   if(!CurrentLongGainPct(gain_pct))
      return false;

   // Close only when BOTH conditions hold: price >= SMA200 AND gain >= threshold.
   if(last_close >= sma200 && gain_pct >= CARRY_GAIN_PCT)
      return true;

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
