#property strict
#property version   "5.0"
#property description "QM5_11676 tc-h1-s12-ema3-5-34-89-rsi3-stoch-adx — 7-indicator confluence (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11676 tc-h1-s12-ema3-5-34-89-rsi3-stoch-adx
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "Forex Trading Strategy #12", in 20 Forex Trading
//   Strategies Collection (H1), 2014.
// Card: artifacts/cards_approved/QM5_11676_tc-h1-s12-ema3-5-34-89-rsi3-stoch-adx.md
//   (g0_status: APPROVED).
//
// Mechanics (closed-bar reads at shift 1; STATES + ONE trigger EVENT):
//   Trigger EVENT (long) : EMA(3,Close) crosses ABOVE EMA(5,Open). One event/bar.
//   Trigger EVENT (short): EMA(3,Close) crosses BELOW EMA(5,Open).
//   Confirming STATES (all must hold on the trigger bar, no second EVENT):
//     1. Macro fan   : EMA(34,Close) > EMA(89,Close)  (long) / < (short).
//     2. ADX trend   : ADX(14) > adx_threshold AND +DI > -DI (long) / -DI > +DI.
//     3. RSI(3) surge: RSI(3) > rsi_long_level (long) / < rsi_short_level (short).
//     4. Stochastic  : %K > %D (long) / %K < %D (short)  — alignment STATE.
//   Stop  : 2 x ATR(14) from entry.
//   Take  : 2:1 reward-to-risk vs the stop distance.
//   Exit  : managed purely by SL/TP (no discretionary exit).
//
// Two-cross trap avoidance: the EMA3/EMA5 cross is the ONLY fresh EVENT. The
// Stochastic %K/%D relationship and every other confluence term are read as
// CURRENT STATES on the closed bar, never as a second same-bar cross.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11676;
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
input int    strategy_ema_close_fast     = 3;      // EMA(3) on Close — trigger leg
input int    strategy_ema_open_fast      = 5;      // EMA(5) on Open  — trigger leg
input int    strategy_ema_macro_fast     = 34;     // EMA(34) Close — macro fan fast
input int    strategy_ema_macro_slow     = 89;     // EMA(89) Close — macro fan slow
input int    strategy_rsi_period         = 3;      // ultra-fast RSI(3)
input double strategy_rsi_long_level     = 80.0;   // RSI(3) > this confirms a long
input double strategy_rsi_short_level    = 20.0;   // RSI(3) < this confirms a short
input int    strategy_stoch_k            = 5;      // Stochastic %K period
input int    strategy_stoch_d            = 3;      // Stochastic %D period
input int    strategy_stoch_slow         = 3;      // Stochastic slowing
input int    strategy_adx_period         = 14;     // ADX period
input double strategy_adx_threshold      = 20.0;   // ADX(14) > this = trend strong enough
input int    strategy_atr_period         = 14;     // ATR period for stop/target
input double strategy_sl_atr_mult        = 2.0;    // stop distance = mult * ATR
input double strategy_tp_rr              = 2.0;    // take profit = RR * stop distance
input double strategy_spread_pct_of_stop = 15.0;   // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — confluence work is on the
// closed-bar path in Strategy_EntrySignal. Fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to entry gate, do not block here

   const double stop_distance = strategy_sl_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Confluence entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Trigger EVENT: EMA(3,Close) cross vs EMA(5,Open) (one event/bar) ---
   const double ema_c_now  = QM_EMA(_Symbol, _Period, strategy_ema_close_fast, 1, PRICE_CLOSE);
   const double ema_c_prev = QM_EMA(_Symbol, _Period, strategy_ema_close_fast, 2, PRICE_CLOSE);
   const double ema_o_now  = QM_EMA(_Symbol, _Period, strategy_ema_open_fast,  1, PRICE_OPEN);
   const double ema_o_prev = QM_EMA(_Symbol, _Period, strategy_ema_open_fast,  2, PRICE_OPEN);
   if(ema_c_now <= 0.0 || ema_c_prev <= 0.0 || ema_o_now <= 0.0 || ema_o_prev <= 0.0)
      return false;

   const bool cross_up   = (ema_c_prev <= ema_o_prev && ema_c_now >  ema_o_now);
   const bool cross_down = (ema_c_prev >= ema_o_prev && ema_c_now <  ema_o_now);
   if(!cross_up && !cross_down)
      return false; // no fresh trigger this bar

   // --- Confirming STATE: macro EMA(34/89) fan ---
   const double ema_macro_fast = QM_EMA(_Symbol, _Period, strategy_ema_macro_fast, 1, PRICE_CLOSE);
   const double ema_macro_slow = QM_EMA(_Symbol, _Period, strategy_ema_macro_slow, 1, PRICE_CLOSE);
   if(ema_macro_fast <= 0.0 || ema_macro_slow <= 0.0)
      return false;

   // --- Confirming STATE: ADX trend strength + DI alignment ---
   const double adx     = QM_ADX(_Symbol, _Period, strategy_adx_period, 1);
   const double plus_di = QM_ADX_PlusDI(_Symbol, _Period, strategy_adx_period, 1);
   const double minus_di = QM_ADX_MinusDI(_Symbol, _Period, strategy_adx_period, 1);
   if(adx <= 0.0)
      return false;
   if(adx <= strategy_adx_threshold)
      return false;

   // --- Confirming STATE: RSI(3) momentum surge ---
   const double rsi = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1, PRICE_CLOSE);
   if(rsi <= 0.0)
      return false;

   // --- Confirming STATE: Stochastic %K vs %D alignment (NOT a second cross) ---
   const double stoch_k = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 1);
   const double stoch_d = QM_Stoch_D(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 1);

   QM_OrderType side;
   if(cross_up)
     {
      // LONG: every confirming state must align bullish.
      if(!(ema_macro_fast > ema_macro_slow))   return false; // macro fan up
      if(!(plus_di > minus_di))                return false; // +DI dominant
      if(!(rsi > strategy_rsi_long_level))     return false; // RSI(3) surge up
      if(!(stoch_k > stoch_d))                 return false; // stoch aligned up
      side = QM_BUY;
     }
   else
     {
      // SHORT: mirror of the long confluence.
      if(!(ema_macro_fast < ema_macro_slow))   return false; // macro fan down
      if(!(minus_di > plus_di))                return false; // -DI dominant
      if(!(rsi < strategy_rsi_short_level))    return false; // RSI(3) surge down
      if(!(stoch_k < stoch_d))                 return false; // stoch aligned down
      side = QM_SELL;
     }

   // --- Build the entry. Framework sizes lots (no lots field). ---
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, side, entry, atr_value, strategy_sl_atr_mult);
   if(sl <= 0.0)
      return false;
   const double tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_tp_rr);
   if(tp <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = (side == QM_BUY) ? "tc_s12_confluence_long" : "tc_s12_confluence_short";
   return true;
  }

// No active trade management — fixed ATR stop / RR target only.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit — exits are handled by SL/TP.
bool Strategy_ExitSignal()
  {
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
