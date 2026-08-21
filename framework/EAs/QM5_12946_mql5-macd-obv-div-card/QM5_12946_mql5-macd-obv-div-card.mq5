#property strict
#property version   "5.0"
#property description "QM5_12946 MACD-OBV confirmed-fractal divergence reversal"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_12946 mql5-macd-obv-div-card
// -----------------------------------------------------------------------------
// Source card: Christian Benjamin, "MQL5 Wizard Techniques you should know
// (Part 71): MACD plus OBV". The card fixes the source concept into a fully
// mechanical H1 reversal: 3-left/3-right price fractals, MACD-main and
// tick-volume OBV divergence, first confirming candle, structural ATR stop,
// and a 2R target. Raw rates are read only from Strategy_EntrySignal, behind
// the framework's QM_IsNewBar gate.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12946;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_macd_fast               = 12;
input int    strategy_macd_slow               = 26;
input int    strategy_macd_signal             = 9;
input int    strategy_atr_period              = 14;
input double strategy_atr_swing_buffer        = 0.25;
input double strategy_reward_risk             = 2.0;
input int    strategy_divergence_expiry_bars  = 10;
input int    strategy_swing_scan_bars         = 160;

const int STRATEGY_FRACTAL_LEFT   = 3;
const int STRATEGY_FRACTAL_RIGHT  = 3;

int    g_pending_direction = 0;
int    g_pending_age = 0;
double g_pending_swing_price = 0.0;
bool   g_exit_cached = false;

// -----------------------------------------------------------------------------
// Deterministic structural helpers
// -----------------------------------------------------------------------------

bool Strategy_IsFractal(const MqlRates &rates[], const int copied,
                        const int index, const bool want_low)
  {
   if(index - STRATEGY_FRACTAL_RIGHT < 0 ||
      index + STRATEGY_FRACTAL_LEFT >= copied)
      return false;

   for(int k = 1; k <= STRATEGY_FRACTAL_RIGHT; ++k)
     {
      if(want_low && rates[index].low >= rates[index - k].low)
         return false;
      if(!want_low && rates[index].high <= rates[index - k].high)
         return false;
     }

   for(int k = 1; k <= STRATEGY_FRACTAL_LEFT; ++k)
     {
      if(want_low && rates[index].low >= rates[index + k].low)
         return false;
      if(!want_low && rates[index].high <= rates[index + k].high)
         return false;
     }
   return true;
  }

int Strategy_PreviousFractal(const MqlRates &rates[], const int copied,
                             const int recent_index, const bool want_low)
  {
   const int last_index = copied - STRATEGY_FRACTAL_LEFT - 1;
   for(int i = recent_index + 1; i <= last_index; ++i)
      if(Strategy_IsFractal(rates, copied, i, want_low))
         return i;
   return -1;
  }

bool Strategy_BuildObv(const MqlRates &rates[], const int copied, double &obv[])
  {
   if(copied < 2)
      return false;

   ArrayResize(obv, copied);
   obv[copied - 1] = 0.0;
   for(int i = copied - 2; i >= 0; --i)
     {
      obv[i] = obv[i + 1];
      const double volume = (double)rates[i].tick_volume;
      if(rates[i].close > rates[i + 1].close)
         obv[i] += volume;
      else if(rates[i].close < rates[i + 1].close)
         obv[i] -= volume;
     }
   return true;
  }

void Strategy_DetectConfirmedDivergence(const MqlRates &rates[],
                                        const double &obv[],
                                        const int copied,
                                        bool &long_divergence,
                                        bool &short_divergence,
                                        double &long_swing,
                                        double &short_swing)
  {
   long_divergence = false;
   short_divergence = false;
   long_swing = 0.0;
   short_swing = 0.0;

   // CopyRates starts at shift 1, so index 3 is the newest pivot whose three
   // right-hand bars have all closed. Indicator shift is therefore index + 1.
   const int recent = STRATEGY_FRACTAL_RIGHT;

   if(Strategy_IsFractal(rates, copied, recent, true))
     {
      const int older = Strategy_PreviousFractal(rates, copied, recent, true);
      if(older >= 0)
        {
         const double macd_recent = QM_MACD_Main(_Symbol, PERIOD_H1,
                                                strategy_macd_fast,
                                                strategy_macd_slow,
                                                strategy_macd_signal,
                                                recent + 1);
         const double macd_older = QM_MACD_Main(_Symbol, PERIOD_H1,
                                               strategy_macd_fast,
                                               strategy_macd_slow,
                                               strategy_macd_signal,
                                               older + 1);
         const bool obv_higher_low = (obv[recent] > obv[older]);
         const bool obv_rises_after =
            (obv[recent - 1] > obv[recent] &&
             obv[recent - 2] > obv[recent - 1] &&
             obv[recent - 3] > obv[recent - 2]);

         long_divergence =
            (rates[recent].low < rates[older].low &&
             macd_recent > macd_older &&
             (obv_higher_low || obv_rises_after));
         if(long_divergence)
            long_swing = rates[recent].low;
        }
     }

   if(Strategy_IsFractal(rates, copied, recent, false))
     {
      const int older = Strategy_PreviousFractal(rates, copied, recent, false);
      if(older >= 0)
        {
         const double macd_recent = QM_MACD_Main(_Symbol, PERIOD_H1,
                                                strategy_macd_fast,
                                                strategy_macd_slow,
                                                strategy_macd_signal,
                                                recent + 1);
         const double macd_older = QM_MACD_Main(_Symbol, PERIOD_H1,
                                               strategy_macd_fast,
                                               strategy_macd_slow,
                                               strategy_macd_signal,
                                               older + 1);
         const bool obv_lower_high = (obv[recent] < obv[older]);
         const bool obv_falls_after =
            (obv[recent - 1] < obv[recent] &&
             obv[recent - 2] < obv[recent - 1] &&
             obv[recent - 3] < obv[recent - 2]);

         short_divergence =
            (rates[recent].high > rates[older].high &&
             macd_recent < macd_older &&
             (obv_lower_high || obv_falls_after));
         if(short_divergence)
            short_swing = rates[recent].high;
        }
     }
  }

int Strategy_PositionDirection()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return 0;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const ENUM_POSITION_TYPE type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(type == POSITION_TYPE_BUY)
         return 1;
      if(type == POSITION_TYPE_SELL)
         return -1;
     }
   return 0;
  }

void Strategy_ClearPending()
  {
   g_pending_direction = 0;
   g_pending_age = 0;
   g_pending_swing_price = 0.0;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// The card adds no per-tick filter. Timeframe and parameter checks stay in the
// closed-bar entry hook so management and exits remain live on every chart tick.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = 0;
   req.expiration_seconds = 0;

   if((ENUM_TIMEFRAMES)_Period != PERIOD_H1 ||
      strategy_macd_fast < 2 ||
      strategy_macd_slow <= strategy_macd_fast ||
      strategy_macd_signal < 1 ||
      strategy_atr_period < 1 ||
      strategy_atr_swing_buffer <= 0.0 ||
      strategy_reward_risk <= 0.0 ||
      strategy_divergence_expiry_bars < 1 ||
      strategy_swing_scan_bars < 48)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_H1, 1,
                                strategy_swing_scan_bars, rates); // perf-allowed: bounded price/OBV scan, called only after framework QM_IsNewBar().
   const int macd_warmup_bars = strategy_macd_slow +
                                strategy_macd_signal + 10;
   const int minimum_bars = (macd_warmup_bars > 48)
                            ? macd_warmup_bars
                            : 48;
   if(copied < minimum_bars)
      return false;

   double obv[];
   if(!Strategy_BuildObv(rates, copied, obv))
      return false;

   bool long_divergence = false;
   bool short_divergence = false;
   double long_swing = 0.0;
   double short_swing = 0.0;
   Strategy_DetectConfirmedDivergence(rates, obv, copied,
                                      long_divergence, short_divergence,
                                      long_swing, short_swing);

   const int position_direction = Strategy_PositionDirection();
   const double macd_closed = QM_MACD_Main(_Symbol, PERIOD_H1,
                                           strategy_macd_fast,
                                           strategy_macd_slow,
                                           strategy_macd_signal, 1);
   const double macd_previous = QM_MACD_Main(_Symbol, PERIOD_H1,
                                             strategy_macd_fast,
                                             strategy_macd_slow,
                                             strategy_macd_signal, 2);

   if(position_direction > 0 &&
      (short_divergence ||
       (macd_closed < 0.0 && macd_previous >= 0.0)))
      g_exit_cached = true;
   else if(position_direction < 0 &&
           (long_divergence ||
            (macd_closed > 0.0 && macd_previous <= 0.0)))
      g_exit_cached = true;

   if(position_direction != 0)
     {
      Strategy_ClearPending();
      return false;
     }

   // A pending divergence can use only a later candle as confirmation. Age 1
   // is the first closed bar after the fractal/divergence was confirmed.
   if(g_pending_direction != 0)
     {
      g_pending_age++;
      if(g_pending_age > strategy_divergence_expiry_bars)
         Strategy_ClearPending();
      else
        {
         const bool confirming_candle =
            (g_pending_direction > 0)
            ? (rates[0].close > rates[0].open)
            : (rates[0].close < rates[0].open);
         if(confirming_candle)
           {
            const double atr = QM_ATR(_Symbol, PERIOD_H1,
                                      strategy_atr_period, 1);
            const double entry = (g_pending_direction > 0)
                                 ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                 : SymbolInfoDouble(_Symbol, SYMBOL_BID);
            if(atr <= 0.0 || entry <= 0.0)
               return false;

            const QM_OrderType side =
               (g_pending_direction > 0) ? QM_BUY : QM_SELL;
            const double raw_sl =
               (g_pending_direction > 0)
               ? (g_pending_swing_price - atr * strategy_atr_swing_buffer)
               : (g_pending_swing_price + atr * strategy_atr_swing_buffer);
            const double sl = QM_StopRulesNormalizePrice(_Symbol, raw_sl);
            const double tp = QM_TakeRR(_Symbol, side, entry, sl,
                                        strategy_reward_risk);

            if(sl <= 0.0 || tp <= 0.0 ||
               (g_pending_direction > 0 && (sl >= entry || tp <= entry)) ||
               (g_pending_direction < 0 && (sl <= entry || tp >= entry)))
              {
               Strategy_ClearPending();
               return false;
              }

            req.type = side;
            req.sl = sl;
            req.tp = tp;
            req.reason = (g_pending_direction > 0)
                         ? "MACD_OBV_DIV_LONG"
                         : "MACD_OBV_DIV_SHORT";
            Strategy_ClearPending();
            return true;
           }
        }
     }

   // An outside bar can technically confirm both a high and a low fractal.
   // Treat that ambiguous case as no setup rather than selecting a direction.
   if(long_divergence != short_divergence)
     {
      g_pending_direction = long_divergence ? 1 : -1;
      g_pending_swing_price = long_divergence ? long_swing : short_swing;
      g_pending_age = 0;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Fixed structural SL and 2R TP; no trailing or partial management.
  }

bool Strategy_ExitSignal()
  {
   if(!g_exit_cached)
      return false;
   if(Strategy_PositionDirection() == 0)
     {
      g_exit_cached = false;
      return false;
     }
   return true;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring - copied unchanged from framework/templates/EA_Skeleton.mq5
// -----------------------------------------------------------------------------

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
   QM_LogEvent(QM_INFO, "DEINIT",
               StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
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

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now,
                                        qm_news_temporal,
                                        qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now,
                                       qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req);
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
