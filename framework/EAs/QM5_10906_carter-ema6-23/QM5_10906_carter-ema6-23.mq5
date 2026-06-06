#property strict
#property version   "5.0"
#property description "QM5_10906 Carter EMA 6/23 MACD Stochastic Trend Cross (carter-ema6-23)"
// Strategy Card: QM5_10906 (carter-ema6-23), G0 APPROVED 2026-05-22.
// Source: Thomas Carter, 20 Forex Trading Strategies (1H), Strategy #3, p.9.

#include <QM/QM_Common.mqh>
#include <QM/QM_Signals.mqh>

// =============================================================================
// Carter EMA 6/23 — H1 EURUSD trend-cross with MACD + Stochastic confirmation.
//   Long : EMA(6) crosses above EMA(23) + MACD(30,60,30) bullish + Stoch(5,3,3)
//          crosses up + entry within 0.5*ATR(14) of EMA(6).
//   Short: mirror.
//   Exit : fixed 25-pip SL / 55-pip TP, OR reverse EMA(6)/EMA(23) cross.
// Only the five Strategy_* hooks + Strategy inputs are EA-specific; the rest is
// framework boilerplate carried verbatim from EA_Skeleton.mq5.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10906;
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
// Card §Mechanik — Carter Strategy #3, fixed (non-ML) parameters.
input int    strategy_ema_fast          = 6;     // fast EMA period (cross trigger).
input int    strategy_ema_slow          = 23;    // slow EMA period (trend filter).
input int    strategy_macd_fast         = 30;    // MACD fast EMA.
input int    strategy_macd_slow         = 60;    // MACD slow EMA.
input int    strategy_macd_signal       = 30;    // MACD signal smoothing.
input int    strategy_stoch_k           = 5;     // Stochastic %K period.
input int    strategy_stoch_d           = 3;     // Stochastic %D period.
input int    strategy_stoch_slow        = 3;     // Stochastic slowing.
input int    strategy_atr_period        = 14;    // ATR period for entry-proximity band.
input double strategy_atr_prox_mult     = 0.5;   // entry within this * ATR of EMA(6).
input int    strategy_sl_pips           = 25;    // fixed stop loss (pips).
input int    strategy_tp_pips           = 55;    // fixed take profit (pips).

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Card §Zusaetzliche Filter: default V5 spread/session/news filters only.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Card §Entry. Caller guarantees QM_IsNewBar() == true on the closed bar.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   // Primary trigger: EMA(6) / EMA(23) cross on the last closed bar.
   const int ma_cross = QM_Sig_MA_Cross(_Symbol, PERIOD_CURRENT,
                                        strategy_ema_fast, strategy_ema_slow, 1);
   if(ma_cross == 0)
      return false;

   // MACD(30,60,30): above zero OR crossed its signal in the trade direction.
   const double macd_main_1 = QM_MACD_Main(_Symbol, PERIOD_CURRENT,
                                           strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);
   const double macd_sig_1  = QM_MACD_Signal(_Symbol, PERIOD_CURRENT,
                                             strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);
   const double macd_main_2 = QM_MACD_Main(_Symbol, PERIOD_CURRENT,
                                           strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 2);
   const double macd_sig_2  = QM_MACD_Signal(_Symbol, PERIOD_CURRENT,
                                             strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 2);
   const bool macd_cross_up   = (macd_main_2 <= macd_sig_2 && macd_main_1 > macd_sig_1);
   const bool macd_cross_down = (macd_main_2 >= macd_sig_2 && macd_main_1 < macd_sig_1);

   // Stochastic(5,3,3): %K crosses %D in the trade direction.
   const double k1 = QM_Stoch_K(_Symbol, PERIOD_CURRENT, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 1);
   const double d1 = QM_Stoch_D(_Symbol, PERIOD_CURRENT, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 1);
   const double k2 = QM_Stoch_K(_Symbol, PERIOD_CURRENT, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 2);
   const double d2 = QM_Stoch_D(_Symbol, PERIOD_CURRENT, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 2);
   const bool stoch_cross_up   = (k2 <= d2 && k1 > d1);
   const bool stoch_cross_down = (k2 >= d2 && k1 < d1);

   // Entry-proximity band: "as close to the 6 EMA as possible" => within
   // strategy_atr_prox_mult * ATR(14) of EMA(6) (card §Entry literal reading).
   const double ema_fast_val = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_ema_fast, 1);
   const double atr_val      = QM_ATR(_Symbol, PERIOD_CURRENT, strategy_atr_period, 1);
   if(ema_fast_val <= 0.0 || atr_val <= 0.0)
      return false;
   const double band = strategy_atr_prox_mult * atr_val;

   QM_OrderType side;
   if(ma_cross > 0)
     {
      const bool macd_ok = (macd_main_1 > 0.0) || macd_cross_up;
      if(!(macd_ok && stoch_cross_up))
         return false;
      side = QM_BUY;
     }
   else
     {
      const bool macd_ok = (macd_main_1 < 0.0) || macd_cross_down;
      if(!(macd_ok && stoch_cross_down))
         return false;
      side = QM_SELL;
     }

   // Reference price for the next-bar-open entry (~current bid/ask at the
   // new-bar tick). Used for both the proximity gate and the fixed SL/TP base.
   const double ref = (side == QM_BUY)
                      ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                      : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ref <= 0.0)
      return false;
   if(MathAbs(ref - ema_fast_val) > band)
      return false;

   const double tp_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_tp_pips);
   req.type   = side;
   req.price  = ref;
   req.sl     = QM_StopFixedPips(_Symbol, side, ref, strategy_sl_pips);
   req.tp     = QM_StopRulesTakeFromDistance(_Symbol, side, ref, tp_dist);
   req.reason = (side == QM_BUY) ? "carter_ema6_23_long" : "carter_ema6_23_short";
   if(req.sl <= 0.0 || req.tp <= 0.0)
      return false;
   return true;
  }

// Card §Exit/§Stop Loss: no trailing/partial/BE — fixed SL/TP set at entry.
void Strategy_ManageOpenPosition()
  {
  }

// Card §Exit alternate: close if EMA(6) crosses EMA(23) in the reverse direction.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   bool have = false;
   ENUM_POSITION_TYPE ptype = POSITION_TYPE_BUY;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      have = true;
      break;
     }
   if(!have)
      return false;

   const int ma_cross = QM_Sig_MA_Cross(_Symbol, PERIOD_CURRENT,
                                        strategy_ema_fast, strategy_ema_slow, 1);
   if(ptype == POSITION_TYPE_BUY && ma_cross < 0)
      return true;
   if(ptype == POSITION_TYPE_SELL && ma_cross > 0)
      return true;
   return false;
  }

// Defer to the central QM news filter (card uses default V5 news filter only).
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_10906_carter-ema6-23\"}");
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
