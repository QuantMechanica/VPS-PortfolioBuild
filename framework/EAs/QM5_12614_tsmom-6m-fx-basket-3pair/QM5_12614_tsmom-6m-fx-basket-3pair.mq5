#property strict
#property version   "5.0"
#property description "QM5_12614 TSMOM 6M FX Basket"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 12614;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours     = 336;
input string qm_news_min_impact          = "high";
input QM_NewsMode qm_news_mode_legacy    = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = false;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_lookback_d1_bars   = 126;
input int    strategy_vol_window_d1      = 20;
input double strategy_target_pair_vol    = 0.033333;
input double strategy_max_vol_scale      = 2.0;
input int    strategy_min_d1_bars        = 155;
input int    strategy_atr_period         = 14;
input double strategy_atr_sl_mult        = 3.0;
input int    strategy_spread_days        = 20;
input double strategy_spread_mult        = 3.0;

#define QM5_12614_SYMBOL_COUNT 3

string g_symbols[QM5_12614_SYMBOL_COUNT] =
  {
   "EURUSD.DWX", "GBPUSD.DWX", "USDJPY.DWX"
  };

int g_slots[QM5_12614_SYMBOL_COUNT] = {0, 1, 2};

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < QM5_12614_SYMBOL_COUNT; ++i)
      if(g_symbols[i] == _Symbol)
         return i;
   return -1;
  }

int Strategy_CurrentSymbolSlot()
  {
   const int index = Strategy_CurrentSymbolIndex();
   if(index < 0)
      return qm_magic_slot_offset;
   return g_slots[index];
  }

bool Strategy_CurrentSymbolAndSlotAllowed()
  {
   const int index = Strategy_CurrentSymbolIndex();
   if(index < 0)
      return false;
   return (g_slots[index] == qm_magic_slot_offset);
  }

bool Strategy_IsMonthRebalanceBar()
  {
   if(_Period != PERIOD_D1)
      return false;

   const datetime broker_now = TimeCurrent();
   if(broker_now <= 0)
      return false;

   MqlDateTime now_dt;
   TimeToStruct(broker_now, now_dt);

   if(now_dt.day == 1)
      return true;

   return (now_dt.day_of_week == 1 && now_dt.day <= 3);
  }

bool Strategy_CurrentPosition(ulong &ticket, int &direction)
  {
   ticket = 0;
   direction = 0;
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
      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      direction = (pos_type == POSITION_TYPE_BUY) ? 1 : -1;
      return true;
     }
   return false;
  }

double Strategy_MedianDailySpreadPoints()
  {
   const int n = strategy_spread_days;
   if(n <= 0 || n > 64)
      return 0.0;

   double values[64];
   int count = 0;
   for(int shift = 1; shift <= n; ++shift)
     {
      const long spread = iSpread(_Symbol, PERIOD_D1, shift); // perf-allowed: card spread filter on D1 history
      if(spread > 0)
        {
         values[count] = (double)spread;
         ++count;
        }
     }

   if(count <= 0)
      return 0.0;

   for(int i = 0; i < count - 1; ++i)
      for(int j = i + 1; j < count; ++j)
         if(values[j] < values[i])
           {
            const double tmp = values[i];
            values[i] = values[j];
            values[j] = tmp;
           }

   if((count % 2) == 1)
      return values[count / 2];
   return 0.5 * (values[(count / 2) - 1] + values[count / 2]);
  }

bool Strategy_SpreadAllowsEntry()
  {
   const double median_spread = Strategy_MedianDailySpreadPoints();
   if(median_spread <= 0.0 || strategy_spread_mult <= 0.0)
      return true;

   const long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(current_spread > 0 && (double)current_spread > median_spread * strategy_spread_mult)
      return false;
   return true;
  }

double Strategy_RealizedVolAnnual()
  {
   const int n = strategy_vol_window_d1;
   if(n < 2 || n > 63)
      return 0.0;
   if(Bars(_Symbol, PERIOD_D1) < n + 2) // perf-allowed: monthly D1 volatility availability guard
      return 0.0;

   double closes[64];
   const int copied = CopyClose(_Symbol, PERIOD_D1, 1, n + 1, closes); // perf-allowed: monthly 20-day realized volatility
   if(copied != n + 1)
      return 0.0;

   double mean = 0.0;
   double returns[63];
   for(int i = 0; i < n; ++i)
     {
      if(closes[i] <= 0.0 || closes[i + 1] <= 0.0)
         return 0.0;
      returns[i] = MathLog(closes[i] / closes[i + 1]);
      mean += returns[i];
     }
   mean /= (double)n;

   double variance = 0.0;
   for(int i = 0; i < n; ++i)
     {
      const double diff = returns[i] - mean;
      variance += diff * diff;
     }
   variance /= (double)MathMax(1, n - 1);
   if(variance <= 0.0)
      return 0.0;
   return MathSqrt(variance) * MathSqrt(252.0);
  }

double Strategy_VolScale()
  {
   const double realized_vol = Strategy_RealizedVolAnnual();
   if(realized_vol <= 0.0 || strategy_target_pair_vol <= 0.0)
      return 0.0;

   double scale = strategy_target_pair_vol / realized_vol;
   if(strategy_max_vol_scale > 0.0 && scale > strategy_max_vol_scale)
      scale = strategy_max_vol_scale;
   if(scale <= 0.0)
      return 0.0;
   return scale;
  }

int Strategy_TsmomDirection()
  {
   if(strategy_lookback_d1_bars <= 0)
      return 0;

   const int min_bars = MathMax(strategy_min_d1_bars,
                                strategy_lookback_d1_bars + strategy_vol_window_d1 + 5);
   if(Bars(_Symbol, PERIOD_D1) < min_bars) // perf-allowed: card requires fixed D1 history window
      return 0;

   const double recent_close = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: card requires D1 close-return sign
   const double lookback_close = iClose(_Symbol, PERIOD_D1, 1 + strategy_lookback_d1_bars); // perf-allowed: card requires D1 close-return sign
   if(recent_close <= 0.0 || lookback_close <= 0.0)
      return 0;

   if(recent_close > lookback_close)
      return 1;
   if(recent_close < lookback_close)
      return -1;
   return 0;
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_D1)
      return true;
   if(!Strategy_CurrentSymbolAndSlotAllowed())
      return true;
   if(strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   if(strategy_lookback_d1_bars <= 0 || strategy_vol_window_d1 < 2)
      return true;
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
   req.symbol_slot = Strategy_CurrentSymbolSlot();
   req.expiration_seconds = 0;

   if(!Strategy_IsMonthRebalanceBar())
      return false;
   if(!Strategy_SpreadAllowsEntry())
      return false;

   const int direction = Strategy_TsmomDirection();
   if(direction == 0)
      return false;

   const double vol_scale = Strategy_VolScale();
   if(vol_scale <= 0.0)
      return false;

   ulong existing_ticket = 0;
   int existing_direction = 0;
   if(Strategy_CurrentPosition(existing_ticket, existing_direction))
     {
      if(existing_direction == direction)
         return false;
      if(!QM_TM_ClosePosition(existing_ticket, QM_EXIT_STRATEGY))
         return false;
     }

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   req.price = (direction > 0) ? ask : bid;
   req.sl = QM_StopATR(_Symbol, req.type, req.price, strategy_atr_period, strategy_atr_sl_mult);
   req.tp = 0.0;
   req.symbol_slot = Strategy_CurrentSymbolSlot();
   req.reason = (direction > 0) ? "QM5_12614_TSMOM_6M_FX_LONG" : "QM5_12614_TSMOM_6M_FX_SHORT";

   if(req.sl <= 0.0)
      return false;
   if(req.type == QM_BUY && req.sl >= req.price)
      return false;
   if(req.type == QM_SELL && req.sl <= req.price)
      return false;

   return true;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, pyramiding, or partial close.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   // Monthly reversal exits are handled inside Strategy_EntrySignal so the
   // framework consumes QM_IsNewBar() only once per D1 bar.
   return false;
  }

// News Filter Hook (callable for P8 News Impact phase)
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring - do NOT edit below this line unless you know why.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12614\",\"ea\":\"tsmom-6m-fx-basket-3pair\"}");
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
