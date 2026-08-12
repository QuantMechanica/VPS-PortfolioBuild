#property strict
#property version   "5.0"
#property description "QM5_1626 Hopwood Bermaui-Stoch H4 Trend-Follower"

#include <QM/QM_Common.mqh>
#include <QM/QM_Indicators.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_1626 — Hopwood/Bermaui double-smoothed Stochastic.
//
// Kernel:  %K_raw     = Stochastic_K(14, slowing=3)
//          %K_smooth1 = WilderMA(%K_raw, 7)
//          %K_smooth2 = HMA(%K_smooth1, 7)     (built from LWMA passes)
//          delta      = smooth2[shift1] - smooth2[shift2]
// Entry:   mid-cross of smooth2 through 50 + confirming delta sign + D1 regime.
// Exits:   reverse-signal / time-stop(30 H4) / trailing breakeven+partial.
//
// Closed-bar convention: shift=1 is the just-closed bar ("current" for signal
// purposes), shift=2 the bar before it. Never act on shift=0 (unclosed bar).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1626;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.5;
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
input int    strategy_stoch_k_period     = 14;    // raw Stochastic %K period
input int    strategy_stoch_d_period     = 3;     // %D period (handle only; %D unused)
input int    strategy_stoch_slowing      = 3;     // Stochastic slowing
input int    strategy_wilder_period      = 7;     // WilderMA first smoothing pass
input int    strategy_hma_period         = 7;     // HMA second smoothing pass
input double strategy_mid_line           = 50.0;  // cross threshold on smooth2
input int    strategy_sma_period         = 200;   // D1 regime SMA period
input int    strategy_atr_period         = 14;    // ATR period for SL/TP/BE
input int    strategy_range_atr_period   = 50;    // slow ATR for range-sanity
input double strategy_range_sanity_mult  = 0.5;   // skip if ATR14 < mult*ATR50
input double strategy_sl_atr_mult        = 2.5;   // initial SL = mult*ATR from entry
input double strategy_tp_atr_mult        = 2.0;   // partial scale-out at mult*ATR profit
input double strategy_be_atr_mult        = 1.0;   // move to breakeven at mult*ATR profit
input int    strategy_time_stop_bars     = 30;    // close after N completed H4 bars
input int    strategy_cooldown_bars      = 6;     // no same-dir re-entry within N bars
input double strategy_max_spread_atr_mult = 0.3;  // skip entry if spread > mult*ATR14
input bool   strategy_sl_swing_anchor    = false; // P3 alt: swing SL instead of ATR SL
input int    strategy_swing_lookback     = 14;    // swing-anchor lookback (bars)

// -----------------------------------------------------------------------------
// File-scope state
// -----------------------------------------------------------------------------
#define QM_BERMAUI_WARMUP 80   // H4 bars of raw %K fed into the double-smoothing

// Per-bar cache of the double-smoothed line (recomputed once per new H4 bar).
double   g_berm_cur        = 50.0;   // smooth2 at shift 1 (current / just-closed)
double   g_berm_prev       = 50.0;   // smooth2 at shift 2 (previous)
double   g_berm_delta      = 0.0;    // smooth2[shift1] - smooth2[shift2]
datetime g_berm_cache_time = 0;      // iTime(H4,0) the cache was computed for

// Same-direction cooldown: bar-open time of the last entry in each direction.
datetime g_last_long_entry_bar  = 0;
datetime g_last_short_entry_bar = 0;

// Partial-close idempotency (same-EA-run; not persisted across restart).
#define QM_PARTIAL_MAX 64
ulong g_partial_taken_tickets[QM_PARTIAL_MAX];
int   g_partial_taken_count = 0;

// -----------------------------------------------------------------------------
// Bermaui double-smoothing kernel
// -----------------------------------------------------------------------------

// Linear-weighted MA over a local array, ending at `end_index` (weighted most),
// spanning `period` samples backwards. Recent samples weighted more heavily.
double LWMA_OfArray(const double &series[], const int end_index, const int period)
  {
   if(end_index < 0)
      return 0.0;
   if(period <= 1 || end_index < period - 1)
      return series[end_index];
   double num = 0.0;
   double den = 0.0;
   for(int j = 0; j < period; j++)
     {
      const double w = (double)(period - j);      // j=0 -> newest sample, max weight
      num += series[end_index - j] * w;
      den += w;
     }
   return (den > 0.0) ? (num / den) : series[end_index];
  }

// Rebuild the smooth2 cache for shift=1 and shift=2 in a single pass over the
// warmup window. Called only when a new H4 bar opens (see EnsureBermauiCache).
void ComputeBermauiKernel()
  {
   const int N = QM_BERMAUI_WARMUP;

   // Raw %K in chronological order: k[0]=oldest (shift N), k[N-1]=shift 1.
   double k[QM_BERMAUI_WARMUP];
   for(int t = 0; t < N; t++)
      k[t] = QM_Stoch_K(_Symbol, PERIOD_H4, strategy_stoch_k_period,
                        strategy_stoch_d_period, strategy_stoch_slowing, N - t); // perf-allowed: warmup scan

   // Pass 1 — Wilder (RMA) smoothing, recursive over the chronological series.
   double s1[QM_BERMAUI_WARMUP];
   const double wp = (double)strategy_wilder_period;
   s1[0] = k[0];
   for(int t = 1; t < N; t++)
      s1[t] = s1[t - 1] + (k[t] - s1[t - 1]) / wp;   // fully converged by newest end

   // Pass 2 — HMA of the Wilder line: diff = 2*LWMA(n/2) - LWMA(n), then LWMA(sqrt n).
   const int half = strategy_hma_period / 2;
   int sq = (int)MathSqrt((double)strategy_hma_period);
   if(sq < 1)
      sq = 1;

   double diff[QM_BERMAUI_WARMUP];
   for(int t = 0; t < N; t++)
     {
      if(t < strategy_hma_period - 1)
        {
         diff[t] = s1[t];
         continue;
        }
      diff[t] = 2.0 * LWMA_OfArray(s1, t, half) - LWMA_OfArray(s1, t, strategy_hma_period);
     }

   g_berm_cur   = LWMA_OfArray(diff, N - 1, sq);   // smooth2 at shift 1
   g_berm_prev  = LWMA_OfArray(diff, N - 2, sq);   // smooth2 at shift 2
   g_berm_delta = g_berm_cur - g_berm_prev;
  }

// Recompute the kernel cache once per new H4 bar; reuse within the bar.
void EnsureBermauiCache()
  {
   const datetime t0 = iTime(_Symbol, PERIOD_H4, 0);   // perf-allowed: bar-time key
   if(t0 > 0 && t0 == g_berm_cache_time)
      return;
   ComputeBermauiKernel();
   g_berm_cache_time = t0;
  }

// Cross helpers read the cached smooth2 values (caller must refresh the cache).
bool IsMidCrossUp()
  {
   return (g_berm_prev < strategy_mid_line && g_berm_cur >= strategy_mid_line);
  }

bool IsMidCrossDown()
  {
   return (g_berm_prev > strategy_mid_line && g_berm_cur <= strategy_mid_line);
  }

// P3 alternative stop anchor: recent H4 swing low/high (raw price, not indicator math).
double GetSwingSL(const QM_OrderType side, const int lookback)
  {
   if(lookback < 1)
      return 0.0;
   if(QM_OrderTypeIsBuy(side))
     {
      double lowest = DBL_MAX;
      for(int i = 1; i <= lookback; i++)
        {
         const double low = iLow(_Symbol, PERIOD_H4, i);   // perf-allowed: range scan
         if(low > 0.0 && low < lowest)
            lowest = low;
        }
      return (lowest == DBL_MAX) ? 0.0 : lowest;
     }
   double highest = 0.0;
   for(int i = 1; i <= lookback; i++)
     {
      const double high = iHigh(_Symbol, PERIOD_H4, i);    // perf-allowed: range scan
      if(high > highest)
         highest = high;
     }
   return highest;
  }

// -----------------------------------------------------------------------------
// Partial-close idempotency bookkeeping
// -----------------------------------------------------------------------------
bool PartialAlreadyTaken(const ulong ticket)
  {
   for(int i = 0; i < g_partial_taken_count; i++)
      if(g_partial_taken_tickets[i] == ticket)
         return true;
   return false;
  }

void MarkPartialTaken(const ulong ticket)
  {
   if(PartialAlreadyTaken(ticket))
      return;
   if(g_partial_taken_count < QM_PARTIAL_MAX)
      g_partial_taken_tickets[g_partial_taken_count++] = ticket;
  }

// -----------------------------------------------------------------------------
// Position selection (one position per magic)
// -----------------------------------------------------------------------------
bool Strategy_SelectOurPosition(ENUM_POSITION_TYPE &position_type, ulong &ticket)
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong candidate = PositionGetTicket(i);
      if(candidate == 0 || !PositionSelectByTicket(candidate))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      ticket = candidate;
      return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick.
bool Strategy_NoTradeFilter()
  {
   // Warmup: enough H4 history for the double-smoothing window + Stochastic lookback.
   if(Bars(_Symbol, PERIOD_H4) < QM_BERMAUI_WARMUP + strategy_stoch_k_period + strategy_stoch_slowing + 10) // perf-allowed: O(1) warmup bar-count guard
      return true;

   const double atr1 = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(atr1 <= 0.0)
      return true;

   // Spread filter: only blocks a genuinely WIDE spread. In the .DWX tester the
   // spread reads as exactly 0, so this never fires on tester quotes.
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask > 0.0 && bid > 0.0 && ask > bid && (ask - bid) > strategy_max_spread_atr_mult * atr1)
      return true;

   // Range-sanity: skip dead-flat ranges where the double-smoothing lags badly.
   const double atr_range = QM_ATR(_Symbol, PERIOD_H4, strategy_range_atr_period, 1);
   if(atr_range > 0.0 && atr1 < strategy_range_sanity_mult * atr_range)
      return true;

   return false;
  }

// Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type               = QM_BUY;
   req.price              = 0.0;
   req.sl                 = 0.0;
   req.tp                 = 0.0;
   req.reason             = "";
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_stoch_k_period < 2 || strategy_wilder_period < 2 || strategy_hma_period < 4)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) > 0)
      return false;   // one position per magic — never stack

   EnsureBermauiCache();

   // D1 regime gate (mandatory).
   const double close1_d1 = iClose(_Symbol, PERIOD_D1, 1);           // perf-allowed: regime read
   const double sma200_d1 = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_period, 1);
   if(close1_d1 <= 0.0 || sma200_d1 <= 0.0)
      return false;   // D1 SMA(200) not yet warmed up

   QM_OrderType side = QM_BUY;
   string reason = "";
   if(IsMidCrossUp() && g_berm_delta > 0.0 && close1_d1 > sma200_d1)
     {
      side = QM_BUY;
      reason = "BERMAUI_STOCH_LONG";
     }
   else if(IsMidCrossDown() && g_berm_delta < 0.0 && close1_d1 < sma200_d1)
     {
      side = QM_SELL;
      reason = "BERMAUI_STOCH_SHORT";
     }
   else
      return false;

   // Same-direction cooldown.
   if(side == QM_BUY && g_last_long_entry_bar > 0 &&
      iBarShift(_Symbol, PERIOD_H4, g_last_long_entry_bar, false) < strategy_cooldown_bars)
      return false;
   if(side == QM_SELL && g_last_short_entry_bar > 0 &&
      iBarShift(_Symbol, PERIOD_H4, g_last_short_entry_bar, false) < strategy_cooldown_bars)
      return false;

   const double entry_price = (side == QM_BUY)
                              ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                              : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry_price <= 0.0)
      return false;

   double sl = 0.0;
   if(strategy_sl_swing_anchor)
      sl = GetSwingSL(side, strategy_swing_lookback);
   else
      sl = QM_StopATR(_Symbol, side, entry_price, strategy_atr_period, strategy_sl_atr_mult);

   if(sl <= 0.0 ||
      (side == QM_BUY  && sl >= entry_price) ||
      (side == QM_SELL && sl <= entry_price))
      return false;

   req.type               = side;
   req.price              = 0.0;
   req.sl                 = sl;
   req.tp                 = 0.0;   // profit target realized as +2.0*ATR partial scale-out (SPEC 1)
   req.reason             = reason;
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   // Record the entry bar for the same-direction cooldown.
   const datetime bar_time = iTime(_Symbol, PERIOD_H4, 0); // perf-allowed: cooldown bar-time bookkeeping
   if(side == QM_BUY)
      g_last_long_entry_bar = bar_time;
   else
      g_last_short_entry_bar = bar_time;

   return true;
  }

// Trailing management (runs every tick): breakeven at +1*ATR, partial 50% at +2*ATR.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) == 0)
      return;

   ENUM_POSITION_TYPE ptype = POSITION_TYPE_BUY;
   ulong ticket = 0;
   if(!Strategy_SelectOurPosition(ptype, ticket))
      return;

   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(atr <= 0.0)
      return;

   const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   const double vol        = PositionGetDouble(POSITION_VOLUME);
   const double cur_sl     = PositionGetDouble(POSITION_SL);
   const double point      = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask        = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid        = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double spread     = (ask > bid && bid > 0.0) ? (ask - bid) : 0.0;
   const double last       = iClose(_Symbol, PERIOD_H4, 1);   // perf-allowed: closed-bar profit gauge
   if(open_price <= 0.0 || last <= 0.0)
      return;

   const double profit = (ptype == POSITION_TYPE_BUY) ? (last - open_price) : (open_price - last);

   // 1. Move stop to breakeven-plus-spread once profit reaches +be*ATR.
   if(profit >= strategy_be_atr_mult * atr)
     {
      const double new_sl = (ptype == POSITION_TYPE_BUY)
                            ? (open_price + spread + 2.0 * point)
                            : (open_price - spread - 2.0 * point);
      const bool improves = (cur_sl <= 0.0) ||
                            (ptype == POSITION_TYPE_BUY ? (new_sl > cur_sl + 0.5 * point)
                                                        : (new_sl < cur_sl - 0.5 * point));
      if(improves && new_sl > 0.0)
         QM_TM_MoveSL(ticket, new_sl, "BREAKEVEN_PLUS_SPREAD");
     }

   // 2. Close 50% once at +tp*ATR (profit target realized as a scale-out).
   if(profit >= strategy_tp_atr_mult * atr && !PartialAlreadyTaken(ticket))
     {
      const double close_vol = QM_TM_NormalizeVolume(_Symbol, vol * 0.5);
      if(close_vol > 0.0 && close_vol < vol)
        {
         if(QM_TM_PartialClose(ticket, close_vol, QM_EXIT_PARTIAL))
            MarkPartialTaken(ticket);
        }
      else
        {
         // Volume too small to split cleanly — mark taken so we don't retry every tick.
         MarkPartialTaken(ticket);
        }
     }
  }

// Bar-gated hard exits. Closes internally with the correct exit reason (1258 pattern).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) == 0)
      return false;

   ENUM_POSITION_TYPE ptype = POSITION_TYPE_BUY;
   ulong ticket = 0;
   if(!Strategy_SelectOurPosition(ptype, ticket))
      return false;

   // Time-stop: N completed H4 bars, restart-safe (walks the bar series).
   const int held = QM_TM_HeldPeriods(_Symbol, PERIOD_H4, (datetime)PositionGetInteger(POSITION_TIME));
   if(held >= strategy_time_stop_bars)   // held < 0 => unknown => not due
     {
      QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
      return false;
     }

   // Reverse-signal: opposite mid-cross with confirming delta sign.
   EnsureBermauiCache();
   if(ptype == POSITION_TYPE_BUY && IsMidCrossDown() && g_berm_delta < 0.0)
     {
      QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
      return false;
     }
   if(ptype == POSITION_TYPE_SELL && IsMidCrossUp() && g_berm_delta > 0.0)
     {
      QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
      return false;
     }

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time) { return false; }

// -----------------------------------------------------------------------------
// Framework wiring (skeleton — same shape as sibling QM5_1258)
// -----------------------------------------------------------------------------
int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy, qm_friday_close_enabled, qm_friday_close_hour_broker,
                        30, 30, qm_news_stale_max_hours, qm_news_min_impact, qm_rng_seed,
                        qm_stress_reject_probability, qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1626\",\"strategy\":\"hopwood-bermaui-stoch-h4\"}");
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

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   Strategy_ExitSignal();

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
