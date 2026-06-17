#property strict
#property version   "5.0"
#property description "QM5_11150 hpetf-pctb-d1 — HPETF Bollinger %B persistence mean-reversion (D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11150 hpetf-pctb-d1
// -----------------------------------------------------------------------------
// Source: Connors & Alvarez, "High Probability ETF Trading" (2009) — Bollinger
//   %B persistence reversion, trend-gated by SMA(200).
// Card: artifacts/cards_approved/QM5_11150_hpetf-pctb-d1.md (g0_status APPROVED).
//
// Mechanics (D1, closed-bar reads at shift 1/2/3):
//   %B[s] = (Close[s] - Lower[s]) / (Upper[s] - Lower[s])
//           with Bollinger(period=20, deviation=2.0).
//   Long  : Close[1] > SMA(200)[1]  AND  %B[1], %B[2], %B[3] each < pctb_lo (0.20).
//   Short : Close[1] < SMA(200)[1]  AND  %B[1], %B[2], %B[3] each > pctb_hi (0.80).
//   Exit long  : %B[1] > pctb_hi (0.80).
//   Exit short : %B[1] < pctb_lo (0.20).
//   Time-stop  : exit after time_stop_bars (12) closed D1 bars in trade.
//   Stop       : entry -/+ sl_atr_mult (3.0) * ATR(14)  (source has no hard stop;
//                bounded-risk QM5 adaptation).
//   Skip if UpperBand == LowerBand (degenerate band).
//   Spread guard: skip only a genuinely WIDE spread > spread_atr_frac * ATR(14)
//                 (fail-open on .DWX zero modeled spread).
//
// .DWX invariants honoured: closed-bar %B persistence is a STATE (3 closed bars),
// not two coincident cross EVENTS; fail-open spread; no swap gate; prior-CLOSE
// based (no gap rule); D1-native (no MN1); no external-macro CSV. The trend gate
// reads the last CLOSE vs SMA(200) — gapless CFDs make this a clean state read.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11150;
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
input ENUM_TIMEFRAMES strategy_timeframe     = PERIOD_D1;   // base timeframe
input int             strategy_bb_period     = 20;          // Bollinger period
input double          strategy_bb_deviation  = 2.0;         // Bollinger std-dev multiplier
input int             strategy_sma_period    = 200;         // trend-gate SMA period
input double          strategy_pctb_lo       = 0.20;        // %B oversold threshold
input double          strategy_pctb_hi       = 0.80;        // %B overbought threshold
input int             strategy_persist_bars  = 3;           // consecutive closed bars at extreme
input int             strategy_atr_period    = 14;          // ATR period (stop + spread cap)
input double          strategy_sl_atr_mult   = 3.0;         // stop distance = mult * ATR
input int             strategy_time_stop_bars = 12;         // exit after N closed bars in trade
input double          strategy_spread_atr_frac = 0.25;      // skip if spread > frac * ATR(14)
input bool            strategy_enable_longs  = true;
input bool            strategy_enable_shorts = true;

// -----------------------------------------------------------------------------
// Helpers (file-scope, pure closed-bar reads — no per-EA new-bar gate)
// -----------------------------------------------------------------------------

// %B at a given closed-bar shift. Returns -1.0 on a degenerate/unavailable band.
double PercentB(const int shift)
  {
   const double upper = QM_BB_Upper(_Symbol, strategy_timeframe, strategy_bb_period,
                                    strategy_bb_deviation, shift, PRICE_CLOSE);
   const double lower = QM_BB_Lower(_Symbol, strategy_timeframe, strategy_bb_period,
                                    strategy_bb_deviation, shift, PRICE_CLOSE);
   if(upper <= 0.0 || lower <= 0.0 || upper <= lower)
      return -1.0; // degenerate band (UpperBand == LowerBand) or unavailable
   const double close_s = iClose(_Symbol, strategy_timeframe, shift); // perf-allowed: single closed-bar read; no QM close reader exists
   if(close_s <= 0.0)
      return -1.0;
   return (close_s - lower) / (upper - lower);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   if(strategy_bb_period < 2 ||
      strategy_bb_deviation <= 0.0 ||
      strategy_sma_period < 2 ||
      strategy_persist_bars < 1 ||
      strategy_atr_period <= 0 ||
      strategy_sl_atr_mult <= 0.0 ||
      strategy_time_stop_bars <= 0 ||
      strategy_spread_atr_frac < 0.0 ||
      strategy_pctb_lo <= 0.0 || strategy_pctb_hi >= 1.0 ||
      strategy_pctb_lo >= strategy_pctb_hi)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > strategy_spread_atr_frac * atr_value)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Trend gate: last CLOSE vs SMA(200) (closed bar) ---
   const double sma = QM_SMA(_Symbol, strategy_timeframe, strategy_sma_period, 1, PRICE_CLOSE);
   if(sma <= 0.0)
      return false;
   const double close1 = iClose(_Symbol, strategy_timeframe, 1); // perf-allowed: single closed-bar read; no QM close reader exists
   if(close1 <= 0.0)
      return false;

   // --- %B persistence STATE: each of the last persist_bars closed bars at the
   //     extreme. Shifts 1..persist_bars (1=%B[t], 2=%B[t-1], 3=%B[t-2]). ---
   bool all_below = true;
   bool all_above = true;
   for(int s = 1; s <= strategy_persist_bars; ++s)
     {
      const double pb = PercentB(s);
      if(pb < 0.0)
         return false; // degenerate/unavailable band → skip this bar
      if(pb >= strategy_pctb_lo)
         all_below = false;
      if(pb <= strategy_pctb_hi)
         all_above = false;
     }

   const double atr_value = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   // --- Long: uptrend (Close > SMA200) + persistent oversold %B ---
   if(strategy_enable_longs && close1 > sma && all_below)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(ask <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, ask, atr_value, strategy_sl_atr_mult);
      if(sl <= 0.0 || sl >= ask)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = 0.0;   // no fixed target; exits via %B reversion or time-stop
      req.reason = "hpetf_pctb_oversold_long";
      return true;
     }

   // --- Short: downtrend (Close < SMA200) + persistent overbought %B ---
   if(strategy_enable_shorts && close1 < sma && all_above)
     {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_SELL, bid, atr_value, strategy_sl_atr_mult);
      if(sl <= bid)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = 0.0;
      req.reason = "hpetf_pctb_overbought_short";
      return true;
     }

   return false;
  }

// No active trade management beyond the fixed ATR stop. Exit logic lives in
// Strategy_ExitSignal (%B reversion + time-stop).
void Strategy_ManageOpenPosition()
  {
  }

// Exit: %B reversion to the opposite extreme, or time-stop after N closed bars.
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

      // Time-stop: closed-bar count since entry.
      const datetime opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened_at > 0)
        {
         const int open_shift = iBarShift(_Symbol, strategy_timeframe, opened_at, false);
         if(open_shift >= strategy_time_stop_bars)
            return true;
        }

      const double pb = PercentB(1);
      if(pb < 0.0)
         continue; // degenerate band — no %B exit this bar (time-stop still guards)

      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(position_type == POSITION_TYPE_BUY)
         return (pb > strategy_pctb_hi);   // long exits when %B closes above 0.80
      if(position_type == POSITION_TYPE_SELL)
         return (pb < strategy_pctb_lo);   // short exits when %B closes below 0.20
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
