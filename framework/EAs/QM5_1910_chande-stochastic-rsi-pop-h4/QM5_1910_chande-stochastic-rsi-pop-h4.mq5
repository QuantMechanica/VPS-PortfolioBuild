#property strict
#property version   "5.0"
#property description "QM5_1910 Chande Stochastic-RSI Pop H4"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_1910 chande-stochastic-rsi-pop-h4
// -----------------------------------------------------------------------------
// Card: D:\QM\strategy_farm\artifacts\cards_approved\
//       QM5_1910_chande-stochastic-rsi-pop-h4.md (g0_status APPROVED).
//
// Mechanics (H4, closed-bar signals):
//   RSI(14) is normalized into StochRSI over the latest 14 RSI values, with a
//   3-bar SMA signal line. Long entries fire when StochRSI has spent two closed
//   bars below 20, then exits above 20 and above its signal while the H4 close
//   is above the D1 EMA(50). Shorts mirror the rule from above 80. Exits are
//   StochRSI midline/opposite-zone exits, ATR trailing after a 1.5 ATR favorable
//   move, initial 2.5 ATR stop, or a 24-H4-bar time stop.
//
// Framework helpers are used for RSI, EMA, ATR, stop construction, order
// open/close, risk sizing, magic resolution, Friday close and news gating. The
// only custom math is bounded StochRSI arithmetic over pooled QM_RSI values.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1910;
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
input int    strategy_rsi_period              = 14;
input int    strategy_stoch_rsi_period        = 14;
input int    strategy_signal_period           = 3;
input double strategy_oversold_level          = 20.0;
input double strategy_overbought_level        = 80.0;
input double strategy_midline_level           = 50.0;
input int    strategy_d1_ema_period           = 50;
input int    strategy_atr_period              = 20;
input double strategy_initial_sl_atr_mult     = 2.5;
input double strategy_trail_atr_mult          = 2.0;
input double strategy_trail_start_atr_mult    = 1.5;
input double strategy_spread_atr_mult         = 0.35;
input int    strategy_time_stop_h4_bars       = 24;
input int    strategy_ema_slope_lookback_d1   = 5;
input double strategy_ema_slope_atr_mult      = 0.5;

bool g_long_rearmed = true;
bool g_short_rearmed = true;

double StrategyClose(const ENUM_TIMEFRAMES tf, const int shift)
  {
   MqlRates rates[1];
   if(CopyRates(_Symbol, tf, shift, 1, rates) != 1) // perf-allowed: one closed-bar close read; Strategy_EntrySignal is reached only after QM_IsNewBar().
      return 0.0;
   return rates[0].close;
  }

bool StrategyStochRSI(const int shift, double &out_value)
  {
   out_value = 50.0;
   if(strategy_rsi_period <= 1 || strategy_stoch_rsi_period <= 1 || shift < 1)
      return false;

   double min_rsi = DBL_MAX;
   double max_rsi = -DBL_MAX;
   const double rsi_now = QM_RSI(_Symbol, PERIOD_H4, strategy_rsi_period, shift, PRICE_CLOSE);
   if(rsi_now <= 0.0)
      return false;

   for(int i = 0; i < strategy_stoch_rsi_period; ++i)
     {
      const double rsi = QM_RSI(_Symbol, PERIOD_H4, strategy_rsi_period, shift + i, PRICE_CLOSE);
      if(rsi <= 0.0)
         return false;
      if(rsi < min_rsi)
         min_rsi = rsi;
      if(rsi > max_rsi)
         max_rsi = rsi;
     }

   const double range = max_rsi - min_rsi;
   if(range <= 0.0)
     {
      out_value = 50.0;
      return true;
     }

   out_value = 100.0 * (rsi_now - min_rsi) / range;
   if(out_value < 0.0)
      out_value = 0.0;
   if(out_value > 100.0)
      out_value = 100.0;
   return true;
  }

bool StrategyStochRSISignal(const int shift, double &out_signal)
  {
   out_signal = 50.0;
   if(strategy_signal_period <= 0)
      return false;

   double sum = 0.0;
   for(int i = 0; i < strategy_signal_period; ++i)
     {
      double value = 0.0;
      if(!StrategyStochRSI(shift + i, value))
         return false;
      sum += value;
     }

   out_signal = sum / strategy_signal_period;
   return true;
  }

void StrategyUpdateRearm(const double stoch_latest)
  {
   if(stoch_latest >= strategy_overbought_level)
      g_long_rearmed = true;
   if(stoch_latest <= strategy_oversold_level)
      g_short_rearmed = true;
  }

bool StrategyFindPosition(ulong &ticket,
                          ENUM_POSITION_TYPE &position_type,
                          double &open_price,
                          datetime &open_time)
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
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = t;
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

bool StrategySpreadAllowsEntry()
  {
   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(atr <= 0.0 || strategy_spread_atr_mult <= 0.0)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double spread = ask - bid;
   if(spread > 0.0 && spread > strategy_spread_atr_mult * atr)
      return false;

   return true;
  }

// Return TRUE to BLOCK all strategy work this tick. Entry-only gates such as
// spread live in Strategy_EntrySignal so management and exits keep running.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Caller guarantees QM_IsNewBar() == true. The card's StochRSI[0] maps to
// shift 1 (latest closed H4 bar) because orders are sent at the next H4 open.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!StrategySpreadAllowsEntry())
      return false;

   double stoch_0 = 0.0;
   double stoch_1 = 0.0;
   double stoch_2 = 0.0;
   double signal_0 = 0.0;
   if(!StrategyStochRSI(1, stoch_0) ||
      !StrategyStochRSI(2, stoch_1) ||
      !StrategyStochRSI(3, stoch_2) ||
      !StrategyStochRSISignal(1, signal_0))
      return false;

   StrategyUpdateRearm(stoch_0);

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double close_0 = StrategyClose(PERIOD_H4, 1);
   const double d1_ema = QM_EMA(_Symbol, PERIOD_D1, strategy_d1_ema_period, 1, PRICE_CLOSE);
   const double d1_ema_past = QM_EMA(_Symbol, PERIOD_D1, strategy_d1_ema_period,
                                     1 + strategy_ema_slope_lookback_d1, PRICE_CLOSE);
   const double d1_atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   const double h4_atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(close_0 <= 0.0 || d1_ema <= 0.0 || d1_ema_past <= 0.0 || d1_atr <= 0.0 || h4_atr <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double ema_slope = d1_ema - d1_ema_past;
   const double strong_slope = strategy_ema_slope_atr_mult * d1_atr;

   const bool long_signal =
      (g_long_rearmed &&
       stoch_2 < strategy_oversold_level &&
       stoch_1 < strategy_oversold_level &&
       stoch_0 > strategy_oversold_level &&
       stoch_0 > signal_0 &&
       close_0 > d1_ema &&
       ema_slope >= -strong_slope);

   if(long_signal)
     {
      const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, ask, h4_atr, strategy_initial_sl_atr_mult);
      if(sl <= 0.0 || sl >= ask)
         return false;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = sl;
      req.tp = 0.0;
      req.reason = "stoch_rsi_oversold_pop_long";
      g_long_rearmed = false;
      return true;
     }

   const bool short_signal =
      (g_short_rearmed &&
       stoch_2 >= strategy_overbought_level &&
       stoch_1 >= strategy_overbought_level &&
       stoch_0 < strategy_overbought_level &&
       stoch_0 < signal_0 &&
       close_0 < d1_ema &&
       ema_slope <= strong_slope);

   if(short_signal)
     {
      const double sl = QM_StopATRFromValue(_Symbol, QM_SELL, bid, h4_atr, strategy_initial_sl_atr_mult);
      if(sl <= bid)
         return false;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = sl;
      req.tp = 0.0;
      req.reason = "stoch_rsi_overbought_pop_short";
      g_short_rearmed = false;
      return true;
     }

   return false;
  }

// Card: start trailing only after a 1.5 ATR favorable move, then trail by
// 2.0 ATR through the framework helper.
void Strategy_ManageOpenPosition()
  {
   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   double open_price;
   datetime open_time;
   if(!StrategyFindPosition(ticket, position_type, open_price, open_time))
      return;

   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(atr <= 0.0 || strategy_trail_start_atr_mult <= 0.0)
      return;

   const bool is_buy = (position_type == POSITION_TYPE_BUY);
   const double market_price = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                      : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(market_price <= 0.0 || open_price <= 0.0)
      return;

   const double favorable_move = is_buy ? (market_price - open_price) : (open_price - market_price);
   if(favorable_move < strategy_trail_start_atr_mult * atr)
      return;

   QM_TM_TrailATR(ticket, strategy_atr_period, strategy_trail_atr_mult);
  }

// Signal exits are checked only while this EA has an open position. Indicator
// work is bounded to the StochRSI window and uses pooled QM_RSI reads.
bool Strategy_ExitSignal()
  {
   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   double open_price;
   datetime open_time;
   if(!StrategyFindPosition(ticket, position_type, open_price, open_time))
      return false;

   const int h4_seconds = PeriodSeconds(PERIOD_H4);
   if(h4_seconds > 0 && open_time > 0 &&
      TimeCurrent() - open_time >= strategy_time_stop_h4_bars * h4_seconds)
      return true;

   double stoch_0 = 0.0;
   double stoch_1 = 0.0;
   if(!StrategyStochRSI(1, stoch_0) || !StrategyStochRSI(2, stoch_1))
      return false;

   StrategyUpdateRearm(stoch_0);

   if(position_type == POSITION_TYPE_BUY)
     {
      if(stoch_1 >= strategy_midline_level && stoch_0 < strategy_midline_level)
         return true;
      if(stoch_0 >= strategy_overbought_level)
         return true;
     }

   if(position_type == POSITION_TYPE_SELL)
     {
      if(stoch_1 <= strategy_midline_level && stoch_0 > strategy_midline_level)
         return true;
      if(stoch_0 <= strategy_oversold_level)
         return true;
     }

   return false;
  }

// Defer to the central two-axis news filter.
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
