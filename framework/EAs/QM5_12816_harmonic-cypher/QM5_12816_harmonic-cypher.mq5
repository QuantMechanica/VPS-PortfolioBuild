#property strict
#property version   "5.0"
#property description "QM5_12816 harmonic-cypher"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails). The framework provides:
//
//   - QM_IsNewBar(sym="", tf=PERIOD_CURRENT)  — closed-bar gate
//   - QM_ATR / QM_EMA / QM_SMA / QM_RSI / QM_MACD_Main / QM_MACD_Signal /
//     QM_ADX / QM_ADX_PlusDI / QM_ADX_MinusDI /
//     QM_BB_Upper / QM_BB_Middle / QM_BB_Lower    (from QM_Indicators.mqh)
//   - QM_TM_OpenPosition(req, ticket) / QM_TM_ClosePosition(ticket, reason)
//   - QM_TM_MoveToBreakEven / QM_TM_TrailATR / QM_TM_TrailStep / QM_TM_PartialClose
//   - QM_LotsForRisk(symbol, sl_points)        — risk model lot sizing
//   - QM_StopFixedPips / QM_StopATR / QM_StopStructure / QM_StopVolatility
//   - QM_FrameworkHandleFridayClose / QM_KillSwitchCheck / QM_NewsAllowsTrade
//
// DO NOT
//   - Write per-EA IsNewBar() — use QM_IsNewBar()
//   - Call iATR / iMA / iRSI / iMACD / iADX / iBands or CopyBuffer directly —
//     use the QM_* readers above. The framework pools handles and releases them
//     on shutdown.
//   - CopyRates over warmup windows on every tick. If you genuinely need raw
//     bar arrays, gate by QM_IsNewBar so the work runs once per closed bar.
//   - Hand-edit framework/include/QM/QM_MagicResolver.mqh. After adding rows
//     to magic_numbers.csv, run:
//         python framework/scripts/update_magic_resolver.py
//     This is idempotent and preserves all rows.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12816;
input int    qm_magic_slot_offset       = 0;
// FW3: Q07 Multi-Seed uses one of the canonical seeds (42, 17, 99, 7, 2026).
// All other phases use 42 by default. Stress / noise dimensions read from
// this single seed so reproducibility is guaranteed across re-runs.
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
// FW1 2026-05-23 — Two-axis news filter per Vault Q09.
//   AXIS A (temporal): per-event behaviour. Default mode 3 = pause 30min pre+post.
//   AXIS B (compliance): prop-firm blackout overlay. Default DXZ = no extra rules.
// A trade is allowed only if BOTH axes allow. See Vault `Q09 News Impact Mode`.
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
// Legacy single-mode input kept for back-compat with pre-FW1 setfiles.
// New EAs use qm_news_temporal + qm_news_compliance above and leave this OFF.
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
// FW2 2026-05-23 — only populated by Q05 MED / Q06 HARSH stress setfiles.
// Default 0.0 = no rejection (Q02/Q03/Q04/Q07/Q08/Q09/Q10/Q13 backtests).
// Q06 HARSH sets to 0.10 (10% of entries randomly dropped before broker send,
// deterministic per qm_rng_seed). MED slip/spread/commission live in the
// tester groups file, not as EA inputs.
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_swing_depth          = 5;
input int    strategy_scan_bars            = 260;
input double strategy_d_tolerance          = 0.02;
input int    strategy_pending_expiry_bars  = 6;
input double strategy_partial_close_pct    = 50.0;

#define CYPHER_MAX_SWINGS 64
#define CYPHER_B_MIN 0.382
#define CYPHER_B_MAX 0.618
#define CYPHER_C_MIN 1.272
#define CYPHER_C_MAX 1.414
#define CYPHER_D_RETRACE 0.786
#define CYPHER_TP1_RETRACE 0.382
#define CYPHER_TP2_RETRACE 0.618
#define CYPHER_STOP_BUFFER_PIPS 5

struct CypherSwing
  {
   int    direction; // +1 swing high, -1 swing low.
   int    shift;
   double price;
  };

struct CypherPattern
  {
   bool   bullish;
   double entry;
   double sl;
   double tp1;
   double tp2;
   string signature;
  };

string g_submitted_pattern_signature = "";

double CypherHigh(const int shift)
  {
   return iHigh(_Symbol, _Period, shift); // perf-allowed: bespoke closed-bar swing geometry.
  }

double CypherLow(const int shift)
  {
   return iLow(_Symbol, _Period, shift); // perf-allowed: bespoke closed-bar swing geometry.
  }

bool CypherIsSwingHigh(const int shift, const int depth)
  {
   const double center = CypherHigh(shift);
   if(center <= 0.0)
      return false;

   for(int k = 1; k <= depth; ++k)
     {
      const double newer = CypherHigh(shift - k);
      const double older = CypherHigh(shift + k);
      if(newer <= 0.0 || older <= 0.0)
         return false;
      if(center <= newer || center <= older)
         return false;
     }

   return true;
  }

bool CypherIsSwingLow(const int shift, const int depth)
  {
   const double center = CypherLow(shift);
   if(center <= 0.0)
      return false;

   for(int k = 1; k <= depth; ++k)
     {
      const double newer = CypherLow(shift - k);
      const double older = CypherLow(shift + k);
      if(newer <= 0.0 || older <= 0.0)
         return false;
      if(center >= newer || center >= older)
         return false;
     }

   return true;
  }

int CypherSwingDirection(const int shift, const int depth)
  {
   const bool high = CypherIsSwingHigh(shift, depth);
   const bool low = CypherIsSwingLow(shift, depth);
   if(high && !low)
      return 1;
   if(low && !high)
      return -1;
   return 0;
  }

int CypherCollectSwings(CypherSwing &swings[])
  {
   int depth = strategy_swing_depth;
   if(depth < 2)
      depth = 2;
   if(depth > 20)
      depth = 20;

   int scan_bars = strategy_scan_bars;
   const int min_scan = depth * 8 + 20;
   if(scan_bars < min_scan)
      scan_bars = min_scan;
   if(scan_bars > 500)
      scan_bars = 500;

   int count = 0;
   for(int shift = scan_bars; shift >= depth + 1; --shift)
     {
      const int dir = CypherSwingDirection(shift, depth);
      if(dir == 0)
         continue;

      const double price = (dir > 0) ? CypherHigh(shift) : CypherLow(shift);
      if(price <= 0.0)
         continue;

      if(count > 0 && swings[count - 1].direction == dir)
        {
         const bool more_extreme = (dir > 0 && price > swings[count - 1].price) ||
                                   (dir < 0 && price < swings[count - 1].price);
         if(more_extreme)
           {
            swings[count - 1].shift = shift;
            swings[count - 1].price = price;
           }
         continue;
        }

      if(count >= CYPHER_MAX_SWINGS)
        {
         for(int i = 1; i < CYPHER_MAX_SWINGS; ++i)
            swings[i - 1] = swings[i];
         count = CYPHER_MAX_SWINGS - 1;
        }

      swings[count].direction = dir;
      swings[count].shift = shift;
      swings[count].price = price;
      ++count;
     }

   return count;
  }

bool CypherValidateLatest(CypherSwing &swings[], const int count, CypherPattern &pattern)
  {
   if(count < 5)
      return false;

   const int first = count - 5;
   const int x_dir = swings[first].direction;
   const int a_dir = swings[first + 1].direction;
   const int b_dir = swings[first + 2].direction;
   const int c_dir = swings[first + 3].direction;
   const int d_dir = swings[first + 4].direction;

   const bool bullish = (x_dir == -1 && a_dir == 1 && b_dir == -1 && c_dir == 1 && d_dir == -1);
   const bool bearish = (x_dir == 1 && a_dir == -1 && b_dir == 1 && c_dir == -1 && d_dir == 1);
   if(!bullish && !bearish)
      return false;

   const double x = swings[first].price;
   const double a = swings[first + 1].price;
   const double b = swings[first + 2].price;
   const double c = swings[first + 3].price;
   const double d = swings[first + 4].price;
   double xa = 0.0;
   double b_retrace = 0.0;
   double c_extend = 0.0;
   double d_retrace = 0.0;
   double cd = 0.0;

   if(bullish)
     {
      if(!(a > x && b > x && b < a && c > a && d > x && d < c))
         return false;
      xa = a - x;
      b_retrace = (a - b) / xa;
      c_extend = (c - x) / xa;
      d_retrace = (c - d) / (c - x);
      cd = c - d;
     }
   else
     {
      if(!(a < x && b < x && b > a && c < a && d < x && d > c))
         return false;
      xa = x - a;
      b_retrace = (b - a) / xa;
      c_extend = (x - c) / xa;
      d_retrace = (d - c) / (x - c);
      cd = d - c;
     }

   if(xa <= 0.0 || cd <= 0.0)
      return false;
   if(b_retrace < CYPHER_B_MIN || b_retrace > CYPHER_B_MAX)
      return false;
   if(c_extend < CYPHER_C_MIN || c_extend > CYPHER_C_MAX)
      return false;
   if(MathAbs(d_retrace - CYPHER_D_RETRACE) > strategy_d_tolerance)
      return false;

   const double buffer = QM_StopRulesPipsToPriceDistance(_Symbol, CYPHER_STOP_BUFFER_PIPS);
   if(buffer <= 0.0)
      return false;

   pattern.bullish = bullish;
   pattern.entry = QM_StopRulesNormalizePrice(_Symbol, d);
   if(bullish)
     {
      pattern.sl = QM_StopRulesNormalizePrice(_Symbol, x - buffer);
      pattern.tp1 = QM_StopRulesNormalizePrice(_Symbol, d + cd * CYPHER_TP1_RETRACE);
      pattern.tp2 = QM_StopRulesNormalizePrice(_Symbol, d + cd * CYPHER_TP2_RETRACE);
      if(!(pattern.sl < pattern.entry && pattern.tp1 > pattern.entry && pattern.tp2 > pattern.tp1))
         return false;
     }
   else
     {
      pattern.sl = QM_StopRulesNormalizePrice(_Symbol, x + buffer);
      pattern.tp1 = QM_StopRulesNormalizePrice(_Symbol, d - cd * CYPHER_TP1_RETRACE);
      pattern.tp2 = QM_StopRulesNormalizePrice(_Symbol, d - cd * CYPHER_TP2_RETRACE);
      if(!(pattern.sl > pattern.entry && pattern.tp1 < pattern.entry && pattern.tp2 < pattern.tp1))
         return false;
     }

   pattern.signature = StringFormat("%d|%.8f|%.8f|%.8f|%.8f|%.8f",
                                    bullish ? 1 : -1, x, a, b, c, d);
   return true;
  }

bool CypherFindPattern(CypherPattern &pattern)
  {
   CypherSwing swings[CYPHER_MAX_SWINGS];
   const int count = CypherCollectSwings(swings);
   return CypherValidateLatest(swings, count, pattern);
  }

bool CypherHasOurPendingOrder()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;

      const ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(order_type == ORDER_TYPE_BUY_LIMIT || order_type == ORDER_TYPE_SELL_LIMIT)
         return true;
     }

   return false;
  }

bool CypherLimitIsTradeable(const CypherPattern &pattern)
  {
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return false;

   if(pattern.bullish)
      return (pattern.entry < ask);
   return (pattern.entry > bid);
  }

int CypherPendingExpirationSeconds()
  {
   int bars = strategy_pending_expiry_bars;
   if(bars < 1)
      bars = 1;
   if(bars > 48)
      bars = 48;

   int seconds = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   if(seconds <= 0)
      seconds = 3600;
   return bars * seconds;
  }

bool CypherPartialAlreadyHandled(const bool is_buy,
                                 const double open_price,
                                 const double current_sl,
                                 const double point)
  {
   if(current_sl <= 0.0 || point <= 0.0)
      return false;
   if(is_buy)
      return (current_sl >= open_price - point * 0.5);
   return (current_sl <= open_price + point * 0.5);
  }

void CypherManageOnePosition(const ulong ticket)
  {
   if(!PositionSelectByTicket(ticket))
      return;
   if(PositionGetString(POSITION_SYMBOL) != _Symbol)
      return;
   if((int)PositionGetInteger(POSITION_MAGIC) != QM_FrameworkMagic())
      return;

   const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   const bool is_buy = (pos_type == POSITION_TYPE_BUY);
   const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   const double current_sl = PositionGetDouble(POSITION_SL);
   const double current_tp = PositionGetDouble(POSITION_TP);
   const double volume = PositionGetDouble(POSITION_VOLUME);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(open_price <= 0.0 || current_tp <= 0.0 || volume <= 0.0 || point <= 0.0)
      return;

   if(CypherPartialAlreadyHandled(is_buy, open_price, current_sl, point))
      return;

   const double tp2_distance = MathAbs(current_tp - open_price);
   if(tp2_distance <= 0.0)
      return;

   const double tp1_distance = tp2_distance * (CYPHER_TP1_RETRACE / CYPHER_TP2_RETRACE);
   const double tp1 = is_buy ? (open_price + tp1_distance) : (open_price - tp1_distance);
   const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(market <= 0.0)
      return;

   const bool hit_tp1 = is_buy ? (market >= tp1) : (market <= tp1);
   if(!hit_tp1)
      return;

   const double be = QM_TM_NormalizePrice(_Symbol, open_price);
   if(be <= 0.0)
      return;
   if(!QM_TM_MoveSL(ticket, be, "cypher_tp1_move_to_be"))
      return;

   double close_pct = strategy_partial_close_pct;
   if(close_pct <= 0.0)
      return;
   if(close_pct > 90.0)
      close_pct = 90.0;

   const double close_lots = QM_TM_NormalizeVolume(_Symbol, volume * close_pct / 100.0);
   const double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   if(close_lots <= 0.0 || min_lot <= 0.0)
      return;
   if(close_lots >= volume - min_lot * 0.5)
      return;

   QM_TM_PartialClose(ticket, close_lots, QM_EXIT_PARTIAL);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // Card has no session regime filter. News, Friday close, and kill-switch
   // are handled by the framework before this strategy hook.
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return true;
   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_d_tolerance <= 0.0 || strategy_d_tolerance > 0.10)
      return false;
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;
   if(CypherHasOurPendingOrder())
      return false;

   CypherPattern pattern;
   if(!CypherFindPattern(pattern))
      return false;
   if(pattern.signature == g_submitted_pattern_signature)
      return false;
   if(!CypherLimitIsTradeable(pattern))
      return false;

   req.type = pattern.bullish ? QM_BUY_LIMIT : QM_SELL_LIMIT;
   req.price = pattern.entry;
   req.sl = pattern.sl;
   req.tp = pattern.tp2;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = CypherPendingExpirationSeconds();
   req.reason = pattern.bullish ? "cypher_bullish_limit" : "cypher_bearish_limit";
   g_submitted_pattern_signature = pattern.signature;
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      CypherManageOnePosition(ticket);
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   // Card exits through geometry SL, TP1 partial/BE management, TP2, and framework Friday close.
   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(broker_time <= 0)
      return false;
   return false; // defer to the framework two-axis news filter.
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
