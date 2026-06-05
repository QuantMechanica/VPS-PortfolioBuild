#property strict
#property version   "5.0"
#property description "QM5_10780 TradingView NY ORB Dynamic System"

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
input int    qm_ea_id                   = 10780;
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
input int    strategy_or_start_hhmm      = 830;
input int    strategy_or_end_hhmm        = 845;
input int    strategy_entry_start_hhmm   = 850;
input int    strategy_entry_end_hhmm     = 1200;
input int    strategy_hard_exit_hhmm     = 1325;
input bool   strategy_second_breakout    = false;
input int    strategy_confirmation_bars  = 1;
input int    strategy_filter_mode        = 3;       // 0 none, 1 VWAP, 2 VWAP+SMMA, 3 VWAP+SMMA+MACD+RSI
input int    strategy_rsi_period         = 14;
input double strategy_rsi_overbought     = 70.0;
input double strategy_rsi_oversold       = 30.0;
input int    strategy_macd_fast          = 12;
input int    strategy_macd_slow          = 26;
input int    strategy_macd_signal        = 9;
input int    strategy_smma_period        = 50;
input int    strategy_atr_period         = 14;
input double strategy_atr_sl_mult        = 1.0;
input bool   strategy_cap_at_or_range    = true;
input double strategy_or_cap_mult        = 1.0;
input double strategy_rr_target          = 2.0;
input int    strategy_max_spread_points  = 0;       // 0 disables non-card spread gate

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(strategy_max_spread_points > 0)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
         return true;
      if((ask - bid) / point > strategy_max_spread_points)
         return true;
     }
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

   MqlRates last_bar[1];
   if(CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 1, 1, last_bar) != 1) // perf-allowed: closed-bar structural ORB read
      return false;

   const datetime signal_broker_time = last_bar[0].time;
   const datetime signal_utc = QM_BrokerToUTC(signal_broker_time);
   const int ny_offset_hours = QM_IsUSDSTUTC(signal_utc) ? -4 : -5;
   const datetime signal_ny = signal_utc + (ny_offset_hours * 3600);

   MqlDateTime ny_dt;
   ZeroMemory(ny_dt);
   TimeToStruct(signal_ny, ny_dt);
   const int signal_hhmm = ny_dt.hour * 100 + ny_dt.min;
   if(signal_hhmm < strategy_entry_start_hhmm || signal_hhmm > strategy_entry_end_hhmm)
      return false;

   MqlDateTime ny_or_start = ny_dt;
   ny_or_start.hour = strategy_or_start_hhmm / 100;
   ny_or_start.min = strategy_or_start_hhmm % 100;
   ny_or_start.sec = 0;
   const datetime or_start_ny = StructToTime(ny_or_start);
   const datetime or_start_utc = or_start_ny - (ny_offset_hours * 3600);
   const datetime or_start_broker = QM_UTCToBroker(or_start_utc);

   MqlRates rates[];
   ArrayResize(rates, 0);
   const int copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, or_start_broker, signal_broker_time, rates); // perf-allowed: closed-bar OR/VWAP session scan
   if(copied <= 2)
      return false;

   double or_high = -DBL_MAX;
   double or_low = DBL_MAX;
   bool have_or = false;
   double vwap_num = 0.0;
   double vwap_den = 0.0;
   double signal_close = 0.0;
   double prev1_close = 0.0;
   double prev2_close = 0.0;
   datetime signal_time = 0;
   datetime prev1_time = 0;
   datetime prev2_time = 0;
   bool earlier_long_break = false;
   bool earlier_short_break = false;

   for(int i = 0; i < copied; ++i)
     {
      const datetime bar_time = rates[i].time;
      if(bar_time > signal_broker_time)
         continue;

      const datetime bar_utc = QM_BrokerToUTC(bar_time);
      const int bar_ny_offset = QM_IsUSDSTUTC(bar_utc) ? -4 : -5;
      const datetime bar_ny = bar_utc + (bar_ny_offset * 3600);
      MqlDateTime bar_dt;
      ZeroMemory(bar_dt);
      TimeToStruct(bar_ny, bar_dt);
      const int bar_hhmm = bar_dt.hour * 100 + bar_dt.min;

      if(bar_hhmm >= strategy_or_start_hhmm && bar_hhmm < strategy_or_end_hhmm)
        {
         or_high = MathMax(or_high, rates[i].high);
         or_low = MathMin(or_low, rates[i].low);
         have_or = true;
        }

      if(have_or && bar_time < signal_broker_time)
        {
         if(rates[i].close > or_high)
            earlier_long_break = true;
         if(rates[i].close < or_low)
            earlier_short_break = true;
        }

      if(bar_hhmm >= strategy_or_start_hhmm && bar_time <= signal_broker_time)
        {
         const double vol = (rates[i].tick_volume > 0) ? (double)rates[i].tick_volume : 1.0;
         const double typical = (rates[i].high + rates[i].low + rates[i].close) / 3.0;
         vwap_num += typical * vol;
         vwap_den += vol;
        }

      if(bar_time > signal_time)
        {
         prev2_time = prev1_time;
         prev2_close = prev1_close;
         prev1_time = signal_time;
         prev1_close = signal_close;
         signal_time = bar_time;
         signal_close = rates[i].close;
        }
      else if(bar_time > prev1_time)
        {
         prev2_time = prev1_time;
         prev2_close = prev1_close;
         prev1_time = bar_time;
         prev1_close = rates[i].close;
        }
      else if(bar_time > prev2_time)
        {
         prev2_time = bar_time;
         prev2_close = rates[i].close;
        }
     }

   if(!have_or || or_high <= or_low || signal_time != signal_broker_time || prev1_time <= 0)
      return false;

   if(strategy_confirmation_bars >= 1 && (prev1_close < or_low || prev1_close > or_high))
      return false;
   if(strategy_confirmation_bars >= 2 && (prev2_time <= 0 || prev2_close < or_low || prev2_close > or_high))
      return false;

   const bool long_break = (signal_close > or_high && prev1_close <= or_high);
   const bool short_break = (signal_close < or_low && prev1_close >= or_low);
   if(!long_break && !short_break)
      return false;

   if(strategy_second_breakout)
     {
      if(long_break && (!earlier_long_break || prev1_close < or_low || prev1_close > or_high))
         return false;
      if(short_break && (!earlier_short_break || prev1_close < or_low || prev1_close > or_high))
         return false;
     }

   const double vwap = (vwap_den > 0.0) ? (vwap_num / vwap_den) : 0.0;
   if(strategy_filter_mode >= 1)
     {
      if(vwap <= 0.0)
         return false;
      if(long_break && signal_close <= vwap)
         return false;
      if(short_break && signal_close >= vwap)
         return false;
     }

   if(strategy_filter_mode >= 2)
     {
      const double smma = QM_SMMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_smma_period, 1);
      if(smma <= 0.0)
         return false;
      if(long_break && signal_close <= smma)
         return false;
      if(short_break && signal_close >= smma)
         return false;
     }

   if(strategy_filter_mode >= 3)
     {
      const double macd_main = QM_MACD_Main(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);
      const double macd_sig = QM_MACD_Signal(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);
      const double rsi = QM_RSI(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_rsi_period, 1);
      if(rsi <= 0.0)
         return false;
      if(long_break && (macd_main <= macd_sig || rsi >= strategy_rsi_overbought))
         return false;
      if(short_break && (macd_main >= macd_sig || rsi <= strategy_rsi_oversold))
         return false;
     }

   const QM_OrderType side = long_break ? QM_BUY : QM_SELL;
   const double entry = long_break ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                   : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(entry <= 0.0 || point <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(atr <= 0.0 || strategy_atr_sl_mult <= 0.0 || strategy_rr_target <= 0.0)
      return false;

   double stop_distance = atr * strategy_atr_sl_mult;
   const double or_range = or_high - or_low;
   if(strategy_cap_at_or_range && strategy_or_cap_mult > 0.0 && or_range > 0.0)
      stop_distance = MathMin(stop_distance, or_range * strategy_or_cap_mult);

   const int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const double min_stop_distance = MathMax(1, stops_level + 2) * point;
   stop_distance = MathMax(stop_distance, min_stop_distance);

   const double adjusted_atr = stop_distance;
   const double sl = QM_StopATRFromValue(_Symbol, side, entry, adjusted_atr, 1.0);
   const double tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_rr_target);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = long_break ? "NY_ORB_LONG" : "NY_ORB_SHORT";
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card baseline uses fixed SL/TP and no adaptive daily PnL or trailing logic.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const datetime broker_now = TimeCurrent();
   const datetime utc_now = QM_BrokerToUTC(broker_now);
   const int ny_offset_hours = QM_IsUSDSTUTC(utc_now) ? -4 : -5;
   const datetime ny_now = utc_now + (ny_offset_hours * 3600);
   MqlDateTime ny_dt;
   ZeroMemory(ny_dt);
   TimeToStruct(ny_now, ny_dt);
   const int hhmm = ny_dt.hour * 100 + ny_dt.min;
   return (hhmm >= strategy_hard_exit_hhmm);
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
