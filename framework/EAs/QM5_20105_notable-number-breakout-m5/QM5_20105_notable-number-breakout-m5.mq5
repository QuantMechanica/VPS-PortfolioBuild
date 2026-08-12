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
input int    qm_ea_id                   = 20105;
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
input string strategy_notable_suffix     = "88";
input int    strategy_lookback_d1_bars   = 41;
input double strategy_sl_price_pct       = 0.75;
input double strategy_tp_price_pct       = 1.00;
input int    strategy_window_start_hhmm  = 1400;
input int    strategy_window_end_hhmm    = 2200;

const bool   g_strnn_fade = false;
const string g_strnn_strategy_id = "STR-009";
const string g_strnn_reason_prefix = "S009";

datetime g_strnn_last_entry_bar = 0;
datetime g_strnn_last_data_log_bar = 0;
datetime g_strnn_cache_d1_bar = 0;
int g_strnn_cache_lookback = 0;
bool g_strnn_cache_valid = false;
double g_strnn_cache_min_low = 0.0;
double g_strnn_cache_max_high = 0.0;
datetime g_strnn_latch_d1_bar = 0;
int g_strnn_latch_direction = 0;
long g_strnn_latch_level_pips = 0;

bool StrategyNN_ParseSuffix(int &width,
                            long &suffix_value,
                            long &modulus)
  {
   width = StringLen(strategy_notable_suffix);
   suffix_value = 0;
   modulus = 1;
   if(width < 2 || width > 4)
      return false;
   for(int i = 0; i < width; ++i)
     {
      const ushort ch = StringGetCharacter(strategy_notable_suffix, i);
      if(ch < (ushort)'0' || ch > (ushort)'9')
         return false;
      suffix_value = suffix_value * 10 + (long)(ch - (ushort)'0');
      modulus *= 10;
     }
   return true;
  }

bool StrategyNN_HhmmValid(const int hhmm)
  {
   if(hhmm < 0 || hhmm > 2359)
      return false;
   const int hour = hhmm / 100;
   const int minute = hhmm % 100;
   return (hour >= 0 && hour < 24 && minute >= 0 && minute < 60);
  }

bool StrategyNN_WindowAllows(const datetime broker_bar_open)
  {
   MqlDateTime parts;
   TimeToStruct(broker_bar_open, parts);
   const int hhmm = parts.hour * 100 + parts.min;
   if(strategy_window_start_hhmm == strategy_window_end_hhmm)
      return true;
   if(strategy_window_start_hhmm < strategy_window_end_hhmm)
      return (hhmm >= strategy_window_start_hhmm &&
              hhmm < strategy_window_end_hhmm);
   return (hhmm >= strategy_window_start_hhmm ||
           hhmm < strategy_window_end_hhmm);
  }

double StrategyNN_TradeTick()
  {
   double tick = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick <= 0.0)
      tick = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   return tick;
  }

double StrategyNN_PipSize()
  {
   const string profit_currency =
      SymbolInfoString(_Symbol, SYMBOL_CURRENCY_PROFIT);
   if(profit_currency == "JPY")
      return 0.01;
   string base_symbol = _Symbol;
   const int dot = StringFind(base_symbol, ".");
   if(dot > 0)
      base_symbol = StringSubstr(base_symbol, 0, dot);
   if(StringLen(base_symbol) >= 3 &&
      StringSubstr(base_symbol, StringLen(base_symbol) - 3) == "JPY")
      return 0.01;
   return 0.0001;
  }

double StrategyNN_AlignPrice(const double raw_price,
                             const int direction)
  {
   const double tick = StrategyNN_TradeTick();
   if(raw_price <= 0.0 || tick <= 0.0)
      return 0.0;
   const double scaled = raw_price / tick;
   double units = MathRound(scaled);
   if(direction < 0)
      units = MathFloor(scaled + 1e-9);
   else if(direction > 0)
      units = MathCeil(scaled - 1e-9);
   return QM_TM_NormalizePrice(_Symbol, units * tick);
  }

bool StrategyNN_CurrentM5(datetime &bar_time,
                          double &bar_open)
  {
   bar_time = iTime(_Symbol, PERIOD_M5, 0); // perf-allowed: immutable just-formed M5 opening time, once per skeleton-gated call
   bar_open = iOpen(_Symbol, PERIOD_M5, 0); // perf-allowed: immutable just-formed M5 opening price, once per skeleton-gated call
   return (bar_time > 0 && bar_open > 0.0);
  }

void StrategyNN_LogDataMissing(const string component,
                               const datetime bar_time)
  {
   if(bar_time > 0 && bar_time == g_strnn_last_data_log_bar)
      return;
   g_strnn_last_data_log_bar = bar_time;
   QM_LogEvent(
      QM_WARN,
      SETUP_DATA_MISSING,
      StringFormat(
         "{\"strategy\":\"%s\",\"component\":\"%s\",\"bar_time\":%I64d}",
         QM_LoggerEscapeJson(g_strnn_strategy_id),
         QM_LoggerEscapeJson(component),
         (long)bar_time));
  }

bool StrategyNN_HasOwnPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic ||
         PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      return true;
     }
   return false;
  }

bool StrategyNN_UpdateD1Cache()
  {
   MqlRates forming_d1;
   if(!QM_ReadBar(_Symbol, PERIOD_D1, 0, forming_d1))
      return false;
   if(g_strnn_cache_valid &&
      forming_d1.time == g_strnn_cache_d1_bar &&
      strategy_lookback_d1_bars == g_strnn_cache_lookback)
      return true;

   MqlRates d1_rates[];
   ArraySetAsSeries(d1_rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, strategy_lookback_d1_bars, d1_rates); // perf-allowed: bounded N-day gate cached once per D1 bar
   if(copied != strategy_lookback_d1_bars || copied <= 0)
      return false;

   double min_low = d1_rates[0].low;
   double max_high = d1_rates[0].high;
   if(min_low <= 0.0 || max_high <= 0.0 || max_high < min_low)
      return false;
   for(int i = 1; i < copied; ++i)
     {
      if(d1_rates[i].low <= 0.0 ||
         d1_rates[i].high <= 0.0 ||
         d1_rates[i].high < d1_rates[i].low)
         return false;
      min_low = MathMin(min_low, d1_rates[i].low);
      max_high = MathMax(max_high, d1_rates[i].high);
     }

   g_strnn_cache_d1_bar = forming_d1.time;
   g_strnn_cache_lookback = strategy_lookback_d1_bars;
   g_strnn_cache_min_low = min_low;
   g_strnn_cache_max_high = max_high;
   g_strnn_cache_valid = true;
   return true;
  }

bool StrategyNN_CrossedLevel(const double previous_open,
                             const double current_open,
                             const long suffix_value,
                             const long modulus,
                             long &level_pips,
                             double &level_price,
                             bool &descending)
  {
   level_pips = 0;
   level_price = 0.0;
   descending = (previous_open > current_open);
   if(previous_open == current_open || modulus <= 0)
      return false;

   const double pip_size = StrategyNN_PipSize();
   if(pip_size <= 0.0)
      return false;
   const double previous_pips = previous_open / pip_size;
   const double current_pips = current_open / pip_size;

   if(descending)
     {
      const long upper =
         (long)MathCeil(previous_pips - 1e-9) - 1;
      long candidate =
         (upper / modulus) * modulus + suffix_value;
      if(candidate > upper)
         candidate -= modulus;
      if(candidate <= 0 ||
         (double)candidate + 1e-9 < current_pips)
         return false;
      level_pips = candidate;
     }
   else
     {
      const long lower =
         (long)MathFloor(previous_pips + 1e-9) + 1;
      long candidate =
         (lower / modulus) * modulus + suffix_value;
      if(candidate < lower)
         candidate += modulus;
      if(candidate <= 0 ||
         (double)candidate - 1e-9 > current_pips)
         return false;
      level_pips = candidate;
     }

   level_price =
      StrategyNN_AlignPrice((double)level_pips * pip_size, 0);
   const double tolerance = StrategyNN_TradeTick() * 0.1;
   if(level_price <= 0.0)
      return false;
   if(descending)
      return (previous_open > level_price &&
              level_price + tolerance >= current_open);
   return (previous_open < level_price &&
           level_price - tolerance <= current_open);
  }

string StrategyNN_OrderReason(const int direction,
                              const datetime d1_bar,
                              const long level_pips)
  {
   return StringFormat("%s_%s_%I64d_%I64d",
                       g_strnn_reason_prefix,
                       direction > 0 ? "B" : "S",
                       (long)d1_bar,
                       level_pips);
  }

bool StrategyNN_HistoryLatched(const int direction,
                               const datetime d1_bar,
                               const long level_pips)
  {
   if(d1_bar <= 0 ||
      !HistorySelect(d1_bar, TimeCurrent()))
      return false;
   const string expected =
      StrategyNN_OrderReason(direction, d1_bar, level_pips);
   const int magic = QM_FrameworkMagic();
   const int deals = HistoryDealsTotal();
   for(int i = 0; i < deals; ++i)
     {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0 ||
         (int)HistoryDealGetInteger(deal, DEAL_MAGIC) != magic ||
         HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol)
         continue;
      const ENUM_DEAL_ENTRY entry_kind =
         (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY);
      if(entry_kind != DEAL_ENTRY_IN &&
         entry_kind != DEAL_ENTRY_INOUT)
         continue;
      if(HistoryDealGetString(deal, DEAL_COMMENT) == expected)
         return true;
     }
   return false;
  }

bool StrategyNN_IsLatched(const int direction,
                          const datetime d1_bar,
                          const long level_pips)
  {
   if(g_strnn_latch_d1_bar == d1_bar &&
      g_strnn_latch_direction == direction &&
      g_strnn_latch_level_pips == level_pips)
      return true;
   return StrategyNN_HistoryLatched(direction, d1_bar, level_pips);
  }

void StrategyNN_SetLatch(const int direction,
                         const datetime d1_bar,
                         const long level_pips)
  {
   g_strnn_latch_d1_bar = d1_bar;
   g_strnn_latch_direction = direction;
   g_strnn_latch_level_pips = level_pips;
  }

bool StrategyNN_StopsValid(const QM_OrderType side,
                           const double entry,
                           const double sl,
                           const double tp)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick = StrategyNN_TradeTick();
   if(point <= 0.0 || tick <= 0.0 ||
      entry <= 0.0 || sl <= 0.0 || tp <= 0.0)
      return false;
   const long stops_level =
      SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const double minimum =
      MathMax(tick, (double)stops_level * point);
   if(QM_OrderTypeIsBuy(side))
      return (sl < entry && tp > entry &&
              entry - sl + tick * 0.1 >= minimum &&
              tp - entry + tick * 0.1 >= minimum);
   return (sl > entry && tp < entry &&
           sl - entry + tick * 0.1 >= minimum &&
           entry - tp + tick * 0.1 >= minimum);
  }

bool Strategy_NoTradeFilter()
  {
   int suffix_width = 0;
   long suffix_value = 0;
   long modulus = 0;
   if(_Period != PERIOD_M5 ||
      !StrategyNN_ParseSuffix(suffix_width,
                              suffix_value,
                              modulus) ||
      strategy_lookback_d1_bars < 1 ||
      !MathIsValidNumber(strategy_sl_price_pct) ||
      !MathIsValidNumber(strategy_tp_price_pct) ||
      strategy_sl_price_pct <= 0.0 ||
      strategy_tp_price_pct <= 0.0 ||
      !StrategyNN_HhmmValid(strategy_window_start_hhmm) ||
      !StrategyNN_HhmmValid(strategy_window_end_hhmm))
      return true;
   const ENUM_SYMBOL_TRADE_MODE trade_mode =
      (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(_Symbol,
                                                SYMBOL_TRADE_MODE);
   if(trade_mode == SYMBOL_TRADE_MODE_DISABLED)
      return true;
   const long d1_bars =
      SeriesInfoInteger(_Symbol, PERIOD_D1, SERIES_BARS_COUNT);
   const long m5_bars =
      SeriesInfoInteger(_Symbol, PERIOD_M5, SERIES_BARS_COUNT);
   return (d1_bars < strategy_lookback_d1_bars + 2 ||
           m5_bars < 3);
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   ZeroMemory(req);
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   datetime current_bar_time = 0;
   double current_open = 0.0;
   if(!StrategyNN_CurrentM5(current_bar_time, current_open))
     {
      StrategyNN_LogDataMissing("forming_m5_bar", current_bar_time);
      return false;
     }
   if(current_bar_time == g_strnn_last_entry_bar)
      return false;
   g_strnn_last_entry_bar = current_bar_time;

   if(StrategyNN_HasOwnPosition() ||
      !StrategyNN_WindowAllows(current_bar_time))
      return false;

   MqlRates previous_bar;
   if(!QM_ReadBar(_Symbol, PERIOD_M5, 1, previous_bar) ||
      previous_bar.open <= 0.0)
     {
      StrategyNN_LogDataMissing("previous_m5_open",
                                current_bar_time);
      return false;
     }

   int suffix_width = 0;
   long suffix_value = 0;
   long modulus = 0;
   if(!StrategyNN_ParseSuffix(suffix_width,
                              suffix_value,
                              modulus))
      return false;

   long level_pips = 0;
   double level = 0.0;
   bool descending = false;
   if(!StrategyNN_CrossedLevel(previous_bar.open,
                               current_open,
                               suffix_value,
                               modulus,
                               level_pips,
                               level,
                               descending))
      return false;

   if(!StrategyNN_UpdateD1Cache())
     {
      StrategyNN_LogDataMissing("d1_gate",
                                current_bar_time);
      return false;
     }
   const bool one_side_gate =
      descending
      ? (g_strnn_cache_min_low > level)
      : (g_strnn_cache_max_high < level);
   if(!one_side_gate)
      return false;

   const bool buy_signal =
      g_strnn_fade ? descending : !descending;
   const int direction = buy_signal ? 1 : -1;
   if(StrategyNN_IsLatched(direction,
                           g_strnn_cache_d1_bar,
                           level_pips))
      return false;

   req.type = buy_signal ? QM_BUY : QM_SELL;
   const double entry =
      buy_signal
      ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
      : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
     {
      StrategyNN_LogDataMissing("market_price",
                                current_bar_time);
      return false;
     }
   const double sl_raw =
      buy_signal
      ? entry * (1.0 - strategy_sl_price_pct / 100.0)
      : entry * (1.0 + strategy_sl_price_pct / 100.0);
   const double tp_raw =
      buy_signal
      ? entry * (1.0 + strategy_tp_price_pct / 100.0)
      : entry * (1.0 - strategy_tp_price_pct / 100.0);
   const double sl =
      StrategyNN_AlignPrice(sl_raw, buy_signal ? -1 : 1);
   const double tp =
      StrategyNN_AlignPrice(tp_raw, buy_signal ? 1 : -1);
   if(!StrategyNN_StopsValid(req.type, entry, sl, tp))
     {
      QM_LogEvent(
         QM_WARN,
         "SETUP_CONFIG_INVALID",
         StringFormat(
            "{\"strategy\":\"%s\",\"reason\":\"stops_level\",\"dir\":\"%s\",\"entry\":%.8f,\"sl\":%.8f,\"tp\":%.8f}",
            QM_LoggerEscapeJson(g_strnn_strategy_id),
            buy_signal ? "BUY" : "SELL",
            entry,
            sl,
            tp));
      return false;
     }

   req.price = StrategyNN_AlignPrice(entry, 0);
   req.sl = sl;
   req.tp = tp;
   req.reason =
      StrategyNN_OrderReason(direction,
                             g_strnn_cache_d1_bar,
                             level_pips);
   StrategyNN_SetLatch(direction,
                       g_strnn_cache_d1_bar,
                       level_pips);

   const string window =
      StringFormat("%04d-%04d",
                   strategy_window_start_hhmm,
                   strategy_window_end_hhmm);
   QM_LogEvent(
      QM_INFO,
      "STRATEGY_ENTRY",
      StringFormat(
         "{\"strategy\":\"%s\",\"dir\":\"%s\",\"level\":%.8f,\"suffix\":\"%s\",\"n_days\":%d,\"window\":\"%s\"}",
         QM_LoggerEscapeJson(g_strnn_strategy_id),
         buy_signal ? "BUY" : "SELL",
         level,
         QM_LoggerEscapeJson(strategy_notable_suffix),
         strategy_lookback_d1_bars,
         QM_LoggerEscapeJson(window)));
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Source baseline has no discretionary management: server SL/TP only.
  }

bool Strategy_ExitSignal()
  {
   return false;
  }

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
