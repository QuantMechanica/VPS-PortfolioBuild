#property strict
#property version   "5.0"
#property description "QM5_2010 NNFX V2 H4 Bias H1 Pullback"
// rework v2 2026-06-16 — SSL channel given persistent Hlv state carry (was instantaneous tri-state that returned neutral whenever close sat between SMA(high)/SMA(low), forcing H4 bias to 0 on the majority of bars and starving entries toward ~0 trades). Faithful to card "SSL green above SSL red".

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
input int    qm_ea_id                   = 2010;
input int    qm_magic_slot_offset       = 0;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsMode qm_news_mode          = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input int    strategy_h4_ema_period      = 89;
input int    strategy_kijun_period       = 26;
input int    strategy_ssl_period         = 10;
input int    strategy_adx_period         = 14;
input double strategy_adx_min            = 14.0;
input int    strategy_atr_period         = 14;
input int    strategy_atr_median_bars    = 50;
input int    strategy_h1_ema_period      = 20;
input int    strategy_rsi_period         = 14;
input double strategy_rsi_midline        = 50.0;
input int    strategy_macd_fast          = 12;
input int    strategy_macd_slow          = 26;
input int    strategy_macd_signal        = 9;
input double strategy_atr_sl_mult        = 1.8;
input double strategy_atr_sl_cap_mult    = 3.0;
input double strategy_be_trigger_r       = 1.2;
input int    strategy_cooldown_h1_bars   = 6;
input int    strategy_time_exit_h1_bars  = 72;
input int    strategy_max_spread_points  = 80;

int    g_cached_h4_bias = 0;
double g_cached_h4_kijun = 0.0;
bool   g_h4_cache_ready = false;

double HighestHigh(const string symbol, const ENUM_TIMEFRAMES tf, const int bars, const int start_shift)
  {
   if(bars <= 0 || start_shift < 0)
      return 0.0;

   double high = -DBL_MAX;
   for(int i = start_shift; i < start_shift + bars; ++i)
     {
      const double value = iHigh(symbol, tf, i);
      if(value <= 0.0)
         return 0.0;
      high = MathMax(high, value);
     }
   return high;
  }

double LowestLow(const string symbol, const ENUM_TIMEFRAMES tf, const int bars, const int start_shift)
  {
   if(bars <= 0 || start_shift < 0)
      return 0.0;

   double low = DBL_MAX;
   for(int i = start_shift; i < start_shift + bars; ++i)
     {
      const double value = iLow(symbol, tf, i);
      if(value <= 0.0)
         return 0.0;
      low = MathMin(low, value);
     }
   return low;
  }

double Kijun(const string symbol, const ENUM_TIMEFRAMES tf, const int period, const int shift)
  {
   const double high = HighestHigh(symbol, tf, period, shift);
   const double low = LowestLow(symbol, tf, period, shift);
   if(high <= 0.0 || low <= 0.0)
      return 0.0;
   return (high + low) * 0.5;
  }

double AverageHigh(const string symbol, const ENUM_TIMEFRAMES tf, const int period, const int shift)
  {
   if(period <= 0)
      return 0.0;

   double sum = 0.0;
   for(int i = shift; i < shift + period; ++i)
     {
      const double value = iHigh(symbol, tf, i);
      if(value <= 0.0)
         return 0.0;
      sum += value;
     }
   return sum / (double)period;
  }

double AverageLow(const string symbol, const ENUM_TIMEFRAMES tf, const int period, const int shift)
  {
   if(period <= 0)
      return 0.0;

   double sum = 0.0;
   for(int i = shift; i < shift + period; ++i)
     {
      const double value = iLow(symbol, tf, i);
      if(value <= 0.0)
         return 0.0;
      sum += value;
     }
   return sum / (double)period;
  }

// SSL channel direction with persistent Hlv state (the standard SSL channel
// rule): once close crosses ABOVE the SMA-of-highs the channel is "green/long"
// and STAYS long until close crosses BELOW the SMA-of-lows (and vice-versa).
// While close sits between the two bands the prior direction is carried, NOT
// reset to neutral. We seed neutral and walk forward over a lookback window so
// the carried state at `shift` is deterministic in the tester.
int SSLDirection(const string symbol, const ENUM_TIMEFRAMES tf, const int period, const int shift)
  {
   const int warmup = 200; // bars walked to settle the Hlv state before `shift`
   int hlv = 0;
   bool seen = false;
   for(int i = shift + warmup; i >= shift; --i)
     {
      const double close = iClose(symbol, tf, i);
      const double sma_high = AverageHigh(symbol, tf, period, i);
      const double sma_low = AverageLow(symbol, tf, period, i);
      if(close <= 0.0 || sma_high <= 0.0 || sma_low <= 0.0)
         continue;
      seen = true;
      if(close > sma_high)
         hlv = 1;
      else if(close < sma_low)
         hlv = -1;
      // else: carry prior hlv (persistent channel state)
     }
   if(!seen)
      return 0;
   return hlv;
  }

double MedianATR(const string symbol, const ENUM_TIMEFRAMES tf, const int period, const int bars, const int start_shift)
  {
   if(period <= 0 || bars <= 0)
      return 0.0;

   double values[];
   ArrayResize(values, bars);
   for(int i = 0; i < bars; ++i)
     {
      values[i] = QM_ATR(symbol, tf, period, start_shift + i);
      if(values[i] <= 0.0)
         return 0.0;
     }

   ArraySort(values);
   if((bars % 2) == 1)
      return values[bars / 2];
   return (values[bars / 2 - 1] + values[bars / 2]) * 0.5;
  }

int H4Bias()
  {
   const double close = iClose(_Symbol, PERIOD_H4, 1);
   const double ema = QM_EMA(_Symbol, PERIOD_H4, strategy_h4_ema_period, 1);
   const double kijun = Kijun(_Symbol, PERIOD_H4, strategy_kijun_period, 1);
   const int ssl = SSLDirection(_Symbol, PERIOD_H4, strategy_ssl_period, 1);
   const double adx = QM_ADX(_Symbol, PERIOD_H4, strategy_adx_period, 1);
   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   const double atr_median = MedianATR(_Symbol, PERIOD_H4, strategy_atr_period, strategy_atr_median_bars, 1);

   if(close <= 0.0 || ema <= 0.0 || kijun <= 0.0 || adx <= 0.0 || atr <= 0.0 || atr_median <= 0.0)
      return 0;
   if(adx < strategy_adx_min || atr < atr_median)
      return 0;
   if(close > ema && close > kijun && ssl > 0)
      return 1;
   if(close < ema && close < kijun && ssl < 0)
      return -1;
   return 0;
  }

void RefreshH4Cache()
  {
   g_cached_h4_bias = H4Bias();
   g_cached_h4_kijun = Kijun(_Symbol, PERIOD_H4, strategy_kijun_period, 1);
   g_h4_cache_ready = true;
  }

bool HasOpenPosition(ulong &ticket, ENUM_POSITION_TYPE &position_type, double &open_price, datetime &open_time)
  {
   ticket = 0;
   position_type = POSITION_TYPE_BUY;
   open_price = 0.0;
   open_time = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong candidate = PositionGetTicket(i);
      if(candidate == 0 || !PositionSelectByTicket(candidate))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = candidate;
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

bool CooldownSatisfied()
  {
   if(strategy_cooldown_h1_bars <= 0)
      return true;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const datetime now = TimeCurrent();
   if(!HistorySelect(now - 366 * 24 * 60 * 60, now))
      return true;

   datetime last_entry = 0;
   for(int i = HistoryDealsTotal() - 1; i >= 0; --i)
     {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;
      if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol)
         continue;
      if((int)HistoryDealGetInteger(deal, DEAL_MAGIC) != magic)
         continue;
      if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY) != DEAL_ENTRY_IN)
         continue;

      last_entry = (datetime)HistoryDealGetInteger(deal, DEAL_TIME);
      break;
     }

   if(last_entry <= 0)
      return true;

   const int bars_since = iBarShift(_Symbol, PERIOD_H1, last_entry, false);
   return (bars_since >= strategy_cooldown_h1_bars);
  }

double PipSize()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(point <= 0.0)
      return 0.0;
   if(digits == 3 || digits == 5)
      return point * 10.0;
   return point;
  }

int DistanceToPips(const double distance)
  {
   const double pip = PipSize();
   if(distance <= 0.0 || pip <= 0.0)
      return 0;
   return (int)MathMax(1.0, MathRound(distance / pip));
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(!g_h4_cache_ready || QM_IsNewBar(_Symbol, PERIOD_H4))
      RefreshH4Cache();

   const int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(strategy_max_spread_points > 0 && spread > strategy_max_spread_points)
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

   if(_Period != PERIOD_H1)
      return false;

   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   double open_price;
   datetime open_time;
   if(HasOpenPosition(ticket, position_type, open_price, open_time))
      return false;
   if(!CooldownSatisfied())
      return false;

   const int bias = g_cached_h4_bias;
   if(bias == 0)
      return false;

   const double h4_kijun = g_cached_h4_kijun;
   const double h1_close_1 = iClose(_Symbol, PERIOD_H1, 1);
   const double h1_close_2 = iClose(_Symbol, PERIOD_H1, 2);
   const double h1_ema_1 = QM_EMA(_Symbol, PERIOD_H1, strategy_h1_ema_period, 1);
   const double h1_ema_2 = QM_EMA(_Symbol, PERIOD_H1, strategy_h1_ema_period, 2);
   const double rsi = QM_RSI(_Symbol, PERIOD_H1, strategy_rsi_period, 1);
   const double macd_main = QM_MACD_Main(_Symbol, PERIOD_H1, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);
   const double macd_signal = QM_MACD_Signal(_Symbol, PERIOD_H1, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);
   const double atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   if(h4_kijun <= 0.0 || h1_close_1 <= 0.0 || h1_close_2 <= 0.0 || h1_ema_1 <= 0.0 || h1_ema_2 <= 0.0 || rsi <= 0.0 || atr <= 0.0)
      return false;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return false;

   const double sl_mult = MathMin(strategy_atr_sl_mult, strategy_atr_sl_cap_mult);
   if(sl_mult <= 0.0)
      return false;

   if(bias > 0 &&
      h1_close_2 <= h1_ema_2 &&
      h1_close_2 > h4_kijun &&
      h1_close_1 > h1_ema_1 &&
      rsi > strategy_rsi_midline &&
      macd_main > macd_signal)
     {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = ask - atr * sl_mult;
      req.tp = 0.0;
      req.reason = "NNFX_V2_H4_BIAS_H1_PULLBACK_LONG";
      return true;
     }

   if(bias < 0 &&
      h1_close_2 >= h1_ema_2 &&
      h1_close_2 < h4_kijun &&
      h1_close_1 < h1_ema_1 &&
      rsi < strategy_rsi_midline &&
      macd_main < macd_signal)
     {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = bid + atr * sl_mult;
      req.tp = 0.0;
      req.reason = "NNFX_V2_H4_BIAS_H1_PULLBACK_SHORT";
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   double open_price;
   datetime open_time;
   if(!HasOpenPosition(ticket, position_type, open_price, open_time))
      return;

   const double current_sl = PositionGetDouble(POSITION_SL);
   if(open_price <= 0.0 || current_sl <= 0.0)
      return;

   const double initial_r = MathAbs(open_price - current_sl);
   const int trigger_pips = DistanceToPips(initial_r * strategy_be_trigger_r);
   if(trigger_pips > 0)
      QM_TM_MoveToBreakEven(ticket, trigger_pips, 0);
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   double open_price;
   datetime open_time;
   if(!HasOpenPosition(ticket, position_type, open_price, open_time))
      return false;

   const int bias = g_cached_h4_bias;
   if(position_type == POSITION_TYPE_BUY && bias <= 0)
      return true;
   if(position_type == POSITION_TYPE_SELL && bias >= 0)
      return true;

   const double close_1 = iClose(_Symbol, PERIOD_H1, 1);
   const double close_2 = iClose(_Symbol, PERIOD_H1, 2);
   const double ema_1 = QM_EMA(_Symbol, PERIOD_H1, strategy_h1_ema_period, 1);
   const double ema_2 = QM_EMA(_Symbol, PERIOD_H1, strategy_h1_ema_period, 2);
   if(close_1 <= 0.0 || close_2 <= 0.0 || ema_1 <= 0.0 || ema_2 <= 0.0)
      return false;

   if(position_type == POSITION_TYPE_BUY && close_1 < ema_1 && close_2 < ema_2)
      return true;
   if(position_type == POSITION_TYPE_SELL && close_1 > ema_1 && close_2 > ema_2)
      return true;

   const int bars_held = iBarShift(_Symbol, PERIOD_H1, open_time, false);
   if(strategy_time_exit_h1_bars > 0 && bars_held >= strategy_time_exit_h1_bars)
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
                        qm_news_mode,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker))
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
   if(!QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode))
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

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
