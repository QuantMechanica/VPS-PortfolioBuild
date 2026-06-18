#property strict
#property version   "5.0"
#property description "QM5_11632 cat-btd-rsi — Catalyst RSI Buy-The-Dip (long-only, D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11632 cat-btd-rsi
// -----------------------------------------------------------------------------
// Source: scrtlabs/catalyst, catalyst/examples/buy_low_sell_high.py
// Card: artifacts/cards_approved/QM5_11632_cat-btd-rsi.md (g0_status APPROVED).
//
// SOURCE LOGIC (unchanged intent):
//   "Buy the dip" mean-reversion on RSI(14) over D1 closed bars. The source
//   opens an initial long and then adds RSI-weighted ladder units while price
//   is below cost basis, capping at TARGET_POSITIONS=30, and closes the whole
//   basket when price > cost_basis * 1.10.
//
// V5 FRAMEWORK ADAPTATION (single-position-per-magic — see open_questions):
//   The QM V5 framework enforces ONE position per magic, so the source's
//   bounded 30-unit ladder (which holds many simultaneous units) cannot be
//   realised as separate positions. We realise the SAME EDGE — buy an RSI dip,
//   sell on a +10% recovery — as a single bounded long. Risk is bounded by the
//   framework RISK_FIXED ($1,000) sizing exactly as the source bounded its
//   ladder; no martingale, no adds.
//
// Mechanics (long-only, closed-bar reads at shift 1):
//   Entry EVENT  : RSI(period) dips INTO the oversold zone — a fresh downward
//                  cross of `strategy_rsi_oversold` (rsi[2] >= level, rsi[1] <
//                  level). ONE event/bar; never paired with a second cross.
//   No trend STATE filter (the source is pure mean-reversion BTD).
//   Take profit  : entry * (1 + strategy_tp_pct/100)  ~ the source's +10% exit,
//                  expressed as a TP price on the single position.
//   RSI recovery exit: RSI crosses back up above `strategy_rsi_recovery`
//                  -> close manually (mean-reversion completed without hitting
//                  the +10% target).
//   Catastrophic stop: entry - sl_atr_mult * ATR (card: "V5 adds ATR
//                  catastrophic basket stop"; the source had none).
//   Spread guard : skip only a genuinely wide spread > spread_pct_of_stop of
//                  the stop distance (fail-open on .DWX zero modeled spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11632;
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
input int    strategy_rsi_period         = 14;     // RSI lookback (source: RSI(14))
input double strategy_rsi_oversold       = 30.0;   // dip-INTO trigger level (source tier 1)
input double strategy_rsi_recovery       = 50.0;   // RSI recovery exit level
input double strategy_tp_pct             = 10.0;   // profit target %, source: cost_basis*1.10
input int    strategy_atr_period         = 14;     // ATR period for catastrophic stop
input double strategy_sl_atr_mult        = 4.0;    // catastrophic stop = mult * ATR
input double strategy_spread_pct_of_stop = 15.0;   // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — signal work is in
// Strategy_EntrySignal on the closed-bar path. Fail-open on .DWX zero spread.
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

// Long-only BTD entry. Caller guarantees QM_IsNewBar() == true (closed bar).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic (framework constraint).
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Entry EVENT: RSI dips INTO oversold (fresh downward cross). ---
   // rsi_prev at shift 2 was above/at the level; rsi_now at shift 1 is below.
   // This is the single trigger event — no second cross is required, so we
   // never hit the two-cross-same-bar zero-trade trap.
   const double rsi_now  = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   const double rsi_prev = QM_RSI(_Symbol, _Period, strategy_rsi_period, 2);
   if(rsi_now <= 0.0 || rsi_prev <= 0.0)
      return false;
   const bool dipped_in = (rsi_prev >= strategy_rsi_oversold &&
                           rsi_now  <  strategy_rsi_oversold);
   if(!dipped_in)
      return false;

   // --- Build the long entry. Framework sizes lots (no lots field). ---
   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   // Catastrophic ATR stop (source had none; card adds it).
   const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_sl_atr_mult);
   // Profit target as the source's +10% recovery, as a TP price.
   const double tp = QM_TM_NormalizePrice(_Symbol, entry * (1.0 + strategy_tp_pct / 100.0));
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type   = QM_BUY;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = "cat_btd_rsi_long";
   return true;
  }

// No active trade management beyond the fixed ATR stop / +10% target. The RSI
// recovery exit lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Mean-reversion completed exit: RSI crosses back up above the recovery level
// (one event at shift 1) without the +10% TP having been hit yet.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   const double rsi_now  = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   const double rsi_prev = QM_RSI(_Symbol, _Period, strategy_rsi_period, 2);
   if(rsi_now <= 0.0 || rsi_prev <= 0.0)
      return false;

   const bool recovered = (rsi_prev <= strategy_rsi_recovery &&
                           rsi_now  >  strategy_rsi_recovery);
   return recovered;
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
