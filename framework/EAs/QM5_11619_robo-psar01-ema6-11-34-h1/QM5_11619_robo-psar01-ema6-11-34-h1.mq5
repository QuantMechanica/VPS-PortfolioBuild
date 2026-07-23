#property strict
#property version   "5.0"
#property description "QM5_11619 robo-psar01-ema6-11-34-h1 — PSAR(0.1,1.0) + EMA(6/11/34) fan trend strategy"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11619 robo-psar01-ema6-11-34-h1
// -----------------------------------------------------------------------------
// Source: RoboForex Educational Team, "Forex Strategy Collection" (~2015),
// "PSAR + EMA Trio", pages 55-56. Card:
// D:\QM\strategy_farm\artifacts\cards_approved\QM5_11619_robo-psar01-ema6-11-34-h1.md
//
// Only the five Strategy_* hooks below are strategy-specific. Everything else
// is framework boilerplate (OnInit/OnTick wiring, risk + magic + news +
// Friday-close guard rails) — do not edit below the wiring marker.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11619;
input int    qm_magic_slot_offset       = 0;
// FW3: Q07 Multi-Seed uses one of the canonical seeds (42, 17, 99, 7, 2026).
// All other phases use 42 by default. Stress / noise dimensions read from
// this single seed so reproducibility is guaranteed across re-runs.
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
// FW1 2026-05-23 — Two-axis news filter per Vault Q09.
//   AXIS A (temporal): per-event behaviour. Default mode 3 = pause 30min pre+post.
//   AXIS B (compliance): prop-firm blackout overlay. Default DXZ = no extra rules.
// A trade is allowed only if BOTH axes allow. See Vault `Q09 News Impact Mode`.
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
// Legacy single-mode input kept for back-compat with pre-FW1 setfiles.
// New EAs use qm_news_temporal + qm_news_compliance above and leave this OFF.
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
// FW2 2026-05-23 — only populated by Q05 MED / Q06 HARSH stress setfiles.
// Default 0.0 = no rejection (Q02/Q03/Q04/Q07/Q08/Q09/Q10/Q13 backtests).
// Q06 HARSH sets to 0.10 (10% of entries randomly dropped before broker send,
// deterministic per qm_rng_seed). MED slip/spread/commission live in the
// tester groups file, not as EA inputs.
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
// Card Mechanik: EMA(6) / EMA(11) / EMA(34) fan alignment + PSAR(0.1,1.0)
// confirmation. Stop = MathMax/MathMin(psar_value, entry -/+ 2*ATR(14)).
// Take profit = 4*ATR(14) factory default; PSAR-flip is the primary exit,
// PSAR also trails the stop while the position is open.
input int    strategy_ema_fast_period   = 6;
input int    strategy_ema_mid_period    = 11;
input int    strategy_ema_slow_period   = 34;
input double strategy_psar_step         = 0.1;
input double strategy_psar_max          = 1.0;
input int    strategy_atr_period        = 14;
input double strategy_atr_sl_mult       = 2.0;
input double strategy_atr_tp_mult       = 4.0;

// -----------------------------------------------------------------------------
// Strategy hooks — implemented mechanically against the card.
// -----------------------------------------------------------------------------

// No card-specified session/spread/regime filter beyond the framework's
// standard news + Friday-close handling — nothing to add here.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Entry (Long): EMA6[1] > EMA11[1] > EMA34[1] (full bullish fan) AND
//               PSAR[1] < Close[1] (PSAR confirms uptrend) -> Buy at market.
// Entry (Short): mirror image with a full bearish fan and PSAR above price.
// SL: card Implementation Notes literal formula
//     MathMax(psar_value, Close[1] - 2*ATR(14)) for longs (mirrored
//     MathMin(..., Close[1] + 2*ATR(14)) for shorts).
// TP: 4*ATR(14) factory default (card "Take Profit" section).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   ZeroMemory(req);
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_ema_fast_period <= 0 ||
      strategy_ema_mid_period <= strategy_ema_fast_period ||
      strategy_ema_slow_period <= strategy_ema_mid_period ||
      strategy_psar_step <= 0.0 ||
      strategy_psar_max <= strategy_psar_step ||
      strategy_atr_period <= 0 ||
      strategy_atr_sl_mult <= 0.0 ||
      strategy_atr_tp_mult <= 0.0)
      return false;

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double ema_fast = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_mid  = QM_EMA(_Symbol, _Period, strategy_ema_mid_period, 1);
   const double ema_slow = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   const double psar1    = QM_SAR(_Symbol, _Period, strategy_psar_step, strategy_psar_max, 1);
   const double atr1     = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   const double close1   = QM_SMA(_Symbol, _Period, 1, 1, PRICE_CLOSE);
   if(ema_fast <= 0.0 || ema_mid <= 0.0 || ema_slow <= 0.0 ||
      psar1 <= 0.0 || atr1 <= 0.0 || close1 <= 0.0)
      return false;

   QM_OrderType side;
   if(ema_fast > ema_mid && ema_mid > ema_slow && psar1 < close1)
      side = QM_BUY;
   else if(ema_fast < ema_mid && ema_mid < ema_slow && psar1 > close1)
      side = QM_SELL;
   else
      return false;

   const double entry = (side == QM_BUY) ? ask : bid;
   if(entry <= 0.0)
      return false;

   const double sl_psar      = QM_StopRulesNormalizePrice(_Symbol, psar1);
   const double sl_atr_floor = QM_StopATRFromValue(_Symbol, side, entry, atr1, strategy_atr_sl_mult);
   if(sl_psar <= 0.0 || sl_atr_floor <= 0.0)
      return false;

   const double sl = (side == QM_BUY) ? MathMax(sl_psar, sl_atr_floor)
                                       : MathMin(sl_psar, sl_atr_floor);
   const double tp = QM_TakeATRFromValue(_Symbol, side, entry, atr1, strategy_atr_tp_mult);
   if(sl <= 0.0 || tp <= 0.0)
      return false;
   if(side == QM_BUY && !(sl < entry && tp > entry))
      return false;
   if(side == QM_SELL && !(sl > entry && tp < entry))
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = (side == QM_BUY) ? "psar_ema_fan_long" : "psar_ema_fan_short";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// Card Exit: "trail via PSAR dots until flip" — walk the stop to the current
// PSAR value each closed bar (only ever tightens toward price, never widens
// past the current SL, never crosses through price).
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return;

   const double psar1 = QM_SAR(_Symbol, _Period, strategy_psar_step, strategy_psar_max, 1);
   if(psar1 <= 0.0)
      return;
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return;
   const double target_sl = QM_TM_NormalizePrice(_Symbol, psar1);
   if(target_sl <= 0.0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const long ptype = PositionGetInteger(POSITION_TYPE);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(bid <= 0.0 || ask <= 0.0)
         continue;

      if(ptype == POSITION_TYPE_BUY &&
         target_sl > current_sl + point &&
         target_sl < bid)
         QM_TM_MoveSL(ticket, target_sl, "psar_trail");
      else if(ptype == POSITION_TYPE_SELL &&
              (current_sl <= 0.0 || target_sl < current_sl - point) &&
              target_sl > ask)
         QM_TM_MoveSL(ticket, target_sl, "psar_trail");
     }
  }

// Card Exit: "Exit when PSAR flips against position" — the primary,
// discretionary exit rule, independent of the SL/TP backstops above.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double psar1  = QM_SAR(_Symbol, _Period, strategy_psar_step, strategy_psar_max, 1);
   const double close1 = QM_SMA(_Symbol, _Period, 1, 1, PRICE_CLOSE);
   if(psar1 <= 0.0 || close1 <= 0.0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && psar1 > close1)
         return true;
      if(ptype == POSITION_TYPE_SELL && psar1 < close1)
         return true;
     }
   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade(...)
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
   // Q08 evidence lifecycle: sample floating P&L before any per-tick guard can
   // return. QM_KillSwitchCheck retains the same call as a compatibility
   // fallback for pre-template EAs; keep this explicit hook in all new builds.
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // Per-tick: trade management can adjust SL/TP on open positions.
   // Management, rule-based exits and the Friday sweep above MUST keep
   // running through news windows — the news gate below blocks NEW entries
   // only (2026-07-02 audit rule; canonical order per QM5_12821 OnTick,
   // commit dc418a720).
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit (e.g. time stop). Separate from SL/TP.
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

   // Per-closed-bar: entry-signal evaluation. Gating here avoids 99% of
   // per-tick recompute mistakes — EntrySignal sees one new closed bar per
   // call, not every incoming tick.
   // FW1 — 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults. Gates NEW entries only —
   // never the management/exit paths above.
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req); // symbol_slot=0 (host slot) + expiration=0 defaults; garbage
                    // in unset fields = the silent-zero-trades class (9e4cfedb1)
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
   // FW4: feeds closing-deal net-profits to the KS kill-switch.
   // No-op outside Q13 (when no baseline.json exists).
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
