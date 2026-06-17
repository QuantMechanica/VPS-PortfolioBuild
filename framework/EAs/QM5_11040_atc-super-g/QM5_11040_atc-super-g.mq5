#property strict
#property version   "5.0"
#property description "QM5_11040 atc-super-g — Super G four-indicator confirmation (MACD/Stoch/SAR/Momentum), M15"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11040 atc-super-g
// -----------------------------------------------------------------------------
// Source: Achmad Hidayat, Interview (ATC 2012), MQL5 Articles 560, 2012-10-03.
// Card: artifacts/cards_approved/QM5_11040_atc-super-g.md (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1; all four indicators must AGREE):
//   Long  STATE: MACD main > MACD signal
//              AND Stoch %K > %D  AND  %K < stoch_upper_guard
//              AND Close[1] > SAR[1]
//              AND Momentum[1] > 100 + momentum_buffer
//   Short STATE: mirror image, with %K > stoch_lower_guard and
//              Momentum[1] < 100 - momentum_buffer.
//   Stop       : entry -/+ sl_atr_mult * ATR(atr_period).
//   Take profit: entry +/- tp_atr_mult * ATR (same ATR value as the stop).
//   Exit       : fixed SL/TP, opposite four-indicator signal, OR ATR trail once
//                profit exceeds trail_start_atr * ATR.
//   Filters    : (a) spread cap vs stop distance (fail-open on .DWX zero spread),
//                (b) ATR within rolling 20th-90th percentile band,
//                (c) optional H1 EMA(200) bias gate.
//   One open position per symbol/magic.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11040;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
// --- MACD ---
input int    strategy_macd_fast         = 12;     // MACD fast EMA period
input int    strategy_macd_slow         = 26;     // MACD slow EMA period
input int    strategy_macd_signal       = 9;      // MACD signal period
// --- Stochastic ---
input int    strategy_stoch_k           = 5;      // Stochastic %K period
input int    strategy_stoch_d           = 3;      // Stochastic %D period
input int    strategy_stoch_slowing     = 3;      // Stochastic slowing
input double strategy_stoch_upper_guard = 80.0;   // long blocked if %K above this (overbought)
input double strategy_stoch_lower_guard = 20.0;   // short blocked if %K below this (oversold)
// --- Parabolic SAR ---
input double strategy_sar_step          = 0.02;   // SAR acceleration step
input double strategy_sar_max           = 0.20;   // SAR acceleration maximum
// --- Momentum ---
input int    strategy_momentum_period   = 14;     // Momentum period
input double strategy_momentum_buffer   = 0.1;    // band around 100 (long >100+buf, short <100-buf)
// --- ATR / stops ---
input int    strategy_atr_period        = 14;     // ATR period (filter / stop / target / trail)
input double strategy_sl_atr_mult       = 2.0;    // stop distance = mult * ATR
input double strategy_tp_atr_mult       = 2.5;    // target distance = mult * ATR
// --- Volatility-percentile filter ---
input int    strategy_atr_pct_lookback  = 100;    // bars to build the ATR percentile distribution
input double strategy_atr_pct_lo        = 20.0;   // skip if ATR below this percentile
input double strategy_atr_pct_hi        = 90.0;   // skip if ATR above this percentile
// --- Trailing stop ---
input double strategy_trail_start_atr   = 1.0;    // start ATR-trailing once profit > this * ATR
input double strategy_trail_atr_mult    = 2.0;    // ATR trail distance multiplier
// --- Optional H1 EMA(200) bias ---
input bool   strategy_use_htf_ema       = false;  // only longs above / shorts below H1 EMA(200)
input int    strategy_htf_ema_period    = 200;    // H1 EMA period
// --- Spread guard ---
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

// Rolling ATR percentile gate. Returns TRUE when ATR(1) sits inside the
// [lo, hi] percentile of the trailing distribution (i.e. the bar is tradeable).
// Closed-bar reads only; the lookback is bounded so it is smoke-safe.
bool ATRInPercentileBand(const double atr_now)
  {
   if(atr_now <= 0.0)
      return false;
   const int n = strategy_atr_pct_lookback;
   if(n <= 1)
      return true; // filter disabled

   int below = 0;
   int counted = 0;
   for(int s = 1; s <= n; ++s)
     {
      const double a = QM_ATR(_Symbol, _Period, strategy_atr_period, s);
      if(a <= 0.0)
         continue;
      counted++;
      if(a < atr_now)
         below++;
     }
   if(counted <= 1)
      return true; // not enough history yet — do not block

   const double pct = (100.0 * (double)below) / (double)counted;
   return (pct >= strategy_atr_pct_lo && pct <= strategy_atr_pct_hi);
  }

// Four-indicator agreement. dir = +1 long, -1 short, 0 no agreement.
int FourIndicatorDirection()
  {
   const double macd_main = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);
   const double macd_sig  = QM_MACD_Signal(_Symbol, _Period, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);

   const double stoch_k   = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 1);
   const double stoch_d   = QM_Stoch_D(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 1);

   const double sar1      = QM_SAR(_Symbol, _Period, strategy_sar_step, strategy_sar_max, 1);
   const double close1    = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read

   const double mom1      = QM_Momentum(_Symbol, _Period, strategy_momentum_period, 1);

   if(close1 <= 0.0 || sar1 <= 0.0 || mom1 <= 0.0)
      return 0;

   const bool long_macd  = (macd_main > macd_sig);
   const bool long_stoch = (stoch_k > stoch_d && stoch_k < strategy_stoch_upper_guard);
   const bool long_sar   = (close1 > sar1);
   const bool long_mom   = (mom1 > 100.0 + strategy_momentum_buffer);
   if(long_macd && long_stoch && long_sar && long_mom)
      return +1;

   const bool short_macd  = (macd_main < macd_sig);
   const bool short_stoch = (stoch_k < stoch_d && stoch_k > strategy_stoch_lower_guard);
   const bool short_sar   = (close1 < sar1);
   const bool short_mom   = (mom1 < 100.0 - strategy_momentum_buffer);
   if(short_macd && short_stoch && short_sar && short_mom)
      return -1;

   return 0;
  }

// Optional higher-timeframe EMA(200) bias. dir = +1 above / -1 below / 0 unknown.
int HTFBias()
  {
   if(!strategy_use_htf_ema)
      return 0; // filter off
   const double ema = QM_EMA(_Symbol, PERIOD_H1, strategy_htf_ema_period, 1);
   const double c1  = iClose(_Symbol, PERIOD_H1, 1); // perf-allowed: single closed-bar read
   if(ema <= 0.0 || c1 <= 0.0)
      return 0;
   return (c1 > ema) ? +1 : -1;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate: spread guard only. Fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to entry gate

   const double stop_distance = strategy_sl_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Entry: four-indicator agreement + volatility band + optional HTF bias.
// Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   // Volatility-percentile band filter.
   if(!ATRInPercentileBand(atr_value))
      return false;

   const int dir = FourIndicatorDirection();
   if(dir == 0)
      return false;

   // Optional higher-timeframe EMA(200) bias gate.
   const int bias = HTFBias();
   if(bias != 0 && bias != dir)
      return false;

   const QM_OrderType side = (dir > 0) ? QM_BUY : QM_SELL;

   const double entry = (dir > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                   : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, side, entry, atr_value, strategy_sl_atr_mult);
   const double tp = QM_TakeATRFromValue(_Symbol, side, entry, atr_value, strategy_tp_atr_mult);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = (dir > 0) ? "super_g_long" : "super_g_short";
   return true;
  }

// Trailing stop once open profit exceeds trail_start_atr * ATR.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return;
   const double trail_trigger = strategy_trail_start_atr * atr_value;
   if(trail_trigger <= 0.0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const long   ptype      = PositionGetInteger(POSITION_TYPE);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      double profit_dist = 0.0;
      if(ptype == POSITION_TYPE_BUY)
         profit_dist = bid - open_price;
      else
         profit_dist = open_price - ask;

      if(profit_dist >= trail_trigger)
         QM_TM_TrailATR(ticket, strategy_atr_period, strategy_trail_atr_mult);
     }
  }

// Opposite four-indicator signal exit.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const int dir = FourIndicatorDirection();
   if(dir == 0)
      return false;

   // Close if the current open position is opposite to the fresh signal.
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && dir < 0)
         return true;
      if(ptype == POSITION_TYPE_SELL && dir > 0)
         return true;
     }
   return false;
  }

// Defer to the central news filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
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
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
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
