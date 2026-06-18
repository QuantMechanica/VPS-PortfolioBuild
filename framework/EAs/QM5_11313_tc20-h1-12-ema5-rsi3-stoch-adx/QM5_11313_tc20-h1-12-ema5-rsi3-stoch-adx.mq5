#property strict
#property version   "5.0"
#property description "QM5_11313 tc20-h1-12 — EMA34/89 trend + RSI3 burst + Stoch + ADX DI + EMA3/5 trigger (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11313 tc20-h1-12-ema5-rsi3-stoch-adx
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Forex Trading Strategies (1 Hour Time Frame)",
//         Strategy #12. Card: artifacts/cards_approved/QM5_11313_...md (APPROVED).
//
// Five-condition confluence (H1, closed-bar reads at shift 1). To avoid the
// two-cross-same-bar zero-trade trap, exactly ONE condition is a fresh EVENT;
// the rest are STATES evaluated on the same closed (signal) bar:
//
//   Trigger EVENT : EMA(3,close) crosses EMA(5,open)  (micro trigger, card #5).
//   Macro  STATE  : EMA(34,close) vs EMA(89,close)    (trend gate, card #1).
//   RSI3   STATE  : RSI(3) in burst zone — at/above 80 (long) or at/below 20
//                   (short) on the signal bar OR within rsi_burst_lookback
//                   bars before it (the card's "RSI crosses 80" momentum
//                   burst, expressed as a recent-state to avoid double-cross).
//   Stoch  STATE  : Stoch(5,3,3) %K vs %D direction confirm (card #3).
//   ADX    STATE  : ADX(14) +DI vs -DI directional filter (card #4).
//
//   Stop  : LONG  = min(EMA34[1], LowestLow(5)) - sl_buffer_pips, floored to
//                   sl_min_pips, capped to atr_cap_mult * ATR(14).
//           SHORT = mirror with HighestHigh(5).
//   Take  : double the SL distance (RR = 2.0, card "TP double SL").
//   Exit  : reverse EMA3/5 cross -> close manually.
//   Spread: skip only a genuinely wide spread (fail-open on .DWX zero spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11313;
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
input int    strategy_ema_macro_fast    = 34;     // macro trend fast EMA (close)
input int    strategy_ema_macro_slow    = 89;     // macro trend slow EMA (close)
input int    strategy_ema_trig_fast     = 3;      // micro trigger fast EMA (close)
input int    strategy_ema_trig_slow     = 5;      // micro trigger slow EMA (open)
input int    strategy_rsi_period        = 3;      // RSI burst period
input double strategy_rsi_burst_hi      = 80.0;   // long burst level (RSI >= this)
input double strategy_rsi_burst_lo      = 20.0;   // short burst level (RSI <= this)
input int    strategy_rsi_burst_lookback = 3;     // bars back the burst state may have occurred
input int    strategy_stoch_k           = 5;      // Stochastic %K period
input int    strategy_stoch_d           = 3;      // Stochastic %D period
input int    strategy_stoch_slow        = 3;      // Stochastic slowing
input int    strategy_adx_period        = 14;     // ADX / DI period
input int    strategy_struct_lookback   = 5;      // bars for LowestLow/HighestHigh stop
input double strategy_sl_buffer_pips    = 2.0;    // buffer beyond structure
input double strategy_sl_min_pips       = 20.0;   // minimum SL distance (pips)
input int    strategy_atr_period        = 14;     // ATR period for SL cap
input double strategy_atr_cap_mult      = 1.5;    // SL capped at mult * ATR
input double strategy_tp_rr             = 2.0;    // TP = rr * SL distance
input double strategy_spread_pct_of_stop = 25.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick spread guard. Fail-OPEN on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote — never block on a zero price

   // Reference stop distance: the minimum SL (pips -> price), so the cap scales.
   const double stop_distance = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_sl_min_pips);
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Returns true if EMA(3,close) crossed EMA(5,open) in `dir` on the signal bar.
// dir = +1 bullish (3 crosses above 5), -1 bearish (3 crosses below 5).
bool EMA35_CrossedThisBar(const int dir)
  {
   const double f_now  = QM_EMA(_Symbol, _Period, strategy_ema_trig_fast, 1, PRICE_CLOSE);
   const double f_prev = QM_EMA(_Symbol, _Period, strategy_ema_trig_fast, 2, PRICE_CLOSE);
   const double s_now  = QM_EMA(_Symbol, _Period, strategy_ema_trig_slow, 1, PRICE_OPEN);
   const double s_prev = QM_EMA(_Symbol, _Period, strategy_ema_trig_slow, 2, PRICE_OPEN);
   if(f_now <= 0.0 || f_prev <= 0.0 || s_now <= 0.0 || s_prev <= 0.0)
      return false;

   if(dir > 0)
      return (f_prev <= s_prev && f_now > s_now);
   return (f_prev >= s_prev && f_now < s_now);
  }

// RSI(3) burst STATE: was RSI in the burst zone on the signal bar OR within the
// preceding lookback window? dir=+1 -> RSI >= hi; dir=-1 -> RSI <= lo.
bool RSI3_BurstState(const int dir)
  {
   const int last_shift = 1 + strategy_rsi_burst_lookback; // shifts 1..1+lookback
   for(int s = 1; s <= last_shift; ++s)
     {
      const double r = QM_RSI(_Symbol, _Period, strategy_rsi_period, s, PRICE_CLOSE);
      if(r <= 0.0)
         continue;
      if(dir > 0 && r >= strategy_rsi_burst_hi)
         return true;
      if(dir < 0 && r <= strategy_rsi_burst_lo)
         return true;
     }
   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Shared STATES ---
   const double ema_macro_fast = QM_EMA(_Symbol, _Period, strategy_ema_macro_fast, 1, PRICE_CLOSE);
   const double ema_macro_slow = QM_EMA(_Symbol, _Period, strategy_ema_macro_slow, 1, PRICE_CLOSE);
   if(ema_macro_fast <= 0.0 || ema_macro_slow <= 0.0)
      return false;

   const double stoch_k = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 1);
   const double stoch_d = QM_Stoch_D(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 1);
   if(stoch_k < 0.0 || stoch_d < 0.0)
      return false;

   const double plus_di  = QM_ADX_PlusDI(_Symbol, _Period, strategy_adx_period, 1);
   const double minus_di = QM_ADX_MinusDI(_Symbol, _Period, strategy_adx_period, 1);
   if(plus_di < 0.0 || minus_di < 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   int dir = 0;

   // --- LONG: macro up, RSI burst >=80 state, Stoch K>D, +DI>-DI, EMA3/5 cross up ---
   if(ema_macro_fast > ema_macro_slow &&
      stoch_k > stoch_d &&
      plus_di > minus_di &&
      RSI3_BurstState(+1) &&
      EMA35_CrossedThisBar(+1))
      dir = +1;
   // --- SHORT (mirror) ---
   else if(ema_macro_fast < ema_macro_slow &&
           stoch_k < stoch_d &&
           minus_di > plus_di &&
           RSI3_BurstState(-1) &&
           EMA35_CrossedThisBar(-1))
      dir = -1;

   if(dir == 0)
      return false;

   // --- Structure stop: LONG = min(EMA34, LowestLow(N)); SHORT = max(EMA34, HighestHigh(N)) ---
   const double buffer_dist = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_sl_buffer_pips);
   const double min_dist    = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_sl_min_pips);
   const double cap_dist    = strategy_atr_cap_mult * atr_value;

   const double entry = (dir > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                  : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   double sl_price = 0.0;
   if(dir > 0)
     {
      double lowest = iLow(_Symbol, _Period, 1); // perf-allowed: closed-bar structure scan
      for(int s = 2; s <= strategy_struct_lookback; ++s)
        {
         const double lo = iLow(_Symbol, _Period, s);
         if(lo > 0.0 && lo < lowest)
            lowest = lo;
        }
      double anchor = MathMin(ema_macro_fast, lowest);
      sl_price = anchor - buffer_dist;
      double sl_dist = entry - sl_price;
      if(sl_dist < min_dist) sl_dist = min_dist;     // floor
      if(sl_dist > cap_dist && cap_dist > 0.0) sl_dist = cap_dist; // ATR cap
      sl_price = entry - sl_dist;
      req.type = QM_BUY;
      req.tp   = QM_TakeRR(_Symbol, QM_BUY, entry, sl_price, strategy_tp_rr);
     }
   else
     {
      double highest = iHigh(_Symbol, _Period, 1); // perf-allowed: closed-bar structure scan
      for(int s = 2; s <= strategy_struct_lookback; ++s)
        {
         const double hi = iHigh(_Symbol, _Period, s);
         if(hi > highest)
            highest = hi;
        }
      double anchor = MathMax(ema_macro_fast, highest);
      sl_price = anchor + buffer_dist;
      double sl_dist = sl_price - entry;
      if(sl_dist < min_dist) sl_dist = min_dist;     // floor
      if(sl_dist > cap_dist && cap_dist > 0.0) sl_dist = cap_dist; // ATR cap
      sl_price = entry + sl_dist;
      req.type = QM_SELL;
      req.tp   = QM_TakeRR(_Symbol, QM_SELL, entry, sl_price, strategy_tp_rr);
     }

   sl_price = QM_StopRulesNormalizePrice(_Symbol, sl_price);
   if(sl_price <= 0.0 || req.tp <= 0.0)
      return false;

   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl_price;
   req.reason = (dir > 0) ? "tc20_12_long" : "tc20_12_short";
   return true;
  }

// Fixed structural stop + RR target; no active trail.
void Strategy_ManageOpenPosition()
  {
  }

// Defensive exit: reverse EMA3/5 cross against the open position's direction.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Determine open direction from the position record.
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY  && EMA35_CrossedThisBar(-1)) return true;
      if(ptype == POSITION_TYPE_SELL && EMA35_CrossedThisBar(+1)) return true;
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
