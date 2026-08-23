#property strict
#property version   "5.0"
#property description "QM5_11292 TRIX(14) signal-line crossover"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_11292
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11292;
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
input int    strategy_trix_period         = 14;
input int    strategy_signal_period       = 9;
input int    strategy_signal_method       = 1;     // 1=TRIX/signal cross, 2=zero-line cross
input int    strategy_warmup_bars         = 240;
input int    strategy_atr_period          = 14;
input double strategy_atr_sl_mult         = 1.5;
input double strategy_atr_tp_mult         = 2.5;
input double strategy_max_spread_pips     = 20.0;
input bool   strategy_use_ema200_filter   = false;
input int    strategy_trend_ema_period    = 200;

bool   g_signal_valid     = false;
int    g_signal_direction = 0;

double Strategy_SpreadPips()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0 || ask < bid)
      return DBL_MAX;

   const double pip_size = point * ((digits == 3 || digits == 5) ? 10.0 : 1.0);
   if(pip_size <= 0.0)
      return DBL_MAX;
   return (ask - bid) / pip_size;
  }

bool Strategy_CalculateSignal(int &direction)
  {
   direction = 0;
   if(strategy_trix_period <= 1 || strategy_signal_period <= 1)
      return false;

   int requested = strategy_warmup_bars;
   const int minimum_warmup = strategy_trix_period * 10 + strategy_signal_period * 4 + 4;
   if(requested < minimum_warmup)
      requested = minimum_warmup;

   double closes[];
   ArraySetAsSeries(closes, true);
   const int copied = CopyClose(_Symbol, _Period, 1, requested, closes); // perf-allowed: bounded TRIX warmup, called once per closed bar.
   if(copied < minimum_warmup)
      return false;

   const double trix_alpha = 2.0 / ((double)strategy_trix_period + 1.0);
   const double signal_alpha = 2.0 / ((double)strategy_signal_period + 1.0);
   const int oldest = copied - 1;
   if(closes[oldest] <= 0.0)
      return false;

   double ema1 = closes[oldest];
   double ema2 = closes[oldest];
   double ema3 = closes[oldest];
   double previous_ema3 = ema3;
   double signal = 0.0;
   double older_trix = 0.0;
   double older_signal = 0.0;
   double latest_trix = 0.0;
   double latest_signal = 0.0;
   double latest_close = 0.0;
   bool signal_seeded = false;
   bool have_older = false;
   bool have_latest = false;

   for(int idx = oldest - 1; idx >= 0; --idx)
     {
      const double close_value = closes[idx];
      if(close_value <= 0.0 || previous_ema3 <= 0.0)
         return false;

      ema1 = trix_alpha * close_value + (1.0 - trix_alpha) * ema1;
      ema2 = trix_alpha * ema1 + (1.0 - trix_alpha) * ema2;
      ema3 = trix_alpha * ema2 + (1.0 - trix_alpha) * ema3;
      const double trix = 100.0 * (ema3 - previous_ema3) / previous_ema3;
      previous_ema3 = ema3;

      if(!signal_seeded)
        {
         signal = trix;
         signal_seeded = true;
        }
      else
         signal = signal_alpha * trix + (1.0 - signal_alpha) * signal;

      if(idx == 1)
        {
         older_trix = trix;
         older_signal = signal;
         have_older = true;
        }
      else if(idx == 0)
        {
         latest_trix = trix;
         latest_signal = signal;
         latest_close = close_value;
         have_latest = true;
        }
     }

   if(!have_older || !have_latest)
      return false;

   if(strategy_signal_method == 1)
     {
      if(older_trix <= older_signal && latest_trix > latest_signal)
         direction = 1;
      else if(older_trix >= older_signal && latest_trix < latest_signal)
         direction = -1;
     }
   else if(strategy_signal_method == 2)
     {
      if(older_trix <= 0.0 && latest_trix > 0.0)
         direction = 1;
      else if(older_trix >= 0.0 && latest_trix < 0.0)
         direction = -1;
     }
   else
      return false;

   if(direction != 0 && strategy_use_ema200_filter)
     {
      const double trend_ema = QM_EMA(_Symbol, _Period, strategy_trend_ema_period, 1);
      if(trend_ema <= 0.0)
         return false;
      if((direction > 0 && latest_close <= trend_ema) ||
         (direction < 0 && latest_close >= trend_ema))
         direction = 0;
     }

   return true;
  }

void Strategy_RefreshSignal()
  {
   g_signal_direction = 0;
   g_signal_valid = Strategy_CalculateSignal(g_signal_direction);
  }

bool Strategy_GetOurPosition(int &direction, ulong &ticket)
  {
   direction = 0;
   ticket = 0;
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong candidate = PositionGetTicket(i);
      if(candidate == 0 || !PositionSelectByTicket(candidate))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic ||
         PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      direction = (position_type == POSITION_TYPE_BUY) ? 1 : -1;
      ticket = candidate;
      return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_signal_valid || g_signal_direction == 0)
      return false;
   if(strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0 ||
      strategy_atr_tp_mult <= 0.0 || strategy_max_spread_pips <= 0.0)
      return false;
   if(Strategy_SpreadPips() > strategy_max_spread_pips)
      return false;

   req.type = (g_signal_direction > 0) ? QM_BUY : QM_SELL;
   req.reason = (g_signal_direction > 0) ? "TRIX_SIGNAL_CROSS_LONG" : "TRIX_SIGNAL_CROSS_SHORT";
   const double entry_price = (g_signal_direction > 0)
                              ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                              : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry_price <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, req.type, entry_price, strategy_atr_period, strategy_atr_sl_mult);
   req.tp = QM_TakeATR(_Symbol, req.type, entry_price, strategy_atr_period, strategy_atr_tp_mult);
   if(g_signal_direction > 0)
      return (req.sl > 0.0 && req.sl < entry_price && req.tp > entry_price);
   return (req.sl > entry_price && req.tp > 0.0 && req.tp < entry_price);
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic ||
         PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      if(open_price <= 0.0 || current_sl <= 0.0)
         continue;

      if(position_type == POSITION_TYPE_BUY)
        {
         if(current_sl >= open_price - point * 0.5)
            continue;
         const double initial_risk = open_price - current_sl;
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(initial_risk > 0.0 && bid - open_price >= initial_risk)
            QM_TM_MoveSL(ticket, NormalizeDouble(open_price, _Digits), "TRIX_BREAK_EVEN_1R");
        }
      else if(position_type == POSITION_TYPE_SELL)
        {
         if(current_sl <= open_price + point * 0.5)
            continue;
         const double initial_risk = current_sl - open_price;
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(initial_risk > 0.0 && open_price - ask >= initial_risk)
            QM_TM_MoveSL(ticket, NormalizeDouble(open_price, _Digits), "TRIX_BREAK_EVEN_1R");
        }
     }
  }

bool Strategy_ExitSignal()
  {
   if(!g_signal_valid || g_signal_direction == 0)
      return false;

   int position_direction = 0;
   ulong ticket = 0;
   if(!Strategy_GetOurPosition(position_direction, ticket))
      return false;
   return (position_direction != g_signal_direction);
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
   if(strategy_trix_period <= 1 || strategy_signal_period <= 1 ||
      (strategy_signal_method != 1 && strategy_signal_method != 2) ||
      strategy_warmup_bars < 1 || strategy_atr_period <= 0 ||
      strategy_atr_sl_mult <= 0.0 || strategy_atr_tp_mult <= 0.0 ||
      strategy_max_spread_pips <= 0.0 || strategy_trend_ema_period <= 1)
      return INIT_PARAMETERS_INCORRECT;

   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy, qm_friday_close_enabled, qm_friday_close_hour_broker,
                        30, 30, qm_news_stale_max_hours, qm_news_min_impact, qm_rng_seed,
                        qm_stress_reject_probability, qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_11292_trix14-signal-cross\"}");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { QM_FrameworkShutdown(); }

void OnTick()
{
   QM_FrameworkTrackOpenPositionMae();
   if(!QM_KillSwitchCheck()) return;
   const datetime broker_now = TimeCurrent();
   if(QM_FrameworkHandleFridayClose()) return;
   if(Strategy_NoTradeFilter()) return;

   Strategy_ManageOpenPosition();

   if(!QM_IsNewBar()) return;
   QM_EquityStreamOnNewBar();
   Strategy_RefreshSignal();

   if(Strategy_ExitSignal())
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

   if(Strategy_NewsFilterHook(broker_now)) return;
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows) return;

   QM_EntryRequest req;
   ZeroMemory(req);
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
