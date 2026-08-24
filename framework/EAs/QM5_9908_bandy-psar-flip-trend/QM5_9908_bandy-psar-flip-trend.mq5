#property strict
#property version   "5.1"
#property description "QM5_9908 Bandy Parabolic SAR Flip Trend"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_9908
// Strategy Card: D:/QM/strategy_farm/artifacts/cards_approved/QM5_9908_bandy-psar-flip-trend.md
// Source: Howard B. Bandy, "Quantitative Technical Analysis", 2015 (9ef19e06-5ca6-5b35-aa06-b8187aa0e016)
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9908;
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
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input double strategy_psar_step         = 0.02;
input double strategy_psar_max          = 0.20;
input int    strategy_sma_period        = 200;
input int    strategy_atr_period        = 14;
input double strategy_sl_atr_mult       = 4.0;
input int    strategy_time_stop_bars    = 60;
input int    strategy_warmup_bars       = 200;

// -----------------------------------------------------------------------------
// Card-faithful helpers
// -----------------------------------------------------------------------------

bool Strategy_InputsValid()
  {
   return (strategy_psar_step > 0.0 &&
           strategy_psar_max >= strategy_psar_step &&
           strategy_sma_period > 0 &&
           strategy_atr_period > 0 &&
           strategy_sl_atr_mult > 0.0 &&
           strategy_time_stop_bars > 0 &&
           strategy_warmup_bars > 0);
  }

bool Strategy_HasWarmup()
  {
   const int required_bars = MathMax(strategy_warmup_bars, strategy_sma_period + 2);
   const int available_bars = Bars(_Symbol, PERIOD_D1); // perf-allowed: one bounded D1 readiness query on the daily entry edge.
   return (available_bars >= required_bars);
  }

bool Strategy_LoadClosedBars(MqlRates &bar1, MqlRates &bar2)
  {
   MqlRates closed_bars[];
   if(ArrayResize(closed_bars, 2) != 2)
      return false;
   ArraySetAsSeries(closed_bars, true);
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, 2, closed_bars); // perf-allowed: constant two-bar D1 flip read.
   if(copied != 2 || ArraySize(closed_bars) < 2)
      return false;
   bar1 = closed_bars[0];
   bar2 = closed_bars[1];
   return (bar1.close > 0.0 && bar2.close > 0.0);
  }

string Strategy_EntryReason(const bool is_buy, const double catastrophic_sl)
  {
   // POSITION_COMMENT persists across EA restarts, so the entry-time ATR
   // catastrophe boundary remains distinct from the moving PSAR stop.
   return StringFormat("BPSAR_%s_C=%.8f", is_buy ? "B" : "S", catastrophic_sl);
  }

bool Strategy_ReadCatastrophicStop(const string comment, double &catastrophic_sl)
  {
   catastrophic_sl = 0.0;
   const int marker = StringFind(comment, "_C=");
   if(marker < 0)
      return false;
   catastrophic_sl = StringToDouble(StringSubstr(comment, marker + 3));
   return (catastrophic_sl > 0.0);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   // Entry-only eligibility. Position management is deliberately called before
   // this hook so missing warmup can never suppress a PSAR or time-stop exit.
   return (!Strategy_InputsValid() || !Strategy_HasWarmup());
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(!Strategy_InputsValid() || !Strategy_HasWarmup())
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) > 0)
      return false;

   MqlRates bar1;
   MqlRates bar2;
   if(!Strategy_LoadClosedBars(bar1, bar2))
      return false;

   const double sma = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_period, 1, PRICE_CLOSE);
   const double psar1 = QM_SAR(_Symbol, PERIOD_D1, strategy_psar_step, strategy_psar_max, 1);
   const double psar2 = QM_SAR(_Symbol, PERIOD_D1, strategy_psar_step, strategy_psar_max, 2);
   if(sma <= 0.0 || psar1 <= 0.0 || psar2 <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double normalized_psar = QM_StopRulesNormalizePrice(_Symbol, psar1);
   if(normalized_psar <= 0.0)
      return false;

   // Long flip: PSAR was above price on bar 2 and is below price on bar 1.
   const bool long_flip = (psar2 > bar2.close && psar1 < bar1.close);
   if(long_flip && bar1.close > sma)
     {
      const double catastrophe = QM_StopATR(_Symbol, QM_BUY, ask,
                                             strategy_atr_period,
                                             strategy_sl_atr_mult);
      // Risk must be sized from the initial PSAR distance. If the PSAR lies
      // beyond the 4-ATR catastrophe boundary, reject instead of silently
      // sizing from a different stop model.
      if(catastrophe <= 0.0 || catastrophe >= ask ||
         normalized_psar >= ask || normalized_psar < catastrophe)
         return false;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = normalized_psar;
      req.tp = 0.0;
      req.reason = Strategy_EntryReason(true, catastrophe);
      req.symbol_slot = 0; // relative host slot; QM_FrameworkMagic was resolved by MagicResolver.
      req.expiration_seconds = 0;
      return true;
     }

   // Short flip: PSAR was below price on bar 2 and is above price on bar 1.
   const bool short_flip = (psar2 < bar2.close && psar1 > bar1.close);
   if(short_flip && bar1.close < sma)
     {
      const double catastrophe = QM_StopATR(_Symbol, QM_SELL, bid,
                                             strategy_atr_period,
                                             strategy_sl_atr_mult);
      if(catastrophe <= bid || normalized_psar <= bid ||
         normalized_psar > catastrophe)
         return false;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = normalized_psar;
      req.tp = 0.0;
      req.reason = Strategy_EntryReason(false, catastrophe);
      req.symbol_slot = 0; // relative host slot; QM_FrameworkMagic was resolved by MagicResolver.
      req.expiration_seconds = 0;
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   MqlRates bar1;
   MqlRates bar2;
   const bool have_bars = Strategy_LoadClosedBars(bar1, bar2);
   const double psar1 = have_bars
                        ? QM_SAR(_Symbol, PERIOD_D1,
                                 strategy_psar_step, strategy_psar_max, 1)
                        : 0.0;
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int bars_held = QM_TM_HeldPeriods(_Symbol, PERIOD_D1, open_time);
      if(bars_held >= strategy_time_stop_bars)
        {
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
         continue;
        }

      if(!have_bars || psar1 <= 0.0 || point <= 0.0)
         continue;

      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const bool is_buy = (type == POSITION_TYPE_BUY);

      // Closed-bar PSAR reversal exits at the next available D1 open/tick.
      if((is_buy && psar1 > bar1.close) || (!is_buy && psar1 < bar1.close))
        {
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
         continue;
        }

      double catastrophe = 0.0;
      const bool have_catastrophe = Strategy_ReadCatastrophicStop(
         PositionGetString(POSITION_COMMENT), catastrophe);
      double target_sl = psar1;
      if(have_catastrophe)
         target_sl = is_buy ? MathMax(target_sl, catastrophe)
                            : MathMin(target_sl, catastrophe);
      target_sl = QM_StopRulesNormalizePrice(_Symbol, target_sl);
      if(target_sl <= 0.0)
         continue;

      const double market_price = is_buy
                                  ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                  : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double current_sl = PositionGetDouble(POSITION_SL);
      if(market_price <= 0.0 ||
         (is_buy && target_sl >= market_price) ||
         (!is_buy && target_sl <= market_price))
         continue;

      const bool improves = (current_sl <= 0.0) ||
                            (is_buy
                             ? target_sl > current_sl + point * 0.5
                             : target_sl < current_sl - point * 0.5);
      if(improves)
         QM_TM_MoveSL(ticket, target_sl, "BANDY_PSAR_TRAIL");
     }
  }

bool Strategy_ExitSignal()
  {
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring
// -----------------------------------------------------------------------------

int OnInit()
  {
   if(!Strategy_InputsValid())
      return INIT_PARAMETERS_INCORRECT;

   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset,
                        RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy,
                        qm_friday_close_enabled, qm_friday_close_hour_broker,
                        30, 30, qm_news_stale_max_hours, qm_news_min_impact,
                        qm_rng_seed, qm_stress_reject_probability,
                        qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;

   if(!QM_FrameworkDeclareExecutionContract(
         PERIOD_D1,
         QM_FRIDAY_CLOSE_FRAMEWORK_OVERRIDE,
         "V5 framework Friday-close safety overlay; strategy signals and holding periods are D1"))
     {
      QM_FrameworkShutdown();
      return INIT_FAILED;
     }

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_9908_bandy-psar-flip-trend\",\"tf\":\"D1\"}");
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

   // Management is position-owned and remains reachable regardless of every
   // entry-only kill/news/session/warmup decision below.
   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
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
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;

   if(QM_FrameworkHandleFridayClose())
      return;

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now,
                                        qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar(_Symbol, PERIOD_D1))
      return;

   QM_EquityStreamOnNewBar();

   if(Strategy_NoTradeFilter())
      return;

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
