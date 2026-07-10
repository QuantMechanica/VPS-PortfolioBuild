#property strict
#property version   "5.0"
#property description "QM5_13105 XNG ID/NR4 contraction breakout"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_13105 - XNG ID/NR4 Contraction Breakout
// -----------------------------------------------------------------------------
// D1 structural natural-gas sleeve:
//   - setup bar is inside the prior bar and narrowest of four completed bars
//   - the immediately following D1 bar must close beyond the setup extreme
//   - structural opposite-range stop, fixed-R target, and max-hold exit
// Runtime uses native MT5 OHLC/spread/ATR only; no API/CSV/external feed.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 13105;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact            = "high";
input QM_NewsMode qm_news_mode_legacy      = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled       = true;
input int    qm_friday_close_hour_broker   = 21;

input group "Stress"
input double qm_stress_reject_probability  = 0.0;

input group "Strategy"
input int    strategy_nr_lookback                = 4;
input int    strategy_atr_period                 = 20;
input double strategy_min_setup_range_atr        = 0.15;
input double strategy_max_setup_range_atr        = 0.90;
input double strategy_break_buffer_atr           = 0.05;
input double strategy_min_break_close_location   = 0.60;
input double strategy_stop_buffer_atr            = 0.10;
input double strategy_rr_target                  = 2.00;
input int    strategy_max_hold_days              = 5;
input int    strategy_max_spread_points          = 2500;

bool Strategy_IsXngD1()
  {
   return (_Symbol == "XNGUSD.DWX" && _Period == PERIOD_D1);
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

bool Strategy_LoadIdNr4State(double &setup_high,
                             double &setup_low,
                             double &setup_range,
                             double &confirm_open,
                             double &confirm_high,
                             double &confirm_low,
                             double &confirm_close,
                             double &confirm_close_location,
                             double &atr_last)
  {
   setup_high = 0.0;
   setup_low = 0.0;
   setup_range = 0.0;
   confirm_open = 0.0;
   confirm_high = 0.0;
   confirm_low = 0.0;
   confirm_close = 0.0;
   confirm_close_location = 0.0;
   atr_last = 0.0;

   const int lookback = MathMax(4, strategy_nr_lookback);
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   // Evaluated only on a new D1 bar; all copied bars are completed.
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, lookback + 2, rates);
   if(copied < lookback + 1)
      return false;

   const MqlRates confirm = rates[0];
   const MqlRates setup = rates[1];
   const MqlRates mother = rates[2];
   if(confirm.high <= confirm.low || setup.high <= setup.low || mother.high <= mother.low)
      return false;
   if(confirm.close <= 0.0 || confirm.open <= 0.0 || setup.close <= 0.0)
      return false;

   // ID: strict containment inside the immediately preceding completed bar.
   if(!(setup.high < mother.high && setup.low > mother.low))
      return false;

   // NR4: setup range is strictly smaller than each of the prior three ranges.
   setup_high = setup.high;
   setup_low = setup.low;
   setup_range = setup_high - setup_low;
   for(int i = 2; i <= lookback; ++i)
     {
      const double prior_range = rates[i].high - rates[i].low;
      if(prior_range <= 0.0 || setup_range >= prior_range)
         return false;
     }

   confirm_open = confirm.open;
   confirm_high = confirm.high;
   confirm_low = confirm.low;
   confirm_close = confirm.close;
   const double confirm_range = confirm_high - confirm_low;
   if(confirm_range <= 0.0)
      return false;

   confirm_close_location = (confirm_close - confirm_low) / confirm_range;
   atr_last = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   return (setup_range > 0.0 &&
           MathIsValidNumber(confirm_close_location) &&
           atr_last > 0.0);
  }

void Strategy_CloseExpiredPositions()
  {
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
      if(opened > 0 && now - opened >= hold_seconds)
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsXngD1())
      return true;
   if(qm_magic_slot_offset != 0)
      return true;
   if(strategy_nr_lookback != 4)
      return true;
   if(strategy_atr_period <= 1)
      return true;
   if(strategy_min_setup_range_atr <= 0.0 ||
      strategy_max_setup_range_atr <= strategy_min_setup_range_atr)
      return true;
   if(strategy_break_buffer_atr < 0.0 || strategy_stop_buffer_atr < 0.0)
      return true;
   if(strategy_min_break_close_location <= 0.5 ||
      strategy_min_break_close_location >= 1.0)
      return true;
   if(strategy_rr_target <= 0.0 || strategy_max_hold_days <= 0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_13105_XNG_IDNR4_BRK";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(Strategy_HasOpenPosition())
      return false;

   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return false;
     }

   double setup_high = 0.0;
   double setup_low = 0.0;
   double setup_range = 0.0;
   double confirm_open = 0.0;
   double confirm_high = 0.0;
   double confirm_low = 0.0;
   double confirm_close = 0.0;
   double confirm_close_location = 0.0;
   double atr_last = 0.0;
   if(!Strategy_LoadIdNr4State(setup_high,
                               setup_low,
                               setup_range,
                               confirm_open,
                               confirm_high,
                               confirm_low,
                               confirm_close,
                               confirm_close_location,
                               atr_last))
      return false;

   if(setup_range < strategy_min_setup_range_atr * atr_last ||
      setup_range > strategy_max_setup_range_atr * atr_last)
      return false;

   const double break_buffer = strategy_break_buffer_atr * atr_last;
   int direction = 0;
   if(confirm_close > setup_high + break_buffer &&
      confirm_close > confirm_open &&
      confirm_close_location >= strategy_min_break_close_location)
      direction = 1;
   else if(confirm_close < setup_low - break_buffer &&
           confirm_close < confirm_open &&
           confirm_close_location <= (1.0 - strategy_min_break_close_location))
      direction = -1;
   else
      return false;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0)
      return false;

   const double stop_buffer = strategy_stop_buffer_atr * atr_last;
   req.sl = (direction > 0) ? setup_low - stop_buffer : setup_high + stop_buffer;
   req.sl = QM_StopRulesNormalizePrice(_Symbol, req.sl);
   if(req.sl <= 0.0)
      return false;

   const double risk_distance = MathAbs(entry_price - req.sl);
   if(risk_distance <= 0.0)
      return false;
   if(req.type == QM_BUY && req.sl >= entry_price)
      return false;
   if(req.type == QM_SELL && req.sl <= entry_price)
      return false;

   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   req.tp = (direction > 0)
            ? NormalizeDouble(entry_price + strategy_rr_target * risk_distance, digits)
            : NormalizeDouble(entry_price - strategy_rr_target * risk_distance, digits);
   req.tp = QM_StopRulesNormalizePrice(_Symbol, req.tp);
   if(req.tp <= 0.0)
      return false;
   if(req.type == QM_BUY && req.tp <= entry_price)
      return false;
   if(req.type == QM_SELL && req.tp >= entry_price)
      return false;

   req.reason = (direction > 0) ? "XNG_IDNR4_BRK_LONG" : "XNG_IDNR4_BRK_SHORT";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   Strategy_CloseExpiredPositions();
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_13105\",\"ea\":\"xng-idnr4-brk\"}");
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

   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   const bool is_new_bar = QM_IsNewBar();
   if(is_new_bar)
      Strategy_ManageOpenPosition();

   if(is_new_bar && Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows || !is_new_bar)
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
