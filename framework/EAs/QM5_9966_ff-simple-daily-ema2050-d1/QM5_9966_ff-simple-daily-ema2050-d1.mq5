#property strict
#property version   "5.0"
#property description "QM5_9966 ForexFactory Simple Daily EMA20/50 Continuation (D1)"

#include <QM/QM_Common.mqh>

// ==========================================================================
// QM5_9966 — ff-simple-daily-ema2050-d1
// Source: TheThing, "Simple Daily System", ForexFactory, 2007
//         (citation in SPEC.md §6 and strategy card)
// Signal: 3 consecutive same-color D1 candles + EMA(20) above/below EMA(50)
//         with both EMAs sloping in the same direction → market entry at D1 open.
// Stop:   min(prev_candle_low − 2 pips, entry − 90 pips); min 0.5×ATR(14,D1).
// TP:     +100 pips. BE: +30 pips trigger. Exit on opposite 3-candle signal.
// ==========================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 9966;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours              = 336;
input string qm_news_min_impact                   = "high";
input QM_NewsMode qm_news_mode_legacy             = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_ema_fast            = 20;   // EMA fast period
input int    strategy_ema_slow            = 50;   // EMA slow period
input int    strategy_candle_lookback     = 3;    // consecutive same-color candles required
input int    strategy_stop_max_pips       = 90;   // hard-cap stop distance in pips
input int    strategy_tp_pips             = 100;  // take-profit distance in pips
input int    strategy_be_trigger_pips     = 30;   // break-even trigger in pips
input int    strategy_atr_period          = 14;   // ATR period for minimum-stop floor
input double strategy_atr_min_sl_mult     = 0.5;  // min stop = this × ATR(14,D1)
input int    strategy_spread_pct_limit    = 8;    // max spread as % of stop distance

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

double OnePip()
  {
   // 5-digit / 3-digit broker: pip = 10 points. 4-digit / 2-digit: pip = 1 point.
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   return _Point * ((digits == 3 || digits == 5) ? 10.0 : 1.0);
  }

bool ThreeCandlesLong()
  {
   for(int i = 1; i <= strategy_candle_lookback; i++)
     {
      if(iClose(_Symbol, PERIOD_D1, i) <= iOpen(_Symbol, PERIOD_D1, i)) // perf-allowed: bespoke D1 candle-color check; no QM helper
         return false;
     }
   return true;
  }

bool ThreeCandlesShort()
  {
   for(int i = 1; i <= strategy_candle_lookback; i++)
     {
      if(iClose(_Symbol, PERIOD_D1, i) >= iOpen(_Symbol, PERIOD_D1, i)) // perf-allowed: bespoke D1 candle-color check; no QM helper
         return false;
     }
   return true;
  }

bool EmaFilterLong()
  {
   const double ema20_1 = QM_EMA(_Symbol, PERIOD_D1, strategy_ema_fast, 1);
   const double ema20_2 = QM_EMA(_Symbol, PERIOD_D1, strategy_ema_fast, 2);
   const double ema50_1 = QM_EMA(_Symbol, PERIOD_D1, strategy_ema_slow, 1);
   const double ema50_2 = QM_EMA(_Symbol, PERIOD_D1, strategy_ema_slow, 2);
   if(ema20_1 <= 0.0 || ema50_1 <= 0.0)
      return false;
   return (ema20_1 > ema50_1) && (ema20_1 > ema20_2) && (ema50_1 > ema50_2);
  }

bool EmaFilterShort()
  {
   const double ema20_1 = QM_EMA(_Symbol, PERIOD_D1, strategy_ema_fast, 1);
   const double ema20_2 = QM_EMA(_Symbol, PERIOD_D1, strategy_ema_fast, 2);
   const double ema50_1 = QM_EMA(_Symbol, PERIOD_D1, strategy_ema_slow, 1);
   const double ema50_2 = QM_EMA(_Symbol, PERIOD_D1, strategy_ema_slow, 2);
   if(ema20_1 <= 0.0 || ema50_1 <= 0.0)
      return false;
   return (ema20_1 < ema50_1) && (ema20_1 < ema20_2) && (ema50_1 < ema50_2);
  }

// ---------------------------------------------------------------------------
// Strategy hooks
// ---------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   // No session or regime filter required by the card.
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type              = QM_BUY;
   req.price             = 0;
   req.sl                = 0;
   req.tp                = 0;
   req.reason            = "";
   req.symbol_slot       = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const bool is_long  = ThreeCandlesLong()  && EmaFilterLong();
   const bool is_short = !is_long && ThreeCandlesShort() && EmaFilterShort();

   if(!is_long && !is_short)
      return false;

   const double pip  = OnePip();
   const double ask  = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid  = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double sprd = ask - bid;
   const double atr14 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);

   if(is_long)
     {
      const double prev_low  = iLow(_Symbol, PERIOD_D1, 1); // perf-allowed: closed D1 bar[1] low for structural stop
      const double sl_struct = prev_low - 2.0 * pip;
      const double sl_cap    = ask - (double)strategy_stop_max_pips * pip;
      double sl = MathMin(sl_struct, sl_cap);   // wider stop wins (lower value)
      double sl_dist = ask - sl;
      // Enforce 0.5×ATR minimum to prevent micro-stop on low-volatility days
      if(atr14 > 0.0 && sl_dist < strategy_atr_min_sl_mult * atr14)
        {
         sl_dist = strategy_atr_min_sl_mult * atr14;
         sl = ask - sl_dist;
        }
      if(sl_dist <= 0.0)
         return false;
      // Spread guard: spread ≤ 8 % of stop distance
      if(sprd > (double)strategy_spread_pct_limit * 0.01 * sl_dist)
         return false;

      const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      req.type    = QM_BUY;
      req.price   = 0;
      req.sl      = NormalizeDouble(sl, digits);
      req.tp      = NormalizeDouble(ask + (double)strategy_tp_pips * pip, digits);
      req.reason  = "FF_EMA2050_LONG";
      return true;
     }
   else // is_short
     {
      const double prev_high = iHigh(_Symbol, PERIOD_D1, 1); // perf-allowed: closed D1 bar[1] high for structural stop
      const double sl_struct = prev_high + 2.0 * pip;
      const double sl_cap    = bid + (double)strategy_stop_max_pips * pip;
      double sl = MathMax(sl_struct, sl_cap);   // wider stop wins (higher value)
      double sl_dist = sl - bid;
      // Enforce 0.5×ATR minimum
      if(atr14 > 0.0 && sl_dist < strategy_atr_min_sl_mult * atr14)
        {
         sl_dist = strategy_atr_min_sl_mult * atr14;
         sl = bid + sl_dist;
        }
      if(sl_dist <= 0.0)
         return false;
      if(sprd > (double)strategy_spread_pct_limit * 0.01 * sl_dist)
         return false;

      const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      req.type    = QM_SELL;
      req.price   = 0;
      req.sl      = NormalizeDouble(sl, digits);
      req.tp      = NormalizeDouble(bid - (double)strategy_tp_pips * pip, digits);
      req.reason  = "FF_EMA2050_SHORT";
      return true;
     }
  }

void Strategy_ManageOpenPosition()
  {
   // Break-even after +30 pips (card exit rule: "move stop to breakeven after +30 pips")
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      QM_TM_MoveToBreakEven(ticket, strategy_be_trigger_pips, 1);
     }
  }

bool Strategy_ExitSignal()
  {
   // Close on opposite 3-candle + EMA signal (card: "close before TP/SL if reverse forms")
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const ENUM_POSITION_TYPE ptype =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY  && ThreeCandlesShort() && EmaFilterShort())
         return true;
      if(ptype == POSITION_TYPE_SELL && ThreeCandlesLong()  && EmaFilterLong())
         return true;
     }
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to framework two-axis news filter
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
