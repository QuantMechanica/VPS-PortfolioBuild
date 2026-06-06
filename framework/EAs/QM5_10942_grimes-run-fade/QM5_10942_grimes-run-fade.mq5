#property strict
#property version   "5.0"
#property description "QM5_10942 Grimes Five-Day Run Fade"

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
input int    qm_ea_id                   = 10942;
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
input int    strategy_run_closes            = 5;
input int    strategy_atr_period            = 20;
input int    strategy_ema_period            = 20;
input int    strategy_adx_period            = 14;
input double strategy_extension_atr_mult    = 1.5;
input double strategy_max_range_atr_mult    = 2.75;
input double strategy_adx_skip_threshold    = 35.0;
input double strategy_stop_atr_mult         = 1.5;
input double strategy_tp_r_mult             = 1.5;
input double strategy_extreme_exit_atr_mult = 0.5;
input int    strategy_time_exit_d1_bars     = 5;
input int    strategy_cooldown_d1_bars      = 10;
input double strategy_spread_stop_pct       = 5.0;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // News, kill-switch, and Friday close are enforced by the framework.
   // Strategy-specific spread and regime gates apply only to new entries.
   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(_Period != PERIOD_D1)
      return false;
   if(strategy_run_closes < 2 || strategy_atr_period < 1 || strategy_ema_period < 1 ||
      strategy_adx_period < 1 || strategy_stop_atr_mult <= 0.0 || strategy_tp_r_mult <= 0.0)
      return false;

   const int bars_needed = MathMax(strategy_run_closes + 2, strategy_cooldown_d1_bars + 2);
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_D1, 0, bars_needed, rates); // perf-allowed: D1 closed-bar structural run check inside framework new-bar entry gate.
   if(copied < bars_needed)
      return false;

   bool five_down = true;
   bool five_up = true;
   for(int i = 1; i <= strategy_run_closes; ++i)
     {
      if(rates[i].close >= rates[i + 1].close)
         five_down = false;
      if(rates[i].close <= rates[i + 1].close)
         five_up = false;
     }
   if(!five_down && !five_up)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   const double ema = QM_EMA(_Symbol, PERIOD_D1, strategy_ema_period, 1);
   const double ema_prev = QM_EMA(_Symbol, PERIOD_D1, strategy_ema_period, 2);
   const double adx = QM_ADX(_Symbol, PERIOD_D1, strategy_adx_period, 1);
   if(atr <= 0.0 || ema <= 0.0 || ema_prev <= 0.0)
      return false;

   const double close1 = rates[1].close;
   const double range1 = rates[1].high - rates[1].low;
   if(range1 <= 0.0 || range1 > strategy_max_range_atr_mult * atr)
      return false;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(bid <= 0.0 || ask <= 0.0 || point <= 0.0)
      return false;

   const double stop_distance = strategy_stop_atr_mult * atr;
   const double max_spread = stop_distance * strategy_spread_stop_pct / 100.0;
   if((ask - bid) > max_spread)
      return false;

   QM_OrderType signal_type = QM_BUY;
   double signal_extreme = 0.0;
   bool has_signal = false;
   if(five_down && close1 <= ema - strategy_extension_atr_mult * atr)
     {
      if(!(adx > strategy_adx_skip_threshold && ema < ema_prev))
        {
         signal_type = QM_BUY;
         signal_extreme = rates[1].low;
         has_signal = true;
        }
     }
   else if(five_up && close1 >= ema + strategy_extension_atr_mult * atr)
     {
      if(!(adx > strategy_adx_skip_threshold && ema > ema_prev))
        {
         signal_type = QM_SELL;
         signal_extreme = rates[1].high;
         has_signal = true;
        }
     }
   if(!has_signal || signal_extreme <= 0.0)
      return false;

   datetime latest_same_dir_exit = 0;
   if(HistorySelect(0, TimeCurrent()))
     {
      const int total_deals = HistoryDealsTotal();
      const int magic = QM_FrameworkMagic();
      for(int i = total_deals - 1; i >= 0; --i)
        {
         const ulong deal = HistoryDealGetTicket(i);
         if(deal == 0)
            continue;
         if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol)
            continue;
         if((int)HistoryDealGetInteger(deal, DEAL_MAGIC) != magic)
            continue;
         const ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY);
         if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY)
            continue;
         const ENUM_DEAL_TYPE dtype = (ENUM_DEAL_TYPE)HistoryDealGetInteger(deal, DEAL_TYPE);
         const bool closed_buy = (dtype == DEAL_TYPE_SELL);
         const bool closed_sell = (dtype == DEAL_TYPE_BUY);
         if((signal_type == QM_BUY && !closed_buy) || (signal_type == QM_SELL && !closed_sell))
            continue;
         latest_same_dir_exit = (datetime)HistoryDealGetInteger(deal, DEAL_TIME);
         break;
        }
     }
   if(latest_same_dir_exit > 0 && latest_same_dir_exit >= rates[strategy_cooldown_d1_bars].time)
      return false;

   const double entry_price = (signal_type == QM_BUY) ? ask : bid;
   if(entry_price <= 0.0)
      return false;

   req.type = signal_type;
   req.price = 0.0;
   if(signal_type == QM_BUY)
     {
      req.sl = entry_price - stop_distance;
      req.tp = entry_price + stop_distance * strategy_tp_r_mult;
      req.reason = StringFormat("GRF_L_%.5f", signal_extreme);
     }
   else
     {
      req.sl = entry_price + stop_distance;
      req.tp = entry_price - stop_distance * strategy_tp_r_mult;
      req.reason = StringFormat("GRF_S_%.5f", signal_extreme);
     }

   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card has no trailing stop, break-even move, partial close, or add-on logic.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   ulong ticket = 0;
   ENUM_POSITION_TYPE ptype = POSITION_TYPE_BUY;
   double open_price = 0.0;
   datetime open_time = 0;
   string comment = "";

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong pos_ticket = PositionGetTicket(i);
      if(pos_ticket == 0 || !PositionSelectByTicket(pos_ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      ticket = pos_ticket;
      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      comment = PositionGetString(POSITION_COMMENT);
      break;
     }
   if(ticket == 0 || open_price <= 0.0)
      return false;

   const double ema = QM_EMA(_Symbol, PERIOD_D1, strategy_ema_period, 1);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(ema > 0.0 && bid > 0.0 && ask > 0.0)
     {
      if(ptype == POSITION_TYPE_BUY && bid >= ema)
         return true;
      if(ptype == POSITION_TYPE_SELL && ask <= ema)
         return true;
     }

   if(!QM_IsNewBar(_Symbol, PERIOD_D1))
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int bars_needed = MathMax(strategy_time_exit_d1_bars + 1, 3);
   const int copied = CopyRates(_Symbol, PERIOD_D1, 0, bars_needed, rates); // perf-allowed: closed-bar exit check only after QM_IsNewBar with open position.
   if(copied < bars_needed)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   double entry_extreme = open_price;
   const int long_pos = StringFind(comment, "GRF_L_");
   const int short_pos = StringFind(comment, "GRF_S_");
   if(long_pos >= 0)
      entry_extreme = StringToDouble(StringSubstr(comment, long_pos + 6));
   else if(short_pos >= 0)
      entry_extreme = StringToDouble(StringSubstr(comment, short_pos + 6));

   const double close1 = rates[1].close;
   const double beyond = strategy_extreme_exit_atr_mult * atr;
   if(ptype == POSITION_TYPE_BUY && entry_extreme > 0.0 && close1 < entry_extreme - beyond)
      return true;
   if(ptype == POSITION_TYPE_SELL && entry_extreme > 0.0 && close1 > entry_extreme + beyond)
      return true;

   if(open_time > 0 && open_time <= rates[strategy_time_exit_d1_bars].time)
      return true;

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
   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   // FW1 — 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults.
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

   // Per-tick: trade management can adjust SL/TP on open positions.
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
   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
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
   // FW4: feeds closing-deal net-profits to the KS kill-switch.
   // No-op outside Q13 (when no baseline.json exists).
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
