#property strict
#property version   "5.0"
#property description "QM5_1328 Brooks 3-Bar Reversal H4"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1328;
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
input ENUM_TIMEFRAMES strategy_tf        = PERIOD_H4;
input int    strategy_atr_period         = 14;
input int    strategy_sma_period         = 50;
input int    strategy_swing_lookback     = 10;
input double strategy_trend_body_min     = 0.50;
input double strategy_stall_body_max     = 0.40;
input double strategy_stall_atr_poke     = 0.25;
input double strategy_sma_atr_buffer     = 0.50;
input double strategy_tp1_rr             = 2.0;
input double strategy_tp2_rr             = 3.5;
input double strategy_tp1_close_fraction = 0.50;
input int    strategy_time_stop_bars     = 12;
input int    strategy_rearm_bars         = 3;
input double strategy_spread_mult        = 2.0;
input int    strategy_spread_lookback    = 20;

ulong    g_qm1328_active_ticket      = 0;
int      g_qm1328_active_direction   = 0;
double   g_qm1328_initial_risk_price = 0.0;
bool     g_qm1328_tp1_done           = false;
bool     g_qm1328_had_position       = false;
int      g_qm1328_rearm_direction    = 0;
int      g_qm1328_rearm_remaining    = 0;

double QM1328_PipDistance()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return 0.0;
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const int pip_factor = (digits == 3 || digits == 5) ? 10 : 1;
   return point * pip_factor;
  }

double QM1328_Body(const MqlRates &bar)
  {
   return MathAbs(bar.close - bar.open);
  }

double QM1328_Range(const MqlRates &bar)
  {
   return bar.high - bar.low;
  }

double QM1328_LowestLow(const MqlRates &rates[], const int count)
  {
   double low = DBL_MAX;
   for(int i = 0; i < count; ++i)
      low = MathMin(low, rates[i].low);
   return low;
  }

double QM1328_HighestHigh(const MqlRates &rates[], const int count)
  {
   double high = -DBL_MAX;
   for(int i = 0; i < count; ++i)
      high = MathMax(high, rates[i].high);
   return high;
  }

bool QM1328_ReadClosedBars(MqlRates &rates[])
  {
   const int need = MathMax(strategy_swing_lookback, 3);
   ArrayResize(rates, need);
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, strategy_tf, 1, need, rates); // perf-allowed: bounded structural OHLC read, EntrySignal is called only after the framework new-bar gate
   return (copied == need);
  }

bool QM1328_SelectPosition(ulong &ticket,
                           int &direction,
                           double &open_price,
                           double &sl,
                           double &volume,
                           datetime &open_time)
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong pos_ticket = PositionGetTicket(i);
      if(pos_ticket == 0 || !PositionSelectByTicket(pos_ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = pos_ticket;
      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      direction = (ptype == POSITION_TYPE_BUY) ? 1 : -1;
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      sl = PositionGetDouble(POSITION_SL);
      volume = PositionGetDouble(POSITION_VOLUME);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }
   return false;
  }

void QM1328_RefreshPositionState()
  {
   ulong ticket = 0;
   int direction = 0;
   double open_price = 0.0;
   double sl = 0.0;
   double volume = 0.0;
   datetime open_time = 0;

   if(QM1328_SelectPosition(ticket, direction, open_price, sl, volume, open_time))
     {
      if(ticket != g_qm1328_active_ticket)
        {
         g_qm1328_active_ticket = ticket;
         g_qm1328_active_direction = direction;
         g_qm1328_initial_risk_price = MathAbs(open_price - sl);
         g_qm1328_tp1_done = false;
        }
      g_qm1328_had_position = true;
      return;
     }

   if(g_qm1328_had_position)
     {
      g_qm1328_rearm_direction = g_qm1328_active_direction;
      g_qm1328_rearm_remaining = MathMax(strategy_rearm_bars, 0);
     }

   g_qm1328_active_ticket = 0;
   g_qm1328_active_direction = 0;
   g_qm1328_initial_risk_price = 0.0;
   g_qm1328_tp1_done = false;
   g_qm1328_had_position = false;
  }

bool QM1328_RearmBlocks(const int direction)
  {
   return (g_qm1328_rearm_remaining > 0 && g_qm1328_rearm_direction == direction);
  }

void QM1328_AdvanceRearm()
  {
   if(g_qm1328_rearm_remaining > 0)
      g_qm1328_rearm_remaining--;
   if(g_qm1328_rearm_remaining <= 0)
     {
      g_qm1328_rearm_remaining = 0;
      g_qm1328_rearm_direction = 0;
     }
  }

bool QM1328_SpreadTooWide()
  {
   if(strategy_spread_mult <= 0.0 || strategy_spread_lookback <= 0)
      return false;

   const long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(current_spread <= 0)
      return false;

   MqlRates rates[];
   const int need = strategy_spread_lookback;
   ArrayResize(rates, need);
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, strategy_tf, 1, need, rates); // perf-allowed: bounded spread median read for declared card filter
   if(copied <= 0)
      return false;

   double spreads[];
   ArrayResize(spreads, copied);
   int n = 0;
   for(int i = 0; i < copied; ++i)
     {
      if(rates[i].spread > 0)
        {
         spreads[n] = (double)rates[i].spread;
         n++;
        }
     }
   if(n <= 0)
      return false;

   ArrayResize(spreads, n);
   ArraySort(spreads);
   double median = spreads[n / 2];
   if((n % 2) == 0)
      median = 0.5 * (spreads[n / 2 - 1] + spreads[n / 2]);

   return ((double)current_spread > strategy_spread_mult * median);
  }

bool QM1328_BuyPattern(const MqlRates &rates[], double &sl, double &tp)
  {
   const double atr = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
   const double sma = QM_SMA(_Symbol, strategy_tf, strategy_sma_period, 1);
   const double pip = QM1328_PipDistance();
   if(atr <= 0.0 || sma <= 0.0 || pip <= 0.0)
      return false;

   const MqlRates rev = rates[0];
   const MqlRates stall = rates[1];
   const MqlRates trend = rates[2];
   const double trend_range = QM1328_Range(trend);
   const double stall_range = QM1328_Range(stall);
   if(trend_range <= 0.0 || stall_range <= 0.0)
      return false;

   if(!(trend.close < trend.open && QM1328_Body(trend) >= strategy_trend_body_min * trend_range))
      return false;
   if(!(QM1328_Body(stall) <= strategy_stall_body_max * stall_range &&
        stall.high <= trend.high &&
        stall.low >= trend.low - strategy_stall_atr_poke * atr))
      return false;
   if(!(rev.close > trend.close && rev.close > rev.open))
      return false;

   const double cluster_low = MathMin(MathMin(trend.low, stall.low), rev.low);
   if(cluster_low > QM1328_LowestLow(rates, strategy_swing_lookback) + _Point * 0.5)
      return false;
   if(rev.close <= sma - strategy_sma_atr_buffer * atr)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   sl = QM_StopRulesNormalizePrice(_Symbol, cluster_low - pip);
   if(ask <= 0.0 || sl <= 0.0 || ask <= sl)
      return false;
   tp = QM_TakeRR(_Symbol, QM_BUY, ask, sl, strategy_tp2_rr);
   return (tp > 0.0);
  }

bool QM1328_SellPattern(const MqlRates &rates[], double &sl, double &tp)
  {
   const double atr = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
   const double sma = QM_SMA(_Symbol, strategy_tf, strategy_sma_period, 1);
   const double pip = QM1328_PipDistance();
   if(atr <= 0.0 || sma <= 0.0 || pip <= 0.0)
      return false;

   const MqlRates rev = rates[0];
   const MqlRates stall = rates[1];
   const MqlRates trend = rates[2];
   const double trend_range = QM1328_Range(trend);
   const double stall_range = QM1328_Range(stall);
   if(trend_range <= 0.0 || stall_range <= 0.0)
      return false;

   if(!(trend.close > trend.open && QM1328_Body(trend) >= strategy_trend_body_min * trend_range))
      return false;
   if(!(QM1328_Body(stall) <= strategy_stall_body_max * stall_range &&
        stall.low >= trend.low &&
        stall.high <= trend.high + strategy_stall_atr_poke * atr))
      return false;
   if(!(rev.close < trend.close && rev.close < rev.open))
      return false;

   const double cluster_high = MathMax(MathMax(trend.high, stall.high), rev.high);
   if(cluster_high < QM1328_HighestHigh(rates, strategy_swing_lookback) - _Point * 0.5)
      return false;
   if(rev.close >= sma + strategy_sma_atr_buffer * atr)
      return false;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   sl = QM_StopRulesNormalizePrice(_Symbol, cluster_high + pip);
   if(bid <= 0.0 || sl <= 0.0 || bid >= sl)
      return false;
   tp = QM_TakeRR(_Symbol, QM_SELL, bid, sl, strategy_tp2_rr);
   return (tp > 0.0);
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   QM1328_RefreshPositionState();
   return false;
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   QM1328_RefreshPositionState();
   QM1328_AdvanceRearm();
   if(g_qm1328_active_ticket != 0)
      return false;
   if(QM1328_SpreadTooWide())
      return false;

   MqlRates rates[];
   if(!QM1328_ReadClosedBars(rates))
      return false;

   double sl = 0.0;
   double tp = 0.0;
   if(!QM1328_RearmBlocks(1) && QM1328_BuyPattern(rates, sl, tp))
     {
      req.type = QM_BUY;
      req.sl = sl;
      req.tp = tp;
      req.reason = "BROOKS_3BAR_REVERSAL_BUY_H4";
      g_qm1328_initial_risk_price = MathAbs(SymbolInfoDouble(_Symbol, SYMBOL_ASK) - sl);
      g_qm1328_tp1_done = false;
      return true;
     }

   if(!QM1328_RearmBlocks(-1) && QM1328_SellPattern(rates, sl, tp))
     {
      req.type = QM_SELL;
      req.sl = sl;
      req.tp = tp;
      req.reason = "BROOKS_3BAR_REVERSAL_SELL_H4";
      g_qm1328_initial_risk_price = MathAbs(sl - SymbolInfoDouble(_Symbol, SYMBOL_BID));
      g_qm1328_tp1_done = false;
      return true;
     }

   return false;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   QM1328_RefreshPositionState();
   if(g_qm1328_active_ticket == 0 || g_qm1328_tp1_done || g_qm1328_initial_risk_price <= 0.0)
      return;
   if(!PositionSelectByTicket(g_qm1328_active_ticket))
      return;

   const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   const bool is_buy = (ptype == POSITION_TYPE_BUY);
   const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   const double volume = PositionGetDouble(POSITION_VOLUME);
   const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(open_price <= 0.0 || market <= 0.0 || volume <= 0.0)
      return;

   const double moved = is_buy ? (market - open_price) : (open_price - market);
   if(moved < strategy_tp1_rr * g_qm1328_initial_risk_price)
      return;

   if(QM_TM_PartialClose(g_qm1328_active_ticket, volume * strategy_tp1_close_fraction, QM_EXIT_PARTIAL))
     {
      QM_TM_MoveSL(g_qm1328_active_ticket, QM_StopRulesNormalizePrice(_Symbol, open_price), "brooks_tp1_move_sl_to_be");
      g_qm1328_tp1_done = true;
     }
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   QM1328_RefreshPositionState();
   if(g_qm1328_active_ticket == 0 || g_qm1328_tp1_done || strategy_time_stop_bars <= 0)
      return false;
   if(!PositionSelectByTicket(g_qm1328_active_ticket))
      return false;

   const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
   const int seconds = PeriodSeconds(strategy_tf);
   if(open_time <= 0 || seconds <= 0)
      return false;
   return (TimeCurrent() >= open_time + (strategy_time_stop_bars * seconds));
  }

// News Filter Hook (callable for P8 News Impact phase)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1328\",\"ea\":\"brooks-3bar-reversal-h4\"}");
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
