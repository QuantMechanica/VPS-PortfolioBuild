#property strict
#property version   "5.0"
#property description "QM5_39005 forexfactory-genesis-matrix-scalper - Genesis Matrix Scalper (M5)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_39005 forexfactory-genesis-matrix-scalper
// -----------------------------------------------------------------------------
// Source: Realtrader (2012-2024). Genesis Matrix Trading System. Forex Factory.
// Card: artifacts/cards_approved/QM5_39005_forexfactory-genesis-matrix-scalper.md (g0_status APPROVED).
//
// Mechanics (closed-bar, M5):
//   - 4-Indicator Confluence Matrix:
//       1. TVI (Tick Volume Indicator, Blau directional volume EMA 12)
//       2. CCI (20)
//       3. T3-filtered CCI (T3 smoothing period 5, b=0.618)
//       4. Gann High-Low Activator (GHL period 10)
//   - Matrix Score: Sum of bullish states (0 to 4).
//   - Long Entry: Matrix_Score[1] == 4 AND Matrix_Score[2] < 4 AND Close[1] > EMA(5)[1].
//   - Short Entry: Matrix_Score[1] == 0 AND Matrix_Score[2] > 0 AND Close[1] < EMA(5)[1].
//   - SL: Beyond recent M5 swing low/high +/- 2.0 pips buffer.
//   - TP: 1:2.0 R:R target.
//   - Exit: Matrix color flip (Long closes when Matrix < 4; Short closes when Matrix > 0).
//   - Management: Move to Break-Even at 15 pips to Entry + 1 pip.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 39005;
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
input int    InpCCIPeriod                  = 20;     // Matrix CCI lookback
input int    InpT3Period                   = 5;      // T3 smoothing factor
input double InpT3Hot                      = 0.618;  // T3 volume hot factor (b)
input int    InpGHLPeriod                  = 10;     // Gann High-Low activator period
input int    InpTVIPeriod                  = 12;     // TVI EMA lookback
input int    strategy_atr_period           = 14;     // ATR period (M5)
input double strategy_sl_buffer_pips       = 2.0;    // SL buffer beyond swing structure in pips
input double strategy_tp_rr                = 2.0;    // Take profit R:R multiple
input int    strategy_swing_lookback       = 10;     // Swing structure lookback bars
input double strategy_be_trigger_pips      = 15.0;   // Break-even trigger distance in pips
input double strategy_daily_loss_halt_pct  = 2.0;    // Daily realized loss entry halt percent
input double strategy_daily_hard_stop_pct  = 2.5;    // Daily hard stop percent
input double strategy_total_dd_halt_pct    = 5.0;    // Total drawdown halt percent
input double strategy_per_trade_risk_cap_pct = 1.0; // Per-trade risk cap percent

// -----------------------------------------------------------------------------
// File-scope cached state (updated once per new closed bar)
// -----------------------------------------------------------------------------
bool   g_state_valid           = false;
int    g_cached_matrix_score_1 = -1;
int    g_cached_matrix_score_2 = -1;
double g_cached_ema5_1         = 0.0;
double g_cached_close_1        = 0.0;
double g_cached_atr_1          = 0.0;

// -----------------------------------------------------------------------------
// Matrix Indicator Helpers
// -----------------------------------------------------------------------------

bool CalculateTVI(const int shift, const int period, double &tvi_val)
{
   tvi_val = 0.0;
   if(period <= 0 || shift < 0) return false;
   const int warmup = period * 4 + 10;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_M5, shift, warmup, rates); // perf-allowed: TVI directional volume window
   const int rates_size = ArraySize(rates);
   if(copied < period + 2 || rates_size != copied) return false;

   const double alpha = 2.0 / ((double)period + 1.0);
   const double one_minus_alpha = 1.0 - alpha;

   double ema = 0.0;
   const int oldest = rates_size;
   for(int s = oldest - 1; s >= 0; --s)
   {
      const double diff = rates[s].close - rates[s].open;
      double dir_vol = 0.0;
      if(diff > 0.0) dir_vol = (double)rates[s].tick_volume;
      else if(diff < 0.0) dir_vol = -(double)rates[s].tick_volume;

      if(s == oldest - 1)
         ema = dir_vol;
      else
         ema = alpha * dir_vol + one_minus_alpha * ema;
   }
   tvi_val = ema;
   return true;
}

bool CalculateT3CCI(const int shift, const int cci_period, const int t3_period, const double b, double &t3_val)
{
   t3_val = 0.0;
   if(t3_period <= 0 || cci_period <= 0 || shift < 0) return false;
   const int warmup = t3_period * 6 + 15;

   double cci_buf[];
   const int resized = ArrayResize(cci_buf, warmup);
   if(resized != warmup || ArraySize(cci_buf) != warmup)
      return false;
   for(int i = 0; i < ArraySize(cci_buf); ++i)
   {
      const double c = QM_CCI(_Symbol, PERIOD_M5, cci_period, shift + (warmup - 1 - i));
      cci_buf[i] = c;
   }

   const double alpha = 2.0 / ((double)t3_period + 1.0);
   const double one_minus_alpha = 1.0 - alpha;

   double e1 = cci_buf[0];
   double e2 = e1, e3 = e1, e4 = e1, e5 = e1, e6 = e1;

   const double b2 = b * b;
   const double b3 = b2 * b;
   const double c1 = -b3;
   const double c2 = 3.0 * (b2 + b3);
   const double c3 = -6.0 * b2 - 3.0 * b - 3.0 * b3;
   const double c4 = 1.0 + 3.0 * b + b3 + 3.0 * b2;

   for(int i = 0; i < ArraySize(cci_buf); ++i)
   {
      const double v = cci_buf[i];
      e1 = alpha * v + one_minus_alpha * e1;
      e2 = alpha * e1 + one_minus_alpha * e2;
      e3 = alpha * e2 + one_minus_alpha * e3;
      e4 = alpha * e3 + one_minus_alpha * e4;
      e5 = alpha * e4 + one_minus_alpha * e5;
      e6 = alpha * e5 + one_minus_alpha * e6;
   }

   t3_val = c1 * e6 + c2 * e5 + c3 * e4 + c4 * e3;
   return true;
}

bool CalculateGHL(const int shift, const int period, bool &ghl_up)
{
   ghl_up = false;
   if(period <= 0 || shift < 0) return false;
   const int warmup = period * 4 + shift + 10;
   int trend = 0;
   for(int s = warmup; s >= shift; --s)
   {
      const double high_sma  = QM_SMA(_Symbol, PERIOD_M5, period, s, PRICE_HIGH);
      const double low_sma   = QM_SMA(_Symbol, PERIOD_M5, period, s, PRICE_LOW);
      const double close_val = QM_SMA(_Symbol, PERIOD_M5, 1, s, PRICE_CLOSE);
      if(close_val <= 0.0 || high_sma <= 0.0 || low_sma <= 0.0)
         return false;

      if(close_val > high_sma)
         trend = 1;
      else if(close_val < low_sma)
         trend = -1;
   }
   if(trend == 0)
      return false;
   ghl_up = (trend == 1);
   return true;
}

void AdvanceState_OnNewBar()
{
   g_state_valid = false;

   double tvi_1 = 0.0, tvi_2 = 0.0;
   if(!CalculateTVI(1, InpTVIPeriod, tvi_1) || !CalculateTVI(2, InpTVIPeriod, tvi_2))
      return;

   const double cci_1 = QM_CCI(_Symbol, PERIOD_M5, InpCCIPeriod, 1);
   const double cci_2 = QM_CCI(_Symbol, PERIOD_M5, InpCCIPeriod, 2);

   double t3_1 = 0.0, t3_2 = 0.0;
   if(!CalculateT3CCI(1, InpCCIPeriod, InpT3Period, InpT3Hot, t3_1) ||
      !CalculateT3CCI(2, InpCCIPeriod, InpT3Period, InpT3Hot, t3_2))
      return;

   bool ghl_1 = false, ghl_2 = false;
   if(!CalculateGHL(1, InpGHLPeriod, ghl_1) || !CalculateGHL(2, InpGHLPeriod, ghl_2))
      return;

   const double ema5_1  = QM_EMA(_Symbol, PERIOD_M5, 5, 1);
   const double close_1 = QM_SMA(_Symbol, PERIOD_M5, 1, 1, PRICE_CLOSE);
   const double atr_1   = QM_ATR(_Symbol, PERIOD_M5, strategy_atr_period, 1);

   if(ema5_1 <= 0.0 || close_1 <= 0.0 || atr_1 <= 0.0)
      return;

   g_cached_matrix_score_1 = (tvi_1 > 0.0 ? 1 : 0) + (cci_1 > 0.0 ? 1 : 0) + (t3_1 > 0.0 ? 1 : 0) + (ghl_1 ? 1 : 0);
   g_cached_matrix_score_2 = (tvi_2 > 0.0 ? 1 : 0) + (cci_2 > 0.0 ? 1 : 0) + (t3_2 > 0.0 ? 1 : 0) + (ghl_2 ? 1 : 0);

   g_cached_ema5_1  = ema5_1;
   g_cached_close_1 = close_1;
   g_cached_atr_1   = atr_1;
   g_state_valid    = true;
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_DailyRealizedLossHalt()
{
   int closed_trades = 0;
   const double realized_pnl = QM_ChartUITodayPnL(0, closed_trades);
   const double balance_now = AccountInfoDouble(ACCOUNT_BALANCE);
   const double day_start_balance = balance_now - realized_pnl;
   if(balance_now <= 0.0 || day_start_balance <= 0.0)
      return true;
   return (realized_pnl <= -(day_start_balance * strategy_daily_loss_halt_pct / 100.0));
}

bool Strategy_NoTradeFilter()
{
   if(Strategy_DailyRealizedLossHalt())
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask > 0.0 && bid > 0.0 && ask > bid && g_cached_atr_1 > 0.0)
   {
      if((ask - bid) > 1.8 * g_cached_atr_1)
         return true;
   }

   const datetime utc_now = QM_BrokerToUTC(TimeCurrent());
   MqlDateTime dt;
   TimeToStruct(utc_now, dt);
   const int minute_of_day = dt.hour * 60 + dt.min;
   if(minute_of_day >= 1435 || minute_of_day < 5) // 23:55 - 00:05 blackout
      return true;

   return false;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   if(!g_state_valid)
      return false;

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(g_cached_atr_1 <= 0.0 || g_cached_close_1 <= 0.0)
      return false;

   const double buf = QM_StopRulesPipsToPriceDistance(_Symbol, (int)MathRound(strategy_sl_buffer_pips));

   // Long Condition: Matrix Score rises to 4 from < 4 AND Close[1] > EMA(5)[1]
   if(g_cached_matrix_score_1 == 4 && g_cached_matrix_score_2 < 4 && g_cached_close_1 > g_cached_ema5_1)
   {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(ask <= 0.0) return false;

      const double swing_low = QM_StopStructure(_Symbol, QM_BUY, ask, strategy_swing_lookback);
      if(swing_low <= 0.0) return false;

      const double sl = swing_low - buf;
      if(sl <= 0.0 || sl >= ask) return false;

      const double tp = QM_TakeRR(_Symbol, QM_BUY, ask, sl, strategy_tp_rr);
      if(tp <= 0.0) return false;

      req.type               = QM_BUY;
      req.price              = 0.0;
      req.sl                 = QM_StopRulesNormalizePrice(_Symbol, sl);
      req.tp                 = QM_StopRulesNormalizePrice(_Symbol, tp);
      req.reason             = "GENESIS_MATRIX_BUY";
      req.symbol_slot        = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
   }

   // Short Condition: Matrix Score drops to 0 from > 0 AND Close[1] < EMA(5)[1]
   if(g_cached_matrix_score_1 == 0 && g_cached_matrix_score_2 > 0 && g_cached_close_1 < g_cached_ema5_1)
   {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid <= 0.0) return false;

      const double swing_high = QM_StopStructure(_Symbol, QM_SELL, bid, strategy_swing_lookback);
      if(swing_high <= 0.0) return false;

      const double sl = swing_high + buf;
      if(sl <= 0.0 || sl <= bid) return false;

      const double tp = QM_TakeRR(_Symbol, QM_SELL, bid, sl, strategy_tp_rr);
      if(tp <= 0.0) return false;

      req.type               = QM_SELL;
      req.price              = 0.0;
      req.sl                 = QM_StopRulesNormalizePrice(_Symbol, sl);
      req.tp                 = QM_StopRulesNormalizePrice(_Symbol, tp);
      req.reason             = "GENESIS_MATRIX_SELL";
      req.symbol_slot        = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
   }

   return false;
}

void Strategy_ManageOpenPosition()
{
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
      QM_TM_MoveToBreakEven(ticket, (int)MathRound(strategy_be_trigger_pips), 1);
   }
}

bool Strategy_ExitSignal()
{
   if(!g_state_valid)
      return false;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(pos_type == POSITION_TYPE_BUY && g_cached_matrix_score_1 < 4)
         return true;
      if(pos_type == POSITION_TYPE_SELL && g_cached_matrix_score_1 > 0)
         return true;
   }
   return false;
}

bool Strategy_NewsFilterHook(const datetime broker_time)
{
   return false;
}

bool Strategy_InputsValid()
{
   return (InpCCIPeriod >= 14 && InpCCIPeriod <= 30 &&
           InpT3Period >= 3 && InpT3Period <= 8 &&
           InpT3Hot >= 0.5 && InpT3Hot <= 0.8 &&
           InpGHLPeriod >= 5 && InpGHLPeriod <= 15 &&
           InpTVIPeriod >= 8 && InpTVIPeriod <= 20 &&
           strategy_atr_period >= 7 && strategy_atr_period <= 28 &&
           strategy_sl_buffer_pips >= 1.0 && strategy_sl_buffer_pips <= 5.0 &&
           strategy_tp_rr >= 1.5 && strategy_tp_rr <= 3.5 &&
           strategy_swing_lookback >= 5 && strategy_swing_lookback <= 20 &&
           strategy_be_trigger_pips >= 10.0 && strategy_be_trigger_pips <= 25.0 &&
           strategy_daily_loss_halt_pct >= 1.0 && strategy_daily_loss_halt_pct <= 3.0 &&
           strategy_daily_hard_stop_pct >= 1.5 && strategy_daily_hard_stop_pct <= 4.0 &&
           strategy_total_dd_halt_pct >= 3.0 && strategy_total_dd_halt_pct <= 10.0 &&
           strategy_per_trade_risk_cap_pct >= 0.5 && strategy_per_trade_risk_cap_pct <= 2.0);
}

bool Strategy_ConfigureCardSlippage()
{
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(point <= 0.0 || tick_size <= 0.0)
      return false;

   // QM_Entry expects deviation in symbol points; the card caps it at 3 ticks.
   const int deviation_points = (int)MathFloor((3.0 * tick_size) / point);
   if(deviation_points <= 0)
      return false;

   QM_EntryConfigure(qm_ea_id,
                     qm_news_mode_legacy,
                     deviation_points,
                     qm_stress_reject_probability,
                     qm_news_temporal,
                     qm_news_compliance,
                     QM_FrameworkMagic());
   return true;
}

// -----------------------------------------------------------------------------
// Framework wiring
// -----------------------------------------------------------------------------

int OnInit()
{
   if(!Strategy_InputsValid())
      return INIT_PARAMETERS_INCORRECT;

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

   if(!Strategy_ConfigureCardSlippage())
      return INIT_FAILED;

   if(!QM_FrameworkDeclareExecutionContract(PERIOD_M5,
                                            QM_FRIDAY_CLOSE_FRAMEWORK_OVERRIDE,
                                            "V5_WEEKEND_RISK_POLICY"))
      return INIT_FAILED;

   if(!QM_KillSwitchInit(qm_ea_id,
                         QM_FrameworkMagic(),
                         strategy_daily_hard_stop_pct,
                         strategy_total_dd_halt_pct,
                         strategy_per_trade_risk_cap_pct))
      return INIT_FAILED;

   AdvanceState_OnNewBar();

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_39005_forexfactory-genesis-matrix-scalper\"}");
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

   AdvanceState_OnNewBar();
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
