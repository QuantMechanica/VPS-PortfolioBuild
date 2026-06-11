#property strict
#property version   "5.0"
#property description "QM5_9698 — ForexFactory Symphonie Four-Lights M15"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_9698 — ForexFactory Symphonie Four-Lights M15
// Source: Evaluator, Symphonie Trader System, ForexFactory 2011-09-16
// Four consensus indicator "lights" — Trendline (EMA slope), Extreme (RSI),
// Emotion (MACD), Sentiment (Stochastic) — must all align on the same M15
// closed bar, with at least one fresh flip in the last 3 bars.
// Targets: EURUSD / GBPUSD / USDJPY / EURJPY
// Thread: Symphonie Trader System, ForexFactory 2011-09-16, handle: Evaluator
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9698;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal     = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance   = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours                = 336;
input string qm_news_min_impact                     = "high";
input QM_NewsMode qm_news_mode_legacy               = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled                = true;
input int    qm_friday_close_hour_broker            = 21;

input group "Stress"
input double qm_stress_reject_probability           = 0.0;

input group "Strategy"
input int    strategy_ema_period        = 20;    // Trendline proxy — EMA period
input int    strategy_rsi_period        = 14;    // Extreme proxy — RSI period
input int    strategy_macd_fast         = 12;    // Emotion proxy — MACD fast
input int    strategy_macd_slow         = 26;    // Emotion proxy — MACD slow
input int    strategy_macd_signal       = 9;     // Emotion proxy — MACD signal
input int    strategy_stoch_k           = 5;     // Sentiment proxy — Stoch K period
input int    strategy_stoch_d           = 3;     // Sentiment proxy — Stoch D period
input int    strategy_stoch_slow        = 3;     // Sentiment proxy — Stoch slow
input int    strategy_atr_period        = 14;    // ATR period for SL
input double strategy_sl_atr_mult       = 0.35;  // SL = signal bar L/H ± mult * ATR(14)
input double strategy_tp_rr             = 1.8;   // TP = entry ± tp_rr * SL_dist
input int    strategy_time_stop_bars    = 16;    // Hard time stop: exit after N M15 bars
input int    strategy_session_start_h   = 7;     // Entry allowed from this broker hour
input int    strategy_session_end_h     = 22;    // Entry blocked from this broker hour

// File-scope state — NOT a bar-detection gate, records trade context for exit
datetime g_entry_bar_time = 0;   // open-time of bar[0] at entry, for iBarShift time-stop
bool     g_trade_is_long  = true; // direction of last opened position

// ============================================================================
// Symphonie four-light proxies — one CopyBuffer per pooled handle per call.
// ============================================================================

bool Light_Trendline(const int shift)
  {
   const double ema = QM_EMA(_Symbol, PERIOD_M15, strategy_ema_period, shift);
   const double c   = iClose(_Symbol, PERIOD_M15, shift); // perf-allowed: bespoke closed-bar trendline check
   return c > ema;
  }

bool Light_Extreme(const int shift)
  {
   return QM_RSI(_Symbol, PERIOD_M15, strategy_rsi_period, shift) > 50.0;
  }

bool Light_Emotion(const int shift)
  {
   const double m = QM_MACD_Main  (_Symbol, PERIOD_M15, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, shift);
   const double s = QM_MACD_Signal(_Symbol, PERIOD_M15, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, shift);
   return m > s;
  }

bool Light_Sentiment(const int shift)
  {
   const double k = QM_Stoch_K(_Symbol, PERIOD_M15, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, shift);
   const double d = QM_Stoch_D(_Symbol, PERIOD_M15, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, shift);
   return k > d;
  }

int CountBullLights(const int shift)
  {
   return (int)Light_Trendline(shift) + (int)Light_Extreme(shift) +
          (int)Light_Emotion(shift)   + (int)Light_Sentiment(shift);
  }

bool AllFourBull(const int shift)
  {
   return Light_Trendline(shift) && Light_Extreme(shift) &&
          Light_Emotion(shift)   && Light_Sentiment(shift);
  }

bool AllFourBear(const int shift)
  {
   return !Light_Trendline(shift) && !Light_Extreme(shift) &&
          !Light_Emotion(shift)   && !Light_Sentiment(shift);
  }

// Freshness: at least one light flipped to bull within the last 3 closed bars.
bool FreshBullFlip()
  {
   bool t21 = (!Light_Trendline(2) && Light_Trendline(1)) ||
              (!Light_Extreme(2)   && Light_Extreme(1))   ||
              (!Light_Emotion(2)   && Light_Emotion(1))   ||
              (!Light_Sentiment(2) && Light_Sentiment(1));
   if(t21)
      return true;
   return (!Light_Trendline(3) && Light_Trendline(2)) ||
          (!Light_Extreme(3)   && Light_Extreme(2))   ||
          (!Light_Emotion(3)   && Light_Emotion(2))   ||
          (!Light_Sentiment(3) && Light_Sentiment(2));
  }

// Freshness: at least one light flipped to bear within the last 3 closed bars.
bool FreshBearFlip()
  {
   bool t21 = (Light_Trendline(2) && !Light_Trendline(1)) ||
              (Light_Extreme(2)   && !Light_Extreme(1))   ||
              (Light_Emotion(2)   && !Light_Emotion(1))   ||
              (Light_Sentiment(2) && !Light_Sentiment(1));
   if(t21)
      return true;
   return (Light_Trendline(3) && !Light_Trendline(2)) ||
          (Light_Extreme(3)   && !Light_Extreme(2))   ||
          (Light_Emotion(3)   && !Light_Emotion(2))   ||
          (Light_Sentiment(3) && !Light_Sentiment(2));
  }

bool HasOurPosition(ENUM_POSITION_TYPE &out_type)
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      out_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }
   return false;
  }

// Weekend / holiday gap detection: the previous closed bar (shift=1) opened more
// than 90 minutes after the bar before it (shift=2), indicating a market reopen.
bool IsPostWeekendBar()
  {
   const datetime t1 = iTime(_Symbol, PERIOD_M15, 1); // perf-allowed: gap detection for weekend skip
   const datetime t2 = iTime(_Symbol, PERIOD_M15, 2); // perf-allowed: gap detection for weekend skip
   if(t1 <= 0 || t2 <= 0)
      return false;
   return (t1 - t2) > 90 * 60;
  }

// ============================================================================
// Strategy hooks — Trade Filter
// ============================================================================

// No Trade Filter — exits run unrestricted; session gate enforced in EntrySignal.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// ============================================================================
// Strategy hooks — Entry Signal
// ============================================================================

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One-position-per-magic guard
   ENUM_POSITION_TYPE existing_type;
   if(HasOurPosition(existing_type))
      return false;

   // Session gate: European + US hours only (broker time)
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.hour < strategy_session_start_h || dt.hour >= strategy_session_end_h)
      return false;

   // Skip the first completed bar after a weekend / holiday market reopen
   if(IsPostWeekendBar())
      return false;

   // ATR must be positive for SL calculation
   const double atr = QM_ATR(_Symbol, PERIOD_M15, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   // ---- LONG: all four lights bullish + freshness gate ----
   if(AllFourBull(1) && FreshBullFlip())
     {
      const double bar_low = iLow(_Symbol, PERIOD_M15, 1); // perf-allowed: bespoke SL from signal bar low
      const double sl      = bar_low - strategy_sl_atr_mult * atr;
      const double ask     = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double sl_dist = ask - sl;
      if(sl_dist <= 0.0)
         return false;

      req.type              = QM_BUY;
      req.price             = 0.0;
      req.sl                = sl;
      req.tp                = ask + strategy_tp_rr * sl_dist;
      req.symbol_slot       = qm_magic_slot_offset;
      req.reason            = "SYMPHONIE_4LIGHTS_LONG";
      req.expiration_seconds = 0;
      g_entry_bar_time      = iTime(_Symbol, PERIOD_M15, 0); // perf-allowed: entry bar time for time-stop
      g_trade_is_long       = true;
      return true;
     }

   // ---- SHORT: all four lights bearish + freshness gate ----
   if(AllFourBear(1) && FreshBearFlip())
     {
      const double bar_high = iHigh(_Symbol, PERIOD_M15, 1); // perf-allowed: bespoke SL from signal bar high
      const double sl       = bar_high + strategy_sl_atr_mult * atr;
      const double bid      = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double sl_dist  = sl - bid;
      if(sl_dist <= 0.0)
         return false;

      req.type              = QM_SELL;
      req.price             = 0.0;
      req.sl                = sl;
      req.tp                = bid - strategy_tp_rr * sl_dist;
      req.symbol_slot       = qm_magic_slot_offset;
      req.reason            = "SYMPHONIE_4LIGHTS_SHORT";
      req.expiration_seconds = 0;
      g_entry_bar_time      = iTime(_Symbol, PERIOD_M15, 0); // perf-allowed: entry bar time for time-stop
      g_trade_is_long       = false;
      return true;
     }

   return false;
  }

// ============================================================================
// Strategy hooks — Trade Management
// ============================================================================

void Strategy_ManageOpenPosition()
  {
   // No intrabar SL/TP adjustment — exits handled by SL/TP broker orders and ExitSignal.
  }

// ============================================================================
// Strategy hooks — Exit Signal
// ============================================================================

bool Strategy_ExitSignal()
  {
   if(g_entry_bar_time == 0)
      return false;

   ENUM_POSITION_TYPE ptype;
   if(!HasOurPosition(ptype))
     {
      // SL/TP hit externally — reset state so entry can fire again
      g_entry_bar_time = 0;
      return false;
     }

   // Time stop: iBarShift returns how many bars ago the entry bar is
   const int bars_elapsed = iBarShift(_Symbol, PERIOD_M15, g_entry_bar_time, false);
   if(bars_elapsed >= strategy_time_stop_bars)
      return true;

   // Conservative exit: Symphonie Trendline (EMA proxy) reverses against the trade
   if(g_trade_is_long && !Light_Trendline(1))
      return true;
   if(!g_trade_is_long && Light_Trendline(1))
      return true;

   // Hard exit: two or more lights close opposite the trade direction
   const int bull_count = CountBullLights(1);
   if(g_trade_is_long && (4 - bull_count) >= 2)
      return true;
   if(!g_trade_is_long && bull_count >= 2)
      return true;

   return false;
  }

// ============================================================================
// Strategy hooks — News Filter Hook (P8 callable)
// ============================================================================

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to framework two-axis news filter
  }

// ============================================================================
// Framework wiring — do NOT edit below this line unless you know why.
// ============================================================================

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_9698_ff-symphonie-4lights-m15\"}");
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
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
      g_entry_bar_time = 0;
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
