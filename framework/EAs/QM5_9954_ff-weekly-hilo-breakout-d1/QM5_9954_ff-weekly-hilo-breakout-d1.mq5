#property strict
#property version   "5.0"
#property description "QM5_9954 — ForexFactory Weekly High-Low Breakout D1"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_9954 — FF Weekly High-Low Breakout D1
// Source: Erebus, "Never Lose Again", ForexFactory 2025
// Card: artifacts/cards_approved/QM5_9954_ff-weekly-hilo-breakout-d1.md
//
// Entry: D1 close breaks above prev-week high (long) or below prev-week low
//        (short) by 0.1*ATR(14) with SMA(20) trend bias.
// Exit:  SL at nearest D1 swing point; TP initial 1R, extended to ADR target
//        (cap 2R) when 0.8R reached and D1 close confirms direction.
//        Friday 20:00 close handled by framework.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 9954;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours     = 336;
input string qm_news_min_impact          = "high";
input QM_NewsMode qm_news_mode_legacy    = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 20;   // card: Friday 20:00 broker time

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_sma_period         = 20;   // SMA period for weekly trend bias
input int    strategy_atr_period         = 14;   // ATR/ADR period
input double strategy_breakout_atr_mult  = 0.10; // breakout buffer = mult * ATR(14,D1)
input int    strategy_swing_lookback     = 20;   // D1 bars back to search for swing points
input double strategy_tp_extension_r     = 0.80; // extend TP when position reaches this R multiple
input double strategy_tp_cap_r           = 2.00; // maximum TP extension in R multiples
input double strategy_adr_excess_pct     = 1.10; // skip entry if weekly range exceeds ADR*this

// =============================================================================
// Per-bar cached state (updated once per D1 bar via AdvanceState_OnNewBar)
// =============================================================================

double g_pwh               = 0.0;   // previous-week high
double g_pwl               = 0.0;   // previous-week low
double g_adr               = 0.0;   // ATR(14,D1) as ADR proxy
double g_sma_cur           = 0.0;   // SMA(20,D1) at shift 1
double g_sma_5ago          = 0.0;   // SMA(20,D1) at shift 6 (slope check)
int    g_bias              = 0;     // +1 bullish, -1 bearish, 0 neutral
double g_week_range        = 0.0;   // current week H-L from completed D1 bars
bool   g_week_long_taken   = false; // one long attempt per week
bool   g_week_short_taken  = false; // one short attempt per week
double g_swing_low         = 0.0;   // nearest confirmed D1 swing low
double g_swing_high        = 0.0;   // nearest confirmed D1 swing high
int    g_last_d1_close_dir = 0;     // +1 if last D1 bar bullish, -1 bearish

// Trade management state
double g_entry_price       = 0.0;
double g_initial_sl_dist   = 0.0;
bool   g_tp_extended       = false;

// =============================================================================
// Helpers
// =============================================================================

void ComputeWeeklyPWHL(const MqlRates &rates[], const int n)
  {
   // rates[] is ArraySetAsSeries=true: rates[0]=most recent completed bar
   // Called when we detect a new week opened.
   // Collect all bars from the PREVIOUS week (contiguous block starting at rates[0])
   // by following strictly decreasing day_of_week until it wraps back.
   double pw_hi = rates[0].high;
   double pw_lo = rates[0].low;
   for(int i = 1; i < n; i++)
     {
      MqlDateTime d, dprev;
      TimeToStruct(rates[i].time,   d);
      TimeToStruct(rates[i-1].time, dprev);
      if(d.day_of_week >= dprev.day_of_week)
         break; // crossed week boundary (e.g., Fri(5) -> Mon(1) of prior week)
      pw_hi = MathMax(pw_hi, rates[i].high);
      pw_lo = MathMin(pw_lo, rates[i].low);
     }
   if(pw_hi > 0.0 && pw_lo < DBL_MAX)
     {
      g_pwh = pw_hi;
      g_pwl = pw_lo;
     }
  }

void ComputeCurrentWeekRange(const MqlRates &rates[], const int n)
  {
   // Collect completed D1 bars belonging to the current week (rates[0] is the most recent).
   // Stop when day_of_week increments (i.e., we've crossed into the previous week).
   double cw_hi = rates[0].high;
   double cw_lo = rates[0].low;
   for(int i = 1; i < n; i++)
     {
      MqlDateTime d, dprev;
      TimeToStruct(rates[i].time,   d);
      TimeToStruct(rates[i-1].time, dprev);
      if(d.day_of_week >= dprev.day_of_week)
         break;
      cw_hi = MathMax(cw_hi, rates[i].high);
      cw_lo = MathMin(cw_lo, rates[i].low);
     }
   g_week_range = (cw_hi > 0.0) ? (cw_hi - cw_lo) : 0.0;
  }

void AdvanceState_OnNewBar()
  {
   // Indicator values via framework helpers (D1, shift 1 = last closed bar)
   g_adr     = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   g_sma_cur  = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_period, 1);
   g_sma_5ago = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_period, 1 + 5);

   // Load D1 bar OHLC for weekly/swing structure  // perf-allowed: bespoke weekly/swing structure
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int n = CopyRates(_Symbol, PERIOD_D1, 1, strategy_swing_lookback + 4, rates);
   if(n < 3)
      return;

   // Bias: D1 close vs SMA and SMA slope (positive = bullish)
   double close1 = rates[0].close;
   if(g_sma_cur > 0.0 && g_sma_5ago > 0.0)
     {
      if(close1 > g_sma_cur && g_sma_cur > g_sma_5ago)
         g_bias = 1;
      else if(close1 < g_sma_cur && g_sma_cur < g_sma_5ago)
         g_bias = -1;
      else
         g_bias = 0;
     }

   // Last D1 close direction (for TP extension confirmation)
   g_last_d1_close_dir = (rates[0].close > rates[0].open) ? 1
                       : (rates[0].close < rates[0].open) ? -1 : 0;

   // Weekly state: detect week transition via current broker time
   MqlDateTime now_dt;
   TimeToStruct(TimeCurrent(), now_dt);
   bool is_monday = (now_dt.day_of_week == 1);

   if(is_monday)
     {
      // New week: rates[0]=Friday of prev week; collect prev week for PWH/PWL
      ComputeWeeklyPWHL(rates, n);
      g_week_long_taken  = false;
      g_week_short_taken = false;
      // Current week so far = just today (not yet complete), range = 0
      g_week_range = 0.0;
     }
   else
     {
      // Mid-week: compute current week range from completed bars
      ComputeCurrentWeekRange(rates, n);
     }

   // Swing high/low detection: 2-bar pivot in rates[] (shift 1..n-2)
   g_swing_low  = 0.0;
   g_swing_high = 0.0;
   for(int i = 1; i < n - 1 && (g_swing_low == 0.0 || g_swing_high == 0.0); i++)
     {
      if(g_swing_low == 0.0 &&
         rates[i].low < rates[i-1].low && rates[i].low < rates[i+1].low)
         g_swing_low = rates[i].low;

      if(g_swing_high == 0.0 &&
         rates[i].high > rates[i-1].high && rates[i].high > rates[i+1].high)
         g_swing_high = rates[i].high;
     }
  }

// =============================================================================
// Strategy hooks
// =============================================================================

bool Strategy_NoTradeFilter()
  {
   return false; // Time filters applied in EntrySignal; framework handles news/Friday
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Advance per-bar state once per D1 bar (called from QM_IsNewBar gate)
   AdvanceState_OnNewBar();

   // Guard: prerequisite data
   if(g_pwh <= 0.0 || g_pwl <= 0.0 || g_adr <= 0.0)
      return false;

   // Time filter: no new entries after Thursday 12:00 or on Friday/Sat/Sun
   MqlDateTime now_dt;
   TimeToStruct(TimeCurrent(), now_dt);
   int dow  = now_dt.day_of_week;  // 0=Sun,1=Mon,...,5=Fri,6=Sat
   int hour = now_dt.hour;
   if((dow == 4 && hour >= 12) || dow == 5 || dow == 6 || dow == 0)
      return false;

   // Weekly range excess filter
   if(g_adr > 0.0 && g_week_range > strategy_adr_excess_pct * g_adr)
      return false;

   // No existing position for this EA (framework will also enforce, but check here to avoid log noise)
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) == (long)magic)
         return false; // position already open
     }

   const double point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double buffer = strategy_breakout_atr_mult * g_adr;

   // --- Long setup ---
   if(!g_week_long_taken && g_bias == 1)
     {
      // Last closed D1 bar above PWH breakout level
      MqlRates chk[];
      ArraySetAsSeries(chk, true);
      if(CopyRates(_Symbol, PERIOD_D1, 1, 1, chk) == 1)  // perf-allowed: entry trigger check
        {
         if(chk[0].close > g_pwh + buffer)
           {
            const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            // SL: nearest swing low below entry; fallback = 1 ATR below entry
            double sl = 0.0;
            if(g_swing_low > 0.0 && g_swing_low < ask)
               sl = g_swing_low - point;
            else
               sl = ask - g_adr;
            if(sl <= 0.0 || sl >= ask)
               return false;

            const double sl_dist = ask - sl;
            const double tp      = ask + sl_dist;  // initial 1R

            req.type              = QM_BUY;
            req.price             = 0.0;   // market order
            req.sl                = sl;
            req.tp                = tp;
            req.reason            = "FF_WKLY_HI_BREAK_LONG";
            req.symbol_slot       = qm_magic_slot_offset;
            req.expiration_seconds = 0;

            g_initial_sl_dist  = sl_dist;
            g_entry_price      = 0.0;  // will be read from position on first manage tick
            g_tp_extended      = false;
            g_week_long_taken  = true;
            return true;
           }
        }
     }

   // --- Short setup ---
   if(!g_week_short_taken && g_bias == -1)
     {
      MqlRates chk[];
      ArraySetAsSeries(chk, true);
      if(CopyRates(_Symbol, PERIOD_D1, 1, 1, chk) == 1)  // perf-allowed: entry trigger check
        {
         if(chk[0].close < g_pwl - buffer)
           {
            const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            double sl = 0.0;
            if(g_swing_high > 0.0 && g_swing_high > bid)
               sl = g_swing_high + point;
            else
               sl = bid + g_adr;
            if(sl <= bid)
               return false;

            const double sl_dist = sl - bid;
            const double tp      = bid - sl_dist;  // initial 1R
            if(tp <= 0.0)
               return false;

            req.type              = QM_SELL;
            req.price             = 0.0;
            req.sl                = sl;
            req.tp                = tp;
            req.reason            = "FF_WKLY_LO_BREAK_SHORT";
            req.symbol_slot       = qm_magic_slot_offset;
            req.expiration_seconds = 0;

            g_initial_sl_dist  = sl_dist;
            g_entry_price      = 0.0;
            g_tp_extended      = false;
            g_week_short_taken = true;
            return true;
           }
        }
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // TP extension: once price reaches 0.8R AND last D1 close is in trade direction,
   // extend TP to ADR-projected target, capped at 2R.
   if(g_tp_extended || g_adr <= 0.0)
      return;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != (long)magic)
         continue;

      const double entry   = PositionGetDouble(POSITION_PRICE_OPEN);
      const double pos_sl  = PositionGetDouble(POSITION_SL);
      const double pos_tp  = PositionGetDouble(POSITION_TP);
      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      // Latch initial SL distance on first manage tick for this position
      if(g_entry_price != entry)
        {
         g_entry_price     = entry;
         g_initial_sl_dist = (pos_sl > 0.0) ? MathAbs(entry - pos_sl) : g_adr;
         g_tp_extended     = false;
        }

      if(g_initial_sl_dist <= 0.0)
         continue;

      const double current_price = (ptype == POSITION_TYPE_BUY)
                                 ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                 : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double profit_dist = (ptype == POSITION_TYPE_BUY)
                               ? (current_price - entry)
                               : (entry - current_price);

      // Check: reached 0.8R
      if(profit_dist < strategy_tp_extension_r * g_initial_sl_dist)
         continue;

      // Check: last D1 close confirms trade direction
      bool d1_confirms = (ptype == POSITION_TYPE_BUY)
                       ? (g_last_d1_close_dir >= 0)
                       : (g_last_d1_close_dir <= 0);
      if(!d1_confirms)
         continue;

      // Extend TP: entry ± ADR, capped at entry ± 2R
      const double adr_tp  = (ptype == POSITION_TYPE_BUY)
                           ? entry + g_adr
                           : entry - g_adr;
      const double cap_tp  = (ptype == POSITION_TYPE_BUY)
                           ? entry + strategy_tp_cap_r * g_initial_sl_dist
                           : entry - strategy_tp_cap_r * g_initial_sl_dist;
      const double new_tp  = (ptype == POSITION_TYPE_BUY)
                           ? MathMin(adr_tp, cap_tp)
                           : MathMax(adr_tp, cap_tp);

      if(new_tp != pos_tp)
         QM_TM_MoveTP(ticket, new_tp, "ff_wkly_tp_ext_0.8R");
      g_tp_extended = true;
      break;
     }
  }

bool Strategy_ExitSignal()
  {
   // All exits via SL/TP and framework Friday close at 20:00; no discretionary exit needed
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade2 in framework
  }

// =============================================================================
// Framework wiring — do NOT edit below this line unless you know why.
// =============================================================================

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_9954_ff-weekly-hilo-breakout-d1\"}");
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
