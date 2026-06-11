#property strict
#property version   "5.0"
#property description "QM5_9725 ForexFactory Roadmap Trendline Retest M5"

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
input int    qm_ea_id                   = 9725;
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
input ENUM_TIMEFRAMES strategy_signal_tf          = PERIOD_M5;
input int    strategy_ema_period                  = 8;
input int    strategy_sma_period                  = 200;
input int    strategy_rsi_period                  = 14;
input int    strategy_atr_period                  = 14;
input int    strategy_trendline_lookback_bars     = 48;
input int    strategy_fractal_left_right          = 2;
input int    strategy_min_anchor_gap_bars         = 8;
input int    strategy_retest_window_bars          = 6;
input double strategy_retest_atr_mult             = 0.20;
input double strategy_sl_atr_buffer               = 0.25;
input double strategy_stop_min_atr                = 0.60;
input double strategy_stop_max_atr                = 2.00;
input double strategy_tp_r_multiple               = 1.80;
input int    strategy_adr_days                    = 14;
input int    strategy_prior_session_bars          = 72;
input int    strategy_session_start_hour          = 7;
input int    strategy_session_end_hour            = 17;
input double strategy_max_spread_atr_pct          = 12.0;
input double strategy_triangle_width_atr_mult     = 0.45;
input int    strategy_triangle_apex_bars          = 8;
input int    strategy_time_stop_bars              = 24;

struct Strategy_Line
  {
   bool     valid;
   int      older_index;
   int      newer_index;
   datetime older_time;
   datetime newer_time;
   double   older_price;
   double   newer_price;
   double   slope;
  };

bool     g_setup_active = false;
int      g_setup_dir = 0;
int      g_setup_age = 0;
datetime g_setup_newer_time = 0;
Strategy_Line g_setup_line;
double   g_setup_swing_extreme = 0.0;

bool     g_active_line_valid = false;
int      g_active_dir = 0;
datetime g_active_newer_time = 0;
Strategy_Line g_active_line;
datetime g_active_entry_time = 0;

double Strategy_NormalizePrice(const double price)
  {
   return NormalizeDouble(price, _Digits);
  }

double Strategy_LineValue(const Strategy_Line &line, const int series_index)
  {
   if(!line.valid)
      return 0.0;
   return line.older_price + line.slope * (double)(line.older_index - series_index);
  }

bool Strategy_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

bool Strategy_IsSwingHigh(MqlRates &rates[], const int copied, const int index, const int wing)
  {
   if(index - wing < 0 || index + wing >= copied)
      return false;
   const double v = rates[index].high;
   if(v <= 0.0)
      return false;
   for(int j = index - wing; j <= index + wing; ++j)
     {
      if(j == index)
         continue;
      if(rates[j].high >= v)
         return false;
     }
   return true;
  }

bool Strategy_IsSwingLow(MqlRates &rates[], const int copied, const int index, const int wing)
  {
   if(index - wing < 0 || index + wing >= copied)
      return false;
   const double v = rates[index].low;
   if(v <= 0.0)
      return false;
   for(int j = index - wing; j <= index + wing; ++j)
     {
      if(j == index)
         continue;
      if(rates[j].low <= v)
         return false;
     }
   return true;
  }

bool Strategy_FindCounterTrendLine(MqlRates &rates[],
                                   const int copied,
                                   const int dir,
                                   Strategy_Line &line)
  {
   line.valid = false;
   const int wing = MathMax(2, strategy_fractal_left_right);
   const int lookback = MathMax(strategy_trendline_lookback_bars, wing * 2 + strategy_min_anchor_gap_bars + 2);
   const int max_index = MathMin(copied - wing - 1, lookback);
   if(max_index <= wing + strategy_min_anchor_gap_bars)
      return false;

   int newer = -1;
   int older = -1;
   double newer_price = 0.0;
   double older_price = 0.0;

   for(int i = wing; i <= max_index; ++i)
     {
      const bool pivot = (dir > 0) ? Strategy_IsSwingHigh(rates, copied, i, wing)
                                   : Strategy_IsSwingLow(rates, copied, i, wing);
      if(!pivot)
         continue;

      if(newer < 0)
        {
         newer = i;
         newer_price = (dir > 0) ? rates[i].high : rates[i].low;
         continue;
        }

      if(i - newer < strategy_min_anchor_gap_bars)
         continue;

      const double price = (dir > 0) ? rates[i].high : rates[i].low;
      const bool slope_ok = (dir > 0) ? (price > newer_price) : (price < newer_price);
      if(!slope_ok)
         continue;

      older = i;
      older_price = price;
      break;
     }

   if(newer < 0 || older < 0)
      return false;

   const double slope = (newer_price - older_price) / (double)(older - newer);
   if(dir > 0 && slope >= 0.0)
      return false;
   if(dir < 0 && slope <= 0.0)
      return false;

   line.valid = true;
   line.older_index = older;
   line.newer_index = newer;
   line.older_time = rates[older].time;
   line.newer_time = rates[newer].time;
   line.older_price = older_price;
   line.newer_price = newer_price;
   line.slope = slope;
   return true;
  }

bool Strategy_CompressedTriangle(MqlRates &rates[],
                                 const int copied,
                                 const double atr_value)
  {
   if(atr_value <= 0.0)
      return false;

   Strategy_Line high_line;
   Strategy_Line low_line;
   if(!Strategy_FindCounterTrendLine(rates, copied, +1, high_line))
      return false;
   if(!Strategy_FindCounterTrendLine(rates, copied, -1, low_line))
      return false;
   if(high_line.slope >= 0.0 || low_line.slope <= 0.0)
      return false;

   const double high_now = Strategy_LineValue(high_line, 1);
   const double low_now = Strategy_LineValue(low_line, 1);
   if(high_now <= low_now)
      return false;
   if((high_now - low_now) > strategy_triangle_width_atr_mult * atr_value)
      return false;

   const double denom = high_line.slope - low_line.slope;
   if(MathAbs(denom) <= DBL_EPSILON)
      return false;

   const double x_current = -1.0;
   const double high_intercept = high_line.older_price - high_line.slope * (-(double)high_line.older_index);
   const double low_intercept = low_line.older_price - low_line.slope * (-(double)low_line.older_index);
   const double x_apex = (low_intercept - high_intercept) / denom;
   const double bars_to_apex = x_apex - x_current;
   return (bars_to_apex > 0.0 && bars_to_apex <= (double)strategy_triangle_apex_bars);
  }

double Strategy_ADR()
  {
   const int days = MathMax(1, strategy_adr_days);
   MqlRates daily[];
   ArraySetAsSeries(daily, true);
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, days, daily); // perf-allowed: bounded ADR calculation inside new-bar gated entry.
   if(copied <= 0)
      return 0.0;

   double sum = 0.0;
   int n = 0;
   for(int i = 0; i < copied; ++i)
     {
      if(daily[i].high <= daily[i].low || daily[i].low <= 0.0)
         continue;
      sum += daily[i].high - daily[i].low;
      n++;
     }
   return (n > 0) ? (sum / (double)n) : 0.0;
  }

void Strategy_PriorSessionLevels(MqlRates &rates[],
                                 const int copied,
                                 double &session_high,
                                 double &session_low)
  {
   session_high = 0.0;
   session_low = DBL_MAX;
   const int limit = MathMin(MathMax(1, strategy_prior_session_bars), copied - 1);
   for(int i = 1; i <= limit; ++i)
     {
      if(rates[i].high > session_high)
         session_high = rates[i].high;
      if(rates[i].low > 0.0 && rates[i].low < session_low)
         session_low = rates[i].low;
     }
   if(session_low == DBL_MAX)
      session_low = 0.0;
  }

bool Strategy_ContextOK(const int dir,
                        const double close_price,
                        const double daily_open,
                        const double sma_now,
                        const double sma_prev,
                        const double rsi)
  {
   if(dir > 0)
      return ((close_price > daily_open && close_price > sma_now) ||
              (rsi > 55.0 && sma_now > sma_prev));
   return ((close_price < daily_open && close_price < sma_now) ||
           (rsi < 45.0 && sma_now < sma_prev));
  }

bool Strategy_BuildRequest(QM_EntryRequest &req,
                           const int dir,
                           const double entry,
                           const double sl,
                           const double atr_value,
                           const double daily_open,
                           const double adr,
                           const double prior_high,
                           const double prior_low)
  {
   if(entry <= 0.0 || sl <= 0.0 || atr_value <= 0.0)
      return false;

   const double risk = MathAbs(entry - sl);
   if(risk < strategy_stop_min_atr * atr_value || risk > strategy_stop_max_atr * atr_value)
      return false;

   double tp = 0.0;
   const double rr_tp = (dir > 0) ? (entry + strategy_tp_r_multiple * risk)
                                  : (entry - strategy_tp_r_multiple * risk);
   if(dir > 0)
     {
      tp = rr_tp;
      const double adr_high = daily_open + adr;
      if(adr_high > entry && adr_high < tp)
         tp = adr_high;
      if(prior_high > entry && prior_high < tp)
         tp = prior_high;
      if(sl >= entry || tp <= entry)
         return false;
      req.type = QM_BUY;
      req.reason = "FF_ROADMAP_TL_RETEST_LONG";
     }
   else
     {
      tp = rr_tp;
      const double adr_low = daily_open - adr;
      if(adr_low > 0.0 && adr_low < entry && adr_low > tp)
         tp = adr_low;
      if(prior_low > 0.0 && prior_low < entry && prior_low > tp)
         tp = prior_low;
      if(sl <= entry || tp >= entry)
         return false;
      req.type = QM_SELL;
      req.reason = "FF_ROADMAP_TL_RETEST_SHORT";
     }

   req.price = 0.0;
   req.sl = Strategy_NormalizePrice(sl);
   req.tp = Strategy_NormalizePrice(tp);
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return (req.sl > 0.0 && req.tp > 0.0);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(Strategy_HasOpenPosition())
      return false;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.day_of_week == 0 || dt.day_of_week == 6)
      return true;

   bool session_ok = true;
   if(strategy_session_start_hour != strategy_session_end_hour)
     {
      if(strategy_session_start_hour < strategy_session_end_hour)
         session_ok = (dt.hour >= strategy_session_start_hour && dt.hour < strategy_session_end_hour);
      else
         session_ok = (dt.hour >= strategy_session_start_hour || dt.hour < strategy_session_end_hour);
     }
   if(!session_ok)
      return true;

   const double atr = QM_ATR(_Symbol, strategy_signal_tf, strategy_atr_period, 1);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(atr <= 0.0 || bid <= 0.0 || ask <= 0.0 || ask < bid)
      return true;
   if((ask - bid) > atr * strategy_max_spread_atr_pct / 100.0)
      return true;

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

   if(Strategy_HasOpenPosition())
      return false;
   if(Strategy_NoTradeFilter())
      return false;

   const int min_bars = MathMax(strategy_sma_period + 5,
                                MathMax(strategy_trendline_lookback_bars + 10,
                                        strategy_prior_session_bars + 5));
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, strategy_signal_tf, 1, min_bars, rates); // perf-allowed: Roadmap swing/trendline structure; Strategy_EntrySignal is called only after the framework QM_IsNewBar() gate.
   if(copied < MathMax(strategy_trendline_lookback_bars, 64))
      return false;

   MqlRates daily0[];
   ArraySetAsSeries(daily0, true);
   if(CopyRates(_Symbol, PERIOD_D1, 0, 1, daily0) != 1) // perf-allowed: daily open context inside new-bar gated entry.
      return false;

   const double daily_open = daily0[0].open;
   const double atr = QM_ATR(_Symbol, strategy_signal_tf, strategy_atr_period, 1);
   const double ema_close = QM_EMA(_Symbol, strategy_signal_tf, strategy_ema_period, 1, PRICE_CLOSE);
   const double sma_now = QM_SMA(_Symbol, strategy_signal_tf, strategy_sma_period, 1, PRICE_CLOSE);
   const double sma_prev = QM_SMA(_Symbol, strategy_signal_tf, strategy_sma_period, 6, PRICE_CLOSE);
   const double rsi = QM_RSI(_Symbol, strategy_signal_tf, strategy_rsi_period, 1, PRICE_CLOSE);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(daily_open <= 0.0 || atr <= 0.0 || ema_close <= 0.0 ||
      sma_now <= 0.0 || sma_prev <= 0.0 || rsi <= 0.0 || bid <= 0.0 || ask <= 0.0)
      return false;

   if(Strategy_CompressedTriangle(rates, copied, atr))
      return false;

   Strategy_Line bearish_line;
   Strategy_Line bullish_line;
   const bool have_bearish = Strategy_FindCounterTrendLine(rates, copied, +1, bearish_line);
   const bool have_bullish = Strategy_FindCounterTrendLine(rates, copied, -1, bullish_line);

   const double close1 = rates[0].close;
   const double open1 = rates[0].open;

   if(g_setup_active)
     {
      g_setup_age++;
      if(g_setup_age > strategy_retest_window_bars ||
         g_setup_newer_time != g_setup_line.newer_time)
        {
         g_setup_active = false;
         g_setup_dir = 0;
        }
     }

   if(!g_setup_active && have_bearish)
     {
      const double line0 = Strategy_LineValue(bearish_line, 0);
      const double line1 = Strategy_LineValue(bearish_line, 1);
      if(rates[1].close <= line1 && close1 > line0)
        {
         g_setup_active = true;
         g_setup_dir = +1;
         g_setup_age = 0;
         g_setup_line = bearish_line;
         g_setup_newer_time = bearish_line.newer_time;
         g_setup_swing_extreme = rates[0].low;
         return false;
        }
     }

   if(!g_setup_active && have_bullish)
     {
      const double line0 = Strategy_LineValue(bullish_line, 0);
      const double line1 = Strategy_LineValue(bullish_line, 1);
      if(rates[1].close >= line1 && close1 < line0)
        {
         g_setup_active = true;
         g_setup_dir = -1;
         g_setup_age = 0;
         g_setup_line = bullish_line;
         g_setup_newer_time = bullish_line.newer_time;
         g_setup_swing_extreme = rates[0].high;
         return false;
        }
     }

   if(!g_setup_active || g_setup_age <= 0)
      return false;

   if(g_setup_dir > 0)
      g_setup_swing_extreme = MathMin(g_setup_swing_extreme, rates[0].low);
   else
      g_setup_swing_extreme = MathMax(g_setup_swing_extreme, rates[0].high);

   const double retest_line = Strategy_LineValue(g_setup_line, 1);
   const bool retest_near = MathAbs(close1 - retest_line) <= strategy_retest_atr_mult * atr ||
                            (rates[0].low <= retest_line + strategy_retest_atr_mult * atr &&
                             rates[0].high >= retest_line - strategy_retest_atr_mult * atr);
   if(!retest_near)
      return false;

   const bool bullish_retest = (g_setup_dir > 0 && close1 > open1 && close1 > ema_close &&
                                Strategy_ContextOK(+1, close1, daily_open, sma_now, sma_prev, rsi));
   const bool bearish_retest = (g_setup_dir < 0 && close1 < open1 && close1 < ema_close &&
                                Strategy_ContextOK(-1, close1, daily_open, sma_now, sma_prev, rsi));
   if(!bullish_retest && !bearish_retest)
      return false;

   double prior_high = 0.0;
   double prior_low = 0.0;
   Strategy_PriorSessionLevels(rates, copied, prior_high, prior_low);
   const double adr = Strategy_ADR();
   if(adr <= 0.0 || prior_high <= 0.0 || prior_low <= 0.0)
      return false;

   const int dir = bullish_retest ? +1 : -1;
   const double entry = (dir > 0) ? ask : bid;
   const double sl = (dir > 0) ? (g_setup_swing_extreme - strategy_sl_atr_buffer * atr)
                               : (g_setup_swing_extreme + strategy_sl_atr_buffer * atr);
   if(!Strategy_BuildRequest(req, dir, entry, sl, atr, daily_open, adr, prior_high, prior_low))
      return false;

   g_active_line_valid = true;
   g_active_dir = dir;
   g_active_newer_time = g_setup_newer_time;
   g_active_line = g_setup_line;
   g_active_entry_time = TimeCurrent();

   g_setup_active = false;
   g_setup_dir = 0;
   g_setup_age = 0;
   g_setup_swing_extreme = 0.0;
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no break-even, trailing, partial-close, or scale-in rule.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      const int max_hold_seconds = strategy_time_stop_bars * PeriodSeconds(strategy_signal_tf);
      if(max_hold_seconds > 0 && opened > 0 && TimeCurrent() - opened >= max_hold_seconds)
        {
         g_active_line_valid = false;
         return true;
        }

      if(!g_active_line_valid)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double line_now = Strategy_LineValue(g_active_line, 0);
      if(line_now <= 0.0 || bid <= 0.0 || ask <= 0.0)
         continue;

      if(ptype == POSITION_TYPE_BUY && bid < line_now)
        {
         g_active_line_valid = false;
         return true;
        }
      if(ptype == POSITION_TYPE_SELL && ask > line_now)
        {
         g_active_line_valid = false;
         return true;
        }
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
