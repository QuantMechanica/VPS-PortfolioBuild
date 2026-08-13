#property strict
#property version   "5.0"
#property description "QM5_1537 Alpha Architect high-volatility 10-day SMA timing"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Card mechanics: once per calendar month, rank the complete portable DWX
// universe by annualized realized volatility over 252 closed D1 returns and
// admit the top three symbols. On each new D1 bar, a selected symbol enters
// long after the prior close crosses above SMA(10) and exits after a cross
// below. The optional short variant is disabled by default. Each entry carries
// the card's 2.5 x ATR(14, D1) initial stop and no discretionary trailing stop.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1537;
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
input int    strategy_sma_period          = 10;
input int    strategy_min_daily_bars      = 270;
input int    strategy_vol_lookback_days   = 252;
input int    strategy_top_symbols         = 3;
input int    strategy_atr_period          = 14;
input double strategy_atr_sl_mult         = 2.5;
input bool   strategy_enable_short        = false;
input int    strategy_max_spread_points   = 0;

// Registry slot order. Every entry is present in dwx_symbol_matrix.csv and in
// magic_numbers.csv for QM5_1537. Each per-symbol EA instance computes the same
// monthly basket ranking and acts only on its own chart symbol.
string g_strategy_basket[37] =
  {
   "XAUUSD.DWX", "XAGUSD.DWX", "XNGUSD.DWX", "XTIUSD.DWX",
   "NDX.DWX", "WS30.DWX", "GDAXI.DWX", "UK100.DWX", "SP500.DWX",
   "AUDCAD.DWX", "AUDCHF.DWX", "AUDJPY.DWX", "AUDNZD.DWX", "AUDUSD.DWX",
   "CADCHF.DWX", "CADJPY.DWX", "CHFJPY.DWX", "EURAUD.DWX", "EURCAD.DWX",
   "EURCHF.DWX", "EURGBP.DWX", "EURJPY.DWX", "EURNZD.DWX", "EURUSD.DWX",
   "GBPAUD.DWX", "GBPCAD.DWX", "GBPCHF.DWX", "GBPJPY.DWX", "GBPNZD.DWX",
   "GBPUSD.DWX", "NZDCAD.DWX", "NZDCHF.DWX", "NZDJPY.DWX", "NZDUSD.DWX",
   "USDCAD.DWX", "USDCHF.DWX", "USDJPY.DWX"
  };

bool   g_sleeve_initialized       = false;
bool   g_sleeve_active            = false;
double g_host_realized_vol_pct    = 0.0;
int    g_host_vol_rank            = -1;
int    g_valid_vol_symbols        = 0;

bool   g_daily_signal_ready       = false;
bool   g_crossed_above_sma        = false;
bool   g_crossed_below_sma        = false;
double g_cached_atr_d1            = 0.0;

#define QM1537_DIR_FLAT   0
#define QM1537_DIR_LONG   1
#define QM1537_DIR_SHORT -1

bool Strategy_ParametersValid()
  {
   if(strategy_sma_period < 2)
      return false;
   if(strategy_vol_lookback_days < 2)
      return false;
   if(strategy_min_daily_bars < strategy_vol_lookback_days + 1)
      return false;
   if(strategy_top_symbols < 1)
      return false;
   if(strategy_atr_period < 1 || strategy_atr_sl_mult <= 0.0)
      return false;
   if(strategy_max_spread_points < 0)
      return false;
   return true;
  }

bool Strategy_HostRegistrationMatches()
  {
   const int n = ArraySize(g_strategy_basket);
   if(qm_magic_slot_offset < 0 || qm_magic_slot_offset >= n)
      return false;
   return (g_strategy_basket[qm_magic_slot_offset] == _Symbol);
  }

int Strategy_CurrentPositionDirection()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return QM1537_DIR_FLAT;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
         return QM1537_DIR_LONG;
      return QM1537_DIR_SHORT;
     }
   return QM1537_DIR_FLAT;
  }

bool Strategy_SpreadAllowsEntry()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;
   if(strategy_max_spread_points <= 0)
      return true;
   if(!(ask > bid))
      return true;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;
   const double cap = (double)strategy_max_spread_points * point;
   return ((ask - bid) <= cap);
  }

// Bespoke cross-sectional statistic from the approved card. This is evaluated
// only from the monthly calendar edge in Strategy_ManageOpenPosition.
bool Strategy_RealizedVolatility(const string sym, double &out_vol_pct)
  {
   out_vol_pct = 0.0;
   if(!QM_SymbolAssertOrLog(sym))
      return false;

   int need = strategy_min_daily_bars;
   const int return_closes = strategy_vol_lookback_days + 1;
   if(need < return_closes)
      need = return_closes;

   double closes[];
   ArraySetAsSeries(closes, true);
   const int copied = CopyClose(sym, PERIOD_D1, 1, need, closes); // perf-allowed: monthly 252-return cross-sectional realized-volatility ranking
   if(copied != need)
      return false;

   double sum = 0.0;
   double sum_sq = 0.0;
   const int n = strategy_vol_lookback_days;
   for(int i = 0; i < n; ++i)
     {
      if(closes[i] <= 0.0 || closes[i + 1] <= 0.0)
         return false;
      const double daily_return = MathLog(closes[i] / closes[i + 1]);
      sum += daily_return;
      sum_sq += daily_return * daily_return;
     }

   const double mean = sum / (double)n;
   double variance = (sum_sq - (double)n * mean * mean) / (double)(n - 1);
   if(variance < 0.0)
      variance = 0.0;
   out_vol_pct = MathSqrt(variance) * MathSqrt(252.0) * 100.0;
   return true;
  }

bool Strategy_ComputeMonthlySelection(bool &out_selected,
                                      double &out_host_vol_pct,
                                      int &out_host_rank,
                                      int &out_valid_count)
  {
   out_selected = false;
   out_host_vol_pct = 0.0;
   out_host_rank = -1;
   out_valid_count = 0;

   const int n = ArraySize(g_strategy_basket);
   double vol[];
   bool valid[];
   ArrayResize(vol, n);
   ArrayResize(valid, n);

   int host_index = -1;
   for(int i = 0; i < n; ++i)
     {
      double value = 0.0;
      valid[i] = Strategy_RealizedVolatility(g_strategy_basket[i], value);
      vol[i] = value;
      if(valid[i])
         out_valid_count++;
      if(g_strategy_basket[i] == _Symbol)
         host_index = i;
     }

   if(host_index < 0 || out_valid_count <= 0)
      return false;
   if(!valid[host_index])
      return true;

   int ranked[];
   ArrayResize(ranked, out_valid_count);
   int k = 0;
   for(int i = 0; i < n; ++i)
     {
      if(!valid[i])
         continue;
      ranked[k] = i;
      k++;
     }

   // Stable descending insertion sort; basket/slot order resolves exact ties.
   for(int i = 1; i < out_valid_count; ++i)
     {
      const int key_index = ranked[i];
      const double key_vol = vol[key_index];
      int j = i - 1;
      while(j >= 0 && vol[ranked[j]] < key_vol)
        {
         ranked[j + 1] = ranked[j];
         j--;
        }
      ranked[j + 1] = key_index;
     }

   for(int i = 0; i < out_valid_count; ++i)
     {
      if(ranked[i] == host_index)
        {
         out_host_rank = i;
         break;
        }
     }
   out_host_vol_pct = vol[host_index];

   int selected_count = strategy_top_symbols;
   if(selected_count > out_valid_count)
      selected_count = out_valid_count;
   out_selected = (out_host_rank >= 0 && out_host_rank < selected_count);
   return true;
  }

void Strategy_AdvanceMonthlyState()
  {
   if(!QM_IsNewCalendarPeriod(PERIOD_MN1))
      return;

   bool selected = false;
   double host_vol_pct = 0.0;
   int host_rank = -1;
   int valid_count = 0;
   const bool ready = Strategy_ComputeMonthlySelection(selected,
                                                        host_vol_pct,
                                                        host_rank,
                                                        valid_count);
   g_sleeve_initialized = ready;
   g_sleeve_active = (ready && selected);
   g_host_realized_vol_pct = host_vol_pct;
   g_host_vol_rank = host_rank;
   g_valid_vol_symbols = valid_count;
  }

void Strategy_AdvanceDailyState()
  {
   if(!QM_IsNewCalendarPeriod(PERIOD_D1))
      return;

   g_daily_signal_ready = false;
   g_crossed_above_sma = false;
   g_crossed_below_sma = false;
   g_cached_atr_d1 = 0.0;

   const double sma_now = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_period, 1);
   const double sma_prev = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_period, 2);
   const double close_now = QM_SMA(_Symbol, PERIOD_D1, 1, 1);
   const double close_prev = QM_SMA(_Symbol, PERIOD_D1, 1, 2);
   const double atr_now = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(sma_now <= 0.0 || sma_prev <= 0.0 ||
      close_now <= 0.0 || close_prev <= 0.0 || atr_now <= 0.0)
      return;

   g_crossed_above_sma = (close_prev <= sma_prev && close_now > sma_now);
   g_crossed_below_sma = (close_prev >= sma_prev && close_now < sma_now);
   g_cached_atr_d1 = atr_now;
   g_daily_signal_ready = true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_D1)
      return true;
   if(!Strategy_ParametersValid() || !Strategy_HostRegistrationMatches())
      return true;

   // News is handled by the central two-axis entry gate below management.
   // A wide spread blocks new exposure only; open-position management and
   // signal exits remain active.
   if(Strategy_CurrentPositionDirection() == QM1537_DIR_FLAT &&
      !Strategy_SpreadAllowsEntry())
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
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_sleeve_initialized || !g_sleeve_active || !g_daily_signal_ready)
      return false;
   if(Strategy_CurrentPositionDirection() != QM1537_DIR_FLAT)
      return false;
   if(!Strategy_SpreadAllowsEntry())
      return false;

   int entry_direction = QM1537_DIR_FLAT;
   if(g_crossed_above_sma)
      entry_direction = QM1537_DIR_LONG;
   else if(strategy_enable_short && g_crossed_below_sma)
      entry_direction = QM1537_DIR_SHORT;
   if(entry_direction == QM1537_DIR_FLAT)
      return false;

   const bool go_long = (entry_direction == QM1537_DIR_LONG);
   const double entry = go_long ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0 || g_cached_atr_d1 <= 0.0)
      return false;

   req.type = go_long ? QM_BUY : QM_SELL;
   req.sl = QM_StopATRFromValue(_Symbol,
                                req.type,
                                entry,
                                g_cached_atr_d1,
                                strategy_atr_sl_mult);
   req.reason = go_long ? "AA_VOL_SMA10_CROSS_ABOVE"
                        : "AA_VOL_SMA10_CROSS_BELOW_SHORT";
   if(req.sl <= 0.0)
      return false;
   if(go_long && req.sl >= entry)
      return false;
   if(!go_long && req.sl <= entry)
      return false;
   return true;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   Strategy_AdvanceMonthlyState();
   Strategy_AdvanceDailyState();
   // Card specifies no trailing stop, break-even, partial close, or pyramiding.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   const int direction = Strategy_CurrentPositionDirection();
   if(direction == QM1537_DIR_FLAT)
      return false;
   if(g_sleeve_initialized && !g_sleeve_active)
      return true;
   if(!g_daily_signal_ready)
      return false;
   if(direction == QM1537_DIR_LONG)
      return g_crossed_below_sma;
   return g_crossed_above_sma;
  }

// News Filter Hook (callable for P8 News Impact phase)
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring
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

   QM_SymbolGuardInit(g_strategy_basket);
   int warmup_bars = strategy_min_daily_bars;
   if(warmup_bars < strategy_vol_lookback_days + 1)
      warmup_bars = strategy_vol_lookback_days + 1;
   if(warmup_bars < 300)
      warmup_bars = 300;
   QM_BasketWarmupHistory(g_strategy_basket, PERIOD_D1, warmup_bars + 2);

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
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol,
                                        broker_now,
                                        qm_news_temporal,
                                        qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol,
                                       broker_now,
                                       qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

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
