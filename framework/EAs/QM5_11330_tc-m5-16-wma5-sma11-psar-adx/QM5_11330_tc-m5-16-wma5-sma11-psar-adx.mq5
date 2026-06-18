#property strict
#property version   "5.0"
#property description "QM5_11330 tc-m5-16-wma5-sma11-psar-adx — WMA(5)/SMA(11) + PSAR + ADX DI (M5)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11330 tc-m5-16-wma5-sma11-psar-adx
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)",
//         5 Min Trading System #16 (source_id e78a9f1f-4e6a-563c-a080-915133d6ed28).
// Card: artifacts/cards_approved/QM5_11330_tc-m5-16-wma5-sma11-psar-adx.md
//       (g0_status APPROVED).
//
// Mechanics (M5, closed-bar reads at shift 1; long + short):
//   Trigger EVENT (ONE of, this bar — avoids the two-cross-same-bar 0-trade trap):
//       * WMA(5)/SMA(11) cross  (fast crosses slow), OR
//       * PSAR flip             (PSAR crosses to the trade side of price).
//   Confirming STATES (must all agree with the trade direction on the bar):
//       * WMA(5) vs SMA(11) position (above for long / below for short),
//       * PSAR side                  (below price for long / above for short),
//       * ADX DI direction           (DI+ > DI- for long / DI- > DI+ for short).
//   Optional ADX strength filter: ADX(period) >= adx_min (default 0 = off, per
//       card which only specifies DI direction, not an ADX level).
//   Stop  : structure swing low/high over sl_lookback closed bars
//           (card "previous swing high/low"); ATR fallback if structure unusable.
//   Take  : RR multiple of the stop distance (tp_rr; 0 disables → PSAR exit only).
//   Exit  : PSAR reversal — PSAR flips to the opposite side of price -> close.
//   Spread guard : skip only a genuinely WIDE spread (> spread_pct_of_stop of the
//           stop distance). Fail-OPEN on .DWX zero modeled spread.
//
// PSAR parameters per card Implementation Notes: step=0.01, max=0.1 (source text
// "(0.1,0.01)" is a typo; convention is (step,max) -> (0.01,0.1)).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11330;
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
input int    strategy_wma_period        = 5;     // fast WMA (LWMA) period
input int    strategy_sma_period        = 11;    // slow SMA period
input double strategy_psar_step         = 0.01;  // Parabolic SAR step (corrected from card typo)
input double strategy_psar_max          = 0.1;   // Parabolic SAR maximum
input int    strategy_adx_period        = 14;    // ADX / DI period
input double strategy_adx_min           = 0.0;   // optional ADX strength floor (0 = off)
input int    strategy_sl_lookback       = 20;    // swing structure lookback for the stop
input int    strategy_atr_period        = 14;    // ATR period (stop fallback / spread ref)
input double strategy_atr_sl_mult       = 1.5;   // ATR stop multiple (fallback)
input double strategy_tp_rr             = 2.0;   // take-profit = tp_rr * stop distance (0 = none)
input double strategy_spread_pct_of_stop = 25.0; // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Helpers (closed-bar reads only; all via QM_* pooled readers)
// -----------------------------------------------------------------------------

// PSAR side at a given closed-bar shift: +1 PSAR below price (bullish),
// -1 PSAR above price (bearish), 0 if data not ready.
int PsarSide(const int shift)
  {
   const double sar   = QM_SAR(_Symbol, _Period, strategy_psar_step, strategy_psar_max, shift);
   const double close = iClose(_Symbol, _Period, shift); // perf-allowed: single closed-bar read
   if(sar <= 0.0 || close <= 0.0)
      return 0;
   if(sar < close)
      return 1;
   if(sar > close)
      return -1;
   return 0;
  }

// WMA-vs-SMA position at a given closed-bar shift: +1 fast>slow, -1 fast<slow, 0.
int MaPosition(const int shift)
  {
   const double fast = QM_WMA(_Symbol, _Period, strategy_wma_period, shift);
   const double slow = QM_SMA(_Symbol, _Period, strategy_sma_period, shift);
   if(fast <= 0.0 || slow <= 0.0)
      return 0;
   if(fast > slow)
      return 1;
   if(fast < slow)
      return -1;
   return 0;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only. Fail-OPEN on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to entry gate, do not block here

   const double stop_distance = strategy_atr_sl_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely WIDE spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Confirming STATES at the just-closed bar (shift 1) ---
   const int ma_pos    = MaPosition(1);      // +1 long-side / -1 short-side
   const int psar_side = PsarSide(1);        // +1 bullish / -1 bearish
   if(ma_pos == 0 || psar_side == 0)
      return false;

   const double di_plus  = QM_ADX_PlusDI(_Symbol, _Period, strategy_adx_period, 1);
   const double di_minus = QM_ADX_MinusDI(_Symbol, _Period, strategy_adx_period, 1);
   if(di_plus <= 0.0 && di_minus <= 0.0)
      return false; // DI not ready
   const int di_dir = (di_plus > di_minus) ? 1 : ((di_minus > di_plus) ? -1 : 0);
   if(di_dir == 0)
      return false;

   // Optional ADX strength floor (off by default — card specifies DI direction
   // only, not an ADX level).
   if(strategy_adx_min > 0.0)
     {
      const double adx = QM_ADX(_Symbol, _Period, strategy_adx_period, 1);
      if(adx < strategy_adx_min)
         return false;
     }

   // --- Trigger EVENT: ONE of a fresh WMA/SMA cross OR a fresh PSAR flip on
   //     the just-closed bar (shift 1 vs shift 2). The other conditions are
   //     STATES (above) — never require two cross EVENTS on the same bar. ---
   const int ma_pos_prev    = MaPosition(2);
   const int psar_side_prev = PsarSide(2);
   const bool ma_cross   = (ma_pos_prev != 0 && ma_pos_prev != ma_pos);
   const bool psar_flip  = (psar_side_prev != 0 && psar_side_prev != psar_side);
   if(!(ma_cross || psar_flip))
      return false;

   // --- Direction resolution: all three states must agree. ---
   int dir = 0;
   if(ma_pos == 1 && psar_side == 1 && di_dir == 1)
      dir = 1;   // LONG
   else if(ma_pos == -1 && psar_side == -1 && di_dir == -1)
      dir = -1;  // SHORT
   else
      return false;

   const QM_OrderType side = (dir == 1) ? QM_BUY : QM_SELL;

   const double entry = (dir == 1) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                    : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   // --- Stop: previous swing low (long) / swing high (short) over the
   //     structure lookback. ATR fallback if structure is degenerate. ---
   double sl = QM_StopStructure(_Symbol, side, entry, strategy_sl_lookback);
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   const bool sl_valid = (dir == 1) ? (sl > 0.0 && sl < entry)
                                     : (sl > 0.0 && sl > entry);
   if(!sl_valid)
     {
      if(atr_value <= 0.0)
         return false;
      sl = QM_StopATRFromValue(_Symbol, side, entry, atr_value, strategy_atr_sl_mult);
     }
   if(sl <= 0.0)
      return false;

   // --- Take profit: RR multiple of the stop distance (0 disables). ---
   double tp = 0.0;
   if(strategy_tp_rr > 0.0)
     {
      tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_tp_rr);
      if(tp <= 0.0)
         return false;
     }

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = (dir == 1) ? "wma_sma_psar_adx_long" : "wma_sma_psar_adx_short";
   return true;
  }

// No active trade management — fixed structure/ATR stop + optional RR target.
// The PSAR-reversal discretionary exit lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Exit on PSAR reversal: PSAR flips to the opposite side of the open position.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const int psar_side = PsarSide(1); // +1 bullish / -1 bearish at closed bar
   if(psar_side == 0)
      return false;

   // Determine current position direction for this magic.
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && psar_side == -1)
         return true; // PSAR flipped above price -> close long
      if(ptype == POSITION_TYPE_SELL && psar_side == 1)
         return true; // PSAR flipped below price -> close short
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
