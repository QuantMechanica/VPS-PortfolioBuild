#property strict
#property version   "5.0"
#property description "QM5_9192 MQL5 Trend Flat Momentum (ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_9192 — Trend Flat Momentum
// Card: D:\QM\strategy_farm\artifacts\cards_approved\QM5_9192_mql5-trend-flat.md
// Source: Allan Munene Mutiiria, MQL5 Articles, 2025-02-27
// Signal: SMA(11) × SMA(25) cross + RSI threshold + dual CCI(36/55) confirmation
// Stop:   Most recent pivot high/low (PivotLeft/PivotRight bars)
// TP:     Fixed points from entry
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 9192;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal     = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance   = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours                = 336;
input string qm_news_min_impact                     = "high";
input QM_NewsMode qm_news_mode_legacy               = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_fast_ma_period   = 11;    // Fast SMA period (source MA(11))
input int    strategy_slow_ma_period   = 25;    // Slow SMA period (source MA(25))
input int    strategy_rsi_period       = 14;    // RSI smoothing period
input double strategy_rsi_buy_thresh   = 50.0;  // RSI min for long entries
input double strategy_rsi_sell_thresh  = 50.0;  // RSI max for short entries
input int    strategy_cci_fast_period  = 36;    // CCI fast period (source)
input int    strategy_cci_slow_period  = 55;    // CCI slow period (source)
input int    strategy_tp_points        = 500;   // Fixed TP in SYMBOL_POINT units
input int    strategy_pivot_left       = 5;     // Pivot detection: bars to the left
input int    strategy_pivot_right      = 5;     // Pivot detection: bars to the right
input int    strategy_pivot_lookback   = 50;    // Max bars to search for pivot

// -----------------------------------------------------------------------------
// Pivot helpers — structural stop calculation from source GetPivotLow/High.
// Called only inside Strategy_EntrySignal which is gated by QM_IsNewBar in OnTick.
// Bounded loop: (pivot_right + lookback) × (pivot_left + pivot_right) ops per bar.
// -----------------------------------------------------------------------------

double GetPivotLow(const int pleft, const int pright, const int lookback)
  {
   const int start = pright + 1;
   const int end   = pright + lookback;
   for(int i = start; i <= end; ++i)
     {
      const double lo = iLow(_Symbol, _Period, i); // perf-allowed
      if(lo <= 0.0)
         continue;
      bool is_pivot = true;
      for(int j = 1; j <= pleft && is_pivot; ++j)
        {
         const double lb = iLow(_Symbol, _Period, i + j); // perf-allowed
         if(lb <= lo)
            is_pivot = false;
        }
      for(int j = 1; j <= pright && is_pivot; ++j)
        {
         const double rb = iLow(_Symbol, _Period, i - j); // perf-allowed
         if(rb <= lo)
            is_pivot = false;
        }
      if(is_pivot)
         return lo;
     }
   return 0.0;
  }

double GetPivotHigh(const int pleft, const int pright, const int lookback)
  {
   const int start = pright + 1;
   const int end   = pright + lookback;
   for(int i = start; i <= end; ++i)
     {
      const double hi = iHigh(_Symbol, _Period, i); // perf-allowed
      if(hi <= 0.0)
         continue;
      bool is_pivot = true;
      for(int j = 1; j <= pleft && is_pivot; ++j)
        {
         const double lb = iHigh(_Symbol, _Period, i + j); // perf-allowed
         if(lb >= hi)
            is_pivot = false;
        }
      for(int j = 1; j <= pright && is_pivot; ++j)
        {
         const double rb = iHigh(_Symbol, _Period, i - j); // perf-allowed
         if(rb >= hi)
            is_pivot = false;
        }
      if(is_pivot)
         return hi;
     }
   return 0.0;
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
   const double fast_now  = QM_SMA(_Symbol, _Period, strategy_fast_ma_period, 1);
   const double slow_now  = QM_SMA(_Symbol, _Period, strategy_slow_ma_period, 1);
   const double fast_prev = QM_SMA(_Symbol, _Period, strategy_fast_ma_period, 2);
   const double slow_prev = QM_SMA(_Symbol, _Period, strategy_slow_ma_period, 2);

   if(fast_now <= 0.0 || slow_now <= 0.0 || fast_prev <= 0.0 || slow_prev <= 0.0)
      return false;

   const double rsi = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   if(rsi <= 0.0)
      return false;

   const double cci_fast = QM_CCI(_Symbol, _Period, strategy_cci_fast_period, 1);
   const double cci_slow = QM_CCI(_Symbol, _Period, strategy_cci_slow_period, 1);

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;

   // Long: bullish SMA cross + RSI above buy threshold + both CCIs positive
   if(fast_prev <= slow_prev && fast_now > slow_now &&
      rsi > strategy_rsi_buy_thresh &&
      cci_fast > 0.0 && cci_slow > 0.0)
     {
      const double sl = GetPivotLow(strategy_pivot_left, strategy_pivot_right, strategy_pivot_lookback);
      if(sl <= 0.0)
         return false;  // no valid pivot low found: skip per card

      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(ask <= 0.0 || sl >= ask)
         return false;

      req.type             = QM_BUY;
      req.price            = 0.0;
      req.sl               = sl;
      req.tp               = ask + strategy_tp_points * point;
      req.reason           = "TRENDFLAT_LONG";
      req.symbol_slot      = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
     }

   // Short: bearish SMA cross + RSI below sell threshold + both CCIs negative
   if(fast_prev >= slow_prev && fast_now < slow_now &&
      rsi < strategy_rsi_sell_thresh &&
      cci_fast < 0.0 && cci_slow < 0.0)
     {
      const double sl = GetPivotHigh(strategy_pivot_left, strategy_pivot_right, strategy_pivot_lookback);
      if(sl <= 0.0)
         return false;  // no valid pivot high found: skip per card

      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid <= 0.0 || sl <= bid)
         return false;

      req.type             = QM_SELL;
      req.price            = 0.0;
      req.sl               = sl;
      req.tp               = bid - strategy_tp_points * point;
      req.reason           = "TRENDFLAT_SHORT";
      req.symbol_slot      = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Card: no trailing or partial-close logic; SL/TP drives exit.
  }

bool Strategy_ExitSignal()
  {
   // Close on opposite validated signal (MA cross + RSI + CCI all confirm reversal).
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   ENUM_POSITION_TYPE ptype = POSITION_TYPE_BUY;
   bool has_pos = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      ptype    = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      has_pos  = true;
      break;
     }
   if(!has_pos)
      return false;

   const double fast_now  = QM_SMA(_Symbol, _Period, strategy_fast_ma_period, 1);
   const double slow_now  = QM_SMA(_Symbol, _Period, strategy_slow_ma_period, 1);
   const double fast_prev = QM_SMA(_Symbol, _Period, strategy_fast_ma_period, 2);
   const double slow_prev = QM_SMA(_Symbol, _Period, strategy_slow_ma_period, 2);

   if(fast_now <= 0.0 || slow_now <= 0.0 || fast_prev <= 0.0 || slow_prev <= 0.0)
      return false;

   const double rsi = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   if(rsi <= 0.0)
      return false;

   const double cci_fast = QM_CCI(_Symbol, _Period, strategy_cci_fast_period, 1);
   const double cci_slow = QM_CCI(_Symbol, _Period, strategy_cci_slow_period, 1);

   // Long position: exit on bearish cross with all reverse confirmations
   if(ptype == POSITION_TYPE_BUY &&
      fast_prev >= slow_prev && fast_now < slow_now &&
      rsi < strategy_rsi_sell_thresh &&
      cci_fast < 0.0 && cci_slow < 0.0)
      return true;

   // Short position: exit on bullish cross with all reverse confirmations
   if(ptype == POSITION_TYPE_SELL &&
      fast_prev <= slow_prev && fast_now > slow_now &&
      rsi > strategy_rsi_buy_thresh &&
      cci_fast > 0.0 && cci_slow > 0.0)
      return true;

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"ba57d97a\",\"ea\":\"QM5_9192_mql5-trend-flat\"}");
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
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
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
