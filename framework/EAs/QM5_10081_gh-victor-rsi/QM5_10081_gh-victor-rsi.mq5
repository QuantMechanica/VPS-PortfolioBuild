#property strict
#property version   "5.0"
#property description "QM5_10081 gh-victor-rsi — RSI/price divergence mean-reversion reversal"
// Strategy Card: QM5_10081_gh-victor-rsi (gh-victor-rsi), G0 APPROVED 2026-05-19.
// Source: Victor Algo "Divergence Rsi de LeTraderSmart" (GitHub). Mechanical
// RSI(14) vs price local-extreme divergence with a percent trailing stop.

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_10081 gh-victor-rsi
// -----------------------------------------------------------------------------
// Five Strategy_* hooks below carry the entire strategy. All per-tick scaffold,
// risk sizing, magic resolution, news + Friday-close guards live in the
// framework (QM_Common.mqh). Divergence detection is bespoke structural logic:
// it reads a closed-bar OHLC window once per new bar (CopyRates, perf-allowed)
// and reads RSI through the pooled QM_RSI reader — never raw iRSI / i* series.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10081;
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
// Card §Entry: RSI(14) on close; divergence searched over the last 20-100 closed
// candles using local price/RSI extremes; thresholds 30 / 70; confirmation candle.
input int    rsi_period            = 14;     // Card: RSI 14 on close.
input double rsi_oversold          = 30.0;   // Card: both RSI lows must be below 30 (buy).
input double rsi_overbought        = 70.0;   // Card: both RSI highs must be above 70 (sell).
input int    div_lookback_max      = 100;    // Card: search the last 20-100 closed candles.
input int    div_pivot_strength    = 2;      // bars each side defining a local price extreme.
// Card §Stop Loss / §Exit: initial + trailing stop expressed as a percent of price.
input double sl_percent            = 1.0;    // Card: initial SL = price * (1 -/+ 1.0%).
input double trail_percent         = 1.0;    // Card: trail SL to price * (1 -/+ 1.0%).

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// O(1) per-tick gate. The strategy has no custom session/spread filter beyond the
// framework news + Friday-close guards (card §Filters allows framework defaults).
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Find the two most recent local price extremes (pivots) of the requested side
// within the closed-bar window. Returns false if fewer than two were found.
// `want_low` true → pivot lows (buy divergence); false → pivot highs (sell).
// Writes bar shifts (1 = last closed bar) into shift_recent / shift_older.
bool FindTwoPivots(const double &highs[], const double &lows[], const int copied,
                   const bool want_low, int &shift_recent, int &shift_older)
  {
   shift_recent = -1;
   shift_older  = -1;
   const int s = (div_pivot_strength < 1) ? 1 : div_pivot_strength;
   const int last = (div_lookback_max < (s + 1)) ? (s + 1) : div_lookback_max;

   int found = 0;
   // i is a series shift; require i-s >= 1 (never use forming bar 0) and i+s < copied.
   for(int i = 1 + s; i <= last && (i + s) < copied; ++i)
     {
      bool is_pivot = true;
      for(int k = 1; k <= s && is_pivot; ++k)
        {
         if(want_low)
           {
            if(!(lows[i] < lows[i - k] && lows[i] < lows[i + k]))
               is_pivot = false;
           }
         else
           {
            if(!(highs[i] > highs[i - k] && highs[i] > highs[i + k]))
               is_pivot = false;
           }
        }
      if(!is_pivot)
         continue;

      if(shift_recent < 0)
        {
         shift_recent = i;
         found = 1;
        }
      else
        {
         shift_older = i;
         found = 2;
         break;
        }
     }
   return (found == 2);
  }

// Populate `req` and return TRUE when a new divergence entry fires on this closed
// bar. Framework guarantees QM_IsNewBar() == true before calling this hook, so
// the single CopyRates window read here runs once per closed bar, not per tick.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(div_lookback_max < 20 || sl_percent <= 0.0)
      return false;

   const int need = div_lookback_max + div_pivot_strength + 2;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, _Period, 0, need, rates); // perf-allowed: bespoke divergence window, once per new bar
   if(copied < (div_lookback_max + 2))
      return false;

   // Decompose the window into plain arrays for the pivot scan.
   double highs[]; double lows[];
   ArrayResize(highs, copied); ArrayResize(lows, copied);
   for(int j = 0; j < copied; ++j)
     {
      highs[j] = rates[j].high;
      lows[j]  = rates[j].low;
     }

   const double open1  = rates[1].open;
   const double close1 = rates[1].close;
   const bool bull_confirm = (close1 > open1);   // Card: latest closed candle bullish.
   const bool bear_confirm = (close1 < open1);   // Card: latest closed candle bearish.

   // ---- Buy divergence -----------------------------------------------------
   int lr = -1, lo = -1;
   if(bull_confirm && FindTwoPivots(highs, lows, copied, true, lr, lo))
     {
      const double price_recent = lows[lr];
      const double price_older  = lows[lo];
      const double rsi_recent = QM_RSI(_Symbol, _Period, rsi_period, lr);
      const double rsi_older  = QM_RSI(_Symbol, _Period, rsi_period, lo);
      // Recent lower low in price, higher low in RSI, both RSI lows oversold.
      if(price_recent < price_older &&
         rsi_recent > rsi_older &&
         rsi_recent < rsi_oversold && rsi_older < rsi_oversold)
        {
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(ask <= 0.0)
            return false;
         req.type = QM_BUY;
         req.price = 0.0; // market
         req.sl = ask * (1.0 - sl_percent / 100.0);
         req.tp = 0.0;    // no TP; exit is the percent trailing stop.
         req.reason = "QM5_10081_DIV_LONG";
         return true;
        }
     }

   // ---- Sell divergence ----------------------------------------------------
   int hr = -1, ho = -1;
   if(bear_confirm && FindTwoPivots(highs, lows, copied, false, hr, ho))
     {
      const double price_recent = highs[hr];
      const double price_older  = highs[ho];
      const double rsi_recent = QM_RSI(_Symbol, _Period, rsi_period, hr);
      const double rsi_older  = QM_RSI(_Symbol, _Period, rsi_period, ho);
      // Recent higher high in price, lower high in RSI, both RSI highs overbought.
      if(price_recent > price_older &&
         rsi_recent < rsi_older &&
         rsi_recent > rsi_overbought && rsi_older > rsi_overbought)
        {
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(bid <= 0.0)
            return false;
         req.type = QM_SELL;
         req.price = 0.0; // market
         req.sl = bid * (1.0 + sl_percent / 100.0);
         req.tp = 0.0;
         req.reason = "QM5_10081_DIV_SHORT";
         return true;
        }
     }

   return false;
  }

// Per-tick percent trailing stop (card §Exit). O(1): reads current Bid/Ask and
// the open position's SL only — no history, no indicator recompute.
void Strategy_ManageOpenPosition()
  {
   if(trail_percent <= 0.0)
      return;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double cur_sl = PositionGetDouble(POSITION_SL);

      if(ptype == POSITION_TYPE_BUY)
        {
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(bid <= 0.0)
            continue;
         const double target = bid * (1.0 - trail_percent / 100.0);
         // Trail up only: tighten SL when the new level is above the current one.
         if(target > cur_sl)
            QM_TM_MoveSL(ticket, target, "QM5_10081_TRAIL_LONG");
        }
      else if(ptype == POSITION_TYPE_SELL)
        {
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(ask <= 0.0)
            continue;
         const double target = ask * (1.0 + trail_percent / 100.0);
         // Trail down only: tighten SL when the new level is below the current one.
         if(cur_sl <= 0.0 || target < cur_sl)
            QM_TM_MoveSL(ticket, target, "QM5_10081_TRAIL_SHORT");
        }
     }
  }

// No discretionary exit — the position is closed by the trailing stop only
// (card §Exit: percent trailing stop, no fixed take-profit, no time stop).
bool Strategy_ExitSignal()
  {
   return false;
  }

// News-filter hook (callable for Q09 News Impact). Defer to the central filter.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_10081_gh-victor-rsi\"}");
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
