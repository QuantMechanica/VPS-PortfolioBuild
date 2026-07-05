#property strict
#property version   "5.0"
#property description "QM5_12913 XTI 12M Carry"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12913 - XTI 12M Carry
// -----------------------------------------------------------------------------
// D1 WTI carry sleeve:
//   - weekly package entry on configured broker weekday
//   - direction = better broker swap side, long or short
//   - 12M return is an adverse-drift guard, not the signal source
//   - ATR hard stop, max-hold exit, carry-side flip exit
// Runtime uses MT5 broker swap/OHLC only; no external feed or ML.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12913;
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
input int    strategy_rebalance_weekday     = 1;
input int    strategy_return_lookback_d1    = 252;
input double strategy_max_adverse_return_pct = 25.0;
input double strategy_min_swap_advantage    = 0.0;
input int    strategy_zero_swap_fallback_direction = -1;
input int    strategy_atr_period            = 20;
input double strategy_atr_sl_mult           = 3.5;
input int    strategy_max_hold_days         = 5;
input int    strategy_max_spread_points     = 1000;

int    g_cache_carry_direction   = 0;
double g_cache_swap_edge         = 0.0;
double g_cache_return_12m_pct    = 0.0;
bool   g_cache_carry_valid       = false;

bool Strategy_IsXtiD1()
  {
   return (_Symbol == "XTIUSD.DWX" && _Period == PERIOD_D1);
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

bool Strategy_LoadCarryState(int &direction, double &swap_edge, double &return_12m_pct)
  {
   direction = 0;
   swap_edge = 0.0;
   return_12m_pct = 0.0;

   const double swap_long = SymbolInfoDouble(_Symbol, SYMBOL_SWAP_LONG);
   const double swap_short = SymbolInfoDouble(_Symbol, SYMBOL_SWAP_SHORT);
   if(!MathIsValidNumber(swap_long) || !MathIsValidNumber(swap_short))
      return false;

   const double diff = swap_long - swap_short;
   const double min_edge = MathMax(0.0, strategy_min_swap_advantage);
   if(diff > min_edge)
      direction = 1;
   else if(-diff > min_edge)
      direction = -1;
   else
     {
      const bool zero_swap_tie = (MathAbs(swap_long) <= 0.0000001 && MathAbs(swap_short) <= 0.0000001);
      if(!zero_swap_tie || (strategy_zero_swap_fallback_direction != 1 && strategy_zero_swap_fallback_direction != -1))
         return false;
      direction = strategy_zero_swap_fallback_direction;
     }
   swap_edge = MathAbs(diff);

   const int lookback = MathMax(21, strategy_return_lookback_d1);
   double closes[];
   ArraySetAsSeries(closes, true);
   const int copied = CopyClose(_Symbol, PERIOD_D1, 1, lookback + 1, closes); // perf-allowed: bounded D1 carry guard behind new-bar.
   if(copied < lookback + 1)
      return false;

   const double close_recent = closes[0];
   const double close_past = closes[lookback];
   if(close_recent <= 0.0 || close_past <= 0.0)
      return false;

   return_12m_pct = 100.0 * MathLog(close_recent / close_past);
   if(!MathIsValidNumber(return_12m_pct))
      return false;

   const double adverse_limit = MathMax(0.0, strategy_max_adverse_return_pct);
   if(direction > 0 && return_12m_pct < -adverse_limit)
      return false;
   if(direction < 0 && return_12m_pct > adverse_limit)
      return false;

   return true;
  }

void Strategy_CloseOpenPositionsIfNeeded()
  {
   int carry_direction = 0;
   double swap_edge = 0.0;
   double return_12m_pct = 0.0;
   const bool carry_ready = Strategy_LoadCarryState(carry_direction, swap_edge, return_12m_pct);

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
      bool should_close = false;
      if(opened > 0 && now - opened >= hold_seconds)
         should_close = true;

      if(carry_ready && carry_direction != 0)
        {
         const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         const int position_direction = (position_type == POSITION_TYPE_BUY) ? 1 : -1;
         if(position_direction != carry_direction)
            should_close = true;
        }

      if(should_close)
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsXtiD1())
      return true;
   if(qm_magic_slot_offset != 0)
      return true;
   if(strategy_rebalance_weekday < 1 || strategy_rebalance_weekday > 5)
      return true;
   if(strategy_return_lookback_d1 < 21)
      return true;
   if(strategy_max_adverse_return_pct < 0.0)
      return true;
   if(strategy_min_swap_advantage < 0.0)
      return true;
   if(strategy_zero_swap_fallback_direction != -1 && strategy_zero_swap_fallback_direction != 0 && strategy_zero_swap_fallback_direction != 1)
      return true;
   if(strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   if(strategy_max_hold_days <= 0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_12913_XTI_12M_CARRY";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   Strategy_CloseOpenPositionsIfNeeded();

   if(!Strategy_IsRebalanceBar())
      return false;

   const datetime current_bar = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: D1 de-dupe behind new-bar.
   const int day_key = Strategy_DayKey(current_bar);
   if(day_key <= 0 || day_key == g_last_entry_day_key)
      return false;

   if(Strategy_HasOpenPosition())
      return false;

   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return false;
     }

   int direction = 0;
   double swap_edge = 0.0;
   double return_12m_pct = 0.0;
   if(!Strategy_LoadCarryState(direction, swap_edge, return_12m_pct))
      return false;
   if(direction == 0)
      return false;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0)
      return false;

   const double atr_last = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr_last <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, req.type, entry_price, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;

   req.reason = (direction > 0) ? "XTI_SWAP_CARRY_LONG" : "XTI_SWAP_CARRY_SHORT";
   g_last_entry_day_key = day_key;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   Strategy_CloseOpenPositionsIfNeeded();
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12913\",\"ea\":\"xti-12m-carry\"}");
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

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();
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

