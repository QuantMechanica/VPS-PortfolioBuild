#property strict
#property version   "5.0"
#property description "QM5_9457 Geraked Bollinger RSI Re-Entry (gk-bbrsi)"
// Strategy Card: QM5_9457 (gk-bbrsi), G0 APPROVED 2026-05-19.
// Source: geraked/metatrader5, BBRSI.mq5 (Geraked/Rabist, commit d3eb29c382)
// Logic: BB(500,2) + RSI(7) re-entry from oversold/overbought extremes on M5.

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9457;
input int    qm_magic_slot_offset       = 0;
// FW3: Q07 Multi-Seed uses one of the canonical seeds (42, 17, 99, 7, 2026).
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
// FW1 2026-05-23 -- Two-axis news filter per Vault Q09.
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
// FW2 2026-05-23 -- only populated by Q05/Q06 stress setfiles.
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
// BB(500, 2.0) + RSI(7) re-entry mean-reversion. Card §Entry/Exit/Stop.
input int    strategy_bb_period         = 500;   // Bollinger band period
input double strategy_bb_deviation      = 2.0;   // Bollinger band deviation
input int    strategy_rsi_period        = 7;     // RSI period
input double strategy_tp_coef           = 1.0;   // TP = tp_coef * SL distance (card TPCoef=1)
input double strategy_sl_dev_mult       = 0.0;   // SL extension beyond band (card P2 seed=0; sweep 0.9)
input int    strategy_max_hold_bars     = 72;    // Fallback time exit after N M5 bars

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   // No session or regime filter for this strategy.
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type               = QM_BUY;
   req.price              = 0.0;
   req.sl                 = 0.0;
   req.tp                 = 0.0;
   req.reason             = "";
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   // One open position at a time (card: MultipleOpenPos = false, Grid = false).
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(strategy_bb_period < 2 || strategy_bb_deviation <= 0.0 || strategy_rsi_period < 2)
      return false;

   // Indicator values at bar[1] and bar[2] -- closed bars only.
   const double bb_upper_1  = QM_BB_Upper (_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1, PRICE_CLOSE);
   const double bb_middle_1 = QM_BB_Middle(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1, PRICE_CLOSE);
   const double bb_lower_1  = QM_BB_Lower (_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1, PRICE_CLOSE);
   const double bb_upper_2  = QM_BB_Upper (_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 2, PRICE_CLOSE);
   const double bb_lower_2  = QM_BB_Lower (_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 2, PRICE_CLOSE);

   if(bb_upper_1 <= 0.0 || bb_middle_1 <= 0.0 || bb_lower_1 <= 0.0)
      return false;
   if(bb_upper_2 <= 0.0 || bb_lower_2 <= 0.0)
      return false;

   const double rsi_1 = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1, PRICE_CLOSE);
   const double rsi_2 = QM_RSI(_Symbol, _Period, strategy_rsi_period, 2, PRICE_CLOSE);

   if(rsi_1 <= 0.0 || rsi_2 <= 0.0)
      return false;
   const double close_1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar structural read
   const double close_2 = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar structural read

   if(close_1 <= 0.0 || close_2 <= 0.0)
      return false;

   // Half-band width at bar[1] (symmetric BB: middle - lower == upper - middle).
   const double band_half_1 = bb_middle_1 - bb_lower_1;

   // ------------------------------------------------------------------
   // BUY: bar[2] oversold below lower band; bar[1] re-enters above it.
   // bar[2]: RSI < 30 AND close < lower band
   // bar[1]: 30 < RSI < 50 AND close above lower AND below middle band
   // ------------------------------------------------------------------
   if(rsi_2 < 30.0 && close_2 < bb_lower_2 &&
      rsi_1 > 30.0 && rsi_1 < 50.0 &&
      close_1 > bb_lower_1 && close_1 < bb_middle_1)
     {
      const double ask      = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(ask <= 0.0) return false;
      const double sl_price = bb_lower_1 - strategy_sl_dev_mult * band_half_1;
      if(sl_price <= 0.0 || sl_price >= ask) return false;
      const double sl_dist  = ask - sl_price;
      if(sl_dist <= 0.0) return false;
      const double tp_price = ask + sl_dist * strategy_tp_coef;
      req.type   = QM_BUY;
      req.price  = ask;
      req.sl     = NormalizeDouble(sl_price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
      req.tp     = NormalizeDouble(tp_price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
      req.reason = "GKBBRSI_BUY";
      return true;
     }

   // ------------------------------------------------------------------
   // SELL: bar[2] overbought above upper band; bar[1] re-enters below it.
   // bar[2]: RSI > 70 AND close > upper band
   // bar[1]: 50 < RSI < 70 AND close below upper AND above middle band
   // ------------------------------------------------------------------
   if(rsi_2 > 70.0 && close_2 > bb_upper_2 &&
      rsi_1 > 50.0 && rsi_1 < 70.0 &&
      close_1 < bb_upper_1 && close_1 > bb_middle_1)
     {
      const double bid      = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid <= 0.0) return false;
      const double sl_price = bb_upper_1 + strategy_sl_dev_mult * band_half_1;
      if(sl_price <= 0.0 || sl_price <= bid) return false;
      const double sl_dist  = sl_price - bid;
      if(sl_dist <= 0.0) return false;
      const double tp_price = bid - sl_dist * strategy_tp_coef;
      if(tp_price <= 0.0) return false;
      req.type   = QM_SELL;
      req.price  = bid;
      req.sl     = NormalizeDouble(sl_price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
      req.tp     = NormalizeDouble(tp_price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
      req.reason = "GKBBRSI_SELL";
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // No trailing stop or break-even for this mean-reversion strategy.
  }

bool Strategy_ExitSignal()
  {
   // All reads are O(1) per tick: POSITION_TIME arithmetic + shift=1 closed-bar reads.
   const int magic = QM_FrameworkMagic();
   const int total = PositionsTotal();
   for(int i = total - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      // Fallback time exit: close after strategy_max_hold_bars M5 bars.
      // Uses POSITION_TIME so it survives EA restarts.
      const datetime open_time    = (datetime)PositionGetInteger(POSITION_TIME);
      const int      elapsed_bars = (int)((TimeCurrent() - open_time) / (5 * 60));
      if(elapsed_bars >= strategy_max_hold_bars) return true;

      // Optional middle-band cross exit -- only when floating profit is non-negative.
      const double profit = PositionGetDouble(POSITION_PROFIT);
      if(profit >= 0.0)
        {
         const double mid     = QM_BB_Middle(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1, PRICE_CLOSE);
         const double close_1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar structural read
         if(mid > 0.0 && close_1 > 0.0)
           {
            const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            if(ptype == POSITION_TYPE_BUY  && close_1 > mid) return true;
            if(ptype == POSITION_TYPE_SELL && close_1 < mid) return true;
           }
        }
      break; // single-position mode
     }
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade(...)
  }

// -----------------------------------------------------------------------------
// Framework wiring -- do NOT edit below this line unless you know why.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_9457_gk-bbrsi\",\"bb_period\":500,\"rsi_period\":7}");
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