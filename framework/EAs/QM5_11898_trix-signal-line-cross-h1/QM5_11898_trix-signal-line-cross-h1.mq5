#property strict
#property version   "5.0"
#property description "QM5_11898 TRIX Signal-Line Cross with Zero-Line Trend Filter H1"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_11898
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11898;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.5;
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
input string strategy_timeframe = "H1";
input int    strategy_trix_ema_period = 14;
input int    strategy_trix_signal_period = 9;
input bool   strategy_zero_line_filter = true;
input int    strategy_atr_period_for_stop = 14;
input double strategy_atr_stop_mult = 2.0;
input double strategy_target_rr = 2.0;

// -----------------------------------------------------------------------------
// Helper Functions
// -----------------------------------------------------------------------------

bool Strategy_SelectOurPosition(ulong &ticket,
                                ENUM_POSITION_TYPE &position_type,
                                double &open_price,
                                double &sl,
                                double &tp,
                                datetime &open_time)
{
   ticket = 0;
   position_type = POSITION_TYPE_BUY;
   open_price = 0.0;
   sl = 0.0;
   tp = 0.0;
   open_time = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong candidate = PositionGetTicket(i);
      if(candidate == 0 || !PositionSelectByTicket(candidate))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = candidate;
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      sl = PositionGetDouble(POSITION_SL);
      tp = PositionGetDouble(POSITION_TP);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
   }

   return false;
}

bool CalculateTrixAndSignal(double &trix1, double &sig1, double &trix2, double &sig2)
{
   trix1 = 0.0; sig1 = 0.0;
   trix2 = 0.0; sig2 = 0.0;
   
   if(strategy_trix_ema_period <= 1 || strategy_trix_signal_period <= 1)
      return false;

   const int count_needed = strategy_trix_signal_period + 3;
   const int warmup = strategy_trix_ema_period * 10;
   const int total_bars = warmup + count_needed;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, _Period, 1, total_bars, rates); // perf-allowed: exact TRIX triple-EMA close window
   if(copied < total_bars)
      return false;

   double close[];
   ArrayResize(close, copied);
   for(int i = 0; i < copied; i++)
   {
      close[i] = rates[copied - 1 - i].close;
   }

   double ema1[], ema2[], ema3[], trix[];
   ArrayResize(ema1, copied);
   ArrayResize(ema2, copied);
   ArrayResize(ema3, copied);
   ArrayResize(trix, copied);

   const double alpha = 2.0 / ((double)strategy_trix_ema_period + 1.0);
   const double one_minus_alpha = 1.0 - alpha;

   ema1[0] = close[0];
   ema2[0] = close[0];
   ema3[0] = close[0];
   trix[0] = 0.0;

   for(int i = 1; i < copied; i++)
   {
      ema1[i] = alpha * close[i] + one_minus_alpha * ema1[i-1];
      ema2[i] = alpha * ema1[i] + one_minus_alpha * ema2[i-1];
      ema3[i] = alpha * ema2[i] + one_minus_alpha * ema3[i-1];

      if(ema3[i-1] != 0.0)
         trix[i] = (ema3[i] - ema3[i-1]) / ema3[i-1];
      else
         trix[i] = 0.0;
   }

   double TRIX_vals[];
   ArrayResize(TRIX_vals, count_needed + 1);
   for(int k = 1; k <= count_needed; k++)
   {
      TRIX_vals[k] = trix[copied - k];
   }

   trix1 = TRIX_vals[1];
   trix2 = TRIX_vals[2];

   double sum1 = 0.0;
   for(int j = 1; j <= strategy_trix_signal_period; j++)
   {
      sum1 += TRIX_vals[j];
   }
   sig1 = sum1 / strategy_trix_signal_period;

   double sum2 = 0.0;
   for(int j = 2; j <= strategy_trix_signal_period + 1; j++)
   {
      sum2 += TRIX_vals[j];
   }
   sig2 = sum2 / strategy_trix_signal_period;

   return true;
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter() { return false; }

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   ENUM_TIMEFRAMES tf = PERIOD_H1;
   if(strategy_timeframe == "H1") tf = PERIOD_H1;
   else if(strategy_timeframe == "H4") tf = PERIOD_H4;
   else if(strategy_timeframe == "D1") tf = PERIOD_D1;
   else if(strategy_timeframe == "M15") tf = PERIOD_M15;
   else if(strategy_timeframe == "M30") tf = PERIOD_M30;
   else if(strategy_timeframe == "M5") tf = PERIOD_M5;
   else if(strategy_timeframe == "M1") tf = PERIOD_M1;

   if(_Period != tf)
      return false;

   // Check if we already have a position
   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   double open_price, sl, tp;
   datetime open_time;
   if(Strategy_SelectOurPosition(ticket, position_type, open_price, sl, tp, open_time))
      return false;

   double trix1, sig1, trix2, sig2;
   if(!CalculateTrixAndSignal(trix1, sig1, trix2, sig2))
      return false;

   const bool bullish_cross = (trix1 > sig1 && trix2 <= sig2);
   const bool bearish_cross = (trix1 < sig1 && trix2 >= sig2);

   if(!bullish_cross && !bearish_cross)
      return false;

   // Zero line filter check
   if(strategy_zero_line_filter)
   {
      if(bullish_cross && trix1 <= 0.0)
         return false;
      if(bearish_cross && trix1 >= 0.0)
         return false;
   }

   const double entry = bullish_cross ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                      : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   if(bullish_cross)
   {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = QM_StopATR(_Symbol, QM_BUY, entry, strategy_atr_period_for_stop, strategy_atr_stop_mult);
      req.tp = QM_TakeRR(_Symbol, QM_BUY, entry, req.sl, strategy_target_rr);
      req.reason = "QM5_11898_LONG";
      return true;
   }
   else if(bearish_cross)
   {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = QM_StopATR(_Symbol, QM_SELL, entry, strategy_atr_period_for_stop, strategy_atr_stop_mult);
      req.tp = QM_TakeRR(_Symbol, QM_SELL, entry, req.sl, strategy_target_rr);
      req.reason = "QM5_11898_SHORT";
      return true;
   }

   return false;
}

void Strategy_ManageOpenPosition() {}

bool Strategy_ExitSignal(const bool is_new_bar)
{
   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   double open_price;
   double sl;
   double tp;
   datetime open_time;
   if(!Strategy_SelectOurPosition(ticket, position_type, open_price, sl, tp, open_time))
      return false;

   // Check hard timeout: 96 H1 bars (4 days) = 96 * 3600 seconds
   if(open_time > 0 && (TimeCurrent() - open_time) >= 96 * 3600)
      return true;

   // We only check opposite cross on a new closed bar
   if(!is_new_bar)
      return false;

   double trix1, sig1, trix2, sig2;
   if(!CalculateTrixAndSignal(trix1, sig1, trix2, sig2))
      return false;

   const bool bullish_cross = (trix1 > sig1 && trix2 <= sig2);
   const bool bearish_cross = (trix1 < sig1 && trix2 >= sig2);

   if(position_type == POSITION_TYPE_BUY && bearish_cross)
      return true;
   if(position_type == POSITION_TYPE_SELL && bullish_cross)
      return true;

   return false;
}

bool Strategy_NewsFilterHook(const datetime broker_time) { return false; }

// -----------------------------------------------------------------------------
// Framework wiring
// -----------------------------------------------------------------------------

int OnInit()
{
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy, qm_friday_close_enabled, qm_friday_close_hour_broker,
                        30, 30, qm_news_stale_max_hours, qm_news_min_impact, qm_rng_seed,
                        qm_stress_reject_probability, qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { QM_FrameworkShutdown(); }

void OnTick()
{
   QM_FrameworkTrackOpenPositionMae(); // first: no guard may skip Q08 evidence
   if(!QM_KillSwitchCheck()) return;
   if(QM_FrameworkHandleFridayClose()) return;
   if(Strategy_NoTradeFilter()) return;

   Strategy_ManageOpenPosition();

   const bool is_new_bar = QM_IsNewBar();

   if(Strategy_ExitSignal(is_new_bar))
   {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
      {
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
      }
   }

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now)) return;
   
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows) return;

   if(!is_new_bar) return;
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
   {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
   }
}

void OnTimer() { QM_FrameworkOnTimer(); }
void OnTradeTransaction(const MqlTradeTransaction &t, const MqlTradeRequest &r, const MqlTradeResult &res)
{
   QM_FrameworkOnTradeTransaction(t, r, res);
}

double OnTester()
{
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
}
