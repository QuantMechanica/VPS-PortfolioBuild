#property strict
#property version   "5.0"
#property description "QM5_11754 Continuation EMA50 WilliamsR MTF"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails). The framework provides:
//
//   - QM_IsNewBar(sym="", tf=PERIOD_CURRENT)  — closed-bar gate
//   - QM_ATR / QM_EMA / QM_SMA / QM_RSI / QM_MACD_Main / QM_MACD_Signal /
//     QM_ADX / QM_ADX_PlusDI / QM_ADX_MinusDI /
//     QM_BB_Upper / QM_BB_Middle / QM_BB_Lower    (from QM_Indicators.mqh)
//   - QM_TM_OpenPosition(req, ticket) / QM_TM_ClosePosition(ticket, reason)
//   - QM_TM_MoveToBreakEven / QM_TM_TrailATR / QM_TM_TrailStep / QM_TM_PartialClose
//   - QM_LotsForRisk(symbol, sl_points)        — risk model lot sizing
//   - QM_StopFixedPips / QM_StopATR / QM_StopStructure / QM_StopVolatility
//   - QM_FrameworkHandleFridayClose / QM_KillSwitchCheck / QM_NewsAllowsTrade
//
// DO NOT
//   - Write per-EA IsNewBar() — use QM_IsNewBar()
//   - Call iATR / iMA / iRSI / iMACD / iADX / iBands or CopyBuffer directly —
//     use the QM_* readers above. The framework pools handles and releases them
//     on shutdown.
//   - CopyRates over warmup windows on every tick. If you genuinely need raw
//     bar arrays, gate by QM_IsNewBar so the work runs once per closed bar.
//   - Hand-edit framework/include/QM/QM_MagicResolver.mqh. After adding rows
//     to magic_numbers.csv, run:
//         python framework/scripts/update_magic_resolver.py
//     This is idempotent and preserves all rows.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11754;
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
input int    strategy_ema_period        = 50;
input int    strategy_wpr_period        = 14;
input double strategy_wpr_oversold      = -80.0;
input double strategy_wpr_overbought    = -20.0;
input int    strategy_trail_sma_period  = 5;
input double strategy_trail_rr_trigger  = 2.0;
input int    strategy_atr_period        = 14;
input double strategy_atr_tp_mult       = 5.0;
input int    strategy_sl_buffer_points  = 10;

// Closed-bar cache for the card's post-2R SMA(5) trail.  OnTick advances
// these values exactly once per H4 bar; the per-tick management path only
// compares cached values with the current Bid/Ask.
double g_trail_close_1 = 0.0;
double g_trail_close_2 = 0.0;
double g_trail_sma_1   = 0.0;
double g_trail_sma_2   = 0.0;
bool   g_trail_cache_ready = false;

// One position per (magic, symbol) is enforced by the framework.  Retain its
// original stop distance so moving the stop never changes the 2R trigger.
ulong  g_initial_risk_ticket = 0;
double g_initial_risk_price  = 0.0;
bool   g_trail_armed         = false;

void AdvanceState_OnNewBar()
  {
   g_trail_cache_ready = false;
   g_trail_close_1 = 0.0;
   g_trail_close_2 = 0.0;
   g_trail_sma_1 = 0.0;
   g_trail_sma_2 = 0.0;

   if(strategy_trail_sma_period < 2)
      return;

   MqlRates bar_1;
   MqlRates bar_2;
   if(!QM_ReadBar(_Symbol, PERIOD_H4, 1, bar_1) ||
      !QM_ReadBar(_Symbol, PERIOD_H4, 2, bar_2))
      return;

   const double sma_1 = QM_SMA(_Symbol, PERIOD_H4, strategy_trail_sma_period, 1);
   const double sma_2 = QM_SMA(_Symbol, PERIOD_H4, strategy_trail_sma_period, 2);
   if(bar_1.close <= 0.0 || bar_2.close <= 0.0 || sma_1 <= 0.0 || sma_2 <= 0.0)
      return;

   g_trail_close_1 = bar_1.close;
   g_trail_close_2 = bar_2.close;
   g_trail_sma_1 = sma_1;
   g_trail_sma_2 = sma_2;
   g_trail_cache_ready = true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // No Trade Filter: the card defines no session, spread, or regime veto
   // beyond the central framework news, kill-switch, and Friday-close gates.
   if(_Period != PERIOD_H4)
      return true;
   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Trade Entry: D1 EMA50 trend, H4 EMA50 pullback, H4 Williams %R re-entry.
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_ema_period < 2 || strategy_wpr_period < 2 ||
      strategy_trail_sma_period < 2 || strategy_atr_period < 1 ||
      strategy_atr_tp_mult <= 0.0 || strategy_trail_rr_trigger <= 0.0)
      return false;

   const string sym = _Symbol;
   MqlRates d1_bar;
   MqlRates h4_bar;
   if(!QM_ReadBar(sym, PERIOD_D1, 1, d1_bar) ||
      !QM_ReadBar(sym, PERIOD_H4, 1, h4_bar))
      return false;

   const double d1_close = d1_bar.close;
   const double d1_ema = QM_EMA(sym, PERIOD_D1, strategy_ema_period, 1);
   const double d1_ema_prev = QM_EMA(sym, PERIOD_D1, strategy_ema_period, 2);
   const double h4_close = h4_bar.close;
   const double h4_high = h4_bar.high;
   const double h4_low = h4_bar.low;
   const double h4_ema = QM_EMA(sym, PERIOD_H4, strategy_ema_period, 1);
   const double wpr_now = QM_WPR(sym, PERIOD_H4, strategy_wpr_period, 1);
   const double wpr_prev = QM_WPR(sym, PERIOD_H4, strategy_wpr_period, 2);
   const double atr = QM_ATR(sym, PERIOD_H4, strategy_atr_period, 1);
   const double point = SymbolInfoDouble(sym, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(sym, SYMBOL_BID);

   if(d1_close <= 0.0 || d1_ema <= 0.0 || d1_ema_prev <= 0.0 ||
      h4_close <= 0.0 || h4_high <= 0.0 || h4_low <= 0.0 ||
      h4_ema <= 0.0 || atr <= 0.0 || point <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;

   const double stop_buffer = (double)strategy_sl_buffer_points * point;
   const bool d1_up = (d1_close > d1_ema && d1_ema > d1_ema_prev);
   const bool d1_down = (d1_close < d1_ema && d1_ema < d1_ema_prev);
   const bool long_pullback = (h4_close < h4_ema);
   const bool short_pullback = (h4_close > h4_ema);
   const bool long_wpr_cross = (wpr_prev <= strategy_wpr_oversold && wpr_now > strategy_wpr_oversold);
   const bool short_wpr_cross = (wpr_prev >= strategy_wpr_overbought && wpr_now < strategy_wpr_overbought);

   if(d1_up && long_pullback && long_wpr_cross)
     {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = NormalizeDouble(h4_low - stop_buffer, _Digits);
      req.tp = NormalizeDouble(ask + atr * strategy_atr_tp_mult, _Digits);
      req.reason = "EMA50_D1_H4_WPR_LONG";
      return (req.sl > 0.0 && req.sl < ask && req.tp > ask);
     }

   if(d1_down && short_pullback && short_wpr_cross)
     {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = NormalizeDouble(h4_high + stop_buffer, _Digits);
      req.tp = NormalizeDouble(bid - atr * strategy_atr_tp_mult, _Digits);
      req.reason = "EMA50_D1_H4_WPR_SHORT";
      return (req.sl > bid && req.tp > 0.0 && req.tp < bid);
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Trade Management: after price reaches 2R, trail SL with the last two
   // H4 closes relative to SMA(5), as specified by the card.
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || !g_trail_cache_ready || strategy_trail_rr_trigger <= 0.0)
      return;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return;

   bool found_position = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      found_position = true;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      if(open_price <= 0.0 || current_sl <= 0.0)
         continue;

      if(g_initial_risk_ticket != ticket || g_initial_risk_price <= 0.0)
        {
         g_initial_risk_ticket = ticket;
         g_initial_risk_price = MathAbs(open_price - current_sl);
         g_trail_armed = false;
        }
      if(g_initial_risk_price <= 0.0)
         continue;

      if(ptype == POSITION_TYPE_BUY)
        {
         if(!g_trail_armed &&
            (bid - open_price) >= g_initial_risk_price * strategy_trail_rr_trigger)
            g_trail_armed = true;
         if(!g_trail_armed)
            continue;
         if(!(g_trail_close_1 < g_trail_sma_1 && g_trail_close_2 < g_trail_sma_2))
            continue;
         const double new_sl = NormalizeDouble(MathMin(g_trail_close_1, g_trail_close_2), _Digits);
         if(new_sl > current_sl && new_sl < bid)
            QM_TM_MoveSL(ticket, new_sl, "SMA5_AFTER_2R_LONG");
        }
      else if(ptype == POSITION_TYPE_SELL)
        {
         if(!g_trail_armed &&
            (open_price - ask) >= g_initial_risk_price * strategy_trail_rr_trigger)
            g_trail_armed = true;
         if(!g_trail_armed)
            continue;
         if(!(g_trail_close_1 > g_trail_sma_1 && g_trail_close_2 > g_trail_sma_2))
            continue;
         const double new_sl = NormalizeDouble(MathMax(g_trail_close_1, g_trail_close_2), _Digits);
         if(new_sl < current_sl && new_sl > ask)
            QM_TM_MoveSL(ticket, new_sl, "SMA5_AFTER_2R_SHORT");
        }
     }

   if(!found_position)
     {
      g_initial_risk_ticket = 0;
      g_initial_risk_price = 0.0;
      g_trail_armed = false;
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   // Trade Close: no discretionary close beyond SL, ATR hard TP, SMA5 trail,
   // framework Friday close, kill-switch, and news gates.
   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   // News Filter Hook: defer to the V5 two-axis framework news filter.
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
   // return. The kill-switch retains a compatibility fallback for older EAs.
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // Consume the closed-bar event once. Refresh indicator/bar state before the
   // per-tick management hook; the hook itself reads only this cache.
   const bool is_new_bar = QM_IsNewBar();
   if(is_new_bar)
     {
      AdvanceState_OnNewBar();
      QM_EquityStreamOnNewBar();
     }

   // Per-tick: trade management can adjust SL/TP from cached closed-bar state.
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

   // News blackouts suppress new entries only. Position management and exits
   // above continue through the blackout window.
   if(Strategy_NewsFilterHook(broker_now))
      return;
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows || !is_new_bar)
      return;

   QM_EntryRequest req;
   ZeroMemory(req);
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
