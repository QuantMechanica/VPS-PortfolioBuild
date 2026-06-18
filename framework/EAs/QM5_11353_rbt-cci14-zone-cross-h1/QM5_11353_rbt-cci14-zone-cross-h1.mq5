#property strict
#property version   "5.0"
#property description "QM5_11353 rbt-cci14-zone-cross-h1 — RoboForex CCI(14) extreme-zone cross (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11353 rbt-cci14-zone-cross-h1
// -----------------------------------------------------------------------------
// Source: RoboForex Strategy Collection, "CCI strategy" (institutional PDF).
// Card: artifacts/cards_approved/QM5_11353_rbt-cci14-zone-cross-h1.md (APPROVED).
//
// Mechanics (closed-bar reads at shift 1; H1):
//   The single EVENT is CCI(14) crossing into the opposite extreme zone.
//   The prior-extreme reading is a STATE observed earlier in a lookback window
//   (never the same bar — avoids the two-cross-same-bar zero-trade trap).
//
//   LONG  : prior-extreme STATE  = CCI <= cci_oversold (-150) on ANY of the
//                                  lookback bars PRECEDING the trigger bar.
//           trigger EVENT         = CCI crosses up through cci_long_zone (+100):
//                                  cci[2] <= +100  AND  cci[1] > +100.
//   SHORT : mirror — prior CCI >= cci_overbought (+150) within lookback, and
//           CCI crosses DOWN through cci_short_zone (-100):
//                                  cci[2] >= -100  AND  cci[1] < -100.
//
//   Stop / Take : fixed pips (pip-scale-correct via QM_StopFixedPips), card
//                 defaults SL=20 pips, TP=40 pips. P2 may sweep ATR-based stop.
//   Momentum-fade exit: LONG closes if CCI falls back below cci_long_zone;
//                       SHORT closes if CCI rises back above cci_short_zone.
//   Spread guard : fail-OPEN on .DWX zero modeled spread; block only a
//                  genuinely wide absolute spread > spread_cap_pips.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11353;
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
input int    strategy_cci_period        = 14;     // CCI period (PRICE_TYPICAL)
input double strategy_cci_oversold       = -150.0; // prior-extreme STATE: deep oversold (long setup)
input double strategy_cci_overbought     = 150.0;  // prior-extreme STATE: deep overbought (short setup)
input double strategy_cci_long_zone      = 100.0;  // EVENT: cross UP through this -> LONG
input double strategy_cci_short_zone     = -100.0; // EVENT: cross DOWN through this -> SHORT
input int    strategy_prior_lookback    = 5;      // bars before trigger to find prior extreme (3-8)
input double strategy_sl_pips           = 20.0;   // fixed stop in pips
input double strategy_tp_pips           = 40.0;   // fixed take-profit in pips
input bool   strategy_use_fade_exit     = true;   // exit when CCI returns past the trigger zone
input double strategy_spread_cap_pips   = 20.0;   // skip only a genuinely wide spread (pips)

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

   const double spread = ask - bid;
   if(spread <= 0.0)
      return false; // zero/negative modeled spread (.DWX) — fail-open, allow

   const double cap_distance = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_spread_cap_pips);
   if(cap_distance <= 0.0)
      return false; // cannot scale cap — do not block here

   if(spread > cap_distance)
      return true;  // genuinely wide spread — block

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Closed-bar CCI readings: shift 1 = just-closed bar, shift 2 = the one before.
   const double cci1 = QM_CCI(_Symbol, _Period, strategy_cci_period, 1, PRICE_TYPICAL);
   const double cci2 = QM_CCI(_Symbol, _Period, strategy_cci_period, 2, PRICE_TYPICAL);

   // --- LONG: fresh cross UP through the long zone (the single EVENT) ---
   const bool long_cross = (cci2 <= strategy_cci_long_zone && cci1 > strategy_cci_long_zone);
   // --- SHORT: fresh cross DOWN through the short zone (the single EVENT) ---
   const bool short_cross = (cci2 >= strategy_cci_short_zone && cci1 < strategy_cci_short_zone);

   if(!long_cross && !short_cross)
      return false;

   // Prior-extreme STATE: scan the bars PRECEDING the trigger bar (shifts
   // 2 .. lookback+1). The cross is the trigger; the deep-zone touch is a state
   // seen earlier — never required on the same bar as the cross.
   const int first_shift = 2;
   const int last_shift  = strategy_prior_lookback + 1;

   if(long_cross)
     {
      bool was_oversold = false;
      for(int s = first_shift; s <= last_shift; ++s)
        {
         const double cci_s = QM_CCI(_Symbol, _Period, strategy_cci_period, s, PRICE_TYPICAL);
         if(cci_s <= strategy_cci_oversold)
           {
            was_oversold = true;
            break;
           }
        }
      if(!was_oversold)
         return false;

      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopFixedPips(_Symbol, QM_BUY, entry, (int)strategy_sl_pips);
      const double tp = QM_TakeFixedPips(_Symbol, QM_BUY, entry, (int)strategy_tp_pips);
      if(sl <= 0.0 || tp <= 0.0)
         return false;

      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "cci14_zone_cross_long";
      return true;
     }

   // short_cross
   bool was_overbought = false;
   for(int s = first_shift; s <= last_shift; ++s)
     {
      const double cci_s = QM_CCI(_Symbol, _Period, strategy_cci_period, s, PRICE_TYPICAL);
      if(cci_s >= strategy_cci_overbought)
        {
         was_overbought = true;
         break;
        }
     }
   if(!was_overbought)
      return false;

   const double sentry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(sentry <= 0.0)
      return false;
   const double ssl = QM_StopFixedPips(_Symbol, QM_SELL, sentry, (int)strategy_sl_pips);
   const double stp = QM_TakeFixedPips(_Symbol, QM_SELL, sentry, (int)strategy_tp_pips);
   if(ssl <= 0.0 || stp <= 0.0)
      return false;

   req.type   = QM_SELL;
   req.price  = 0.0;
   req.sl     = ssl;
   req.tp     = stp;
   req.reason = "cci14_zone_cross_short";
   return true;
  }

// No active trade management beyond the fixed SL/TP. Fade exit lives in
// Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Momentum-fade exit: LONG closes if CCI falls back below the long zone;
// SHORT closes if CCI rises back above the short zone. STATE check on the
// just-closed bar.
bool Strategy_ExitSignal()
  {
   if(!strategy_use_fade_exit)
      return false;

   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double cci1 = QM_CCI(_Symbol, _Period, strategy_cci_period, 1, PRICE_TYPICAL);

   // Determine the direction of the open position for this magic.
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && cci1 < strategy_cci_long_zone)
         return true;  // long momentum faded below the entry zone
      if(ptype == POSITION_TYPE_SELL && cci1 > strategy_cci_short_zone)
         return true;  // short momentum faded above the entry zone
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
