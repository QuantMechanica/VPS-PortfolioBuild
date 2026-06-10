#property strict
#property version   "5.0"
#property description "QM5_9413 MQL5 PAQ Marubozu Continuation"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_9413 — MQL5 PAQ Marubozu Continuation
// Card: D:\QM\strategy_farm\artifacts\cards_approved\QM5_9413_mql5-paq-marubozu.md
// Source: Christian Benjamin, MQL5 Article 18207 (2025-05-22)
// Build task: ca7a766f-9186-44a6-a088-80ed301c6e8d
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 9413;
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
input double strategy_marubozu_ratio      = 0.90; // Body/TotalRange minimum (card default 0.90)
input int    strategy_atr_period          = 14;   // ATR period for SL and range filter
input double strategy_atr_sl_mult         = 0.25; // SL = bar extreme +/- atr * this
input int    strategy_ema_trend_period    = 50;   // EMA trend filter period
input int    strategy_ema_exit_period     = 20;   // EMA exit cross period
input double strategy_tp_risk_mult        = 1.5;  // TP at N * R from entry
input int    strategy_time_exit_bars      = 18;   // max hold time in H1 bars

// ---------------------------------------------------------------------------
// File-scope: bar-level exit flag updated in Strategy_EntrySignal (new-bar gate)
// ---------------------------------------------------------------------------
bool g_exit_bar_signal = false;

// ---------------------------------------------------------------------------
// Helper: find our open position on this symbol/magic
// ---------------------------------------------------------------------------
bool HasOurPosition(ENUM_POSITION_TYPE &out_type, datetime &out_open_time)
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      out_type      = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      out_open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }
   return false;
  }

// ---------------------------------------------------------------------------
// Strategy hooks
// ---------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Called once per new closed bar (QM_IsNewBar gate already passed by framework).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Reset per-bar exit cache
   g_exit_bar_signal = false;

   // Read last closed bar OHLC — bespoke Marubozu body/wick structural math; no QM_* helper covers raw OHLC
   const double bar_open  = iOpen(_Symbol,  _Period, 1); // perf-allowed
   const double bar_high  = iHigh(_Symbol,  _Period, 1); // perf-allowed
   const double bar_low   = iLow(_Symbol,   _Period, 1); // perf-allowed
   const double bar_close = iClose(_Symbol, _Period, 1); // perf-allowed
   if(bar_open <= 0.0 || bar_high <= 0.0 || bar_low <= 0.0 || bar_close <= 0.0)
      return false;

   // Indicator reads (framework-pooled handles)
   const double atr14  = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   const double ema50  = QM_EMA(_Symbol, _Period, strategy_ema_trend_period, 1);
   const double ema20  = QM_EMA(_Symbol, _Period, strategy_ema_exit_period, 1);
   if(atr14 <= 0.0 || ema50 <= 0.0 || ema20 <= 0.0)
      return false;

   // Marubozu geometry on the last closed bar
   const double total_range = bar_high - bar_low;
   const double body        = MathAbs(bar_close - bar_open);
   const double upper_wick  = bar_high - MathMax(bar_open, bar_close);
   const double lower_wick  = MathMin(bar_open, bar_close) - bar_low;
   const double wick_max    = total_range * (1.0 - strategy_marubozu_ratio);

   // --- Update bar-level exit signals for any open position ---
   ENUM_POSITION_TYPE pos_type;
   datetime pos_open_time;
   if(HasOurPosition(pos_type, pos_open_time))
     {
      // EMA(20) close-back: price closed against the trade through EMA20
      if(pos_type == POSITION_TYPE_BUY  && bar_close < ema20) g_exit_bar_signal = true;
      if(pos_type == POSITION_TYPE_SELL && bar_close > ema20) g_exit_bar_signal = true;

      // Opposite-direction Marubozu formed on this bar
      if(!g_exit_bar_signal && total_range > 0.0 &&
         body >= total_range * strategy_marubozu_ratio &&
         upper_wick <= wick_max && lower_wick <= wick_max)
        {
         const bool bar_bullish = bar_close > bar_open;
         const bool bar_bearish = bar_close < bar_open;
         if(pos_type == POSITION_TYPE_BUY  && bar_bearish) g_exit_bar_signal = true;
         if(pos_type == POSITION_TYPE_SELL && bar_bullish)  g_exit_bar_signal = true;
        }

      return false; // V5: one position per symbol/magic
     }

   // --- Range filter: skip weak / flat bars ---
   if(total_range < atr14)
      return false;

   // --- Marubozu quality filter ---
   if(body < total_range * strategy_marubozu_ratio)
      return false;
   if(upper_wick > wick_max || lower_wick > wick_max)
      return false;

   // --- Direction + EMA trend filter then build entry request ---
   if(bar_close > bar_open && bar_close > ema50)
     {
      // Bullish Marubozu above EMA50 — BUY
      const double ask  = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double sl   = NormalizeDouble(bar_low - strategy_atr_sl_mult * atr14, _Digits);
      const double risk = ask - sl;
      if(risk <= 0.0) return false;
      const double tp   = NormalizeDouble(ask + strategy_tp_risk_mult * risk, _Digits);

      req.type        = QM_BUY;
      req.price       = 0.0;
      req.sl          = sl;
      req.tp          = tp;
      req.reason      = "marubozu_bull";
      req.symbol_slot = qm_magic_slot_offset;
      return true;
     }

   if(bar_close < bar_open && bar_close < ema50)
     {
      // Bearish Marubozu below EMA50 — SELL
      const double bid  = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double sl   = NormalizeDouble(bar_high + strategy_atr_sl_mult * atr14, _Digits);
      const double risk = sl - bid;
      if(risk <= 0.0) return false;
      const double tp   = NormalizeDouble(bid - strategy_tp_risk_mult * risk, _Digits);

      req.type        = QM_SELL;
      req.price       = 0.0;
      req.sl          = sl;
      req.tp          = tp;
      req.reason      = "marubozu_bear";
      req.symbol_slot = qm_magic_slot_offset;
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // SL/TP handles 1.5R target and structural stop; no intra-trade adjustments needed.
  }

bool Strategy_ExitSignal()
  {
   // Bar-based exit: EMA(20) close-back or opposite Marubozu (set in EntrySignal per bar)
   if(g_exit_bar_signal)
      return true;

   // Time stop: 18 H1 bars elapsed since position open
   const long max_hold_secs = (long)strategy_time_exit_bars * 3600L;
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      const datetime open_t = (datetime)PositionGetInteger(POSITION_TIME);
      if((TimeCurrent() - open_t) >= max_hold_secs)
         return true;
     }
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade2 via framework
  }

// =============================================================================
// Framework wiring — do NOT edit below this line.
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
