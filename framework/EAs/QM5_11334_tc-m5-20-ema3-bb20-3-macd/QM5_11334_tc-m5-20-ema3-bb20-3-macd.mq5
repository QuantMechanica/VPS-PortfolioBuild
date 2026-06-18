#property strict
#property version   "5.0"
#property description "QM5_11334 tc-m5-20-ema3-bb20-3-macd — EMA3 cross BB(20,3) middle + MACD zero-approach (M5)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11334 tc-m5-20-ema3-bb20-3-macd
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)",
//         5 Min Trading System #20. Card:
//         artifacts/cards_approved/QM5_11334_tc-m5-20-ema3-bb20-3-macd.md
//         (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1; M5):
//   TRIGGER EVENT  : EMA(ema_period) crosses the BB(bb_period, bb_dev) MIDDLE
//                    band (= SMA(bb_period)). Up cross -> long bias, down cross
//                    -> short bias. ONE fresh cross is the event (shift 2 -> 1),
//                    OR a cross within the last `macd_lookback` closed bars so
//                    EVENT + STATE need not coincide on a single bar (.DWX
//                    invariant #4: two fresh events almost never share a bar).
//   STATE (filter) : MACD(macd_fast, macd_slow, macd_signal) main line is
//                    "approaching or crossing zero" in the trade direction.
//                    LONG  : macd<0 trending up (macd[1] > macd[2])  OR  a fresh
//                            upward zero cross (macd[2] <= 0 < macd[1]).
//                    SHORT : mirror. MACD MAY be negative — no swap/sign reject.
//   STOP / TAKE    : fixed sl_pips / tp_pips (default 12 each), pip-scale-correct
//                    via QM_StopFixedPips / QM_TakeFixedPips (5-digit / JPY safe).
//   Spread guard   : skip only a genuinely wide spread > spread_pct_of_stop of
//                    the stop distance (fail-OPEN on .DWX zero modeled spread).
//
// One position per symbol/magic. Only the 5 Strategy_* hooks + Strategy inputs
// are EA-specific; everything else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11334;
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
input int    strategy_ema_period          = 3;     // fast EMA crossing the BB middle
input int    strategy_bb_period           = 20;    // Bollinger period (middle = SMA20)
input double strategy_bb_dev              = 3.0;   // Bollinger deviation (band width; middle is dev-independent)
input int    strategy_macd_fast           = 12;    // MACD fast EMA
input int    strategy_macd_slow           = 26;    // MACD slow EMA
input int    strategy_macd_signal         = 9;     // MACD signal EMA
input int    strategy_macd_lookback       = 3;     // bars to allow EMA/BB cross before the MACD state (P3: 0/1/3)
input int    strategy_sl_pips             = 12;    // fixed stop in pips (card 10-15 midpoint)
input int    strategy_tp_pips             = 12;    // fixed target in pips (card 10-15 midpoint)
input double strategy_spread_pct_of_stop  = 50.0;  // skip if spread > this % of stop distance (scalp-wide cap)

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — fail-OPEN on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double stop_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_pips);
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Detect an EMA-vs-BB-middle cross at a given closed-bar pair (cross_shift is the
// "now" bar; cross_shift+1 is the "prev" bar). dir=+1 wants an up cross, dir=-1
// wants a down cross. Returns true if that exact cross occurred at that pair.
bool EmaBBMiddleCrossAt(const int dir, const int cross_shift)
  {
   const double ema_now  = QM_EMA(_Symbol, _Period, strategy_ema_period, cross_shift);
   const double ema_prev = QM_EMA(_Symbol, _Period, strategy_ema_period, cross_shift + 1);
   const double mid_now  = QM_BB_Middle(_Symbol, _Period, strategy_bb_period, strategy_bb_dev, cross_shift);
   const double mid_prev = QM_BB_Middle(_Symbol, _Period, strategy_bb_period, strategy_bb_dev, cross_shift + 1);
   if(ema_now <= 0.0 || ema_prev <= 0.0 || mid_now <= 0.0 || mid_prev <= 0.0)
      return false;

   if(dir > 0)
      return (ema_prev <= mid_prev && ema_now > mid_now);   // fresh up cross
   return (ema_prev >= mid_prev && ema_now < mid_now);      // fresh down cross
  }

// MACD "approaching or crossing zero" STATE in the trade direction, read at the
// trigger (shift 1) closed bar. MACD may be negative (long) / positive (short).
bool MacdZeroApproach(const int dir)
  {
   const double macd_now  = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);
   const double macd_prev = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 2);

   if(dir > 0)
     {
      // below zero but trending UP toward it, OR a fresh upward zero cross.
      const bool approaching = (macd_now < 0.0 && macd_now > macd_prev);
      const bool crossed_up  = (macd_prev <= 0.0 && macd_now > 0.0);
      return (approaching || crossed_up);
     }

   // SHORT mirror: above zero but trending DOWN toward it, OR fresh downward cross.
   const bool approaching = (macd_now > 0.0 && macd_now < macd_prev);
   const bool crossed_dn  = (macd_prev >= 0.0 && macd_now < 0.0);
   return (approaching || crossed_dn);
  }

// Returns +1 long / -1 short / 0 no signal for the current closed bar.
int DirectionalSignal()
  {
   // STATE first (cheap, one read pair each direction is decided by the cross).
   // EVENT: EMA/BB-middle cross within the last `macd_lookback` closed bars,
   // ending at the trigger bar (shift 1). lookback 0 => cross must be on bar 1.
   const int last_extra = (strategy_macd_lookback > 0) ? strategy_macd_lookback : 0;

   // --- LONG: any up cross in [shift 1 .. shift 1+last_extra] + MACD up-state ---
   for(int s = 1; s <= 1 + last_extra; ++s)
     {
      if(EmaBBMiddleCrossAt(+1, s))
        {
         if(MacdZeroApproach(+1))
            return +1;
         break; // an up cross was found but MACD state failed — do not also short
        }
     }

   // --- SHORT: any down cross in the same window + MACD down-state ---
   for(int s = 1; s <= 1 + last_extra; ++s)
     {
      if(EmaBBMiddleCrossAt(-1, s))
        {
         if(MacdZeroApproach(-1))
            return -1;
         break;
        }
     }

   return 0;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const int dir = DirectionalSignal();
   if(dir == 0)
      return false;

   if(dir > 0)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopFixedPips(_Symbol, QM_BUY, entry, strategy_sl_pips);
      const double tp = QM_TakeFixedPips(_Symbol, QM_BUY, entry, strategy_tp_pips);
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "ema3_bb_mid_up_macd_zero";
      return true;
     }

   // dir < 0 — short
   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;
   const double sl = QM_StopFixedPips(_Symbol, QM_SELL, entry, strategy_sl_pips);
   const double tp = QM_TakeFixedPips(_Symbol, QM_SELL, entry, strategy_tp_pips);
   if(sl <= 0.0 || tp <= 0.0)
      return false;
   req.type   = QM_SELL;
   req.price  = 0.0;
   req.sl     = sl;
   req.tp     = tp;
   req.reason = "ema3_bb_mid_dn_macd_zero";
   return true;
  }

// Fixed SL/TP only — no active management.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit beyond the fixed SL/TP (scalp profile).
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
