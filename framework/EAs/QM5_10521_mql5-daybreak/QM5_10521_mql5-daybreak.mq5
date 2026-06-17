#property strict
#property version   "5.0"
#property description "QM5_10521 MQL5 Daily BreakPoint — previous-daily-bar high/low breakout (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_10521 — MQL5 Daily BreakPoint (previous daily bar breakout)
// -----------------------------------------------------------------------------
// Card: artifacts/cards_approved/QM5_10521_mql5-daybreak.md (g0_status: APPROVED)
// Source: risyadi / Gusti Risyadi Noor "Daily BreakPoint", MQL5 CodeBase 19498.
//
// Mechanic (mechanical, deterministic):
//   - Evaluate once per CLOSED H1 bar.
//   - Reference the most recently COMPLETED D1 bar (shift 1 on PERIOD_D1):
//       prev_daily_high, prev_daily_low, prev_daily_range = high - low.
//   - Range filter: trade only if min <= prev_daily_range <= max.
//   - Long  when the just-closed H1 close breaks ABOVE prev_daily_high + break.
//   - Short when the just-closed H1 close breaks BELOW prev_daily_low  - break.
//   - One active position per symbol/magic (no pyramiding).
//   - SL = prev_daily_range * sl_range_mult, capped by ATR(14) * sl_atr_cap_mult.
//   - TP = sl_rr * R (risk-multiple).
//
// Broker time / session note:
//   This is a DAILY-BAR breakout, NOT an intraday opening-range strategy. The
//   "day boundary" is the PERIOD_D1 bar boundary itself, which the MT5 tester
//   rolls at broker server midnight = the DXZ NY-Close convention (UTC+2/+3,
//   DST-aware by construction). We therefore reference the prior COMPLETED D1
//   bar directly; no raw wall-clock session window is built, so there is no
//   raw-ET/UTC clock to convert. The .DWX gapless-CFD prior-CLOSE concern does
//   not apply: the breakout level is prior-day HIGH/LOW (a true daily extreme),
//   compared against the just-closed H1 bar's close, not an opening gap.
//
// .DWX invariants honoured:
//   - Spread guard fails OPEN on zero modeled spread (only blocks a genuinely
//     wide spread when ask>bid).
//   - QM_IsNewBar(H1) consumed exactly ONCE per tick (latched in OnTick by the
//     framework; the entry hook is only called on a fresh H1 bar).
//   - Breakout offset + range-filter thresholds are expressed in PIPS and
//     converted to price distance via QM_StopRulesPipsToPriceDistance so they
//     are scale-correct on 5-digit FX and 3-digit JPY pairs.
//   - Daily OHLC reads are bespoke structural data with no framework reader;
//     they run only on a fresh H1 bar (perf-allowed) — O(1), no per-tick loop.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10521;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
// Breakout offset beyond the prior daily high/low, in pips (scale-correct).
input int    daily_break_pips           = 10;
// Previous-daily-range acceptance band, in pips (min/max bar size filter).
input int    range_min_pips             = 30;
input int    range_max_pips             = 500;
// Stop loss = prev_daily_range * sl_range_mult, capped by ATR(14)*sl_atr_cap_mult.
input double sl_range_mult              = 1.0;
input int    sl_atr_period              = 14;
input double sl_atr_cap_mult            = 2.0;
// Take profit as a risk multiple (R).
input double sl_rr                      = 1.5;
// Maximum spread allowed (pips). Fails OPEN on zero modeled spread (.DWX).
input double max_spread_pips            = 8.0;

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Block trading only on a genuinely wide spread. .DWX quotes ask==bid (spread 0)
// in the tester, so this MUST fail open on zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask > 0.0 && bid > 0.0 && ask > bid)
     {
      const double cap = QM_StopRulesPipsToPriceDistance(_Symbol, (int)MathRound(max_spread_pips));
      if(cap > 0.0 && (ask - bid) > cap)
         return true;   // genuinely wide spread → block
     }
   return false;
  }

// New entry on a freshly-closed H1 bar. Caller guarantees QM_IsNewBar()==true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One active position per symbol/magic — no pyramiding.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Previous COMPLETED daily bar (shift 1 on D1). perf-allowed: bespoke
   //     daily-OHLC structural data, no framework reader; runs once per H1 bar.
   const double prev_high = iHigh(_Symbol, PERIOD_D1, 1);
   const double prev_low  = iLow(_Symbol, PERIOD_D1, 1);
   if(prev_high <= 0.0 || prev_low <= 0.0 || prev_high <= prev_low)
      return false;
   const double prev_range = prev_high - prev_low;

   // --- Range (last-bar-size) filter in price terms.
   const double range_min = QM_StopRulesPipsToPriceDistance(_Symbol, range_min_pips);
   const double range_max = QM_StopRulesPipsToPriceDistance(_Symbol, range_max_pips);
   if(range_min > 0.0 && prev_range < range_min)
      return false;
   if(range_max > 0.0 && prev_range > range_max)
      return false;

   // --- Breakout levels off the prior daily extreme + offset.
   const double brk = QM_StopRulesPipsToPriceDistance(_Symbol, daily_break_pips);
   const double up_level = prev_high + brk;
   const double dn_level = prev_low  - brk;

   // --- Just-closed H1 bar close drives the breakout (closed-bar read).
   const double h1_close = iClose(_Symbol, PERIOD_H1, 1);
   if(h1_close <= 0.0)
      return false;

   QM_OrderType side;
   if(h1_close > up_level)
      side = QM_BUY;
   else
      if(h1_close < dn_level)
         side = QM_SELL;
      else
         return false;

   // --- Stop loss = prev_range * sl_range_mult, capped by ATR(14)*sl_atr_cap_mult.
   double sl_distance = prev_range * sl_range_mult;
   if(sl_distance <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, PERIOD_H1, sl_atr_period, 1);
   if(atr_value > 0.0 && sl_atr_cap_mult > 0.0)
     {
      const double atr_cap = atr_value * sl_atr_cap_mult;
      if(atr_cap > 0.0 && sl_distance > atr_cap)
         sl_distance = atr_cap;   // cap the stop at the volatility ceiling
     }

   // Market entry: framework fills price at send (req.price=0). Derive SL/TP
   // as absolute prices from the breakout reference (entry approximated by the
   // breakout level for SL/TP geometry; framework normalises).
   const double entry_ref = (side == QM_BUY) ? up_level : dn_level;
   const double sl_price = QM_StopRulesStopFromDistance(_Symbol, side, entry_ref, sl_distance);
   if(sl_price <= 0.0)
      return false;
   const double tp_price = QM_TakeRR(_Symbol, side, entry_ref, sl_price, sl_rr);

   req.type   = side;
   req.price  = 0.0;        // market
   req.sl     = sl_price;
   req.tp     = tp_price;   // 0.0 if sl_rr invalid → no TP
   req.reason = "QM5_10521 daily_breakpoint";
   return true;
  }

// No active trade management beyond SL/TP (card P2 baseline uses fixed exits).
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit: card closes on SL/TP only (close-by-signal flag is a
// P3 sweep dimension, OFF in the P2 baseline). Opposite breakout only acts when
// flat, which is enforced by the one-position-per-magic gate in EntrySignal.
bool Strategy_ExitSignal()
  {
   return false;
  }

// Defer to the central two-axis news filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line.
// -----------------------------------------------------------------------------

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,
                        30,
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,
                        qm_news_compliance))
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
