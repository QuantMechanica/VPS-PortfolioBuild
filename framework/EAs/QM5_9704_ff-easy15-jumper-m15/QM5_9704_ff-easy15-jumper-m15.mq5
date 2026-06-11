#property strict
#property version   "5.0"
#property description "QM5_9704 ForexFactory Easy 15 Jumper M15 (6e967762-b26d-59a3-b076-35c17f2e7c36)"

#include <QM/QM_Common.mqh>

//=============================================================================
// QuantMechanica V5 Framework inputs
//=============================================================================
input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 9704;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal      = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance    = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours                  = 336;
input string qm_news_min_impact                       = "high";
input QM_NewsMode qm_news_mode_legacy                 = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_sl_pips                = 20;     // baseline SL pips, symbol-normalized
input double strategy_sl_atr_mult           = 0.20;   // ATR SL: anchor +/- 0.20 * ATR14
input double strategy_tp_r_mult             = 1.2;    // TP = 1.2 x 1R
input int    strategy_be_trigger_pips       = 10;     // move to BE after +N pips
input int    strategy_time_stop_bars        = 16;     // max hold: 16 M15 bars
input int    strategy_ema_fast_period       = 2;      // card EMA 2.1, approximated as EMA 2
input int    strategy_ema_trend_period      = 200;    // trend EMA period (M15)
input int    strategy_rsi_period            = 13;     // TDI RSI period
input int    strategy_tdi_green_period      = 2;      // TDI RSI Price Line EMA period
input int    strategy_tdi_yellow_period     = 7;      // TDI Market Base Line EMA period
input int    strategy_atr_period            = 14;     // ATR period for SL and volatility filter
input double strategy_atr_filter_ratio      = 0.60;  // skip if ATR < ratio * 20-day session mean
input int    strategy_london_open_hour      = 10;    // London open broker hour (GMT+2=10, GMT+3=11)
input int    strategy_london_duration_hours = 4;     // London trading window hours

//=============================================================================
// Session state — reset on each new trading day
//=============================================================================
int      g_session_day_key      = -1;
bool     g_jumper_found         = false;
datetime g_jumper_bar_time      = 0;
int      g_jumper_dir           = 0;      // +1=long, -1=short
double   g_jumper_high          = 0.0;
double   g_jumper_low           = 0.0;
bool     g_session_trade_done   = false;
bool     g_be_moved             = false;
bool     g_atr_ok               = false;
bool     g_atr_checked          = false;

// TDI values cached on each new bar
double g_tdi_green_1  = 50.0;  // EMA(green_period) of RSI at shift 1
double g_tdi_green_2  = 50.0;  // EMA(green_period) of RSI at shift 2
double g_tdi_yellow_1 = 50.0;  // EMA(yellow_period) of RSI at shift 1
double g_tdi_yellow_2 = 50.0;  // EMA(yellow_period) of RSI at shift 2

//=============================================================================
// TDI_EMA — EMA(ema_period) of RSI(strategy_rsi_period) at target_shift
// Called inside AdvanceState_OnNewBar (under QM_IsNewBar gate, not per-tick).
//=============================================================================
double TDI_EMA(const int ema_period, const int target_shift)
  {
   const int    warmup = 28;
   const double k      = 2.0 / (ema_period + 1.0);
   double ema = QM_RSI(_Symbol, PERIOD_M15, strategy_rsi_period, warmup + target_shift);
   for(int s = warmup - 1; s >= 0; s--)
      ema = k * QM_RSI(_Symbol, PERIOD_M15, strategy_rsi_period, s + target_shift)
            + (1.0 - k) * ema;
   return ema;
  }

//=============================================================================
// AdvanceState_OnNewBar — session tracking, TDI, jumper detection
// Called ONCE per closed bar immediately after QM_IsNewBar() fires.
//=============================================================================
void AdvanceState_OnNewBar()
  {
   // Refresh TDI cached values for the two most-recent closed bars
   g_tdi_green_1  = TDI_EMA(strategy_tdi_green_period,  1);
   g_tdi_green_2  = TDI_EMA(strategy_tdi_green_period,  2);
   g_tdi_yellow_1 = TDI_EMA(strategy_tdi_yellow_period, 1);
   g_tdi_yellow_2 = TDI_EMA(strategy_tdi_yellow_period, 2);

   // Detect new session by day change in broker time
   const datetime bar1_t = iTime(_Symbol, PERIOD_M15, 1); // perf-allowed: session key
   if(bar1_t <= 0)
      return;
   MqlDateTime dt;
   TimeToStruct(bar1_t, dt);
   const int day_key = dt.year * 10000 + dt.mon * 100 + dt.day;

   if(day_key != g_session_day_key)
     {
      g_session_day_key    = day_key;
      g_jumper_found       = false;
      g_jumper_bar_time    = 0;
      g_jumper_dir         = 0;
      g_jumper_high        = 0.0;
      g_jumper_low         = 0.0;
      g_session_trade_done = false;
      g_be_moved           = false;
      g_atr_ok             = false;
      g_atr_checked        = false;
     }

   // Only process bars inside the London session window
   const int bar_hour = dt.hour;
   if(bar_hour < strategy_london_open_hour ||
      bar_hour >= strategy_london_open_hour + strategy_london_duration_hours)
      return;

   // ATR session filter: computed once on the first London bar of the session
   if(!g_atr_checked)
     {
      g_atr_checked = true;
      double atr_sum = 0.0;
      int    atr_cnt = 0;
      for(int d = 1; d <= 20; d++)
        {
         // Sample ATR at approx same-session time each day (stride ~96 M15 bars/day)
         const double a = QM_ATR(_Symbol, PERIOD_M15, strategy_atr_period, d * 96);
         if(a > 0.0) { atr_sum += a; atr_cnt++; }
        }
      const double atr_mean = (atr_cnt > 0) ? atr_sum / atr_cnt : 0.0;
      const double atr_now  = QM_ATR(_Symbol, PERIOD_M15, strategy_atr_period, 1);
      g_atr_ok = (atr_mean <= 0.0 || atr_now >= strategy_atr_filter_ratio * atr_mean);
     }

   // Skip jumper detection if we already have one or trade is done
   if(g_session_trade_done || g_jumper_found)
      return;

   // Check whether bar[1] qualifies as the jumper candle
   const double close1 = iClose(_Symbol, PERIOD_M15, 1); // perf-allowed: jumper scan
   const double close2 = iClose(_Symbol, PERIOD_M15, 2); // perf-allowed: jumper scan prev
   const double ema2_1 = QM_EMA(_Symbol, PERIOD_M15, strategy_ema_fast_period, 1);
   const double ema2_2 = QM_EMA(_Symbol, PERIOD_M15, strategy_ema_fast_period, 2);

   if(close1 <= 0.0 || close2 <= 0.0 || ema2_1 <= 0.0 || ema2_2 <= 0.0)
      return;

   // Long jumper: bar[1] closed above EMA(2), bar[2] was at or below
   if(close1 > ema2_1 && close2 <= ema2_2)
     {
      g_jumper_found    = true;
      g_jumper_dir      = 1;
      g_jumper_bar_time = iTime(_Symbol, PERIOD_M15, 1); // perf-allowed: jumper time anchor
      g_jumper_high     = iHigh(_Symbol, PERIOD_M15, 1); // perf-allowed: jumper high anchor
      g_jumper_low      = iLow(_Symbol,  PERIOD_M15, 1); // perf-allowed: jumper low anchor
     }
   // Short jumper: bar[1] closed below EMA(2), bar[2] was at or above
   else if(close1 < ema2_1 && close2 >= ema2_2)
     {
      g_jumper_found    = true;
      g_jumper_dir      = -1;
      g_jumper_bar_time = iTime(_Symbol, PERIOD_M15, 1); // perf-allowed: jumper time anchor
      g_jumper_high     = iHigh(_Symbol, PERIOD_M15, 1); // perf-allowed: jumper high anchor
      g_jumper_low      = iLow(_Symbol,  PERIOD_M15, 1); // perf-allowed: jumper low anchor
     }
  }

//=============================================================================
// Strategy hooks
//=============================================================================

// No Trade Filter: blanket session block omitted — management/exit must run
// outside London window. London-window entry filter is inside Strategy_EntrySignal.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Trade Entry: next-candle break above/below jumper high/low + TDI + EMA200
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(!g_jumper_found || g_session_trade_done || !g_atr_ok)
      return false;

   // bar[2] must be the jumper bar (bar[1] is the immediately following candle)
   const datetime t2 = iTime(_Symbol, PERIOD_M15, 2); // perf-allowed: jumper sequence check
   if(t2 != g_jumper_bar_time)
      return false;

   // Confirmation bar (bar[1]) must start within or just after London window
   const datetime bar1_t = iTime(_Symbol, PERIOD_M15, 1); // perf-allowed: entry window check
   MqlDateTime bar1_dt;
   TimeToStruct(bar1_t, bar1_dt);
   if(bar1_dt.hour > strategy_london_open_hour + strategy_london_duration_hours)
      return false;

   // One active position per magic allowed
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;
   const double high1  = iHigh(_Symbol,  PERIOD_M15, 1); // perf-allowed: break check
   const double low1   = iLow(_Symbol,   PERIOD_M15, 1); // perf-allowed: break check
   const double close1 = iClose(_Symbol, PERIOD_M15, 1); // perf-allowed: EMA200 check
   const double ema200 = QM_EMA(_Symbol, PERIOD_M15, strategy_ema_trend_period, 1);
   const double atr    = QM_ATR(_Symbol, PERIOD_M15, strategy_atr_period, 1);

   if(g_jumper_dir == 1) // --- long setup ---
     {
      if(high1 <= g_jumper_high)             return false; // no break above jumper high
      if(g_tdi_green_1 < g_tdi_yellow_1)    return false; // TDI green not above yellow
      if(ema200 <= 0.0 || close1 <= ema200) return false; // close not above EMA200

      const double ask      = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double sl_fixed = QM_StopFixedPips(_Symbol, QM_BUY, ask, strategy_sl_pips);
      const double sl_atr   = g_jumper_low - strategy_sl_atr_mult * atr;
      const double sl_price = MathMin(sl_fixed, sl_atr); // wider = lower for long
      if(sl_price <= 0.0 || ask <= sl_price)
         return false;

      req.type               = QM_BUY;
      req.price              = 0.0;
      req.sl                 = sl_price;
      req.tp                 = ask + strategy_tp_r_mult * (ask - sl_price);
      req.reason             = "FF_EASY15_LONG";
      req.symbol_slot        = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      g_session_trade_done   = true;
      return true;
     }

   if(g_jumper_dir == -1) // --- short setup ---
     {
      if(low1 >= g_jumper_low)               return false; // no break below jumper low
      if(g_tdi_green_1 > g_tdi_yellow_1)    return false; // TDI green not below yellow
      if(ema200 <= 0.0 || close1 >= ema200) return false; // close not below EMA200

      const double bid        = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double sl_fixed_s = QM_StopFixedPips(_Symbol, QM_SELL, bid, strategy_sl_pips);
      const double sl_atr_s   = g_jumper_high + strategy_sl_atr_mult * atr;
      const double sl_price_s = MathMax(sl_fixed_s, sl_atr_s); // wider = higher for short
      if(sl_price_s <= 0.0 || bid >= sl_price_s)
         return false;

      req.type               = QM_SELL;
      req.price              = 0.0;
      req.sl                 = sl_price_s;
      req.tp                 = bid - strategy_tp_r_mult * (sl_price_s - bid);
      req.reason             = "FF_EASY15_SHORT";
      req.symbol_slot        = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      g_session_trade_done   = true;
      return true;
     }

   return false;
  }

// Trade Management: per-tick time-stop close and breakeven shift
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      // Time stop: close after 16 M15 bars (14400 s)
      const datetime open_t = (datetime)PositionGetInteger(POSITION_TIME);
      if(TimeCurrent() - open_t >= (long)strategy_time_stop_bars * 15 * 60)
        {
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
         break;
        }

      // Move SL to breakeven after reaching +be_trigger_pips
      if(!g_be_moved)
         if(QM_TM_MoveToBreakEven(ticket, strategy_be_trigger_pips, 2))
            g_be_moved = true;

      break; // one position per magic
     }
  }

// Trade Close: TDI-cross reversal exit
// Called per-bar after AdvanceState has updated g_tdi_* with fresh values.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = 0; i < PositionsTotal(); i++)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE ptype =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      // Long: exit if TDI green crosses below yellow (bearish reversal)
      if(ptype == POSITION_TYPE_BUY &&
         g_tdi_green_1 < g_tdi_yellow_1 && g_tdi_green_2 >= g_tdi_yellow_2)
         return true;

      // Short: exit if TDI green crosses above yellow (bullish reversal)
      if(ptype == POSITION_TYPE_SELL &&
         g_tdi_green_1 > g_tdi_yellow_1 && g_tdi_green_2 <= g_tdi_yellow_2)
         return true;

      break;
     }
   return false;
  }

// News Filter Hook: defer all news filtering to the framework
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

//=============================================================================
// Framework wiring
//=============================================================================

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,
                        30,
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,
                        qm_news_compliance))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK",
               "{\"ea\":\"QM5_9704\",\"slug\":\"ff-easy15-jumper-m15\","
               "\"source\":\"6e967762-b26d-59a3-b076-35c17f2e7c36\"}");
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

   // Per-tick: time-stop and breakeven management
   Strategy_ManageOpenPosition();

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   // Per-bar: advance session state, TDI, and jumper detection
   AdvanceState_OnNewBar();

   // Per-bar: TDI-cross exit (fresh TDI values from AdvanceState)
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
                        const MqlTradeRequest       &request,
                        const MqlTradeResult        &result)
  {
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
