#property strict
#property version   "5.0"
#property description "QM5_11151 hpetf-mdu-mdd-d1 — Connors HPETF Multi-Day Up/Down reversion (D1, long+short)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11151 hpetf-mdu-mdd-d1
// -----------------------------------------------------------------------------
// Source: Larry Connors & Cesar Alvarez, "High Probability ETF Trading" (2009).
// Card: artifacts/cards_approved/QM5_11151_hpetf-mdu-mdd-d1.md (g0_status APPROVED).
//
// HPETF close-count pullback variant (D1, closed-bar reads at shift 1):
//   Long MDD (multi-day down):
//     close[1] > SMA(200)[1]                                  (trend up)
//     >= 4 of the last 5 closes are lower than the prior close (down pressure)
//     close[1] < SMA(5)[1]                                    (stretched below)
//   Short MDU (multi-day up):
//     close[1] < SMA(200)[1]                                  (trend down)
//     >= 4 of the last 5 closes are higher than the prior close (up pressure)
//     close[1] > SMA(5)[1]                                    (stretched above)
//   Exit:
//     long  -> close[1] > SMA(5)[1]
//     short -> close[1] < SMA(5)[1]
//     time-stop -> exit after time_stop_bars closed D1 bars.
//   Stop loss (bounded-risk adaptation; source has no hard stop):
//     SL = entry -/+ sl_atr_mult * ATR(atr_period).
//   Spread filter: skip if spread > spread_atr_frac * ATR (fail-open on .DWX
//     zero modeled spread).
//   Re-arm: structural. Exit requires close to cross back over SMA(5), which
//     breaks the 4-of-5 close-count entry condition; a same-direction re-entry
//     can only fire once the close-count rule re-forms.
//
// .DWX invariants honoured: fail-OPEN spread, no swap gate, prior CLOSE (not
// range) on gapless CFDs, single-consume QM_IsNewBar (entry gate only), real
// (non-degenerate) params, no external-macro CSV. Indices are D1-native so the
// MN1 / intraday-cache concerns do not apply.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11151;
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
input int    strategy_sma_trend_period  = 200;   // long-term trend filter SMA
input int    strategy_sma_fast_period   = 5;      // entry/exit fast SMA
input int    strategy_count_window      = 5;      // close-count lookback window
input int    strategy_count_min         = 4;      // min lower/higher closes in window
input int    strategy_atr_period        = 14;     // ATR period (stop + spread guard)
input double strategy_sl_atr_mult       = 3.0;    // stop distance = mult * ATR
input int    strategy_time_stop_bars    = 10;     // exit after this many D1 bars
input double strategy_spread_atr_frac   = 0.25;   // skip if spread > frac * ATR
input bool   strategy_allow_long        = true;   // enable long MDD entries
input bool   strategy_allow_short       = true;   // enable short MDU entries

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

// Count, over the last `window` closed bars, how many closed lower than the
// immediately prior close. Returns the down-count; up-count = window - down.
// shift s in [1..window] compares close[s] vs close[s+1] (prior close).
// Reads single closed bars only (perf-allowed; bounded D1 loop, window<=10).
int CloseCountDown()
  {
   int down = 0;
   for(int s = 1; s <= strategy_count_window; ++s)
     {
      const double c_cur  = iClose(_Symbol, _Period, s);     // perf-allowed
      const double c_prev = iClose(_Symbol, _Period, s + 1); // perf-allowed
      if(c_cur <= 0.0 || c_prev <= 0.0)
         return -1; // insufficient history
      if(c_cur < c_prev)
         ++down;
     }
   return down;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — signal work is on the closed-bar
// path in Strategy_EntrySignal. Fail-open on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate, do not block here

   const double cap = strategy_spread_atr_frac * atr_value;
   if(cap <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > cap)
      return true;

   return false;
  }

// Long+short entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   const double sma_trend = QM_SMA(_Symbol, _Period, strategy_sma_trend_period, 1);
   const double sma_fast  = QM_SMA(_Symbol, _Period, strategy_sma_fast_period, 1);
   if(sma_trend <= 0.0 || sma_fast <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const int down = CloseCountDown();
   if(down < 0)
      return false; // insufficient history
   const int up = strategy_count_window - down;

   // --- Long MDD: uptrend, >=count_min down closes, stretched below SMA(5) ---
   if(strategy_allow_long &&
      close1 > sma_trend &&
      down >= strategy_count_min &&
      close1 < sma_fast)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_sl_atr_mult);
      if(sl <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = 0.0;   // no fixed target — SMA(5) reversion / time-stop exit
      req.reason = "hpetf_mdd_long";
      return true;
     }

   // --- Short MDU: downtrend, >=count_min up closes, stretched above SMA(5) ---
   if(strategy_allow_short &&
      close1 < sma_trend &&
      up >= strategy_count_min &&
      close1 > sma_fast)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_SELL, entry, atr_value, strategy_sl_atr_mult);
      if(sl <= 0.0)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = 0.0;
      req.reason = "hpetf_mdu_short";
      return true;
     }

   return false;
  }

// No active SL/TP management beyond the fixed ATR stop. Reversion + time-stop
// exits live in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Exit: SMA(5) reversion (long -> close>SMA5, short -> close<SMA5) OR time-stop
// after strategy_time_stop_bars closed D1 bars since entry.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double close1   = iClose(_Symbol, _Period, 1); // perf-allowed
   const double sma_fast = QM_SMA(_Symbol, _Period, strategy_sma_fast_period, 1);
   if(close1 <= 0.0 || sma_fast <= 0.0)
      return false;

   // Inspect this EA's open position direction + age.
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const long pos_type = PositionGetInteger(POSITION_TYPE);

      // --- SMA(5) reversion exit ---
      if(pos_type == POSITION_TYPE_BUY && close1 > sma_fast)
         return true;
      if(pos_type == POSITION_TYPE_SELL && close1 < sma_fast)
         return true;

      // --- Time-stop: bars elapsed since entry (closed-bar count) ---
      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int entry_shift = iBarShift(_Symbol, _Period, open_time, false); // perf-allowed: single read
      // entry_shift = number of closed bars between entry bar and current bar.
      if(entry_shift >= strategy_time_stop_bars)
         return true;

      return false; // single position per magic — first match decides
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
