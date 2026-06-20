#property strict
#property version   "5.0"
#property description "QM5_11522 carter-t-ema4-10-adx28-macd5104-h4 — EMA(4/10) cross + ADX(28) + MACD(5,10,4) triple (H4)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11522 carter-t-ema4-10-adx28-macd5104-h4
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "Forex Trend Following Strategies: 20 Trend Following
//         Systems", System #20, self-published 2014.
// Card: artifacts/cards_approved/QM5_11522_carter-t-ema4-10-adx28-macd5104-h4.md
//       (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1; H4):
//   Trigger EVENT : EMA(4) crosses EMA(10). To avoid the two-cross zero-trade
//                   trap, the cross is the SOLE event; it may have occurred
//                   within the last `cross_lookback` closed bars (card: "crossed
//                   up within last 3 bars"). ADX/MACD are confirming STATES.
//   ADX STATE     : +DI > -DI (long) / -DI > +DI (short), ADX(28). Optional
//                   strength floor `adx_min` (0 = no floor, the card baseline).
//   MACD STATE    : MACD(5,10,4) main > 0 (long) / < 0 (short).
//   Stop          : entry -/+ sl_pips (scale-correct pip->price distance).
//   Take profit   : entry +/- tp_pips (source-specified; EURUSD H4 = 70 pips).
//   Spread guard  : block only a genuinely wide spread (> spread_cap_pips);
//                   fail-open on .DWX zero modeled spread.
//   No Friday entry (card filter) in addition to the framework Friday-close.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11522;
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
input int    strategy_ema_fast_period   = 4;      // fast EMA (cross trigger)
input int    strategy_ema_slow_period   = 10;     // slow EMA (cross trigger)
input int    strategy_cross_lookback    = 3;      // EMA cross within last N closed bars (card: 3)
input int    strategy_adx_period        = 28;     // ADX/DI period (longer-than-standard)
input double strategy_adx_min           = 0.0;    // ADX strength floor (0 = no floor; card baseline)
input int    strategy_macd_fast         = 5;      // MACD fast EMA (non-standard)
input int    strategy_macd_slow         = 10;     // MACD slow EMA
input int    strategy_macd_signal       = 4;      // MACD signal period
input double strategy_sl_pips           = 35.0;   // stop distance (pips); QM P2 = 35
input double strategy_tp_pips           = 70.0;   // target distance (pips); EURUSD H4 source = 70
input double strategy_spread_cap_pips   = 15.0;   // block only a wider-than-this spread
input bool   strategy_no_friday_entry   = true;   // card filter: no Friday entry

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only (fail-open on .DWX zero spread).
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double spread = ask - bid;
   const double cap    = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_spread_cap_pips);
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && cap > 0.0 && spread > cap)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // No Friday entry (card filter). Broker time; Fri = day-of-week 5.
   if(strategy_no_friday_entry)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.day_of_week == 5)
         return false;
     }

   // --- Confirming STATE: ADX(28) directional index sides (closed bar) ---
   const double plus_di  = QM_ADX_PlusDI(_Symbol, _Period, strategy_adx_period, 1);
   const double minus_di = QM_ADX_MinusDI(_Symbol, _Period, strategy_adx_period, 1);
   if(plus_di <= 0.0 || minus_di <= 0.0)
      return false;

   // Optional strength floor (0 = disabled, the card baseline).
   if(strategy_adx_min > 0.0)
     {
      const double adx = QM_ADX(_Symbol, _Period, strategy_adx_period, 1);
      if(adx < strategy_adx_min)
         return false;
     }

   // --- Confirming STATE: MACD(5,10,4) main side (closed bar) ---
   const double macd_main = QM_MACD_Main(_Symbol, _Period,
                                         strategy_macd_fast,
                                         strategy_macd_slow,
                                         strategy_macd_signal, 1);

   // --- LONG: upward EMA cross (trigger) + +DI>-DI + MACD>0 ---
   bool crossed_up = false;
   bool crossed_down = false;
   for(int s = 1; s <= strategy_cross_lookback; ++s)
     {
      const double fast_s = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, s);
      const double slow_s = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, s);
      const double fast_p = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, s + 1);
      const double slow_p = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, s + 1);
      if(fast_s <= 0.0 || slow_s <= 0.0 || fast_p <= 0.0 || slow_p <= 0.0)
         continue;

      if(fast_p <= slow_p && fast_s > slow_s)
         crossed_up = true;
      if(fast_p >= slow_p && fast_s < slow_s)
         crossed_down = true;
     }

   const bool long_di = (plus_di > minus_di);
   const bool long_macd = (macd_main > 0.0);
   if(long_di && long_macd && crossed_up)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopFixedPips(_Symbol, QM_BUY, entry, (int)strategy_sl_pips);
      const double tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl,
                                  strategy_tp_pips / strategy_sl_pips);
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "carter_ema_adx_macd_long";
      return true;
     }

   // --- SHORT: downward EMA cross (trigger) + -DI>+DI + MACD<0 ---
   const bool short_di = (minus_di > plus_di);
   const bool short_macd = (macd_main < 0.0);
   if(short_di && short_macd && crossed_down)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopFixedPips(_Symbol, QM_SELL, entry, (int)strategy_sl_pips);
      const double tp = QM_TakeRR(_Symbol, QM_SELL, entry, sl,
                                  strategy_tp_pips / strategy_sl_pips);
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "carter_ema_adx_macd_short";
      return true;
     }

   return false;
  }

// Fixed SL/TP only — no active management.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit beyond the fixed SL/TP.
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
