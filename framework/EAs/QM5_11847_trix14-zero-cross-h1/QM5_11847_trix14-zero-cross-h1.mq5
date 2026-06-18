#property strict
#property version   "5.0"
#property description "QM5_11847 trix14-zero-cross-h1 — TRIX(14) zero-line cross (H1 FX)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11847 trix14-zero-cross-h1
// -----------------------------------------------------------------------------
// Source: Anonymous, "Trix Strategy Trading System — Method #2: Zero-line
//   Cross", Strategy #309, forexstrategiesresources.com, ~2013 (R1/R2/R3/R4
//   PASS). Card: artifacts/cards_approved/QM5_11847_trix14-zero-cross-h1.md
//   (g0_status APPROVED). source_id 48c5b99e-3b71-5956-aabc-3a2f1ae44c43.
//
// Mechanics (closed-bar reads, H1):
//   TRIX(14)     : rate-of-change (in basis points) of a triple-smoothed EMA of
//                  close. EMA1 = EMA(close,14); EMA2 = EMA(EMA1,14);
//                  EMA3 = EMA(EMA2,14); TRIX[i] = (EMA3[i]-EMA3[i+1])/EMA3[i+1]*1e4.
//   Long  EVENT  : TRIX crosses ABOVE zero  (TRIX[2] < 0 AND TRIX[1] >= 0).
//   Short EVENT  : TRIX crosses BELOW zero  (TRIX[2] > 0 AND TRIX[1] <= 0).
//   Stop         : 2 x ATR(14)  (card factory default).
//   Take profit  : 4 x ATR(14) = 2 x SL distance => 2:1 RR (card factory default).
//   Exit         : SL / TP only; opposite zero-cross also flattens (manual exit).
//
// The zero-line cross is a SINGLE trigger EVENT — long and short are mutually
// exclusive on any given bar (TRIX cannot cross up AND down through zero on the
// same closed bar), so there is no two-cross-same-bar zero-trade trap.
//
// There is NO built-in MT5 TRIX indicator and no QM_TRIX helper, and QM_EMA
// reads price-buffer handles (it cannot EMA an arbitrary in-EA series). So the
// triple-EMA chain is reconstructed manually ONCE per closed bar from a bounded
// warmup seed (perf-allowed) and cached in file scope. The per-tick path only
// reads cached doubles.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11847;
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
input int    strategy_trix_period       = 14;     // EMA period for each of the 3 smoothing stages
input int    strategy_atr_period        = 14;     // ATR period for the stop distance
input double strategy_sl_atr_mult       = 2.0;    // stop distance = mult * ATR
input double strategy_tp_rr             = 2.0;    // take-profit risk-reward multiple (4xATR / 2xATR = 2.0)
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Cached TRIX state (advanced once per closed bar)
// -----------------------------------------------------------------------------
double   g_trix1   = 0.0;   // TRIX at closed shift 1 (current closed bar)
double   g_trix2   = 0.0;   // TRIX at closed shift 2 (prior closed bar)
bool     g_trix_ready = false;
datetime g_trix_bar   = 0;

// EMA helper over an in-memory array. src/dst are oldest->newest (index 0 =
// oldest). Seeds with an SMA of the first `period` samples, then iterates.
void EMA_Series(const double &src[], const int n, const int period, double &dst[])
  {
   ArrayResize(dst, n);
   if(n <= 0 || period <= 0)
      return;
   const double k = 2.0 / (period + 1.0);

   // Seed: if we have at least `period` samples, seed with their SMA at the
   // (period-1) index and back-fill the warmup region with the running seed.
   int seed_end = (period <= n) ? period : n;
   double sum = 0.0;
   for(int i = 0; i < seed_end; ++i)
      sum += src[i];
   double seed = sum / seed_end;
   for(int i = 0; i < seed_end; ++i)
      dst[i] = seed;                 // flat warmup; converges away downstream
   double prev = seed;
   for(int i = seed_end; i < n; ++i)
     {
      prev = src[i] * k + prev * (1.0 - k);
      dst[i] = prev;
     }
  }

// Recompute the full triple-EMA / TRIX chain from a bounded warmup window and
// cache the last two CLOSED-bar TRIX values. Called once per new closed bar.
void AdvanceState_OnNewBar()
  {
   g_trix_ready = false;

   const int p = strategy_trix_period;
   if(p < 1)
      return;

   // Warmup: 3 EMA stages of period p (~5*p each to converge) + a couple of
   // bars of headroom. Bound it so the per-bar reconstruction stays cheap.
   const int warmup = 5 * p * 3 + 10;
   const int need   = warmup + 4;     // +4 so TRIX (diff series) reaches shift 2

   const int avail = Bars(_Symbol, _Period);
   if(avail < need)
      return;

   // Pull closes oldest->newest over the window, EXCLUDING the still-forming
   // bar 0. We read closed bars only: shift `need` .. shift 1.
   double closes[];
   ArrayResize(closes, need);
   for(int j = 0; j < need; ++j)
     {
      // shift = need - j  => j=0 -> oldest (shift need); j=need-1 -> shift 1.
      const int shift = need - j;
      const double c = iClose(_Symbol, _Period, shift); // perf-allowed: once per closed bar
      if(c <= 0.0)
         return;
      closes[j] = c;
     }

   // Triple EMA chain.
   double ema1[]; EMA_Series(closes, need, p, ema1);
   double ema2[]; EMA_Series(ema1,   need, p, ema2);
   double ema3[]; EMA_Series(ema2,   need, p, ema3);

   // TRIX = basis-point ROC of ema3. trix[j] uses ema3[j] vs ema3[j-1].
   // trix[0] undefined (no prior); fill with 0.
   double trix[];
   ArrayResize(trix, need);
   trix[0] = 0.0;
   for(int j = 1; j < need; ++j)
     {
      const double prev = ema3[j - 1];
      if(prev == 0.0)
         trix[j] = 0.0;
      else
         trix[j] = (ema3[j] - prev) / prev * 10000.0;
     }

   // Map newest->shift. j = need-1 is shift 1; j = need-2 is shift 2.
   g_trix1 = trix[need - 1];
   g_trix2 = trix[need - 2];

   g_trix_ready = true;
   g_trix_bar   = iTime(_Symbol, _Period, 1);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only; fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double stop_distance = strategy_sl_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Zero-line cross event helpers (TRIX[2] = prior closed bar, TRIX[1] = current).
bool TrixCrossUp()
  {
   // Crosses up through zero: was below, now at/above.
   return (g_trix2 < 0.0 && g_trix1 >= 0.0);
  }
bool TrixCrossDown()
  {
   // Crosses down through zero: was above, now at/below.
   return (g_trix2 > 0.0 && g_trix1 <= 0.0);
  }

// TRIX zero-line cross entry. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(!g_trix_ready)
      return false;

   // ONE trigger EVENT: the zero-line cross. Long and short are mutually
   // exclusive on a given bar, so there is no two-cross-same-bar trap.
   const bool cross_up   = TrixCrossUp();
   const bool cross_down = TrixCrossDown();
   if(!cross_up && !cross_down)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   if(cross_up)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_sl_atr_mult);
      const double tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, strategy_tp_rr);
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "trix_zero_cross_long";
      return true;
     }

   // cross_down
   const double entry_s = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry_s <= 0.0)
      return false;
   const double sl_s = QM_StopATRFromValue(_Symbol, QM_SELL, entry_s, atr_value, strategy_sl_atr_mult);
   const double tp_s = QM_TakeRR(_Symbol, QM_SELL, entry_s, sl_s, strategy_tp_rr);
   if(sl_s <= 0.0 || tp_s <= 0.0)
      return false;
   req.type   = QM_SELL;
   req.price  = 0.0;
   req.sl     = sl_s;
   req.tp     = tp_s;
   req.reason = "trix_zero_cross_short";
   return true;
  }

// No active management beyond the fixed ATR stop / RR target.
void Strategy_ManageOpenPosition()
  {
  }

// Opposite TRIX zero-cross flattens the open position (manual exit).
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;
   if(!g_trix_ready)
      return false;

   const bool cross_up   = TrixCrossUp();
   const bool cross_down = TrixCrossDown();
   if(!cross_up && !cross_down)
      return false;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      // Close a long on a bearish zero-cross, a short on a bullish zero-cross.
      if(ptype == POSITION_TYPE_BUY && cross_down)
         return true;
      if(ptype == POSITION_TYPE_SELL && cross_up)
         return true;
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

   // FIRST: advance closed-bar TRIX state on a new bar (single new-bar consume).
   if(QM_IsNewBar())
     {
      AdvanceState_OnNewBar();
      QM_EquityStreamOnNewBar();

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
        }

      QM_EntryRequest req;
      if(Strategy_EntrySignal(req))
        {
         ulong out_ticket = 0;
         QM_TM_OpenPosition(req, out_ticket);
        }
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
