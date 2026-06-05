#property strict
#property version   "5.0"
#property description "QM5_10081 gh-victor-rsi — RSI/price divergence reversal (Victor Algo)"
// Strategy Card: QM5_10081 (gh-victor-rsi), G0 APPROVED 2026-05-19.
// Source: Victor Algo "Divergence Rsi de LeTraderSmart" (GitHub), card source_id
// 3b3ec48a-0755-5187-9331-afb36e174175.

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_10081 gh-victor-rsi
// -----------------------------------------------------------------------------
// Mechanical RSI/price divergence reversal, H1 baseline.
//   Long  : recent price local-low < older price local-low (price lower-low),
//           recent RSI  local-low > older RSI  local-low  (RSI higher-low),
//           BOTH RSI local-lows < oversold, latest closed candle bullish.
//   Short : recent price local-high > older price local-high (price higher-high),
//           recent RSI  local-high < older RSI  local-high  (RSI lower-high),
//           BOTH RSI local-highs > overbought, latest closed candle bearish.
//   Stop  : initial SL = entry * (1 -/+ sl_percent%).
//   Exit  : percent trailing stop (no fixed TP).
// One active position per symbol/magic, and no re-entry if an entry deal for
// this magic already fired on the prior closed bar. Entry is evaluated once per
// closed bar (framework QM_IsNewBar gate in OnTick). The divergence pivot scan
// is bespoke structural logic gated to once-per-closed-bar; all raw series reads
// are routed through the tagged Px* helpers below (// perf-allowed).
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
input int    inp_rsi_period             = 14;     // RSI period (close).
input double inp_rsi_oversold           = 30.0;   // Buy: both RSI local-lows must be below this.
input double inp_rsi_overbought         = 70.0;   // Sell: both RSI local-highs must be above this.
input int    inp_div_lookback_max       = 100;    // Search window in closed candles (card: 20-100).
input int    inp_pivot_strength         = 2;      // Bars each side that define a local extreme.
input int    inp_pivot_min_gap          = 5;      // Min bar separation between the two compared pivots.
input double inp_sl_percent             = 1.0;    // Initial stop distance, percent of entry.
input double inp_trail_percent          = 1.0;    // Percent trailing stop distance.

// -----------------------------------------------------------------------------
// Bespoke series readers. The divergence pivot scan needs raw OHLC of the
// closed-bar window; these helpers are the ONLY raw-series call sites and are
// tagged // perf-allowed. They run inside the QM_IsNewBar()-gated entry path
// (once per closed bar), never per tick.
// -----------------------------------------------------------------------------
double   PxLow(const int sh)   { return iLow(_Symbol, _Period, sh); }    // perf-allowed
double   PxHigh(const int sh)  { return iHigh(_Symbol, _Period, sh); }   // perf-allowed
double   PxClose(const int sh) { return iClose(_Symbol, _Period, sh); }  // perf-allowed
double   PxOpen(const int sh)  { return iOpen(_Symbol, _Period, sh); }   // perf-allowed
datetime PxTime(const int sh)  { return iTime(_Symbol, _Period, sh); }   // perf-allowed

double NormPrice(const double price)
  {
   if(price <= 0.0)
      return 0.0;
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   return NormalizeDouble(price, digits);
  }

double RsiAt(const int sh)
  {
   return QM_RSI(_Symbol, _Period, inp_rsi_period, sh);
  }

// A local price low at shift `i` is strictly lower than the `s` bars on both
// sides (more-recent: i-k, older: i+k).
bool IsPivotLow(const int i, const int s)
  {
   const double li = PxLow(i);
   if(li <= 0.0)
      return false;
   for(int k = 1; k <= s; ++k)
     {
      if(!(li < PxLow(i - k)))
         return false;
      if(!(li < PxLow(i + k)))
         return false;
     }
   return true;
  }

bool IsPivotHigh(const int i, const int s)
  {
   const double hi = PxHigh(i);
   if(hi <= 0.0)
      return false;
   for(int k = 1; k <= s; ++k)
     {
      if(!(hi > PxHigh(i - k)))
         return false;
      if(!(hi > PxHigh(i + k)))
         return false;
     }
   return true;
  }

// Most-recent (smallest shift) and next-older pivot lows within the window,
// separated by at least min_gap bars. Returns false if two cannot be found.
bool FindTwoPivotLows(const int s, const int max_shift, const int min_gap,
                      int &recent, int &older)
  {
   recent = -1;
   older  = -1;
   const int hi = max_shift - s;
   for(int i = s + 1; i <= hi; ++i)
     {
      if(!IsPivotLow(i, s))
         continue;
      if(recent < 0)
        {
         recent = i;
         continue;
        }
      if(i - recent >= min_gap)
        {
         older = i;
         return true;
        }
     }
   return false;
  }

bool FindTwoPivotHighs(const int s, const int max_shift, const int min_gap,
                       int &recent, int &older)
  {
   recent = -1;
   older  = -1;
   const int hi = max_shift - s;
   for(int i = s + 1; i <= hi; ++i)
     {
      if(!IsPivotHigh(i, s))
         continue;
      if(recent < 0)
        {
         recent = i;
         continue;
        }
      if(i - recent >= min_gap)
        {
         older = i;
         return true;
        }
     }
   return false;
  }

// Card: do not re-enter if this magic already opened a position on the prior
// closed bar. Scans closed-deal history for an entry-in deal in [bar1, bar0).
bool HasPriorBarEntry()
  {
   const datetime bar_start = PxTime(1);
   const datetime bar_end   = PxTime(0);
   if(bar_start <= 0 || bar_end <= bar_start)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || !HistorySelect(bar_start, bar_end))
      return false;

   const int total = HistoryDealsTotal();
   for(int i = 0; i < total; ++i)
     {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;
      if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol)
         continue;
      if((int)HistoryDealGetInteger(deal, DEAL_MAGIC) != magic)
         continue;
      if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY) == DEAL_ENTRY_IN)
         return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// No Trade Filter — framework news/Friday-close defaults cover this card; no
// strategy-specific block. Cheap O(1).
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Trade Entry — RSI/price divergence reversal. Caller guarantees QM_IsNewBar().
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type               = QM_BUY;
   req.price              = 0.0;   // market
   req.sl                 = 0.0;
   req.tp                 = 0.0;
   req.reason             = "";
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(inp_pivot_strength < 1 ||
      inp_div_lookback_max < (inp_pivot_strength + 1 + inp_pivot_min_gap))
      return false;

   // One active position per symbol/magic, no prior-bar re-entry.
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;
   if(HasPriorBarEntry())
      return false;

   const double c1 = PxClose(1);
   const double o1 = PxOpen(1);
   if(c1 <= 0.0 || o1 <= 0.0)
      return false;

   // ---- Bullish divergence (long) ----
   int rl = -1, ol = -1;
   if(FindTwoPivotLows(inp_pivot_strength, inp_div_lookback_max, inp_pivot_min_gap, rl, ol))
     {
      const double price_recent = PxLow(rl);
      const double price_older  = PxLow(ol);
      const double rsi_recent   = RsiAt(rl);
      const double rsi_older    = RsiAt(ol);
      if(rsi_recent > 0.0 && rsi_older > 0.0 &&
         price_recent < price_older &&                 // price lower-low
         rsi_recent   > rsi_older &&                    // RSI higher-low (divergence)
         rsi_recent   < inp_rsi_oversold &&
         rsi_older    < inp_rsi_oversold &&
         c1 > o1)                                       // bullish confirmation candle
        {
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(ask <= 0.0)
            return false;
         const double sl = NormPrice(ask * (1.0 - inp_sl_percent / 100.0));
         if(sl <= 0.0 || sl >= ask)
            return false;
         req.type   = QM_BUY;
         req.price  = 0.0;
         req.sl     = sl;
         req.tp     = 0.0;
         req.reason = "gh-victor-rsi DIV LONG";
         return true;
        }
     }

   // ---- Bearish divergence (short) ----
   int rh = -1, oh = -1;
   if(FindTwoPivotHighs(inp_pivot_strength, inp_div_lookback_max, inp_pivot_min_gap, rh, oh))
     {
      const double price_recent = PxHigh(rh);
      const double price_older  = PxHigh(oh);
      const double rsi_recent   = RsiAt(rh);
      const double rsi_older    = RsiAt(oh);
      if(rsi_recent > 0.0 && rsi_older > 0.0 &&
         price_recent > price_older &&                 // price higher-high
         rsi_recent   < rsi_older &&                    // RSI lower-high (divergence)
         rsi_recent   > inp_rsi_overbought &&
         rsi_older    > inp_rsi_overbought &&
         c1 < o1)                                       // bearish confirmation candle
        {
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(bid <= 0.0)
            return false;
         const double sl = NormPrice(bid * (1.0 + inp_sl_percent / 100.0));
         if(sl <= bid)
            return false;
         req.type   = QM_SELL;
         req.price  = 0.0;
         req.sl     = sl;
         req.tp     = 0.0;
         req.reason = "gh-victor-rsi DIV SHORT";
         return true;
        }
     }

   return false;
  }

// Trade Management — percent trailing stop. Runs per tick (O(1) per position).
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return;
   const double trail = inp_trail_percent / 100.0;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const ENUM_POSITION_TYPE pt = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double cur_sl = PositionGetDouble(POSITION_SL);

      if(pt == POSITION_TYPE_BUY)
        {
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(bid <= 0.0)
            continue;
         const double target = NormPrice(bid * (1.0 - trail));
         if(target > 0.0 && (cur_sl <= 0.0 || target > cur_sl + point * 0.5))   // ratchet up only
            QM_TM_MoveSL(ticket, target, "gh-victor-rsi trail");
        }
      else if(pt == POSITION_TYPE_SELL)
        {
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(ask <= 0.0)
            continue;
         const double target = NormPrice(ask * (1.0 + trail));
         if(target > 0.0 && (cur_sl <= 0.0 || target < cur_sl - point * 0.5))   // ratchet down only
            QM_TM_MoveSL(ticket, target, "gh-victor-rsi trail");
        }
     }
  }

// Trade Close — no discretionary exit; exits via trailing SL + framework Friday close.
bool Strategy_ExitSignal()
  {
   return false;
  }

// News Filter Hook — defer to the central two-axis framework news filter.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10081\",\"ea\":\"gh-victor-rsi\"}");
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
   // FW1 — 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults.
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

   // Per-tick: trade management can adjust SL/TP on open positions.
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit (e.g. time stop). Separate from SL/TP.
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

   // Per-closed-bar: entry-signal evaluation. Gating here avoids 99% of
   // per-tick recompute mistakes — EntrySignal sees one new closed bar per
   // call, not every incoming tick.
   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
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
   // FW4: feeds closing-deal net-profits to the KS kill-switch.
   // No-op outside Q13 (when no baseline.json exists).
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
