#property strict
#property version   "5.0"
#property description "QuantMechanica V5 EA skeleton template"

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
//   - QM_FrameworkTrackOpenPositionMae / QM_FrameworkHandleFridayClose /
//     QM_KillSwitchCheck / QM_NewsAllowsTrade
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
input int    qm_ea_id                   = 39003;
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
input int    InpPPZLookback                         = 20;
input int    InpTrendEMA                            = 21;
input int    strategy_atr_period                    = 14;
input double strategy_ppz_zone_atr_fraction         = 0.50;
input double strategy_pinbar_wick_fraction          = 0.65;
input double strategy_pinbar_body_fraction          = 0.25;
input double strategy_spread_atr_multiplier         = 1.80;
input int    strategy_sl_buffer_pips                = 2;
input double strategy_reward_risk                   = 2.50;
input double strategy_slippage_tolerance_ticks      = 3.00;
input int    strategy_max_open_positions            = 1;
input double strategy_daily_entry_loss_limit_pct    = 2.00;
input double strategy_daily_drawdown_stop_pct       = 2.50;
input double strategy_total_drawdown_stop_pct       = 5.00;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   static double initial_equity = 0.0;
   static int balance_day_key = 0;
   static double day_start_balance = 0.0;
   static int atr_day_key = 0;
   static double cached_atr = 0.0;
   const datetime broker_now = TimeCurrent();
   const double equity_now = AccountInfoDouble(ACCOUNT_EQUITY);
   const double balance_now = AccountInfoDouble(ACCOUNT_BALANCE);
   if(initial_equity <= 0.0 && equity_now > 0.0)
      initial_equity = equity_now;

   MqlDateTime broker_parts;
   TimeToStruct(broker_now, broker_parts);
   const int current_balance_day_key =
      broker_parts.year * 10000 + broker_parts.mon * 100 + broker_parts.day;
   if(current_balance_day_key != balance_day_key)
     {
      balance_day_key = current_balance_day_key;
      day_start_balance = balance_now;
     }

   const int current_atr_day_key = QM_CalendarPeriodKey(PERIOD_D1, _Symbol, 0);
   if(current_atr_day_key > 0 && current_atr_day_key != atr_day_key)
     {
      atr_day_key = current_atr_day_key;
      cached_atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
     }

   const int magic = QM_FrameworkMagic();
   const int open_count = QM_TM_OpenPositionCount(magic);
   // The skeleton invokes this hook before management. Existing exposure must
   // reach its protective trail and hard-stop exit; entry admission is checked
   // again in Strategy_EntrySignal.
   if(open_count > 0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   const datetime utc_now = QM_BrokerToUTC(broker_now);
   MqlDateTime utc_parts;
   TimeToStruct(utc_now, utc_parts);
   if((utc_parts.hour == 23 && utc_parts.min >= 55) ||
      (utc_parts.hour == 0 && utc_parts.min <= 5))
      return true;

   const double realized_today = balance_now - day_start_balance;
   if(day_start_balance > 0.0 &&
      realized_today <= -(day_start_balance * strategy_daily_entry_loss_limit_pct / 100.0))
      return true;
   if(day_start_balance > 0.0 && equity_now > 0.0 &&
      equity_now <= day_start_balance * (1.0 - strategy_daily_drawdown_stop_pct / 100.0))
      return true;
   if(initial_equity > 0.0 && equity_now > 0.0 &&
      equity_now <= initial_equity * (1.0 - strategy_total_drawdown_stop_pct / 100.0))
      return true;

   if(cached_atr <= 0.0)
      return true;
   // .DWX Model-4 spread can be exactly zero; only a genuinely positive,
   // overly wide spread blocks entry.
   if(ask > bid && (ask - bid) > strategy_spread_atr_multiplier * cached_atr)
      return true;

   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(InpPPZLookback < 1 || InpTrendEMA < 1 || strategy_atr_period < 1 ||
      strategy_ppz_zone_atr_fraction <= 0.0 ||
      strategy_pinbar_wick_fraction <= 0.0 || strategy_pinbar_wick_fraction > 1.0 ||
      strategy_pinbar_body_fraction < 0.0 || strategy_pinbar_body_fraction > 1.0 ||
      strategy_sl_buffer_pips < 1 || strategy_reward_risk <= 0.0 ||
      strategy_slippage_tolerance_ticks <= 0.0 ||
      strategy_max_open_positions < 1)
      return false;

   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) >= strategy_max_open_positions)
      return false;

   // Re-check the card's account-level entry halt after any same-tick close.
   int closed_trades_today = 0;
   const double realized_today = QM_ChartUITodayPnL(0, closed_trades_today);
   const double day_start_balance = AccountInfoDouble(ACCOUNT_BALANCE) - realized_today;
   if(day_start_balance > 0.0 &&
      realized_today <= -(day_start_balance * strategy_daily_entry_loss_limit_pct / 100.0))
      return false;
   if(Strategy_ExitSignal())
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(point <= 0.0 || tick_size <= 0.0)
      return false;
   const int deviation_points =
      (int)MathCeil(strategy_slippage_tolerance_ticks * tick_size / point);
   if(deviation_points < 1)
      return false;
   QM_EntryConfigure(qm_ea_id,
                     qm_news_mode_legacy,
                     deviation_points,
                     qm_stress_reject_probability,
                     qm_news_temporal,
                     qm_news_compliance,
                     magic);

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   const double ema = QM_EMA(_Symbol, PERIOD_D1, InpTrendEMA, 1);
   if(atr <= 0.0 || ema <= 0.0)
      return false;

   const double open_1 = iOpen(_Symbol, PERIOD_D1, 1);    // perf-allowed: bespoke PPZ/pinbar structure, once per closed D1 bar.
   const double high_1 = iHigh(_Symbol, PERIOD_D1, 1);    // perf-allowed: bespoke PPZ/pinbar structure, once per closed D1 bar.
   const double low_1 = iLow(_Symbol, PERIOD_D1, 1);      // perf-allowed: bespoke PPZ/pinbar structure, once per closed D1 bar.
   const double close_1 = iClose(_Symbol, PERIOD_D1, 1);  // perf-allowed: bespoke PPZ/pinbar structure, once per closed D1 bar.
   if(open_1 <= 0.0 || high_1 <= low_1 || low_1 <= 0.0 || close_1 <= 0.0)
      return false;

   double ppz_support = 0.0;
   double ppz_resistance = 0.0;
   for(int shift = 2; shift <= InpPPZLookback + 1; ++shift)
     {
      const double prior_low = iLow(_Symbol, PERIOD_D1, shift);    // perf-allowed: bounded card-authorized PPZ window behind the framework new-bar gate.
      const double prior_high = iHigh(_Symbol, PERIOD_D1, shift);  // perf-allowed: bounded card-authorized PPZ window behind the framework new-bar gate.
      if(prior_low <= 0.0 || prior_high <= prior_low)
         return false;
      if(ppz_support <= 0.0 || prior_low < ppz_support)
         ppz_support = prior_low;
      if(ppz_resistance <= 0.0 || prior_high > ppz_resistance)
         ppz_resistance = prior_high;
     }

   if(ppz_support <= 0.0 || ppz_resistance <= 0.0)
      return false;

   const double total_range = high_1 - low_1;
   const double body = MathAbs(close_1 - open_1);
   const double lower_wick = MathMin(open_1, close_1) - low_1;
   const double upper_wick = high_1 - MathMax(open_1, close_1);
   if(total_range <= 0.0 || body > strategy_pinbar_body_fraction * total_range)
      return false;

   const double ppz_tolerance = strategy_ppz_zone_atr_fraction * atr;
   const bool bullish_pinbar = (close_1 > open_1 &&
                                lower_wick >= strategy_pinbar_wick_fraction * total_range);
   const bool bearish_pinbar = (close_1 < open_1 &&
                                upper_wick >= strategy_pinbar_wick_fraction * total_range);
   const bool at_support = (MathAbs(low_1 - ppz_support) <= ppz_tolerance);
   const bool at_resistance = (MathAbs(high_1 - ppz_resistance) <= ppz_tolerance);
   const double sl_buffer = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_buffer_pips);
   if(sl_buffer <= 0.0)
      return false;

   if(bullish_pinbar && at_support && close_1 > ema)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double sl = QM_StopRulesNormalizePrice(_Symbol, low_1 - sl_buffer);
      if(ask <= 0.0 || sl <= 0.0 || sl >= ask)
         return false;
      const double tp = QM_TakeRR(_Symbol, QM_BUY, ask, sl, strategy_reward_risk);
      if(tp <= ask)
         return false;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = sl;
      req.tp = tp;
      req.reason = "JAMES16_PPZ_PINBAR_LONG";
      req.symbol_slot = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
     }

   if(bearish_pinbar && at_resistance && close_1 < ema)
     {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double sl = QM_StopRulesNormalizePrice(_Symbol, high_1 + sl_buffer);
      if(bid <= 0.0 || sl <= bid)
         return false;
      const double tp = QM_TakeRR(_Symbol, QM_SELL, bid, sl, strategy_reward_risk);
      if(tp <= 0.0 || tp >= bid)
         return false;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = sl;
      req.tp = tp;
      req.reason = "JAMES16_PPZ_PINBAR_SHORT";
      req.symbol_slot = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return;

   // A calendar key does not consume the framework's single-use new-bar gate.
   // This keeps the 20-bar structural trail out of the Model-4 per-tick path.
   static int last_trailing_day_key = 0;
   const int trailing_day_key = QM_CalendarPeriodKey(PERIOD_D1, _Symbol, 0);
   if(trailing_day_key <= 0 || trailing_day_key == last_trailing_day_key)
      return;
   last_trailing_day_key = trailing_day_key;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double sl_buffer = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_buffer_pips);
   if(point <= 0.0 || sl_buffer <= 0.0 || InpPPZLookback < 1)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic ||
         PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const ENUM_POSITION_TYPE position_type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const bool is_buy = (position_type == POSITION_TYPE_BUY);
      const QM_OrderType side = is_buy ? QM_BUY : QM_SELL;
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double structure = QM_StopStructure(_Symbol, side, open_price, InpPPZLookback);
      if(structure <= 0.0)
         continue;

      const double target_sl = QM_StopRulesNormalizePrice(
         _Symbol, is_buy ? structure - sl_buffer : structure + sl_buffer);
      const double market_price = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(target_sl <= 0.0 || market_price <= 0.0)
         continue;
      if(is_buy && target_sl >= market_price)
         continue;
      if(!is_buy && target_sl <= market_price)
         continue;

      const bool improves = (current_sl <= 0.0) ||
                            (is_buy ? target_sl > current_sl + point * 0.5
                                    : target_sl < current_sl - point * 0.5);
      if(improves)
         QM_TM_MoveSL(ticket, target_sl, "JAMES16_DYNAMIC_SWING_TRAIL");
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   static double initial_equity = 0.0;
   static int balance_day_key = 0;
   static double day_start_balance = 0.0;
   const datetime broker_now = TimeCurrent();
   const double equity_now = AccountInfoDouble(ACCOUNT_EQUITY);
   const double balance_now = AccountInfoDouble(ACCOUNT_BALANCE);
   if(initial_equity <= 0.0 && equity_now > 0.0)
      initial_equity = equity_now;

   MqlDateTime broker_parts;
   TimeToStruct(broker_now, broker_parts);
   const int current_balance_day_key =
      broker_parts.year * 10000 + broker_parts.mon * 100 + broker_parts.day;
   if(current_balance_day_key != balance_day_key)
     {
      balance_day_key = current_balance_day_key;
      day_start_balance = balance_now;
     }

   if(day_start_balance > 0.0 && equity_now > 0.0 &&
      equity_now <= day_start_balance * (1.0 - strategy_daily_drawdown_stop_pct / 100.0))
      return true;
   if(initial_equity > 0.0 && equity_now > 0.0 &&
      equity_now <= initial_equity * (1.0 - strategy_total_drawdown_stop_pct / 100.0))
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
