#property strict
#property version   "5.0"
#property description "QM5_12811 XTI Volatility-Contraction Breakout"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12811 - XTI Volatility-Contraction Breakout
// -----------------------------------------------------------------------------
// D1 structural WTI sleeve:
//   - low Bollinger BandWidth rank identifies volatility contraction
//   - close-confirmed Bollinger envelope breakout, symmetric long/short
//   - exits on middle-band failure, SMA failure, or max hold
// Runtime uses MT5 OHLC/broker calendar only; no futures curve/API/CSV/feed.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12811;
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
input int    strategy_bb_period             = 20;
input double strategy_bb_deviation          = 2.00;
input int    strategy_bandwidth_lookback    = 126;
input double strategy_bandwidth_rank_max    = 0.20;
input int    strategy_trend_period          = 80;
input int    strategy_sma_slope_shift       = 10;
input double strategy_close_location_min    = 0.58;
input double strategy_break_buffer_atr      = 0.05;
input int    strategy_atr_period            = 20;
input double strategy_atr_sl_mult           = 2.75;
input double strategy_atr_tp_mult           = 4.50;
input int    strategy_max_hold_days         = 18;
input int    strategy_max_spread_points     = 1000;

int g_last_entry_bar_key = 0;

bool Strategy_IsXtiD1()
  {
   return (_Symbol == "XTIUSD.DWX" && _Period == PERIOD_D1);
  }

int Strategy_DateKey(const datetime t)
  {
   if(t <= 0)
      return 0;
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

bool Strategy_HasOpenPosition()
  {
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
      return true;
     }
   return false;
  }

bool Strategy_BandwidthAtShift(const int shift, double &bandwidth)
  {
   bandwidth = 0.0;
   const double upper = QM_BB_Upper(_Symbol, PERIOD_D1, strategy_bb_period, strategy_bb_deviation, shift, PRICE_CLOSE);
   const double lower = QM_BB_Lower(_Symbol, PERIOD_D1, strategy_bb_period, strategy_bb_deviation, shift, PRICE_CLOSE);
   const double middle = QM_BB_Middle(_Symbol, PERIOD_D1, strategy_bb_period, strategy_bb_deviation, shift, PRICE_CLOSE);
   if(upper <= lower || middle <= 0.0)
      return false;

   bandwidth = (upper - lower) / middle;
   return (bandwidth > 0.0 && MathIsValidNumber(bandwidth));
  }

bool Strategy_BandwidthRank(const double current_bw, double &rank)
  {
   rank = 1.0;
   if(current_bw <= 0.0 || !MathIsValidNumber(current_bw))
      return false;

   int samples = 0;
   int less_or_equal = 0;
   for(int shift = 2; shift <= strategy_bandwidth_lookback + 1; ++shift)
     {
      double prior_bw = 0.0;
      if(!Strategy_BandwidthAtShift(shift, prior_bw))
         continue;
      ++samples;
      if(prior_bw <= current_bw)
         ++less_or_equal;
     }

   if(samples < MathMax(20, strategy_bandwidth_lookback / 2))
      return false;

   rank = (double)less_or_equal / (double)samples;
   return (rank >= 0.0 && rank <= 1.0 && MathIsValidNumber(rank));
  }

bool Strategy_LoadSignalState(double &close_last,
                              double &high_last,
                              double &low_last,
                              double &upper,
                              double &lower,
                              double &middle,
                              double &bandwidth_rank,
                              double &atr_last,
                              double &sma_last,
                              double &sma_prior,
                              double &close_location,
                              datetime &signal_time,
                              int &signal_bar_key)
  {
   close_last = 0.0;
   high_last = 0.0;
   low_last = 0.0;
   upper = 0.0;
   lower = 0.0;
   middle = 0.0;
   bandwidth_rank = 1.0;
   atr_last = 0.0;
   sma_last = 0.0;
   sma_prior = 0.0;
   close_location = 0.0;
   signal_time = 0;
   signal_bar_key = 0;

   signal_time = iTime(_Symbol, PERIOD_D1, 1); // perf-allowed: D1 state is evaluated only after QM_IsNewBar.
   close_last = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: D1 state is evaluated only after QM_IsNewBar.
   high_last = iHigh(_Symbol, PERIOD_D1, 1); // perf-allowed: D1 state is evaluated only after QM_IsNewBar.
   low_last = iLow(_Symbol, PERIOD_D1, 1); // perf-allowed: D1 state is evaluated only after QM_IsNewBar.
   signal_bar_key = Strategy_DateKey(signal_time);
   if(signal_time <= 0 || signal_bar_key <= 0)
      return false;
   if(close_last <= 0.0 || high_last <= low_last)
      return false;

   upper = QM_BB_Upper(_Symbol, PERIOD_D1, strategy_bb_period, strategy_bb_deviation, 1, PRICE_CLOSE);
   lower = QM_BB_Lower(_Symbol, PERIOD_D1, strategy_bb_period, strategy_bb_deviation, 1, PRICE_CLOSE);
   middle = QM_BB_Middle(_Symbol, PERIOD_D1, strategy_bb_period, strategy_bb_deviation, 1, PRICE_CLOSE);
   atr_last = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   sma_last = QM_SMA(_Symbol, PERIOD_D1, strategy_trend_period, 1, PRICE_CLOSE);
   sma_prior = QM_SMA(_Symbol, PERIOD_D1, strategy_trend_period, 1 + strategy_sma_slope_shift, PRICE_CLOSE);
   if(upper <= lower || middle <= 0.0 || atr_last <= 0.0 || sma_last <= 0.0 || sma_prior <= 0.0)
      return false;

   const double signal_range = high_last - low_last;
   if(signal_range <= 0.0)
      return false;
   close_location = (close_last - low_last) / signal_range;
   if(close_location < 0.0 || close_location > 1.0 || !MathIsValidNumber(close_location))
      return false;

   const double current_bw = (upper - lower) / middle;
   if(!Strategy_BandwidthRank(current_bw, bandwidth_rank))
      return false;

   return true;
  }

void Strategy_CloseOpenPositionsIfNeeded()
  {
   double close_last = 0.0;
   double high_last = 0.0;
   double low_last = 0.0;
   double upper = 0.0;
   double lower = 0.0;
   double middle = 0.0;
   double bandwidth_rank = 1.0;
   double atr_last = 0.0;
   double sma_last = 0.0;
   double sma_prior = 0.0;
   double close_location = 0.0;
   datetime signal_time = 0;
   int signal_bar_key = 0;
   const bool have_state = Strategy_LoadSignalState(close_last,
                                                    high_last,
                                                    low_last,
                                                    upper,
                                                    lower,
                                                    middle,
                                                    bandwidth_rank,
                                                    atr_last,
                                                    sma_last,
                                                    sma_prior,
                                                    close_location,
                                                    signal_time,
                                                    signal_bar_key);

   const int magic = QM_FrameworkMagic();
   const datetime now = TimeCurrent();
   const int hold_seconds = MathMax(1, strategy_max_hold_days) * 86400;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      bool should_close = false;

      if(opened > 0 && now - opened >= hold_seconds)
         should_close = true;

      if(have_state && pos_type == POSITION_TYPE_BUY)
        {
         if(close_last < middle || close_last < sma_last)
            should_close = true;
        }
      else if(have_state && pos_type == POSITION_TYPE_SELL)
        {
         if(close_last > middle || close_last > sma_last)
            should_close = true;
        }

      if(should_close)
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsXtiD1())
      return true;
   if(qm_magic_slot_offset != 0)
      return true;
   if(strategy_bb_period < 10 || strategy_bb_period > 80)
      return true;
   if(strategy_bb_deviation <= 0.0 || strategy_bb_deviation > 5.0)
      return true;
   if(strategy_bandwidth_lookback < MathMax(40, strategy_bb_period + 10) || strategy_bandwidth_lookback > 300)
      return true;
   if(strategy_bandwidth_rank_max <= 0.0 || strategy_bandwidth_rank_max >= 0.60)
      return true;
   if(strategy_trend_period <= strategy_bb_period || strategy_trend_period > 260)
      return true;
   if(strategy_sma_slope_shift <= 0 || strategy_sma_slope_shift > 60)
      return true;
   if(strategy_close_location_min <= 0.5 || strategy_close_location_min > 1.0)
      return true;
   if(strategy_break_buffer_atr < 0.0 || strategy_break_buffer_atr > 1.0)
      return true;
   if(strategy_atr_period <= 0 || strategy_atr_period > 80)
      return true;
   if(strategy_atr_sl_mult <= 0.0 || strategy_atr_tp_mult <= 0.0)
      return true;
   if(strategy_max_hold_days <= 0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_12811_XTI_VCB";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   Strategy_CloseOpenPositionsIfNeeded();

   if(Strategy_HasOpenPosition())
      return false;

   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return false;
     }

   double close_last = 0.0;
   double high_last = 0.0;
   double low_last = 0.0;
   double upper = 0.0;
   double lower = 0.0;
   double middle = 0.0;
   double bandwidth_rank = 1.0;
   double atr_last = 0.0;
   double sma_last = 0.0;
   double sma_prior = 0.0;
   double close_location = 0.0;
   datetime signal_time = 0;
   int signal_bar_key = 0;
   if(!Strategy_LoadSignalState(close_last,
                                high_last,
                                low_last,
                                upper,
                                lower,
                                middle,
                                bandwidth_rank,
                                atr_last,
                                sma_last,
                                sma_prior,
                                close_location,
                                signal_time,
                                signal_bar_key))
      return false;

   if(signal_bar_key <= 0 || signal_bar_key == g_last_entry_bar_key)
      return false;
   if(bandwidth_rank > strategy_bandwidth_rank_max)
      return false;

   const double buffer = strategy_break_buffer_atr * atr_last;
   int direction = 0;
   if(close_last > upper + buffer &&
      close_last > sma_last &&
      sma_last > sma_prior &&
      close_location >= strategy_close_location_min)
      direction = 1;
   else if(close_last < lower - buffer &&
           close_last < sma_last &&
           sma_last < sma_prior &&
           close_location <= (1.0 - strategy_close_location_min))
      direction = -1;
   else
      return false;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0)
      return false;

   req.sl = QM_StopATRFromValue(_Symbol, req.type, entry_price, atr_last, strategy_atr_sl_mult);
   req.tp = QM_TakeATRFromValue(_Symbol, req.type, entry_price, atr_last, strategy_atr_tp_mult);
   if(req.sl <= 0.0 || req.tp <= 0.0)
      return false;

   req.reason = (direction > 0) ? "XTI_BANDWIDTH_BREAKOUT_LONG" : "XTI_BANDWIDTH_BREAKOUT_SHORT";
   g_last_entry_bar_key = signal_bar_key;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   Strategy_CloseOpenPositionsIfNeeded();
  }

bool Strategy_ExitSignal()
  {
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12811\",\"ea\":\"xti-vcb\"}");
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

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();
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
