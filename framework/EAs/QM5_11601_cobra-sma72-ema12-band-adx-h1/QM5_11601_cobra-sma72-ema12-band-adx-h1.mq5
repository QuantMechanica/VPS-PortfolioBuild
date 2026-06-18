#property strict
#property version   "5.0"
#property description "QM5_11601 cobra-sma72-ema12-band-adx-h1 — Forex Cobra dual-MA band breakout + ADX (H1, both directions)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11601 cobra-sma72-ema12-band-adx-h1
// -----------------------------------------------------------------------------
// Source: ForexCobraSystem.com, "The Forex Cobra System" (49pp, 2009).
// Card: artifacts/cards_approved/QM5_11601_cobra-sma72-ema12-band-adx-h1.md
//       (g0_status APPROVED).
//
// Mechanics (both directions, closed-bar reads, H1):
//   SMA72 band  : center = SMA(72, TYPICAL), upper = SMA(72, HIGH),
//                 lower = SMA(72, LOW). Defines the macro TREND STATE.
//   EMA12 band  : center = EMA(12, TYPICAL), upper = EMA(12, HIGH),
//                 lower = EMA(12, LOW). Defines the dynamic entry zone.
//   ADX(14)     : trend-strength filter.
//
//   Trend STATE (long): close[1] > sma72_upper[1]  (price fully above the
//                       orange band → bullish macro bias).
//   Trigger EVENT (long): a 2-candle EMA12-band breakout that COMPLETES on the
//                       just-closed bar[1]:
//                         - bar[2] closed above ema12_upper[2] and was a bullish
//                           non-doji candle  (PRECEDING state),
//                         - bar[1] closed above ema12_upper[1], bullish non-doji,
//                           and made a NEW HIGH vs bar[2]  (the completing event),
//                       gated by ADX(14)[1] > adx_threshold AND ADX rising.
//                       The breakout itself is the single fresh EVENT; the SMA72
//                       trend and the bar[2] band-state are STATES — never two
//                       independent cross events on the same bar (no 2-cross trap).
//   Day filter  : no NEW entries on Friday (broker DayOfWeek).
//   Stop        : EMA12 outer band edge at the entry bar (lower for long, upper
//                 for short). Factory floor: if that distance < 1x ATR(14), use
//                 sl_atr_floor_mult x ATR(14) instead.
//   Exit        : close crosses back through the EMA12 typical midline
//                 (long: close[1] < ema12_typical[1]; short: mirror).
//   Spread guard: blocks only a genuinely wide spread (fail-open on .DWX zero
//                 modeled spread).
//
// Symbols (card "Target Symbols", all present in dwx_symbol_matrix.csv):
//   EURUSD GBPUSD USDJPY USDCHF AUDUSD USDCAD NZDUSD EURJPY GBPJPY EURGBP
//   AUDJPY EURAUD EURCHF GBPAUD. No porting required (no GER40/OIL in card).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11601;
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
input int    strategy_sma_period        = 72;    // orange band: SMA macro trend bias
input int    strategy_ema_period        = 12;    // blue band: EMA dynamic entry zone
input int    strategy_adx_period        = 14;    // ADX trend-strength filter period
input double strategy_adx_threshold     = 22.0;  // min ADX for a valid trend
input bool   strategy_require_adx_rising = true;  // ADX[1] > ADX[2] confirmation
input double strategy_doji_body_frac    = 0.30;  // min body / (high-low) for a real candle
input bool   strategy_block_friday      = true;  // no NEW entries on Friday
input int    strategy_atr_period        = 14;    // ATR period for the stop floor
input double strategy_sl_atr_floor_mult = 2.0;   // floor stop = mult x ATR when band stop too tight

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate: spread guard only. Fail-open on .DWX zero spread;
// only a genuinely wide spread (> floor stop distance) blocks.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer, do not block here

   const double cap = strategy_sl_atr_floor_mult * atr_value;
   if(cap <= 0.0)
      return false;

   const double spread = ask - bid;
   if(spread > 0.0 && spread > cap)
      return true; // genuinely wide spread only

   return false;
  }

// True if the closed candle at `shift` is a "real" (non-doji) candle in the
// requested direction. bullish=true requires an up candle with a body that is
// at least doji_body_frac of the full range; bullish=false requires a down one.
bool IsDirectionalCandle(const int shift, const bool bullish)
  {
   const double o = iOpen(_Symbol,  _Period, shift); // perf-allowed: single closed-bar reads
   const double h = iHigh(_Symbol,  _Period, shift);
   const double l = iLow(_Symbol,   _Period, shift);
   const double c = iClose(_Symbol, _Period, shift);
   if(o <= 0.0 || h <= 0.0 || l <= 0.0 || c <= 0.0)
      return false;

   const double range = h - l;
   if(range <= 0.0)
      return false;

   const double body = MathAbs(c - o);
   if(body < strategy_doji_body_frac * range)
      return false; // doji / reversal candle

   if(bullish)
      return (c > o);
   return (c < o);
  }

// Both-direction entry. Caller guarantees QM_IsNewBar() == true (closed bar).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Day filter: no new entries on Friday (broker DayOfWeek).
   if(strategy_block_friday)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.day_of_week == FRIDAY)
         return false;
     }

   // ADX trend-strength filter (shared by both directions).
   const double adx1 = QM_ADX(_Symbol, _Period, strategy_adx_period, 1);
   const double adx2 = QM_ADX(_Symbol, _Period, strategy_adx_period, 2);
   if(adx1 <= 0.0)
      return false;
   if(adx1 <= strategy_adx_threshold)
      return false;
   if(strategy_require_adx_rising && !(adx1 > adx2))
      return false;

   // SMA72 orange band (macro trend STATE) at shift 1.
   const double sma_up_1  = QM_SMA(_Symbol, _Period, strategy_sma_period, 1, PRICE_HIGH);
   const double sma_lo_1  = QM_SMA(_Symbol, _Period, strategy_sma_period, 1, PRICE_LOW);
   if(sma_up_1 <= 0.0 || sma_lo_1 <= 0.0)
      return false;

   // EMA12 blue band edges at shifts 1 and 2 (entry-zone breakout).
   const double ema_up_1  = QM_EMA(_Symbol, _Period, strategy_ema_period, 1, PRICE_HIGH);
   const double ema_lo_1  = QM_EMA(_Symbol, _Period, strategy_ema_period, 1, PRICE_LOW);
   const double ema_up_2  = QM_EMA(_Symbol, _Period, strategy_ema_period, 2, PRICE_HIGH);
   const double ema_lo_2  = QM_EMA(_Symbol, _Period, strategy_ema_period, 2, PRICE_LOW);
   if(ema_up_1 <= 0.0 || ema_lo_1 <= 0.0 || ema_up_2 <= 0.0 || ema_lo_2 <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double close2 = iClose(_Symbol, _Period, 2);
   const double high1  = iHigh(_Symbol,  _Period, 1);
   const double high2  = iHigh(_Symbol,  _Period, 2);
   const double low1   = iLow(_Symbol,   _Period, 1);
   const double low2   = iLow(_Symbol,   _Period, 2);
   if(close1 <= 0.0 || close2 <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   // ---------------------------- LONG ----------------------------
   // Trend STATE: price fully above the orange band.
   // Trigger EVENT (completes on bar[1]): bar[2] state above blue band +
   // bullish candle, bar[1] above blue band + bullish candle + new high.
   const bool long_trend   = (close1 > sma_up_1);
   const bool long_state2  = (close2 > ema_up_2) && IsDirectionalCandle(2, true);
   const bool long_event1  = (close1 > ema_up_1) && IsDirectionalCandle(1, true) && (high1 > high2);
   if(long_trend && long_state2 && long_event1)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;

      // Stop: outer lower edge of the blue band at the entry bar, floored to
      // sl_atr_floor_mult x ATR if the band distance is < 1x ATR.
      double sl = ema_lo_1;
      double sl_dist = entry - sl;
      if(sl_dist < atr_value)
         sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_sl_atr_floor_mult);
      if(sl <= 0.0 || sl >= entry)
         return false;

      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = 0.0;   // no fixed TP; managed by the EMA-midline exit
      req.reason = "cobra_band_breakout_long";
      return true;
     }

   // ---------------------------- SHORT ---------------------------
   const bool short_trend  = (close1 < sma_lo_1);
   const bool short_state2 = (close2 < ema_lo_2) && IsDirectionalCandle(2, false);
   const bool short_event1 = (close1 < ema_lo_1) && IsDirectionalCandle(1, false) && (low1 < low2);
   if(short_trend && short_state2 && short_event1)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;

      // Stop: outer upper edge of the blue band at the entry bar, floored.
      double sl = ema_up_1;
      double sl_dist = sl - entry;
      if(sl_dist < atr_value)
         sl = QM_StopATRFromValue(_Symbol, QM_SELL, entry, atr_value, strategy_sl_atr_floor_mult);
      if(sl <= 0.0 || sl <= entry)
         return false;

      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = 0.0;
      req.reason = "cobra_band_breakout_short";
      return true;
     }

   return false;
  }

// No active trade management beyond the fixed stop and the discretionary
// EMA-midline exit in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Discretionary exit: price closes back through the EMA12 typical midline.
// Long closes when close[1] < ema12_typical[1]; short mirror. One closed-bar
// evaluation; direction taken from the open position.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double ema_mid_1 = QM_EMA(_Symbol, _Period, strategy_ema_period, 1, PRICE_TYPICAL);
   const double close1     = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(ema_mid_1 <= 0.0 || close1 <= 0.0)
      return false;

   // Determine the side of this EA's open position.
   bool have_long  = false;
   bool have_short = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)
         have_long = true;
      else if(ptype == POSITION_TYPE_SELL)
         have_short = true;
     }

   if(have_long && close1 < ema_mid_1)
      return true;
   if(have_short && close1 > ema_mid_1)
      return true;
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
