#property strict
#property version   "5.0"
#property description "QM5_11823 carter-m5-s13-cci14-macd-m5 — CCI(14) +/-100 cross + MACD histogram confirm (M5)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11823 carter-m5-s13-cci14-macd-m5
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)",
//   Strategy 13, self-published 2014.
// Card: artifacts/cards_approved/QM5_11823_carter-m5-s13-cci14-macd-m5.md
//       (g0_status APPROVED).
//
// Mechanics (M5, closed-bar reads at shift 1/2):
//   Trigger EVENT : CCI(14) crosses the +/-100 level in the trade direction.
//                   LONG  -> cci@1 > +level AND cci@2 <= +level (fresh up-cross).
//                   SHORT -> cci@1 < -level AND cci@2 >= -level (fresh down-cross).
//                   ONE cross is the event; the MACD condition below is a STATE,
//                   never a second same-bar cross (two-cross-same-bar trap avoided).
//   Confirm STATE : MACD(12,26,9) histogram = (MACD main - MACD signal), closed bar.
//                   LONG  -> histogram > 0 (bullish momentum).
//                   SHORT -> histogram < 0 (bearish momentum).
//   Stop          : fixed sl_pips (card: 12-15p, factory 13p) via pip-correct helper.
//   Take profit   : fixed tp_pips (card: 7-10p, factory 10p; asymmetric TP < SL).
//   Spread guard  : skip only a genuinely wide spread (fail-open on .DWX zero
//                   modeled spread).
//
// MACD params: card frontmatter + Implementation Notes specify MACD(12,26,9).
// The card states "MACD histogram > 0 / < 0" as a confirming STATE (sign only),
// distinct from the sibling QM5_11553 which used an expanding-histogram variant.
// THIS card is followed literally: plain histogram-sign confirmation.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11823;
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
input int    strategy_cci_period         = 14;     // CCI lookback period
input double strategy_cci_level          = 100.0;  // CCI breakout level (+/-)
input int    strategy_macd_fast          = 12;     // MACD fast EMA period
input int    strategy_macd_slow          = 26;     // MACD slow EMA period
input int    strategy_macd_signal        = 9;      // MACD signal period
input int    strategy_sl_pips            = 13;     // stop-loss distance, pips (card 12-15)
input int    strategy_tp_pips            = 10;     // take-profit distance, pips (card 7-10)
input double strategy_spread_pct_of_stop = 25.0;   // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — signal work is on the closed-bar
// path in Strategy_EntrySignal. Fail-open on .DWX zero modeled spread.
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

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- CCI values (closed bars) ---
   const double cci1 = QM_CCI(_Symbol, _Period, strategy_cci_period, 1);
   const double cci2 = QM_CCI(_Symbol, _Period, strategy_cci_period, 2);

   // --- MACD histogram = main - signal (closed bar, shift 1) ---
   const double main1 = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);
   const double sig1  = QM_MACD_Signal(_Symbol, _Period, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);
   const double hist1 = main1 - sig1;

   QM_OrderType dir;

   // --- LONG: fresh CCI cross above +level (EVENT) + bullish histogram (STATE) ---
   const bool cci_cross_up = (cci1 >  strategy_cci_level && cci2 <=  strategy_cci_level);
   const bool macd_long_ok = (hist1 > 0.0);

   // --- SHORT: fresh CCI cross below -level (EVENT) + bearish histogram (STATE) ---
   const bool cci_cross_down = (cci1 < -strategy_cci_level && cci2 >= -strategy_cci_level);
   const bool macd_short_ok  = (hist1 < 0.0);

   if(cci_cross_up && macd_long_ok)
      dir = QM_BUY;
   else if(cci_cross_down && macd_short_ok)
      dir = QM_SELL;
   else
      return false;

   // --- Build the entry. Framework sizes lots (no lots field). ---
   const double entry = (dir == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopFixedPips(_Symbol, dir, entry, strategy_sl_pips);
   const double tp = QM_TakeRR(_Symbol, dir, entry, sl,
                               (double)strategy_tp_pips / (double)strategy_sl_pips);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type   = dir;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = (dir == QM_BUY) ? "cci_macd_cross_long" : "cci_macd_cross_short";
   return true;
  }

// Fixed pip stop/target only — no active trade management.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit beyond the fixed pip SL/TP (card: exit only via SL/TP).
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
