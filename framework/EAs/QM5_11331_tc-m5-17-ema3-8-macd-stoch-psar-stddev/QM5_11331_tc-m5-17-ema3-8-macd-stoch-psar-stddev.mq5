#property strict
#property version   "5.0"
#property description "QM5_11331 tc-m5-17 — EMA3/8 + MACD + Stoch + PSAR + StdDev confluence (M5)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11331 tc-m5-17-ema3-8-macd-stoch-psar-stddev
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)",
//   5 Min Trading System #17.
// Card: artifacts/cards_approved/QM5_11331_tc-m5-17-ema3-8-macd-stoch-psar-stddev.md
//   (g0_status APPROVED, source_id e78a9f1f-4e6a-563c-a080-915133d6ed28).
//
// Five-condition confluence on M5. To avoid the .DWX two-cross-same-bar
// zero-trade trap (INVARIANT #4), exactly ONE condition is a fresh EVENT; the
// rest are STATES read on the last closed bar (shift 1 / shift 2):
//
//   Trigger EVENT : Stochastic K crosses D  (long: K crosses above D;
//                   short: K crosses below D)  — one event per bar.
//   STATE (trend) : EMA(3) vs EMA(8) direction. Long: EMA3 > EMA8.
//   STATE (PSAR)  : PSAR side. Long: SAR below price (sar < close).
//   STATE (MACD)  : MACD main sign. Long: macd_main > 0. MACD CAN be negative
//                   for a short — sign, not a cross (INVARIANT note in card).
//   STATE (vol)   : StdDev(20) >= medium threshold (per-symbol; flat markets
//                   below the threshold are skipped).
//
//   Stop          : ATR(14)*1.5 for P2, per the card's Stop Loss section.
//   Exit          : EMA(3) crosses back through EMA(8) against the position
//                   (long closes when EMA3 < EMA8). No fixed TP — exit is the
//                   EMA-reverse per the card.
//   Spread guard  : skip only a genuinely WIDE spread (fail-open on .DWX zero
//                   modeled spread — INVARIANT #1).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11331;
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
input int    strategy_ema_fast_period   = 3;       // fast EMA (direction state)
input int    strategy_ema_slow_period   = 8;       // slow EMA (direction state)
input int    strategy_macd_fast         = 12;      // MACD fast EMA
input int    strategy_macd_slow         = 26;      // MACD slow EMA
input int    strategy_macd_signal       = 9;       // MACD signal EMA
input int    strategy_stoch_k           = 10;      // Stochastic %K period (card 10,15,15)
input int    strategy_stoch_d           = 15;      // Stochastic %D period
input int    strategy_stoch_slow        = 15;      // Stochastic slowing
input double strategy_psar_step         = 0.02;    // Parabolic SAR step
input double strategy_psar_max          = 0.20;    // Parabolic SAR maximum
input int    strategy_stddev_period     = 20;      // StdDev period (volatility filter)
input double strategy_stddev_medium_min = 0.010;   // min StdDev for "medium" regime
                                                   // EURUSD/GBPUSD majors: 0.010
                                                   // USDJPY: override to 0.10 in setfile
                                                   // AUD/NZD: override to 0.0005
input int    strategy_atr_period        = 14;      // ATR period (fallback stop)
input double strategy_atr_sl_mult       = 1.5;     // P2 stop = mult * ATR (card P2)
input int    strategy_spread_cap_pips   = 12;      // card spread cap

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block

   const double spread = ask - bid;
   const double spread_cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_spread_cap_pips);
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread_cap > 0.0 && spread > spread_cap)
      return true;

   return false;
  }

// Confluence entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type               = QM_BUY;
   req.price              = 0.0;
   req.sl                 = 0.0;
   req.tp                 = 0.0;
   req.reason             = "";
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Closed-bar reads (shift 1 = last closed bar; shift 2 = prior) ---
   const double ema_fast = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_slow = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   if(ema_fast <= 0.0 || ema_slow <= 0.0)
      return false;

   const double high1 = iHigh(_Symbol, _Period, 1); // perf-allowed: fixed closed-bar PSAR side read
   const double low1  = iLow(_Symbol, _Period, 1);  // perf-allowed: fixed closed-bar PSAR side read
   if(high1 <= 0.0 || low1 <= 0.0)
      return false;

   const double sar1 = QM_SAR(_Symbol, _Period, strategy_psar_step, strategy_psar_max, 1);
   if(sar1 <= 0.0)
      return false;

   const double macd_main = QM_MACD_Main(_Symbol, _Period,
                                         strategy_macd_fast, strategy_macd_slow,
                                         strategy_macd_signal, 1);

   const double stddev = QM_StdDev(_Symbol, _Period, strategy_stddev_period, 1);
   if(stddev < strategy_stddev_medium_min) // STATE: only medium/strong volatility
      return false;

   // --- Trigger EVENT: Stochastic K crosses D (one event per bar) ---
   const double k_now  = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 1);
   const double d_now  = QM_Stoch_D(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 1);
   const double k_prev = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 2);
   const double d_prev = QM_Stoch_D(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 2);
   if(k_now <= 0.0 || d_now <= 0.0 || k_prev <= 0.0 || d_prev <= 0.0)
      return false;

   const bool stoch_cross_up   = (k_prev <= d_prev && k_now >  d_now);
   const bool stoch_cross_down = (k_prev >= d_prev && k_now <  d_now);

   // --- LONG: trend up STATE + PSAR below candle STATE + MACD>0 STATE + stoch cross up EVENT ---
   const bool long_states = (ema_fast > ema_slow) && (sar1 < low1) && (macd_main > 0.0);
   // --- SHORT: trend down STATE + PSAR above candle STATE + MACD<0 STATE + stoch cross down EVENT ---
   const bool short_states = (ema_fast < ema_slow) && (sar1 > high1) && (macd_main < 0.0);

   QM_OrderType side;
   if(long_states && stoch_cross_up)
      side = QM_BUY;
   else if(short_states && stoch_cross_down)
      side = QM_SELL;
   else
      return false;

   // --- Entry price ---
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   // --- Stop: P2 uses ATR(14) x 1.5 per the card's Stop Loss section. ---
   double sl = QM_StopATR(_Symbol, side, entry, strategy_atr_period, strategy_atr_sl_mult);
   if(sl <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = 0.0;   // no fixed TP — exit is the EMA-reverse (Strategy_ExitSignal)
   req.reason = (side == QM_BUY) ? "tc_m5_17_long" : "tc_m5_17_short";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// No active trade management beyond the fixed structure/ATR stop.
void Strategy_ManageOpenPosition()
  {
  }

// Exit: EMA(3) crosses back through EMA(8) against the open position.
//   Long  closes when EMA3 < EMA8.
//   Short closes when EMA3 > EMA8.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double ema_fast = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_slow = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   if(ema_fast <= 0.0 || ema_slow <= 0.0)
      return false;

   // Determine the direction of the open position for this magic.
   bool have_long = false, have_short = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)  have_long = true;
      if(ptype == POSITION_TYPE_SELL) have_short = true;
     }

   if(have_long && ema_fast < ema_slow)
      return true;
   if(have_short && ema_fast > ema_slow)
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
