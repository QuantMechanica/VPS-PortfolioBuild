#property strict
#property version   "5.0"
#property description "QM5_1128 Daniel-Moskowitz momentum crash volatility scaling"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1128;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal        = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance      = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours     = 336;
input string qm_news_min_impact          = "high";
input QM_NewsMode qm_news_mode_legacy    = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_momentum_12m_bars      = 252;
input int    strategy_vol_window_d1_bars     = 63;
input double strategy_target_vol_annual      = 0.15;
input double strategy_min_abs_return         = 0.005;
input int    strategy_atr_period_d1          = 14;
input double strategy_atr_sl_mult            = 3.0;
input int    strategy_min_history_d1_bars    = 270;
input bool   strategy_intramonth_vol_exit    = false;
input double strategy_vol_shock_mult         = 2.0;
input int    strategy_max_spread_points      = 0;

#define QM5_1128_SYMBOL_COUNT 6

string g_symbols[QM5_1128_SYMBOL_COUNT] = {
   "NDX.DWX",
   "GDAXI.DWX",
   "WS30.DWX",
   "UK100.DWX",
   "EURUSD.DWX",
   "XAUUSD.DWX"
};

int g_slots[QM5_1128_SYMBOL_COUNT] = {0, 1, 2, 3, 4, 5};

datetime g_last_entry_rebalance_day = 0;
datetime g_last_exit_rebalance_day = 0;
double   g_entry_sigma_annual = 0.0;

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < QM5_1128_SYMBOL_COUNT; ++i)
      if(g_symbols[i] == _Symbol)
         return i;
   return -1;
  }

int Strategy_SlotForCurrentSymbol()
  {
   const int index = Strategy_CurrentSymbolIndex();
   if(index < 0)
      return qm_magic_slot_offset;
   return g_slots[index];
  }

datetime Strategy_LastClosedD1Time()
  {
   return iTime(_Symbol, PERIOD_D1, 1);
  }

bool Strategy_IsFirstTradingDayRebalance(const datetime closed_day)
  {
   if(closed_day <= 0)
      return false;

   const datetime current_day = iTime(_Symbol, PERIOD_D1, 0);
   if(current_day <= 0)
      return false;

   MqlDateTime closed_dt;
   MqlDateTime current_dt;
   TimeToStruct(closed_day, closed_dt);
   TimeToStruct(current_day, current_dt);
   return (closed_dt.year != current_dt.year || closed_dt.mon != current_dt.mon);
  }

bool Strategy_TradingStatusValid(const string symbol)
  {
   if(!SymbolSelect(symbol, true))
      return false;
   return (SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE) != SYMBOL_TRADE_MODE_DISABLED);
  }

bool Strategy_ReturnOverBars(const string symbol, const int lookback_bars, double &out_return)
  {
   out_return = 0.0;
   if(lookback_bars <= 0)
      return false;
   if(Bars(symbol, PERIOD_D1) < MathMax(strategy_min_history_d1_bars, lookback_bars + 5))
      return false;

   const double recent_close = iClose(symbol, PERIOD_D1, 1);
   const double past_close = iClose(symbol, PERIOD_D1, 1 + lookback_bars);
   if(recent_close <= 0.0 || past_close <= 0.0)
      return false;

   out_return = (recent_close / past_close) - 1.0;
   return true;
  }

bool Strategy_RealizedVolAnnual(const string symbol, const int window_bars, double &out_sigma)
  {
   out_sigma = 0.0;
   if(window_bars <= 1 || Bars(symbol, PERIOD_D1) < window_bars + 5)
      return false;

   double values[256];
   if(window_bars > 256)
      return false;

   int count = 0;
   double sum = 0.0;
   for(int shift = 1; shift <= window_bars; ++shift)
     {
      const double c0 = iClose(symbol, PERIOD_D1, shift);
      const double c1 = iClose(symbol, PERIOD_D1, shift + 1);
      if(c0 <= 0.0 || c1 <= 0.0)
         return false;

      const double r = MathLog(c0 / c1);
      values[count] = r;
      sum += r;
      ++count;
     }

   if(count < 2)
      return false;

   const double mean = sum / (double)count;
   double ss = 0.0;
   for(int i = 0; i < count; ++i)
     {
      const double d = values[i] - mean;
      ss += d * d;
     }

   const double variance = ss / (double)(count - 1);
   if(variance <= 0.0)
      return false;

   out_sigma = MathSqrt(variance) * MathSqrt(252.0);
   return (out_sigma > 0.0);
  }

double Strategy_VolScaleK(const double sigma_annual)
  {
   if(sigma_annual <= 0.0 || strategy_target_vol_annual <= 0.0)
      return 0.0;

   const double k = strategy_target_vol_annual / sigma_annual;
   return MathMax(0.0, MathMin(1.0, k));
  }

int Strategy_Direction(double &out_return, double &out_sigma, double &out_k)
  {
   out_return = 0.0;
   out_sigma = 0.0;
   out_k = 0.0;

   if(!Strategy_ReturnOverBars(_Symbol, strategy_momentum_12m_bars, out_return))
      return 0;
   if(MathAbs(out_return) < strategy_min_abs_return)
      return 0;
   if(!Strategy_RealizedVolAnnual(_Symbol, strategy_vol_window_d1_bars, out_sigma))
      return 0;

   out_k = Strategy_VolScaleK(out_sigma);
   if(out_k <= 0.0)
      return 0;

   return (out_return > 0.0) ? 1 : -1;
  }

bool Strategy_HasOpenPosition(ulong &ticket, datetime &opened_at, QM_OrderType &side)
  {
   ticket = 0;
   opened_at = 0;
   side = QM_BUY;

   const int magic = QM_Magic(qm_ea_id, Strategy_SlotForCurrentSymbol());
   if(magic <= 0)
      return false;

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
      opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      side = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) ? QM_SELL : QM_BUY;
      return true;
     }

   return false;
  }

bool Strategy_ConfigureScaledRisk(const double k)
  {
   if(k <= 0.0 || k > 1.0)
      return false;

   if(RISK_PERCENT > 0.0)
      return QM_RiskSizerConfigure(QM_RISK_MODE_PERCENT, RISK_PERCENT * k, 0.0, PORTFOLIO_WEIGHT);

   if(RISK_FIXED > 0.0)
      return QM_RiskSizerConfigure(QM_RISK_MODE_FIXED, 0.0, RISK_FIXED * k, PORTFOLIO_WEIGHT);

   return false;
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_D1)
      return true;
   if(Strategy_CurrentSymbolIndex() < 0)
      return true;
   if(!Strategy_TradingStatusValid(_Symbol))
      return true;
   if(strategy_max_spread_points > 0 && SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > strategy_max_spread_points)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const datetime rebalance_day = Strategy_LastClosedD1Time();
   if(!Strategy_IsFirstTradingDayRebalance(rebalance_day) || g_last_entry_rebalance_day == rebalance_day)
      return false;

   ulong ticket = 0;
   datetime opened_at = 0;
   QM_OrderType open_side = QM_BUY;
   if(Strategy_HasOpenPosition(ticket, opened_at, open_side))
      return false;

   double momentum_return = 0.0;
   double sigma_annual = 0.0;
   double k = 0.0;
   const int direction = Strategy_Direction(momentum_return, sigma_annual, k);
   if(direction == 0)
      return false;

   const QM_OrderType selected_side = (direction > 0) ? QM_BUY : QM_SELL;
   const double entry = QM_OrderTypeIsBuy(selected_side) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   const double sl = QM_StopATRFromValue(_Symbol, selected_side, entry, atr, strategy_atr_sl_mult);
   if(sl <= 0.0)
      return false;
   if(QM_OrderTypeIsBuy(selected_side) && sl >= entry)
      return false;
   if(!QM_OrderTypeIsBuy(selected_side) && sl <= entry)
      return false;

   if(!Strategy_ConfigureScaledRisk(k))
      return false;

   req.type = selected_side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = QM_OrderTypeIsBuy(selected_side) ? "QM5_1128_DM_TSMOM_VOL_LONG"
                                                 : "QM5_1128_DM_TSMOM_VOL_SHORT";
   req.symbol_slot = Strategy_SlotForCurrentSymbol();
   req.expiration_seconds = 0;

   g_entry_sigma_annual = sigma_annual;
   g_last_entry_rebalance_day = rebalance_day;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card baseline uses the hard ATR stop; monthly-only rebalancing handles exits.
  }

bool Strategy_ExitSignal()
  {
   ulong ticket = 0;
   datetime opened_at = 0;
   QM_OrderType open_side = QM_BUY;
   if(!Strategy_HasOpenPosition(ticket, opened_at, open_side))
      return false;
   if(!Strategy_TradingStatusValid(_Symbol))
      return true;

   double current_sigma = 0.0;
   if(strategy_intramonth_vol_exit &&
      g_entry_sigma_annual > 0.0 &&
      strategy_vol_shock_mult > 0.0 &&
      Strategy_RealizedVolAnnual(_Symbol, strategy_vol_window_d1_bars, current_sigma) &&
      current_sigma >= g_entry_sigma_annual * strategy_vol_shock_mult)
      return true;

   const datetime rebalance_day = Strategy_LastClosedD1Time();
   if(!Strategy_IsFirstTradingDayRebalance(rebalance_day) || g_last_exit_rebalance_day == rebalance_day)
      return false;
   if(opened_at >= rebalance_day)
      return false;

   double momentum_return = 0.0;
   double sigma_annual = 0.0;
   double k = 0.0;
   const int direction = Strategy_Direction(momentum_return, sigma_annual, k);
   if(direction == 0)
     {
      g_last_exit_rebalance_day = rebalance_day;
      return true;
     }

   const QM_OrderType selected_side = (direction > 0) ? QM_BUY : QM_SELL;
   if(selected_side != open_side)
     {
      g_last_exit_rebalance_day = rebalance_day;
      return true;
     }

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

   QM_SymbolGuardInit(g_symbols);
   QM_BasketWarmupHistory(g_symbols, PERIOD_D1, MathMax(strategy_min_history_d1_bars, strategy_momentum_12m_bars + 5));

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1128_daniel-momentum-crash-vol-scale\"}");
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
      const int magic = QM_Magic(qm_ea_id, Strategy_SlotForCurrentSymbol());
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
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

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
