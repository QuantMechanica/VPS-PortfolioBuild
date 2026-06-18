#property strict
#property version   "5.0"
#property description "QM5_11836 robo-psar-macd1269-h4 — PSAR trend state + MACD(12,26,9) cross trigger (H4)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11836 robo-psar-macd1269-h4
// -----------------------------------------------------------------------------
// Source: RoboForex Educational Team, "Forex Strategy Collection" (~2015),
//         page 100, strategy "PSAR + MACD".
// Card: artifacts/cards_approved/QM5_11836_robo-psar-macd1269-h4.md (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1; H4):
//   Trend STATE  : PSAR(0.02,0.2) position vs price.
//                  Long  state -> PSAR below the last close (PSAR bullish).
//                  Short state -> PSAR above the last close (PSAR bearish).
//   Trigger EVENT: MACD(12,26,9) main line crosses the signal line — ONE fresh
//                  cross event per bar (main[2] vs signal[2] -> main[1] vs signal[1]).
//                  Long  -> main crosses ABOVE signal.
//                  Short -> main crosses BELOW signal.
//   Two-cross trap avoided: PSAR is a continuous STATE (not a flip event), the
//   MACD cross is the single EVENT. They never need to coincide on one bar.
//   Stop         : entry -/+ sl_atr_mult * ATR(atr_period)   (card: 2 x ATR(14)).
//   Take profit  : entry +/- tp_atr_mult * ATR(atr_period)   (card: 4 x ATR(14)).
//   Trade mgmt   : optional PSAR trail of the stop (card: "trail using PSAR").
//   Spread guard : skip only a genuinely wide spread (fail-open on .DWX zero
//                  modeled spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact. One position per magic.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11836;
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
input double strategy_psar_step         = 0.02;   // PSAR acceleration step
input double strategy_psar_max          = 0.20;   // PSAR acceleration maximum
input int    strategy_macd_fast         = 12;     // MACD fast EMA
input int    strategy_macd_slow         = 26;     // MACD slow EMA
input int    strategy_macd_signal       = 9;      // MACD signal SMA
input int    strategy_atr_period        = 14;     // ATR period (stop / target)
input double strategy_sl_atr_mult       = 2.0;    // stop distance = mult * ATR
input double strategy_tp_atr_mult       = 4.0;    // target distance = mult * ATR
input bool   strategy_trail_psar        = true;   // trail the stop to PSAR each closed bar
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — regime/signal work is on the
// closed-bar path in Strategy_EntrySignal. Fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate, do not block here

   const double stop_distance = strategy_sl_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// PSAR trend STATE + MACD cross EVENT entry. Caller guarantees QM_IsNewBar().
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   // --- Trend STATE: PSAR position vs the last close (closed bar) ---
   const double psar1 = QM_SAR(_Symbol, _Period, strategy_psar_step, strategy_psar_max, 1);
   if(psar1 <= 0.0)
      return false;
   const bool psar_bullish = (psar1 < close1); // PSAR below price -> uptrend state
   const bool psar_bearish = (psar1 > close1); // PSAR above price -> downtrend state

   // --- Trigger EVENT: MACD main/signal cross (one fresh event per bar) ---
   const double macd_main_1 = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                           strategy_macd_slow, strategy_macd_signal, 1);
   const double macd_sig_1  = QM_MACD_Signal(_Symbol, _Period, strategy_macd_fast,
                                             strategy_macd_slow, strategy_macd_signal, 1);
   const double macd_main_2 = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                           strategy_macd_slow, strategy_macd_signal, 2);
   const double macd_sig_2  = QM_MACD_Signal(_Symbol, _Period, strategy_macd_fast,
                                             strategy_macd_slow, strategy_macd_signal, 2);

   const bool macd_cross_up   = (macd_main_2 <= macd_sig_2 && macd_main_1 >  macd_sig_1);
   const bool macd_cross_down = (macd_main_2 >= macd_sig_2 && macd_main_1 <  macd_sig_1);

   QM_OrderType dir;
   if(psar_bullish && macd_cross_up)
      dir = QM_BUY;
   else if(psar_bearish && macd_cross_down)
      dir = QM_SELL;
   else
      return false;

   // --- Stop / target from ATR (same ATR value for both) ---
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double entry = (dir == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, dir, entry, atr_value, strategy_sl_atr_mult);
   const double tp = QM_TakeATRFromValue(_Symbol, dir, entry, atr_value, strategy_tp_atr_mult);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type   = dir;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = (dir == QM_BUY) ? "psar_macd_long" : "psar_macd_short";
   return true;
  }

// Trail the stop toward the PSAR value, once per closed bar. Only tightens the
// stop in the trade's favour — never loosens it (QM_TM_MoveSL guards direction).
void Strategy_ManageOpenPosition()
  {
   if(!strategy_trail_psar)
      return;

   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return;

   const double psar1 = QM_SAR(_Symbol, _Period, strategy_psar_step, strategy_psar_max, 1);
   if(psar1 <= 0.0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const long pos_type = PositionGetInteger(POSITION_TYPE);
      const double cur_sl = PositionGetDouble(POSITION_SL);
      const double new_sl = QM_TM_NormalizePrice(_Symbol, psar1);

      if(pos_type == POSITION_TYPE_BUY)
        {
         // Long: trail up only — new PSAR stop above the old stop.
         if(cur_sl <= 0.0 || new_sl > cur_sl)
            QM_TM_MoveSL(ticket, new_sl, "psar_trail");
        }
      else if(pos_type == POSITION_TYPE_SELL)
        {
         // Short: trail down only — new stop below the old stop.
         if(cur_sl <= 0.0 || new_sl < cur_sl)
            QM_TM_MoveSL(ticket, new_sl, "psar_trail");
        }
     }
  }

// Defensive exit: PSAR flips against the open position (trend state reversed).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;
   const double psar1 = QM_SAR(_Symbol, _Period, strategy_psar_step, strategy_psar_max, 1);
   if(psar1 <= 0.0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const long pos_type = PositionGetInteger(POSITION_TYPE);
      // Long exits when PSAR flips above price; short exits when PSAR flips below.
      if(pos_type == POSITION_TYPE_BUY && psar1 > close1)
         return true;
      if(pos_type == POSITION_TYPE_SELL && psar1 < close1)
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
