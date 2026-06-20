#property strict
#property version   "5.0"
#property description "QM5_9243 MQL5 A-Star Swing Path"

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
input int    qm_ea_id                   = 9243;
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
input int    strategy_swing_lookback       = 5;
input int    strategy_max_nodes            = 100;
input int    strategy_min_swing_bars       = 3;
input int    strategy_atr_period           = 14;
input double strategy_spread_penalty       = 1.5;
input double strategy_noise_penalty        = 0.5;
input double strategy_max_path_cost_atr    = 5.0;
input double strategy_min_direction_ratio  = 0.55;
input double strategy_stop_atr_buffer_mult = 0.5;
input int    strategy_max_hold_bars        = 72;
input int    strategy_max_spread_points    = 40;
input int    strategy_scan_bars            = 260;

struct StrategyPathNode
  {
   int    bar_index;
   double price;
   bool   is_high;
   double atr;
  };

struct StrategyPathResult
  {
   bool   qualified;
   int    direction;
   double target;
   double stop_reference;
   double cost_atr;
   double direction_ratio;
  };

int g_strategy_last_signal = 0;

void Strategy_ResetPathResult(StrategyPathResult &result)
  {
   result.qualified = false;
   result.direction = 0;
   result.target = 0.0;
   result.stop_reference = 0.0;
   result.cost_atr = 0.0;
   result.direction_ratio = 0.0;
  }

void Strategy_AddNode(StrategyPathNode &nodes[], StrategyPathNode &node)
  {
   const int n = ArraySize(nodes);
   ArrayResize(nodes, n + 1);
   nodes[n] = node;
  }

bool Strategy_ReadRates(const int bars, MqlRates &rates[])
  {
   if(bars < 32)
      return false;

   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_CURRENT, 0, bars, rates); // perf-allowed: bounded structural swing graph, called only from Strategy_EntrySignal after framework new-bar gate.
   return (copied >= bars);
  }

bool Strategy_IsValidSwingHigh(MqlRates &rates[], const int copied, const int shift)
  {
   const double high = rates[shift].high;
   if(high <= 0.0)
      return false;

   for(int j = 1; j <= strategy_swing_lookback; ++j)
     {
      if(shift - j < 1 || shift + j >= copied)
         return false;
      if(high <= rates[shift - j].high || high <= rates[shift + j].high)
         return false;
     }

   for(int newer = shift - 1; newer >= 1; --newer)
     {
      if(rates[newer].close > high)
         return false;
     }

   return true;
  }

bool Strategy_IsValidSwingLow(MqlRates &rates[], const int copied, const int shift)
  {
   const double low = rates[shift].low;
   if(low <= 0.0)
      return false;

   for(int j = 1; j <= strategy_swing_lookback; ++j)
     {
      if(shift - j < 1 || shift + j >= copied)
         return false;
      if(low >= rates[shift - j].low || low >= rates[shift + j].low)
         return false;
     }

   for(int newer = shift - 1; newer >= 1; --newer)
     {
      if(rates[newer].close < low)
         return false;
     }

   return true;
  }

void Strategy_DetectSwingNodes(MqlRates &rates[], const int copied, StrategyPathNode &nodes[])
  {
   ArrayResize(nodes, 0);
   const int min_shift = strategy_swing_lookback + 1;
   const int max_shift = copied - strategy_swing_lookback - 1;
   if(min_shift > max_shift)
      return;

   int last_added_shift = -1000000;
   for(int shift = max_shift; shift >= min_shift; --shift)
     {
      if(ArraySize(nodes) >= strategy_max_nodes)
         return;

      if(last_added_shift > 0 && MathAbs(last_added_shift - shift) < strategy_min_swing_bars)
         continue;

      const bool is_high = Strategy_IsValidSwingHigh(rates, copied, shift);
      const bool is_low = Strategy_IsValidSwingLow(rates, copied, shift);
      if(is_high == is_low)
         continue;

      StrategyPathNode node;
      node.bar_index = shift;
      node.is_high = is_high;
      node.price = is_high ? rates[shift].high : rates[shift].low;
      node.atr = QM_ATR(_Symbol, PERIOD_CURRENT, strategy_atr_period, shift);
      if(node.price <= 0.0 || node.atr <= 0.0)
         continue;

      Strategy_AddNode(nodes, node);
      last_added_shift = shift;
     }
  }

double Strategy_CurrentPrice()
  {
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid > 0.0 && ask > 0.0)
      return (bid + ask) * 0.5;
   if(bid > 0.0)
      return bid;
   return ask;
  }

int Strategy_NearestNode(StrategyPathNode &nodes[], const double price)
  {
   int best = -1;
   double best_dist = DBL_MAX;
   for(int i = 0; i < ArraySize(nodes); ++i)
     {
      const double dist = MathAbs(nodes[i].price - price);
      if(dist < best_dist)
        {
         best = i;
         best_dist = dist;
        }
     }
   return best;
  }

int Strategy_TargetNode(StrategyPathNode &nodes[], const int direction, const double current_price)
  {
   int best = -1;
   double best_dist = DBL_MAX;
   for(int i = 0; i < ArraySize(nodes); ++i)
     {
      if(direction > 0)
        {
         if(!nodes[i].is_high || nodes[i].price <= current_price)
            continue;
        }
      else
        {
         if(nodes[i].is_high || nodes[i].price >= current_price)
            continue;
        }

      const double dist = MathAbs(nodes[i].price - current_price);
      if(dist < best_dist)
        {
         best = i;
         best_dist = dist;
        }
     }
   return best;
  }

double Strategy_SpreadPenalty()
  {
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(bid <= 0.0 || ask <= 0.0 || point <= 0.0 || ask <= bid)
      return 0.0;

   const double spread_points = (ask - bid) / point;
   if(strategy_max_spread_points <= 0)
      return strategy_spread_penalty;
   return strategy_spread_penalty * MathMin(1.0, spread_points / (double)strategy_max_spread_points);
  }

double Strategy_EdgeCost(StrategyPathNode &nodes[], const int from_idx, const int to_idx)
  {
   double atr = (nodes[from_idx].atr + nodes[to_idx].atr) * 0.5;
   if(atr <= 0.0)
      atr = QM_ATR(_Symbol, PERIOD_CURRENT, strategy_atr_period, 1);
   if(atr <= 0.0)
      return DBL_MAX;

   double cost = MathAbs(nodes[to_idx].price - nodes[from_idx].price) / atr;
   cost += Strategy_SpreadPenalty();
   if(nodes[to_idx].is_high == nodes[from_idx].is_high)
      cost += strategy_noise_penalty;
   return cost;
  }

bool Strategy_AStar(StrategyPathNode &nodes[],
                    const int start_idx,
                    const int target_idx,
                    int &came_from[],
                    double &out_cost)
  {
   const int n = ArraySize(nodes);
   out_cost = 0.0;
   if(start_idx < 0 || target_idx < 0 || start_idx >= n || target_idx >= n || start_idx == target_idx)
      return false;

   double g_score[];
   double f_score[];
   bool open_set[];
   bool closed_set[];
   ArrayResize(g_score, n);
   ArrayResize(f_score, n);
   ArrayResize(open_set, n);
   ArrayResize(closed_set, n);
   ArrayResize(came_from, n);

   for(int i = 0; i < n; ++i)
     {
      g_score[i] = DBL_MAX;
      f_score[i] = DBL_MAX;
      open_set[i] = false;
      closed_set[i] = false;
      came_from[i] = -1;
     }

   g_score[start_idx] = 0.0;
   f_score[start_idx] = MathAbs(nodes[start_idx].price - nodes[target_idx].price) / nodes[start_idx].atr;
   open_set[start_idx] = true;

   for(int guard = 0; guard < n * n; ++guard)
     {
      int current = -1;
      double best_f = DBL_MAX;
      for(int i = 0; i < n; ++i)
        {
         if(open_set[i] && f_score[i] < best_f)
           {
            current = i;
            best_f = f_score[i];
           }
        }

      if(current < 0)
         return false;
      if(current == target_idx)
        {
         out_cost = g_score[current];
         return true;
        }

      open_set[current] = false;
      closed_set[current] = true;

      for(int offset = -2; offset <= 2; ++offset)
        {
         if(offset == 0)
            continue;
         const int neighbor = current + offset;
         if(neighbor < 0 || neighbor >= n || closed_set[neighbor])
            continue;

         const double edge_cost = Strategy_EdgeCost(nodes, current, neighbor);
         if(edge_cost == DBL_MAX)
            continue;

         const double tentative = g_score[current] + edge_cost;
         if(!open_set[neighbor])
            open_set[neighbor] = true;
         else if(tentative >= g_score[neighbor])
            continue;

         came_from[neighbor] = current;
         g_score[neighbor] = tentative;
         f_score[neighbor] = tentative + MathAbs(nodes[neighbor].price - nodes[target_idx].price) / nodes[neighbor].atr;
        }
     }

   return false;
  }

bool Strategy_PathQuality(StrategyPathNode &nodes[],
                          int &came_from[],
                          const int start_idx,
                          const int target_idx,
                          const int direction,
                          double &out_ratio,
                          bool &out_blocked)
  {
   out_ratio = 0.0;
   out_blocked = false;
   int path[];
   ArrayResize(path, 0);

   int current = target_idx;
   for(int guard = 0; guard < ArraySize(nodes); ++guard)
     {
      const int n = ArraySize(path);
      ArrayResize(path, n + 1);
      path[n] = current;
      if(current == start_idx)
         break;
      current = came_from[current];
      if(current < 0)
         return false;
     }

   const int path_count = ArraySize(path);
   if(path_count < 2)
      return false;

   int favorable = 0;
   int total = 0;
   for(int i = path_count - 1; i > 0; --i)
     {
      const int from_idx = path[i];
      const int to_idx = path[i - 1];
      const double delta = nodes[to_idx].price - nodes[from_idx].price;
      if(direction > 0 && delta > 0.0)
         favorable++;
      if(direction < 0 && delta < 0.0)
         favorable++;

      const double atr = MathMax(nodes[from_idx].atr, nodes[to_idx].atr);
      if(atr > 0.0)
        {
         if(direction > 0 && delta < -atr)
            out_blocked = true;
         if(direction < 0 && delta > atr)
            out_blocked = true;
        }
      total++;
     }

   if(total <= 0)
      return false;
   out_ratio = (double)favorable / (double)total;
   return true;
  }

double Strategy_StopReference(StrategyPathNode &nodes[], const int direction, const double entry)
  {
   double reference = 0.0;
   for(int i = ArraySize(nodes) - 1; i >= 0; --i)
     {
      if(direction > 0 && !nodes[i].is_high && nodes[i].price < entry)
        {
         reference = nodes[i].price;
         break;
        }
      if(direction < 0 && nodes[i].is_high && nodes[i].price > entry)
        {
         reference = nodes[i].price;
         break;
        }
     }
   return reference;
  }

bool Strategy_EvaluateDirection(StrategyPathNode &nodes[],
                                const int direction,
                                const double current_price,
                                StrategyPathResult &result)
  {
   Strategy_ResetPathResult(result);
   const int start_idx = Strategy_NearestNode(nodes, current_price);
   const int target_idx = Strategy_TargetNode(nodes, direction, current_price);
   if(start_idx < 0 || target_idx < 0 || start_idx == target_idx)
      return false;

   int came_from[];
   double cost = 0.0;
   if(!Strategy_AStar(nodes, start_idx, target_idx, came_from, cost))
      return false;

   double ratio = 0.0;
   bool blocked = false;
   if(!Strategy_PathQuality(nodes, came_from, start_idx, target_idx, direction, ratio, blocked))
      return false;

   const double stop_reference = Strategy_StopReference(nodes, direction, current_price);
   if(stop_reference <= 0.0)
      return false;

   result.qualified = (ratio >= strategy_min_direction_ratio &&
                       cost <= strategy_max_path_cost_atr &&
                       !blocked);
   result.direction = direction;
   result.target = nodes[target_idx].price;
   result.stop_reference = stop_reference;
   result.cost_atr = cost;
   result.direction_ratio = ratio;
   return result.qualified;
  }

bool Strategy_GetOurPosition(ENUM_POSITION_TYPE &position_type, datetime &open_time)
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

      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(bid <= 0.0 || ask <= 0.0 || point <= 0.0)
      return true;
   if(ask > bid && strategy_max_spread_points > 0)
     {
      const double spread_points = (ask - bid) / point;
      if(spread_points > (double)strategy_max_spread_points)
         return true;
     }
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

   g_strategy_last_signal = 0;

   if(strategy_swing_lookback < 2 ||
      strategy_max_nodes < 8 ||
      strategy_min_swing_bars < 1 ||
      strategy_atr_period < 1 ||
      strategy_spread_penalty < 0.0 ||
      strategy_noise_penalty < 0.0 ||
      strategy_max_path_cost_atr <= 0.0 ||
      strategy_min_direction_ratio <= 0.0 ||
      strategy_stop_atr_buffer_mult <= 0.0 ||
      strategy_scan_bars < strategy_swing_lookback * 2 + 32)
      return false;

   MqlRates rates[];
   const int bars_to_read = MathMax(strategy_scan_bars, strategy_max_nodes + strategy_swing_lookback * 2 + 16);
   if(!Strategy_ReadRates(bars_to_read, rates))
      return false;

   StrategyPathNode nodes[];
   Strategy_DetectSwingNodes(rates, bars_to_read, nodes);
   if(ArraySize(nodes) < 4)
      return false;

   const double current_price = Strategy_CurrentPrice();
   if(current_price <= 0.0)
      return false;

   StrategyPathResult long_path;
   StrategyPathResult short_path;
   const bool has_long = Strategy_EvaluateDirection(nodes, 1, current_price, long_path);
   const bool has_short = Strategy_EvaluateDirection(nodes, -1, current_price, short_path);

   if(has_long == has_short)
      return false;

   StrategyPathResult selected;
   if(has_long)
      selected = long_path;
   else
      selected = short_path;

   g_strategy_last_signal = selected.direction;

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_CURRENT, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const QM_OrderType side = (selected.direction > 0) ? QM_BUY : QM_SELL;
   double stop = 0.0;
   if(selected.direction > 0)
      stop = QM_StopRulesNormalizePrice(_Symbol, selected.stop_reference - atr * strategy_stop_atr_buffer_mult);
   else
      stop = QM_StopRulesNormalizePrice(_Symbol, selected.stop_reference + atr * strategy_stop_atr_buffer_mult);

   if(stop <= 0.0)
      return false;
   if(side == QM_BUY && stop >= current_price)
      return false;
   if(side == QM_SELL && stop <= current_price)
      return false;

   const double target = QM_StopRulesNormalizePrice(_Symbol, selected.target);
   if(side == QM_BUY && target <= current_price)
      return false;
   if(side == QM_SELL && target >= current_price)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = stop;
   req.tp = target;
   req.reason = (side == QM_BUY) ? "ASTAR_SWING_LONG" : "ASTAR_SWING_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card does not specify trailing, break-even, or partial-close management.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   datetime open_time = 0;
   if(!Strategy_GetOurPosition(position_type, open_time))
      return false;

   const int period_seconds = PeriodSeconds(PERIOD_H1);
   if(strategy_max_hold_bars > 0 && period_seconds > 0 && open_time > 0)
     {
      if(TimeCurrent() - open_time >= strategy_max_hold_bars * period_seconds)
         return true;
     }

   if(g_strategy_last_signal > 0 && position_type == POSITION_TYPE_SELL)
      return true;
   if(g_strategy_last_signal < 0 && position_type == POSITION_TYPE_BUY)
      return true;

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade(...)
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
