#property strict
#property version   "5.0"
#property description "QM5_9412 PAQ Engulfing Reversal (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// Strategy: PAQ Engulfing Reversal
// Card:     QM5_9412_mql5-paq-engulf
// Source:   ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb
//           Christian Benjamin, MQL5 Article 18207, 2025-05-22
// Logic:    Bullish/bearish engulfing body on H1, EMA(20) context filter,
//           2R TP, time stop 24H, opposite engulf exit, EMA cross-back exit.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 9412;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours               = 336;
input string qm_news_min_impact                    = "high";
input QM_NewsMode qm_news_mode_legacy              = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_ema_period          = 20;     // EMA context filter period
input int    strategy_atr_period          = 14;     // ATR period for SL and range filter
input double strategy_sl_atr_mult         = 0.25;   // ATR multiple added to pattern extremes for SL
input double strategy_tp_rr               = 2.0;    // Risk:reward ratio for TP (2R)
input double strategy_range_filter        = 0.5;    // Min current-bar range as ATR fraction (noise guard)
input int    strategy_max_hold_bars       = 24;     // Max hold time in H1 bars (time stop)

// ---------------------------------------------------------------------------
// File-scope state for exit logic (position lifecycle tracking, not IsNewBar)
// ---------------------------------------------------------------------------
bool     g_pos_was_fav_ema    = false;  // true once price closed on EMA's favourable side
datetime g_pos_entry_bar_time = 0;      // iTime[0] captured when position opened (for entry-bar guard)

// ---------------------------------------------------------------------------
// No Trade Filter
// ---------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   return false;
  }

// ---------------------------------------------------------------------------
// Entry Signal — called once per closed bar (QM_IsNewBar gate in framework)
// ---------------------------------------------------------------------------

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One-position-per-magic guard
   const int magic = QM_FrameworkMagic();
   if(QM_EntryHasOpenPosition(magic, _Symbol))
      return false;

   const double currOpen  = iOpen (_Symbol, PERIOD_CURRENT, 1); // perf-allowed: engulfing reads fixed closed-bar shifts, O(1), gated by QM_IsNewBar
   const double currClose = iClose(_Symbol, PERIOD_CURRENT, 1); // perf-allowed
   const double currHigh  = iHigh (_Symbol, PERIOD_CURRENT, 1); // perf-allowed
   const double currLow   = iLow  (_Symbol, PERIOD_CURRENT, 1); // perf-allowed
   const double prevOpen  = iOpen (_Symbol, PERIOD_CURRENT, 2); // perf-allowed
   const double prevClose = iClose(_Symbol, PERIOD_CURRENT, 2); // perf-allowed
   const double prevHigh  = iHigh (_Symbol, PERIOD_CURRENT, 2); // perf-allowed
   const double prevLow   = iLow  (_Symbol, PERIOD_CURRENT, 2); // perf-allowed

   if(currOpen <= 0 || prevOpen <= 0) return false;

   const double atr = QM_ATR(_Symbol, PERIOD_CURRENT, strategy_atr_period, 1);
   const double ema = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_ema_period,  1);
   if(atr <= 0 || ema <= 0) return false;

   // Noise guard: skip tiny-body bars
   const double currRange = currHigh - currLow;
   if(currRange < strategy_range_filter * atr) return false;

   const double currBody = MathAbs(currClose - currOpen);
   const double prevBody = MathAbs(prevClose - prevOpen);
   if(prevBody <= 0 || currBody <= prevBody) return false;

   const double patternLow  = MathMin(currLow,  prevLow);
   const double patternHigh = MathMax(currHigh, prevHigh);

   // Bullish engulfing → BUY (prior bearish, current engulfs, close at/below EMA)
   const bool bull = (prevClose < prevOpen) &&   // prior bearish
                     (currOpen  <= prevClose) &&  // open within prior body
                     (currClose >= prevOpen)  &&  // close engulfs prior body high
                     (currClose <= ema);          // below or at EMA (mean-reversion context)

   // Bearish engulfing → SELL (prior bullish, current engulfs, close at/above EMA)
   const bool bear = (prevClose > prevOpen) &&   // prior bullish
                     (currOpen  >= prevClose) &&  // open within prior body
                     (currClose <= prevOpen)  &&  // close engulfs prior body low
                     (currClose >= ema);          // above or at EMA

   if(!bull && !bear) return false;

   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   req.price              = 0.0;  // market order

   if(bull)
     {
      const double sl     = patternLow - strategy_sl_atr_mult * atr;
      const double point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      const double sl_pts = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - sl) / point;
      if(sl_pts <= 0) return false;
      req.type   = QM_BUY;
      req.sl     = sl;
      req.tp     = SymbolInfoDouble(_Symbol, SYMBOL_ASK) + strategy_tp_rr * sl_pts * point;
      req.reason = "PAQ_BULL_ENGULF";
     }
   else
     {
      const double sl     = patternHigh + strategy_sl_atr_mult * atr;
      const double point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      const double sl_pts = (sl - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / point;
      if(sl_pts <= 0) return false;
      req.type   = QM_SELL;
      req.sl     = sl;
      req.tp     = SymbolInfoDouble(_Symbol, SYMBOL_BID) - strategy_tp_rr * sl_pts * point;
      req.reason = "PAQ_BEAR_ENGULF";
     }

   // Reset exit-tracking state for new position
   g_pos_was_fav_ema    = false;
   g_pos_entry_bar_time = iTime(_Symbol, PERIOD_CURRENT, 0); // perf-allowed: entry bar capture for exit-guard, O(1)

   return true;
  }

// ---------------------------------------------------------------------------
// Trade Management — no trailing/BE per card spec (SL/TP + discrete exits)
// ---------------------------------------------------------------------------

void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing stop or BE logic; exits handled by SL/TP and Strategy_ExitSignal.
  }

// ---------------------------------------------------------------------------
// Exit Signal — per-tick; bar-based checks guarded by entry-bar elapsed time
// ---------------------------------------------------------------------------

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0) return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))             continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;

      const ENUM_POSITION_TYPE ptype    = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const datetime           open_tm  = (datetime)PositionGetInteger(POSITION_TIME);
      const long               elapsed  = (long)(TimeCurrent() - open_tm);

      // Time stop: 24 H1 bars ≈ 24 hours (always active)
      if(elapsed >= (long)strategy_max_hold_bars * 3600L)
         return true;

      // Bar-based exits: skip the entry bar to avoid data aliasing
      // (bar[1] at entry is the signal bar; EMA/engulf checks valid from bar after entry)
      if(elapsed < 3600L)
         return false;

      const double c1 = iClose(_Symbol, PERIOD_CURRENT, 1); // perf-allowed: exit checks fixed closed-bar shifts, O(1), stable within bar
      const double o1 = iOpen (_Symbol, PERIOD_CURRENT, 1); // perf-allowed
      const double c2 = iClose(_Symbol, PERIOD_CURRENT, 2); // perf-allowed
      const double o2 = iOpen (_Symbol, PERIOD_CURRENT, 2); // perf-allowed
      const double ema = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_ema_period, 1);

      // Track whether price has closed on EMA's favourable side (required for EMA cross-back exit)
      if(ema > 0)
        {
         if(ptype == POSITION_TYPE_BUY  && c1 >= ema) g_pos_was_fav_ema = true;
         if(ptype == POSITION_TYPE_SELL && c1 <= ema) g_pos_was_fav_ema = true;
        }

      // EMA cross-back exit: only if position first moved to favourable EMA side
      if(g_pos_was_fav_ema && ema > 0)
        {
         if(ptype == POSITION_TYPE_BUY  && c1 < ema) return true;
         if(ptype == POSITION_TYPE_SELL && c1 > ema) return true;
        }

      // Opposite engulfing exit
      const double body1 = MathAbs(c1 - o1);
      const double body2 = MathAbs(c2 - o2);
      if(body2 > 0 && body1 > body2)
        {
         if(ptype == POSITION_TYPE_BUY)
           {
            // Bearish engulfing: prior bullish, current engulfs downward
            if(c2 > o2 && o1 >= c2 && c1 <= o2) return true;
           }
         else
           {
            // Bullish engulfing: prior bearish, current engulfs upward
            if(c2 < o2 && o1 <= c2 && c1 >= o2) return true;
           }
        }

      break;  // only first matching position per magic
     }

   return false;
  }

// ---------------------------------------------------------------------------
// News Filter Hook — defer to framework's two-axis check
// ---------------------------------------------------------------------------

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// ---------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line unless you know why.
// ---------------------------------------------------------------------------

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_9412\",\"ea\":\"mql5-paq-engulf\"}");
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
