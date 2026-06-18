#property strict
#property version   "5.0"
#property description "QM5_11358 robo-cci-macd — RoboForex CCI(14)+MACD(12,26,2) dual-oscillator (M5)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11358 robo-cci-macd
// -----------------------------------------------------------------------------
// Source: RoboForex "Strategy with the use of Oscillators CCI and MACD" (M5).
// Card: artifacts/cards_approved/QM5_11358_robo-cci-macd.md (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1; one position per magic):
//   Trigger EVENT : CCI(14) crosses the +cci_level (LONG) / -cci_level (SHORT)
//                   level. Exactly one cross event resolves per bar/side.
//   Confirm STATE : MACD(12,26,2) Main line on the SAME side of zero as the
//                   trade direction (Main > 0 for LONG, Main < 0 for SHORT).
//                   MACD Main can be negative — that is the whole point of the
//                   sign STATE; never gate on its magnitude or a swap/spread.
//
//   IMPORTANT (zero-trade trap, per card NOTE): the CCI level cross is the
//   single EVENT; the MACD sign is a STATE. We never require two fresh crosses
//   on the same bar (CCI cross AND a MACD-zero cross would almost never
//   coincide -> 0 trades). One EVENT + one STATE.
//
//   Exit (deterministic) :
//     STATE exit  : CCI returns back across the level toward zero
//                   (LONG: CCI < +cci_level ; SHORT: CCI > -cci_level).
//                   The card's "CCI crosses MACD line" exit is ambiguous (CCI
//                   and MACD live on different scales and the card itself
//                   defers it to P3); the P2 deterministic exit is the
//                   CCI-return-through-level state plus the fixed SL/TP below.
//     SL / TP     : fixed pips from the card P2 (sl 12 pips, tp 15 pips),
//                   scale-correct via the framework pip helpers.
//   Spread guard  : fail-OPEN on .DWX zero modeled spread; block only a
//                   genuinely wide spread > spread_cap_pips.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11358;
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
input int    strategy_cci_period        = 14;     // CCI lookback period
input double strategy_cci_level         = 100.0;  // CCI overbought/oversold trigger level
input int    strategy_macd_fast         = 12;     // MACD fast EMA period
input int    strategy_macd_slow         = 26;     // MACD slow EMA period
input int    strategy_macd_signal       = 2;      // MACD signal SMA period (card: fast SMA(2))
input int    strategy_sl_pips           = 12;     // fixed stop-loss in pips (card P2)
input int    strategy_tp_pips           = 15;     // fixed take-profit in pips (card P2)
input double strategy_spread_cap_pips   = 3.0;    // skip only a genuinely wide spread (card cap 3 pips)

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only. Fail-OPEN on .DWX zero spread:
// only a genuinely wide spread blocks; zero/negative modeled spread passes.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double spread = ask - bid;
   if(spread <= 0.0)
      return false; // .DWX models zero spread — fail OPEN, never block

   const double cap = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_spread_cap_pips);
   if(cap <= 0.0)
      return false; // no scale yet — defer to entry gate
   if(spread > cap)
      return true;  // genuinely wide spread — block

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
// EVENT = CCI level cross; STATE = MACD Main sign on the same side of zero.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- CCI(14) at the last two closed bars (shift 1 = trigger bar, 2 = prior) ---
   const double cci_now  = QM_CCI(_Symbol, _Period, strategy_cci_period, 1);
   const double cci_prev = QM_CCI(_Symbol, _Period, strategy_cci_period, 2);

   // --- MACD(12,26,2) Main line sign STATE at the trigger bar. Main can be
   //     negative; we only read its sign, never its magnitude. ---
   const double macd_main = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                         strategy_macd_slow, strategy_macd_signal, 1);

   const double up_level   = strategy_cci_level;     // +100 by default
   const double down_level = -strategy_cci_level;    // -100 by default

   // LONG: CCI crosses UP through +level (EVENT) AND MACD Main > 0 (STATE).
   const bool cci_cross_up = (cci_prev <= up_level && cci_now > up_level);
   if(cci_cross_up && macd_main > 0.0)
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
      req.reason = "cci_macd_long";
      return true;
     }

   // SHORT: CCI crosses DOWN through -level (EVENT) AND MACD Main < 0 (STATE).
   const bool cci_cross_dn = (cci_prev >= down_level && cci_now < down_level);
   if(cci_cross_dn && macd_main < 0.0)
     {
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
      req.reason = "cci_macd_short";
      return true;
     }

   return false;
  }

// No active trade management beyond the fixed SL/TP. Discretionary exit is in
// Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Deterministic discretionary exit: CCI returns back across the level toward
// zero, against the open position's direction. Fixed SL/TP handle the rest.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double cci_now = QM_CCI(_Symbol, _Period, strategy_cci_period, 1);
   const double up_level   = strategy_cci_level;
   const double down_level = -strategy_cci_level;

   // Identify the open position's direction for this magic.
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)
        {
         // LONG exit: CCI fell back below the +level (momentum spent).
         if(cci_now < up_level)
            return true;
        }
      else if(ptype == POSITION_TYPE_SELL)
        {
         // SHORT exit: CCI rose back above the -level.
         if(cci_now > down_level)
            return true;
        }
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
