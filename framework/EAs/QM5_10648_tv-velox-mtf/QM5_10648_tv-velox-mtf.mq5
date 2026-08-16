#property strict
#property version   "5.0"
#property description "QM5_10648 TradingView Velox MTF Marubozu"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_10648 tv-velox-mtf
// Source: TradingView "Velox MTF - Visual Enhanced + Marubozu Filter"
// (rakshithradhakrishna) — trend-following, EMA(6/21) cross + steep 3-bar
// slope + Marubozu body filter + confirmed pivot-structure confluence + ADX.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10648;
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
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_ema_fast              = 6;
input int    strategy_ema_slow              = 21;
input int    strategy_atr_period             = 14;
input int    strategy_slope_lookback_bars    = 3;     // 3-bar EMA slope window
input double strategy_angle_deg_threshold    = 80.0;  // card: "at least 80 degrees"
// Normalization constant for the dimensionless slope->angle proxy: the card
// specifies an angle threshold but no chart-scale reference, so the slope is
// expressed in ATR units before atan() (portable across XAUUSD/GDAXI/NDX/
// GBPJPY without symbol-specific magic numbers). Documented design choice,
// not a hard-bounded card value.
input double strategy_angle_norm_atr_mult    = 0.15;
input double strategy_marubozu_body_ratio    = 0.60;  // card: "at least 60%"
input int    strategy_adx_period             = 14;
input double strategy_adx_threshold          = 20.0;  // card: "ADX(14) > 20"
input int    strategy_pivot_lookback_bars    = 60;    // confirmed-pivot scan window
input double strategy_sl_atr_mult            = 1.5;   // stop beyond signal-candle extreme
input double strategy_sl_atr_cap_mult        = 4.0;   // skip if stop distance exceeds this
input double strategy_tp_r_mult              = 7.0;   // card: "7.0R"
input int    strategy_time_exit_bars         = 48;    // card: "close after 48 bars"

// -----------------------------------------------------------------------------
// Bespoke structural helper — confirmed pivot (fractal) scan.
// No generic multi-pivot helper exists in QM_Indicators.mqh; QM_FractalUpper/
// QM_FractalLower give single-shift reads only. Bounded loop (<=
// strategy_pivot_lookback_bars, default 60), called once per CLOSED bar from
// Strategy_EntrySignal (itself only invoked after QM_IsNewBar()==true by the
// framework OnTick wiring) — never per-tick.
// perf-allowed: bespoke structural logic, no QM_* multi-pivot helper exists.
// -----------------------------------------------------------------------------
bool FindLastTwoFractals(const string sym, const ENUM_TIMEFRAMES tf, const bool upper,
                         const int max_lookback, double &val1, double &val2)
  {
   val1 = 0.0;
   val2 = 0.0;
   int found = 0;
   for(int s = 2; s <= max_lookback; s++)
     {
      const double v = upper ? QM_FractalUpper(sym, tf, s) : QM_FractalLower(sym, tf, s);
      if(v != EMPTY_VALUE && v != 0.0)
        {
         if(found == 0)
           {
            val1 = v;
            found = 1;
           }
         else
           {
            val2 = v;
            return true;
           }
        }
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double ema_fast_now  = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_ema_fast, 1);
   const double ema_slow_now  = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_ema_slow, 1);
   const double atr           = QM_ATR(_Symbol, PERIOD_CURRENT, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const double ema_fast_prev = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_ema_fast, 1 + strategy_slope_lookback_bars);
   const double slope         = ema_fast_now - ema_fast_prev;
   const double angle_deg     = MathArctan(slope / (strategy_angle_norm_atr_mult * atr)) * (180.0 / M_PI);

   const bool trend_up   = (ema_fast_now > ema_slow_now) && (angle_deg >=  strategy_angle_deg_threshold);
   const bool trend_down = (ema_fast_now < ema_slow_now) && (angle_deg <= -strategy_angle_deg_threshold);
   if(!trend_up && !trend_down)
      return false;

   // Marubozu body filter on the signal (just-closed) candle. perf-allowed:
   // bespoke structural logic, no QM_* OHLC reader exists (single closed-bar
   // shift, not a loop; called once per closed bar via Strategy_EntrySignal).
   const double o1 = iOpen(_Symbol, PERIOD_CURRENT, 1); // perf-allowed
   const double c1 = iClose(_Symbol, PERIOD_CURRENT, 1); // perf-allowed
   const double h1 = iHigh(_Symbol, PERIOD_CURRENT, 1); // perf-allowed
   const double l1 = iLow(_Symbol, PERIOD_CURRENT, 1); // perf-allowed
   const double range = h1 - l1;
   if(range <= 0.0)
      return false;
   const double body_ratio = MathAbs(c1 - o1) / range;
   if(body_ratio < strategy_marubozu_body_ratio)
      return false;

   // ADX choppiness guard.
   if(QM_ADX(_Symbol, PERIOD_CURRENT, strategy_adx_period, 1) <= strategy_adx_threshold)
      return false;

   // Confirmed pivot-structure confluence.
   double fh1, fh2, fl1, fl2;
   const bool have_highs = FindLastTwoFractals(_Symbol, PERIOD_CURRENT, true,  strategy_pivot_lookback_bars, fh1, fh2);
   const bool have_lows  = FindLastTwoFractals(_Symbol, PERIOD_CURRENT, false, strategy_pivot_lookback_bars, fl1, fl2);
   if(!have_highs || !have_lows)
      return false;

   const bool structure_up   = (fh1 > fh2) && (fl1 > fl2);
   const bool structure_down = (fh1 < fh2) && (fl1 < fl2);

   const bool long_setup  = trend_up   && structure_up;
   const bool short_setup = trend_down && structure_down;
   if(!long_setup && !short_setup)
      return false;

   const double entry_price = long_setup ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                          : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry_price <= 0.0)
      return false;

   double sl_price;
   if(long_setup)
      sl_price = l1 - strategy_sl_atr_mult * atr;
   else
      sl_price = h1 + strategy_sl_atr_mult * atr;

   const double stop_distance = MathAbs(entry_price - sl_price);
   if(stop_distance <= 0.0 || stop_distance > strategy_sl_atr_cap_mult * atr)
      return false; // card: "Skip entries where stop distance exceeds 4.0 ATR(14)"

   const double tp_price = long_setup ? entry_price + strategy_tp_r_mult * stop_distance
                                       : entry_price - strategy_tp_r_mult * stop_distance;

   req.type               = long_setup ? QM_BUY : QM_SELL;
   req.price               = 0.0;
   req.sl                  = QM_StopRulesNormalizePrice(_Symbol, sl_price);
   req.tp                  = QM_StopRulesNormalizePrice(_Symbol, tp_price);
   req.reason               = long_setup ? "velox_mtf_marubozu_long" : "velox_mtf_marubozu_short";
   req.symbol_slot          = qm_magic_slot_offset;
   req.expiration_seconds   = 0;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   const double ema_fast_now = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_ema_fast, 1);
   const double ema_slow_now = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_ema_slow, 1);
   const int period_sec = PeriodSeconds(PERIOD_CURRENT);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const long pos_type = PositionGetInteger(POSITION_TYPE);
      bool cross_exit = false;
      if(pos_type == POSITION_TYPE_BUY && ema_fast_now <= ema_slow_now)
         cross_exit = true;
      else if(pos_type == POSITION_TYPE_SELL && ema_fast_now >= ema_slow_now)
         cross_exit = true;

      bool time_exit = false;
      if(period_sec > 0)
        {
         const datetime open_time    = (datetime)PositionGetInteger(POSITION_TIME);
         const int      bars_elapsed = (int)((TimeCurrent() - open_time) / period_sec);
         if(bars_elapsed >= strategy_time_exit_bars)
            time_exit = true;
        }

      if(cross_exit)
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
      else if(time_exit)
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
     }
  }

bool Strategy_ExitSignal()
  {
   return false; // handled per-ticket in Strategy_ManageOpenPosition
  }

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
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
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
