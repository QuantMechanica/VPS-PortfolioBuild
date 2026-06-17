#property strict
#property version   "5.0"
#property description "QM5_11236 ft-tr-bb — Freqtrade TrendRider Bollinger Bounce (long-only, H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11236 ft-tr-bb
// -----------------------------------------------------------------------------
// Source: Freqtrade community strategy `TrendRiderStrategy.py`, entry tag
//   `bb_bounce`, repo freqtrade/freqtrade-strategies, commit dbd5b0b2.
// Card: artifacts/cards_approved/QM5_11236_ft-tr-bb.md (g0_status APPROVED).
//
// Mechanics (long-only, H1, closed-bar reads at shift 1):
//   Entry (all true on the just-closed bar):
//     - close <= BB_lower(20, 2.0) * (1 + bb_touch_slack)   (lower-band touch)
//     - close > open                                        (bullish candle)
//     - RSI(16) < rsi_entry_max
//     - volume_ratio = vol[1] / EMA(20) of volume > vol_ratio_min
//     - ADX(14) > adx_min
//     - vol[1] > 0
//   The source's BTC / fear-greed cross-asset filters are neutralized for the
//   DWX single-symbol port (card: "BTC/fear-greed source filters are disabled").
//
//   Exit (source TrendRider long exits — any true closes the position):
//     - RSI(16) > rsi_exit_high
//     - EMA(9) crosses below EMA(16)  AND  MACD-hist < 0  AND  RSI(16) > 50
//     - close crosses below EMA(200) * 0.99
//     - close < EMA(200) * 0.995  AND  RSI(16) > 72  AND  MACD-hist falling
//
//   Custom time/loss exits (profit measured as fraction of entry price):
//     - held >  2h and profit < -1.5%   -> exit
//     - held >  4h and profit <  0.0%   -> exit
//     - held >  8h and profit <  0.5%   -> exit
//     - held > 16h and profit <  1.0%   -> exit
//     - held > 24h                      -> exit regardless
//
//   Stop loss: emergency protective stop = min(source -6% stop, 3*ATR(14))
//              expressed as a fixed SL price at entry (tighter of the two).
//   Trailing : after unrealized profit >= +5%, trail by 3% of price (manual
//              SL ratchet via QM_TM_MoveSL — bounded, deterministic).
//
//   Spread guard: skip only a genuinely wide spread (fail-open on .DWX zero
//                 modeled spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11236;
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
input int    strategy_bb_period          = 20;     // Bollinger period
input double strategy_bb_deviation       = 2.0;    // Bollinger deviation (MANDATORY arg)
input double strategy_bb_touch_slack     = 0.005;  // close <= lower * (1+slack)
input int    strategy_rsi_period         = 16;     // RSI lookback
input double strategy_rsi_entry_max      = 45.0;   // entry: RSI below this
input double strategy_rsi_exit_high      = 78.0;   // exit: RSI above this
input int    strategy_adx_period         = 14;     // ADX lookback
input double strategy_adx_min            = 18.0;   // entry: ADX above this
input int    strategy_vol_ema_period     = 20;     // EMA period for volume baseline
input double strategy_vol_ratio_min      = 0.7;    // entry: vol / EMA(vol) above this
input int    strategy_ema_fast_period    = 9;      // exit EMA fast
input int    strategy_ema_slow_period    = 16;     // exit EMA slow
input int    strategy_ema_trend_period   = 200;    // trend EMA for breakdown exits
input int    strategy_macd_fast          = 12;     // MACD fast
input int    strategy_macd_slow          = 26;     // MACD slow
input int    strategy_macd_signal        = 9;      // MACD signal
input int    strategy_atr_period         = 14;     // ATR period (emergency stop)
input double strategy_atr_stop_mult      = 3.0;    // emergency stop = mult * ATR
input double strategy_source_stop_pct    = 6.0;    // source fixed stop, percent
input double strategy_trail_activate_pct = 5.0;    // trailing activates at +this %
input double strategy_trail_distance_pct = 3.0;    // trailing distance, percent of price
input double strategy_spread_pct_of_stop = 15.0;   // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Volume baseline helper — EMA of tick volume over N closed bars.
// .DWX carries no exchange volume; the card maps volume to tick volume. This is
// a bespoke, bounded (N reads), new-bar-gated computation, hence perf-allowed.
// -----------------------------------------------------------------------------
double VolumeEMA(const int period)
  {
   if(period < 1)
      return 0.0;
   const double alpha = 2.0 / (period + 1.0);
   // Seed with the oldest bar in the window, then walk forward to shift 1.
   double ema = (double)iVolume(_Symbol, _Period, period); // perf-allowed: bounded closed-bar read
   for(int s = period - 1; s >= 1; --s)                    // perf-allowed: bounded (<=period) loop
     {
      const double v = (double)iVolume(_Symbol, _Period, s);
      ema = alpha * v + (1.0 - alpha) * ema;
     }
   return ema;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only. Fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to entry gate, do not block here

   const double stop_distance = strategy_atr_stop_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Long-only entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double open1  = iOpen(_Symbol, _Period, 1);  // perf-allowed: single closed-bar read
   if(close1 <= 0.0 || open1 <= 0.0)
      return false;

   // --- Bollinger lower-band touch (deviation arg is MANDATORY) ---
   const double bb_lower = QM_BB_Lower(_Symbol, _Period, strategy_bb_period,
                                       strategy_bb_deviation, 1);
   if(bb_lower <= 0.0)
      return false;
   if(!(close1 <= bb_lower * (1.0 + strategy_bb_touch_slack)))
      return false;

   // --- Bullish candle ---
   if(!(close1 > open1))
      return false;

   // --- RSI filter ---
   const double rsi1 = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   if(rsi1 <= 0.0)
      return false;
   if(!(rsi1 < strategy_rsi_entry_max))
      return false;

   // --- ADX filter ---
   const double adx1 = QM_ADX(_Symbol, _Period, strategy_adx_period, 1);
   if(adx1 <= 0.0)
      return false;
   if(!(adx1 > strategy_adx_min))
      return false;

   // --- Volume filter: vol[1] > 0 and vol[1] / EMA(vol) > ratio_min ---
   const double vol1 = (double)iVolume(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(vol1 <= 0.0)
      return false;
   const double vol_ema = VolumeEMA(strategy_vol_ema_period);
   if(vol_ema <= 0.0)
      return false;
   if(!((vol1 / vol_ema) > strategy_vol_ratio_min))
      return false;

   // --- Build the long entry. Framework sizes lots (no lots field). ---
   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   // Emergency protective stop = tighter of (source -X% stop) and (mult*ATR stop).
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;
   const double sl_pct_price = entry * (1.0 - strategy_source_stop_pct / 100.0);
   const double sl_atr_price = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_atr_stop_mult);
   if(sl_atr_price <= 0.0)
      return false;
   // Long stop is below entry; the tighter (closer) stop is the HIGHER price.
   double sl = MathMax(sl_pct_price, sl_atr_price);
   sl = QM_TM_NormalizePrice(_Symbol, sl);
   if(sl <= 0.0 || sl >= entry)
      return false;

   req.type   = QM_BUY;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = 0.0;   // no fixed TP; exits handled by Strategy_ExitSignal / time stops
   req.reason = "ft_tr_bb_long";
   return true;
  }

// Trailing stop: once unrealized profit >= activate%, ratchet the SL up to
// trail_distance% below the current bid. Bounded, deterministic, never loosens.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY)
         continue;

      const double entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry_price <= 0.0 || bid <= 0.0)
         continue;

      const double profit_pct = (bid - entry_price) / entry_price * 100.0;
      if(profit_pct < strategy_trail_activate_pct)
         continue;

      const double new_sl = QM_TM_NormalizePrice(_Symbol,
                              bid * (1.0 - strategy_trail_distance_pct / 100.0));
      const double cur_sl = PositionGetDouble(POSITION_SL);
      // Only ratchet up (never loosen) and keep the stop below the current bid.
      if(new_sl > cur_sl && new_sl < bid)
         QM_TM_MoveSL(ticket, new_sl, "trail_3pct");
     }
  }

// Source TrendRider long exits + custom time/loss exits. Any true -> close.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Closed-bar indicator reads.
   const double rsi1 = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   const double rsi2 = QM_RSI(_Symbol, _Period, strategy_rsi_period, 2);

   const double ema_fast1 = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_slow1 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   const double ema_fast2 = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 2);
   const double ema_slow2 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 2);

   const double ema200_1  = QM_EMA(_Symbol, _Period, strategy_ema_trend_period, 1);
   const double ema200_2  = QM_EMA(_Symbol, _Period, strategy_ema_trend_period, 2);

   const double macd_main1 = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                          strategy_macd_slow, strategy_macd_signal, 1);
   const double macd_sig1  = QM_MACD_Signal(_Symbol, _Period, strategy_macd_fast,
                                            strategy_macd_slow, strategy_macd_signal, 1);
   const double macd_main2 = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                          strategy_macd_slow, strategy_macd_signal, 2);
   const double macd_sig2  = QM_MACD_Signal(_Symbol, _Period, strategy_macd_fast,
                                            strategy_macd_slow, strategy_macd_signal, 2);
   const double macd_hist1 = macd_main1 - macd_sig1;
   const double macd_hist2 = macd_main2 - macd_sig2;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read

   // Exit 1: RSI overbought.
   if(rsi1 > 0.0 && rsi1 > strategy_rsi_exit_high)
      return true;

   // Exit 2: EMA(fast) crosses below EMA(slow) AND MACD-hist<0 AND RSI>50.
   if(ema_fast1 > 0.0 && ema_slow1 > 0.0 && ema_fast2 > 0.0 && ema_slow2 > 0.0)
     {
      const bool ema_cross_down = (ema_fast2 >= ema_slow2 && ema_fast1 < ema_slow1);
      if(ema_cross_down && macd_hist1 < 0.0 && rsi1 > 50.0)
         return true;
     }

   // Exit 3: close crosses below EMA(200)*0.99 (state flip across bars).
   if(ema200_1 > 0.0 && ema200_2 > 0.0 && close1 > 0.0 && close2 > 0.0)
     {
      const bool was_above = (close2 >= ema200_2 * 0.99);
      const bool now_below = (close1 <  ema200_1 * 0.99);
      if(was_above && now_below)
         return true;
     }

   // Exit 4: close < EMA(200)*0.995 AND RSI>72 AND MACD-hist falling.
   if(ema200_1 > 0.0 && close1 > 0.0)
     {
      const bool below_trend  = (close1 < ema200_1 * 0.995);
      const bool macd_falling = (macd_hist1 < macd_hist2);
      if(below_trend && rsi1 > 72.0 && macd_falling)
         return true;
     }

   // --- Custom time/loss exits. Profit as fraction of entry price. ---
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      const double entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(opened <= 0 || entry_price <= 0.0 || bid <= 0.0)
         continue;

      const double held_hours = (double)(TimeCurrent() - opened) / 3600.0;
      const double profit_pct = (bid - entry_price) / entry_price * 100.0;

      if(held_hours > 24.0)
         return true;
      if(held_hours > 16.0 && profit_pct < 1.0)
         return true;
      if(held_hours >  8.0 && profit_pct < 0.5)
         return true;
      if(held_hours >  4.0 && profit_pct < 0.0)
         return true;
      if(held_hours >  2.0 && profit_pct < -1.5)
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
