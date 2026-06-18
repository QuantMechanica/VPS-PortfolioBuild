#property strict
#property version   "5.0"
#property description "QM5_11737 rfs-adx-momentum-m5 — ADX/DI trend + Momentum(100) trigger scalp (M5)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11737 rfs-adx-momentum-m5
// -----------------------------------------------------------------------------
// Source: Anonymous, "ADX and Momentum", Robo-forex Strategy Compilation,
//         robofx.com ~2015. Source PDF 362359657-Robo-forex-strategy.pdf p.19-20.
// Card: artifacts/cards_approved/QM5_11737_rfs-adx-momentum-m5.md (g0 APPROVED).
//
// Mechanics (closed-bar reads at shift 1; one position per magic):
//   Trend STATE  : ADX(14) main > adx_threshold  (market is trending).
//   Direction    : LONG  -> DI+ > di_threshold AND DI+ > DI-.
//                  SHORT -> DI- > di_threshold AND DI- > DI+.
//   Bias STATE   : optional EMA(55) — LONG close>EMA, SHORT close<EMA.
//   Trigger EVENT: Momentum(14) crosses the 100 level (the SINGLE event).
//                  LONG  -> mom[shift2] <= 100 AND mom[shift1] > 100.
//                  SHORT -> mom[shift2] >= 100 AND mom[shift1] < 100.
//   Stop / Take  : fixed pips from entry (card: SL 6 pips, TP 15 pips ~2.5:1).
//   Exit         : SL/TP, or flatten on an opposite-direction trend+momentum
//                  state on a closed bar (Strategy_ExitSignal).
//
// Two-cross trap avoided: the ADX/DI/EMA conditions are STATES (currently true),
// NOT fresh cross EVENTS. Only the Momentum/100 cross is an event. Requiring two
// fresh crosses on one bar would never fire -> 0 trades.
//
// .DWX invariants: spread guard fails OPEN on zero modeled spread; no swap gate;
// QM_IsNewBar() consumed once by the framework wiring; pip-correct SL/TP via
// the QM_Stop*/QM_TakeRR helpers. FX symbols only (5-digit pip scaling handled
// by the helpers). Only the 5 Strategy_* hooks + inputs are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11737;
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
input int    strategy_adx_period        = 14;     // ADX / DI period
input double strategy_adx_threshold     = 25.0;   // ADX main must exceed this (trending)
input double strategy_di_threshold      = 25.0;   // dominant DI must exceed this
input int    strategy_mom_period        = 14;     // Momentum lookback period
input double strategy_mom_level         = 100.0;  // Momentum cross level (100 = flat)
input bool   strategy_use_ema_filter    = true;   // require EMA(55) bias agreement
input int    strategy_ema_period        = 55;     // EMA bias-filter period
input int    strategy_sl_pips           = 6;      // stop-loss distance in pips
input double strategy_tp_rr             = 2.5;    // take-profit as RR multiple of SL (~15 pips)
input double strategy_spread_pct_of_stop = 25.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only. Fail-OPEN on .DWX zero spread:
// only a genuinely wide spread (ask>bid and over the cap) blocks.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote — defer, do not block

   const double stop_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_pips);
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Direction-agnostic trend+bias STATE check on the closed bar (shift 1).
// Returns +1 long-state, -1 short-state, 0 neither.
int TrendDirectionState()
  {
   const double adx = QM_ADX(_Symbol, _Period, strategy_adx_period, 1);
   if(adx <= 0.0 || adx <= strategy_adx_threshold)
      return 0; // not trending

   const double di_plus  = QM_ADX_PlusDI(_Symbol, _Period, strategy_adx_period, 1);
   const double di_minus = QM_ADX_MinusDI(_Symbol, _Period, strategy_adx_period, 1);
   if(di_plus <= 0.0 || di_minus <= 0.0)
      return 0;

   const double close1 = QM_EMA(_Symbol, _Period, 1, 1); // 1-period EMA == close[1]
   double ema_bias = 0.0;
   if(strategy_use_ema_filter)
     {
      ema_bias = QM_EMA(_Symbol, _Period, strategy_ema_period, 1);
      if(ema_bias <= 0.0)
         return 0;
     }

   // Long state: DI+ dominant and strong, price above EMA bias.
   if(di_plus > strategy_di_threshold && di_plus > di_minus)
     {
      if(!strategy_use_ema_filter || close1 > ema_bias)
         return +1;
     }
   // Short state: DI- dominant and strong, price below EMA bias.
   if(di_minus > strategy_di_threshold && di_minus > di_plus)
     {
      if(!strategy_use_ema_filter || close1 < ema_bias)
         return -1;
     }
   return 0;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const int trend = TrendDirectionState();
   if(trend == 0)
      return false;

   // --- Trigger EVENT: Momentum crosses the level (the single event). ---
   const double mom_now  = QM_Momentum(_Symbol, _Period, strategy_mom_period, 1);
   const double mom_prev = QM_Momentum(_Symbol, _Period, strategy_mom_period, 2);
   if(mom_now <= 0.0 || mom_prev <= 0.0)
      return false;

   const bool crossed_up   = (mom_prev <= strategy_mom_level && mom_now > strategy_mom_level);
   const bool crossed_down = (mom_prev >= strategy_mom_level && mom_now < strategy_mom_level);

   const double entry = (trend > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                    : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   if(trend > 0 && crossed_up)
     {
      const double sl = QM_StopFixedPips(_Symbol, QM_BUY, entry, strategy_sl_pips);
      const double tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, strategy_tp_rr);
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "adx_mom_long";
      return true;
     }

   if(trend < 0 && crossed_down)
     {
      const double sl = QM_StopFixedPips(_Symbol, QM_SELL, entry, strategy_sl_pips);
      const double tp = QM_TakeRR(_Symbol, QM_SELL, entry, sl, strategy_tp_rr);
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "adx_mom_short";
      return true;
     }

   return false;
  }

// Fixed SL/TP only — no active trade management.
void Strategy_ManageOpenPosition()
  {
  }

// Defensive flatten: opposite trend+momentum state on a closed bar. The card's
// "flatten if the opposite entry signal appears" rule. State-based (not a fresh
// double cross) so it can actually trigger before SL/TP.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   const int trend = TrendDirectionState();
   if(trend == 0)
      return false;

   const double mom_now = QM_Momentum(_Symbol, _Period, strategy_mom_period, 1);
   if(mom_now <= 0.0)
      return false;

   const bool mom_bull = (mom_now > strategy_mom_level);
   const bool mom_bear = (mom_now < strategy_mom_level);

   // Determine the side of the currently open position for this magic.
   const int magic = QM_FrameworkMagic();
   bool have_long = false, have_short = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)  have_long = true;
      if(ptype == POSITION_TYPE_SELL) have_short = true;
     }

   // Long open but a confirmed short state appears -> exit. Mirror for short.
   if(have_long  && trend < 0 && mom_bear)
      return true;
   if(have_short && trend > 0 && mom_bull)
      return true;

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
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
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
