#property strict
#property version   "5.0"
#property description "QM5_9958 — ForexFactory RSI EMA CCI H1/H4 (ahmedabbas)"

#include <QM/QM_Common.mqh>
#include <QM/QM_Signals.mqh>

// =============================================================================
// QM5_9958 — ForexFactory RSI EMA CCI H1-H4
// Card: D:\QM\strategy_farm\artifacts\cards_approved\QM5_9958_ff-rsi-ema-cci-h1h4.md
// Source: ahmedabbas, ForexFactory 2016
// Strategy: EMA(5/12) cross on H1 with RSI(21) and CCI(80) midline confirmation.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9958;
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
input int    strategy_ema_fast_period    = 5;     // EMA fast period (card: 5)
input int    strategy_ema_slow_period    = 12;    // EMA slow period (card: 12)
input int    strategy_rsi_period         = 21;    // RSI period (card: 21)
input int    strategy_cci_period         = 80;    // CCI period (card: 80)
input double strategy_rsi_threshold      = 50.0;  // RSI midline for confirmation
input double strategy_cci_threshold      = 50.0;  // CCI midline for confirmation
input int    strategy_atr_period         = 14;    // ATR period for SL calibration
input int    strategy_stop_pips          = 45;    // Baseline stop in pips (card: 35-60 range, mid=45)
input double strategy_stop_atr_min_mult  = 0.8;   // ATR lower bound for pip stop validity
input double strategy_stop_atr_max_mult  = 1.8;   // ATR upper bound for pip stop validity
input double strategy_stop_atr_fallback  = 1.2;   // ATR multiplier when pip stop is outside bounds
input double strategy_tp_ratio           = 1.5;   // TP as multiple of SL distance (card: 1.5R)
input int    strategy_max_bars_hold      = 20;    // Time stop in H1 bars (card: 20)
input double strategy_min_sep_atr_mult   = 0.05;  // Min EMA separation as fraction of ATR
input double strategy_spread_filter_pct  = 0.12;  // Max spread as fraction of SL distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const string sym = _Symbol;
   const ENUM_TIMEFRAMES tf = PERIOD_H1;

   // EMA(5/12) cross on the just-closed bar
   const int cross = QM_Sig_MA_Cross(sym, tf, strategy_ema_fast_period, strategy_ema_slow_period, 1);
   if(cross == 0)
      return false;

   // RSI(21) and CCI(80) confirmation at last closed bar
   const double rsi = QM_RSI(sym, tf, strategy_rsi_period, 1);
   const double cci = QM_CCI(sym, tf, strategy_cci_period, 1);
   const double atr = QM_ATR(sym, tf, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   // EMA separation filter: skip thin crosses
   const double ema_fast = QM_EMA(sym, tf, strategy_ema_fast_period, 1);
   const double ema_slow = QM_EMA(sym, tf, strategy_ema_slow_period, 1);
   if(MathAbs(ema_fast - ema_slow) < strategy_min_sep_atr_mult * atr)
      return false;

   // Directional confirmation
   if(cross > 0)
     {
      // Long: RSI > 50, CCI > 50, close above both EMAs
      if(rsi <= strategy_rsi_threshold) return false;
      if(cci <= strategy_cci_threshold) return false;
      if(QM_Sig_Price_Above_MA(sym, tf, strategy_ema_fast_period, 0.0, 1) <= 0) return false;
      if(QM_Sig_Price_Above_MA(sym, tf, strategy_ema_slow_period, 0.0, 1) <= 0) return false;
     }
   else
     {
      // Short: RSI < 50, CCI < 50, close below both EMAs
      if(rsi >= strategy_rsi_threshold) return false;
      if(cci >= strategy_cci_threshold) return false;
      if(QM_Sig_Price_Above_MA(sym, tf, strategy_ema_fast_period, 0.0, 1) >= 0) return false;
      if(QM_Sig_Price_Above_MA(sym, tf, strategy_ema_slow_period, 0.0, 1) >= 0) return false;
     }

   // Compute stop-loss distance
   const double pip_dist = QM_StopRulesPipsToPriceDistance(sym, strategy_stop_pips);
   double sl_dist;
   if(pip_dist < strategy_stop_atr_min_mult * atr || pip_dist > strategy_stop_atr_max_mult * atr)
      sl_dist = strategy_stop_atr_fallback * atr;
   else
      sl_dist = pip_dist;

   // Spread filter: spread <= 12% of SL distance
   const double spread = SymbolInfoDouble(sym, SYMBOL_ASK) - SymbolInfoDouble(sym, SYMBOL_BID);
   if(spread > strategy_spread_filter_pct * sl_dist)
      return false;

   // Build entry request
   req.type        = (cross > 0) ? QM_ORDER_BUY : QM_ORDER_SELL;
   req.price       = QM_EntryMarketPrice(req.type);
   req.sl          = QM_StopRulesStopFromDistance(sym, req.type, req.price, sl_dist);
   req.tp          = QM_StopRulesTakeFromDistance(sym, req.type, req.price, strategy_tp_ratio * sl_dist);
   req.reason      = (cross > 0) ? "EMA_CROSS_LONG" : "EMA_CROSS_SHORT";
   req.symbol_slot = qm_magic_slot_offset;

   return (req.sl > 0.0 && req.tp > 0.0);
  }

void Strategy_ManageOpenPosition()
  {
   // No intrabar management defined in the card; SL/TP handle exits.
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      // Time stop: 20 H1 bars after entry
      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const long elapsed_bars  = (long)(TimeCurrent() - open_time) / (long)PeriodSeconds(PERIOD_H1);
      if(elapsed_bars >= (long)strategy_max_bars_hold)
         return true;

      // Signal-based exit using closed-bar shift=1 values (stable between bar closes)
      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const bool is_long = (pos_type == POSITION_TYPE_BUY);

      const int  cross = QM_Sig_MA_Cross(_Symbol, PERIOD_H1, strategy_ema_fast_period, strategy_ema_slow_period, 1);
      const double rsi = QM_RSI(_Symbol, PERIOD_H1, strategy_rsi_period, 1);
      const double cci = QM_CCI(_Symbol, PERIOD_H1, strategy_cci_period, 1);

      if(is_long)
        {
         if(cross < 0) return true;  // EMA5 crossed below EMA12
         if(rsi < strategy_rsi_threshold && cci < strategy_cci_threshold) return true;
        }
      else
        {
         if(cross > 0) return true;  // EMA5 crossed above EMA12
         if(rsi > strategy_rsi_threshold && cci > strategy_cci_threshold) return true;
        }
     }
   return false;
  }

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
