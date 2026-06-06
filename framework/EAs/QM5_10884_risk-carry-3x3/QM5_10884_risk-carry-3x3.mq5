#property strict
#property version   "5.0"
#property description "QM5_10884 Risk.net G10 Carry 3x3 Monthly Rebalance"

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
input int    qm_ea_id                   = 10884;
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
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
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
input int    strategy_atr_period              = 20;
input double strategy_atr_sl_mult             = 2.5;
input int    strategy_vol_lookback_days       = 252;
input double strategy_vol_percentile_cap      = 0.90;
input int    strategy_top_currencies          = 3;
input int    strategy_bottom_currencies       = 3;
input int    strategy_rebalance_first_days    = 3;
input int    strategy_rebalance_hour_broker   = 0;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // No Trade Filter (time, spread, news): framework handles news and Friday close;
   // this card adds only D1/monthly timing, which is enforced in entry/exit.
   if(_Period != PERIOD_D1)
      return true;

   const string symbols[7] =
     {"EURUSD.DWX","GBPUSD.DWX","USDJPY.DWX","AUDUSD.DWX",
      "USDCAD.DWX","USDCHF.DWX","NZDUSD.DWX"};
   bool in_universe = false;
   for(int i = 0; i < 7; ++i)
      if(_Symbol == symbols[i])
         in_universe = true;

   if(!in_universe)
      return true;

   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Trade Entry: first tradable D1 bar of each month, long top-3 carry
   // currencies vs bottom-3 currencies when the current DWX pair maps directly.
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.day_of_week == 0 || dt.day_of_week == 6)
      return false;
   if(dt.day > strategy_rebalance_first_days)
      return false;
   if(dt.hour < strategy_rebalance_hour_broker)
      return false;

   static int last_entry_month_key = -1;
   const int month_key = dt.year * 100 + dt.mon;
   if(last_entry_month_key == month_key)
      return false;
   last_entry_month_key = month_key;

   if(strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0 ||
      strategy_vol_lookback_days < strategy_atr_period ||
      strategy_top_currencies <= 0 || strategy_bottom_currencies <= 0)
      return false;

   const double current_atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(current_atr <= 0.0)
      return false;

   int valid_atr = 0;
   int le_current = 0;
   for(int shift = 1; shift <= strategy_vol_lookback_days; ++shift)
     {
      const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, shift);
      if(atr <= 0.0)
         return false;
      valid_atr++;
      if(atr <= current_atr)
         le_current++;
     }
   if(valid_atr < strategy_vol_lookback_days)
      return false;
   const double atr_percentile = (double)le_current / (double)valid_atr;
   if(atr_percentile > strategy_vol_percentile_cap)
      return false;

   const string currencies[8] = {"USD","EUR","GBP","JPY","AUD","CAD","CHF","NZD"};
   const string symbols[7] =
     {"EURUSD.DWX","GBPUSD.DWX","USDJPY.DWX","AUDUSD.DWX",
      "USDCAD.DWX","USDCHF.DWX","NZDUSD.DWX"};
   const string bases[7]  = {"EUR","GBP","USD","AUD","USD","USD","NZD"};
   const string quotes[7] = {"USD","USD","JPY","USD","CAD","CHF","USD"};

   double carry[8];
   int samples[8];
   ArrayInitialize(carry, 0.0);
   ArrayInitialize(samples, 0);

   for(int p = 0; p < 7; ++p)
     {
      const string sym = symbols[p];
      SymbolSelect(sym, true);

      double px = SymbolInfoDouble(sym, SYMBOL_BID);
      if(px <= 0.0)
         px = SymbolInfoDouble(sym, SYMBOL_ASK);
      if(px <= 0.0)
         px = SymbolInfoDouble(sym, SYMBOL_LAST);

      const double point = SymbolInfoDouble(sym, SYMBOL_POINT);
      const double swap_long = SymbolInfoDouble(sym, SYMBOL_SWAP_LONG);
      const double swap_short = SymbolInfoDouble(sym, SYMBOL_SWAP_SHORT);
      if(px <= 0.0 || point <= 0.0 || (swap_long == 0.0 && swap_short == 0.0))
         return false;

      int base_idx = -1;
      int quote_idx = -1;
      for(int c = 0; c < 8; ++c)
        {
         if(currencies[c] == bases[p])
            base_idx = c;
         if(currencies[c] == quotes[p])
            quote_idx = c;
        }
      if(base_idx < 0 || quote_idx < 0)
         return false;

      carry[base_idx] += (swap_long * point) / px;
      samples[base_idx]++;
      carry[quote_idx] += (swap_short * point) / px;
      samples[quote_idx]++;
     }

   for(int c = 0; c < 8; ++c)
     {
      if(samples[c] <= 0)
         return false;
      carry[c] /= (double)samples[c];
     }

   int order[8];
   for(int i = 0; i < 8; ++i)
      order[i] = i;
   for(int a = 0; a < 7; ++a)
      for(int b = 0; b < 7 - a; ++b)
         if(carry[order[b]] < carry[order[b + 1]])
           {
            const int tmp = order[b];
            order[b] = order[b + 1];
            order[b + 1] = tmp;
           }

   int pair_idx = -1;
   for(int p = 0; p < 7; ++p)
      if(_Symbol == symbols[p])
         pair_idx = p;
   if(pair_idx < 0)
      return false;

   int base_idx = -1;
   int quote_idx = -1;
   for(int c = 0; c < 8; ++c)
     {
      if(currencies[c] == bases[pair_idx])
         base_idx = c;
      if(currencies[c] == quotes[pair_idx])
         quote_idx = c;
     }
   if(base_idx < 0 || quote_idx < 0)
      return false;

   bool base_top = false;
   bool quote_top = false;
   bool base_bottom = false;
   bool quote_bottom = false;
   int top_n = strategy_top_currencies;
   if(top_n > 8)
      top_n = 8;
   int bottom_n = strategy_bottom_currencies;
   if(bottom_n > 8)
      bottom_n = 8;
   for(int i = 0; i < top_n; ++i)
     {
      if(order[i] == base_idx)
         base_top = true;
      if(order[i] == quote_idx)
         quote_top = true;
     }
   for(int i = 0; i < bottom_n; ++i)
     {
      const int idx = order[7 - i];
      if(idx == base_idx)
         base_bottom = true;
      if(idx == quote_idx)
         quote_bottom = true;
     }

   int direction = 0;
   if(base_top && quote_bottom)
      direction = 1;
   if(quote_top && base_bottom)
      direction = -1;
   if(direction == 0)
      return false;

   const double expected_carry = (direction > 0)
      ? SymbolInfoDouble(_Symbol, SYMBOL_SWAP_LONG)
      : SymbolInfoDouble(_Symbol, SYMBOL_SWAP_SHORT);
   if(expected_carry <= 0.0)
      return false;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   const double entry = (direction > 0)
      ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
      : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, req.type, entry, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;

   req.reason = (direction > 0) ? "RISK_CARRY_3X3_LONG" : "RISK_CARRY_3X3_SHORT";
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Trade Management: card specifies no trailing, break-even, partial close,
   // or in-month stop adjustment beyond the fixed emergency ATR stop.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   // Trade Close: on monthly rebalance, close if this pair is no longer in the
   // selected high-vs-low basket or if carry-ranking data is unavailable.
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.day_of_week == 0 || dt.day_of_week == 6)
      return false;
   if(dt.day > strategy_rebalance_first_days)
      return false;
   if(dt.hour < strategy_rebalance_hour_broker)
      return false;

   const int magic = QM_FrameworkMagic();
   ENUM_POSITION_TYPE current_type = POSITION_TYPE_BUY;
   bool have_position = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      current_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      have_position = true;
     }
   if(!have_position)
      return false;

   const string currencies[8] = {"USD","EUR","GBP","JPY","AUD","CAD","CHF","NZD"};
   const string symbols[7] =
     {"EURUSD.DWX","GBPUSD.DWX","USDJPY.DWX","AUDUSD.DWX",
      "USDCAD.DWX","USDCHF.DWX","NZDUSD.DWX"};
   const string bases[7]  = {"EUR","GBP","USD","AUD","USD","USD","NZD"};
   const string quotes[7] = {"USD","USD","JPY","USD","CAD","CHF","USD"};

   double carry[8];
   int samples[8];
   ArrayInitialize(carry, 0.0);
   ArrayInitialize(samples, 0);

   for(int p = 0; p < 7; ++p)
     {
      const string sym = symbols[p];
      SymbolSelect(sym, true);

      double px = SymbolInfoDouble(sym, SYMBOL_BID);
      if(px <= 0.0)
         px = SymbolInfoDouble(sym, SYMBOL_ASK);
      if(px <= 0.0)
         px = SymbolInfoDouble(sym, SYMBOL_LAST);

      const double point = SymbolInfoDouble(sym, SYMBOL_POINT);
      const double swap_long = SymbolInfoDouble(sym, SYMBOL_SWAP_LONG);
      const double swap_short = SymbolInfoDouble(sym, SYMBOL_SWAP_SHORT);
      if(px <= 0.0 || point <= 0.0 || (swap_long == 0.0 && swap_short == 0.0))
         return true;

      int base_idx = -1;
      int quote_idx = -1;
      for(int c = 0; c < 8; ++c)
        {
         if(currencies[c] == bases[p])
            base_idx = c;
         if(currencies[c] == quotes[p])
            quote_idx = c;
        }
      if(base_idx < 0 || quote_idx < 0)
         return true;

      carry[base_idx] += (swap_long * point) / px;
      samples[base_idx]++;
      carry[quote_idx] += (swap_short * point) / px;
      samples[quote_idx]++;
     }

   for(int c = 0; c < 8; ++c)
     {
      if(samples[c] <= 0)
         return true;
      carry[c] /= (double)samples[c];
     }

   int order[8];
   for(int i = 0; i < 8; ++i)
      order[i] = i;
   for(int a = 0; a < 7; ++a)
      for(int b = 0; b < 7 - a; ++b)
         if(carry[order[b]] < carry[order[b + 1]])
           {
            const int tmp = order[b];
            order[b] = order[b + 1];
            order[b + 1] = tmp;
           }

   int pair_idx = -1;
   for(int p = 0; p < 7; ++p)
      if(_Symbol == symbols[p])
         pair_idx = p;
   if(pair_idx < 0)
      return true;

   int base_idx = -1;
   int quote_idx = -1;
   for(int c = 0; c < 8; ++c)
     {
      if(currencies[c] == bases[pair_idx])
         base_idx = c;
      if(currencies[c] == quotes[pair_idx])
         quote_idx = c;
     }
   if(base_idx < 0 || quote_idx < 0)
      return true;

   bool base_top = false;
   bool quote_top = false;
   bool base_bottom = false;
   bool quote_bottom = false;
   int top_n = strategy_top_currencies;
   if(top_n > 8)
      top_n = 8;
   int bottom_n = strategy_bottom_currencies;
   if(bottom_n > 8)
      bottom_n = 8;
   for(int i = 0; i < top_n; ++i)
     {
      if(order[i] == base_idx)
         base_top = true;
      if(order[i] == quote_idx)
         quote_top = true;
     }
   for(int i = 0; i < bottom_n; ++i)
     {
      const int idx = order[7 - i];
      if(idx == base_idx)
         base_bottom = true;
      if(idx == quote_idx)
         quote_bottom = true;
     }

   int desired_direction = 0;
   if(base_top && quote_bottom)
      desired_direction = 1;
   if(quote_top && base_bottom)
      desired_direction = -1;
   if(desired_direction == 0)
      return true;

   const double expected_carry = (desired_direction > 0)
      ? SymbolInfoDouble(_Symbol, SYMBOL_SWAP_LONG)
      : SymbolInfoDouble(_Symbol, SYMBOL_SWAP_SHORT);
   if(expected_carry <= 0.0)
      return true;

   if(current_type == POSITION_TYPE_BUY && desired_direction < 0)
      return true;
   if(current_type == POSITION_TYPE_SELL && desired_direction > 0)
      return true;

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   // News Filter Hook: no card-specific override; central framework filter is callable for P8.
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
