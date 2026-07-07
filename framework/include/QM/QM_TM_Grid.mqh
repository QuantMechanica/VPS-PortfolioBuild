#ifndef QM_TM_GRID_MQH
#define QM_TM_GRID_MQH

// V5 Framework — Bounded grid-trading manager.
//
// Created 2026-05-23 (FW7, pipeline rewrite) after the R4 update that
// permits grid trading provided it is deterministic and bounded.
//
// What's allowed (per Hard Rule 14 amendment 2026-05-23, see
// `processes/qb_reputable_source_criteria.md`):
//   - Grid levels at code-determined fixed distances
//   - Lot sizes from a code-determined formula (linear, geometric capped,
//     constant) — NEVER unbounded martingale
//   - Maximum simultaneous open positions per magic, bounded at compile
//     time via the SizingMode + MaxLevels caps below
//   - Worst-case drawdown explicitly capped via QM_GridMaxDrawdownGuard
//
// What's rejected at OnInit (returns false / sets QM_LogFatal):
//   - GeoMultiplier > QM_GRID_GEO_MULT_HARD_CAP (default 1.5)
//   - MaxLevels > QM_GRID_LEVELS_HARD_CAP (default 10)
//   - Per-cycle worst-case loss (computed from formula + levels + distance)
//     exceeding `worst_case_loss_cap_pct` of starting equity
//
// What it does NOT do:
//   - Magic-number arithmetic (uses the EA's existing magic via QM_FrameworkMagic)
//   - News / kill-switch / risk-mode checks (those run at the QM_Entry boundary)
//   - Open-position-per-magic enforcement (grid intentionally opens N — bypasses
//     QM_ENTRY_REJECTED_DUPLICATE via its own dedicated path)

#include "QM_Errors.mqh"
#include "QM_Logger.mqh"
#include "QM_TradeContext.mqh"
#include "QM_OrderTypes.mqh"
#include "QM_RiskSizer.mqh"
#include "QM_MagicResolver.mqh"
#include "QM_StopRules.mqh"

#define QM_GRID_GEO_MULT_HARD_CAP   1.5    // geometric grid: no slot > 1.5× prior
#define QM_GRID_LEVELS_HARD_CAP     10     // max simultaneous open grid orders

enum QM_GridSizingMode
  {
   QM_GRID_LOT_CONSTANT = 0,    // every level: same lot
   QM_GRID_LOT_LINEAR,          // lot[k] = lot[0] + (k * step)
   QM_GRID_LOT_GEOMETRIC        // lot[k] = lot[0] * multiplier^k  (multiplier capped)
  };

struct QM_GridConfig
  {
   string             symbol;
   int                magic;
   QM_OrderType       direction;            // BUY or SELL grid
   double             base_lot;
   QM_GridSizingMode  sizing_mode;
   double             linear_step;          // for LINEAR
   double             geo_multiplier;       // for GEOMETRIC, capped at HARD_CAP
   int                max_levels;
   int                level_distance_pips;
   double             worst_case_loss_cap_pct;   // ≤ this share of starting equity
   double             starting_equity_snapshot;
  };

struct QM_GridState
  {
   bool               initialized;
   QM_GridConfig      cfg;
   ulong              level_tickets[];      // populated as levels open
   double             level_entry_prices[];
   double             level_lots[];
   int                level_count;
   double             reference_price;      // anchor for level computation
   double             worst_case_loss_money;
  };

QM_GridState g_qm_grid_state;

// Hardening 2026-07-07 (audit F7): quantize to the symbol's volume step and
// clamp to min/max. The prior NormalizeDouble(lot,2) rejected on symbols with
// step 0.1/1.0 (indices/CFDs) with INVALID_VOLUME and could round half-up past
// the intended lot. Floor to step (never exceed the risk-sized lot).
double QM_GridNormalizeVolume(const string symbol, const double lot)
  {
   const double step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   const double vmin = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   const double vmax = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   if(step <= 0.0)
      return 0.0;
   double v = MathFloor((lot + 1e-9) / step) * step;
   if(vmax > 0.0 && v > vmax)
      v = MathFloor(vmax / step) * step;
   if(v < vmin)
      return 0.0; // below min lot after flooring → cannot place this level
   // Normalize to the step's decimal precision to avoid float dust.
   int digits = 0;
   double probe = step;
   while(digits < 8 && MathAbs(probe - MathRound(probe)) > 1e-10)
     {
      probe *= 10.0;
      ++digits;
     }
   return NormalizeDouble(v, digits);
  }

double QM_GridLevelLot(const QM_GridConfig &cfg, const int level_idx)
  {
   if(level_idx < 0)
      return 0.0;
   switch(cfg.sizing_mode)
     {
      case QM_GRID_LOT_CONSTANT:
         return cfg.base_lot;
      case QM_GRID_LOT_LINEAR:
         return cfg.base_lot + (level_idx * cfg.linear_step);
      case QM_GRID_LOT_GEOMETRIC:
         return cfg.base_lot * MathPow(cfg.geo_multiplier, level_idx);
     }
   return 0.0;
  }

double QM_GridWorstCaseLossMoney(const QM_GridConfig &cfg)
  {
   // Worst case: price moves against every level by (level_distance_pips * max_levels).
   // Each level loses (lot_k * level_distance_pips * (max_levels - k)) approximated.
   // We use the symbol's tick value and pip-point conversion via QM_LotsForRisk's
   // companion lookup. Conservative upper-bound by summing lot[k] * (max_levels - k).
   const double point = SymbolInfoDouble(cfg.symbol, SYMBOL_POINT);
   const int    digits = (int)SymbolInfoInteger(cfg.symbol, SYMBOL_DIGITS);
   const double tick_value = SymbolInfoDouble(cfg.symbol, SYMBOL_TRADE_TICK_VALUE);
   const double tick_size  = SymbolInfoDouble(cfg.symbol, SYMBOL_TRADE_TICK_SIZE);
   if(point <= 0.0 || tick_value <= 0.0 || tick_size <= 0.0)
      return 0.0;

   const int pip_factor = (digits == 3 || digits == 5) ? 10 : 1;
   const double pip_distance = cfg.level_distance_pips * pip_factor * point;
   double total_loss = 0.0;
   for(int k = 0; k < cfg.max_levels; k++)
     {
      const double lot_k = QM_GridLevelLot(cfg, k);
      // levels still open after price walks past 'k' grid steps: max_levels - k
      const double price_move = pip_distance * (cfg.max_levels - k);
      const double money_per_lot = (price_move / tick_size) * tick_value;
      total_loss += lot_k * money_per_lot;
     }
   return total_loss;
  }

bool QM_GridValidateConfig(const QM_GridConfig &cfg)
  {
   if(cfg.max_levels <= 0 || cfg.max_levels > QM_GRID_LEVELS_HARD_CAP)
     {
      QM_LogEvent(QM_FATAL, EA_GRID_RISK_EXCEEDED,
                  StringFormat("{\"reason\":\"max_levels_invalid\",\"max_levels\":%d,\"hard_cap\":%d}",
                               cfg.max_levels, QM_GRID_LEVELS_HARD_CAP));
      return false;
     }
   if(cfg.sizing_mode == QM_GRID_LOT_GEOMETRIC &&
      cfg.geo_multiplier > QM_GRID_GEO_MULT_HARD_CAP)
     {
      QM_LogEvent(QM_FATAL, EA_GRID_RISK_EXCEEDED,
                  StringFormat("{\"reason\":\"geo_multiplier_exceeds_cap\",\"multiplier\":%.4f,\"hard_cap\":%.4f}",
                               cfg.geo_multiplier, QM_GRID_GEO_MULT_HARD_CAP));
      return false;
     }
   if(cfg.base_lot <= 0.0)
     {
      QM_LogEvent(QM_FATAL, EA_GRID_RISK_EXCEEDED,
                  "{\"reason\":\"base_lot_non_positive\"}");
      return false;
     }
   if(cfg.level_distance_pips <= 0)
     {
      QM_LogEvent(QM_FATAL, EA_GRID_RISK_EXCEEDED,
                  "{\"reason\":\"level_distance_non_positive\"}");
      return false;
     }
   if(cfg.worst_case_loss_cap_pct <= 0.0 || cfg.worst_case_loss_cap_pct >= 100.0)
     {
      QM_LogEvent(QM_FATAL, EA_GRID_RISK_EXCEEDED,
                  StringFormat("{\"reason\":\"worst_case_loss_cap_pct_invalid\",\"value\":%.4f}",
                               cfg.worst_case_loss_cap_pct));
      return false;
     }

   const double worst = QM_GridWorstCaseLossMoney(cfg);
   // Hardening 2026-07-07 (audit F6): QM_GridWorstCaseLossMoney returns 0.0 when
   // the symbol's tick_value/tick_size/point read 0 (unselected symbol, custom-
   // symbol gap, market closed at init). Accepting worst=0 would pass the 1%
   // cap check unconditionally — the risk gate silently disabled exactly when
   // the data to prove it is missing. Fail closed: an uncomputable worst case
   // is not a safe one.
   if(worst <= 0.0)
     {
      QM_LogEvent(QM_FATAL, EA_GRID_RISK_EXCEEDED,
                  StringFormat("{\"reason\":\"worst_case_uncomputable_failclosed\",\"symbol\":\"%s\"}",
                               QM_LoggerEscapeJson(cfg.symbol)));
      return false;
     }
   const double cap_money = cfg.starting_equity_snapshot * (cfg.worst_case_loss_cap_pct / 100.0);
   if(worst > cap_money)
     {
      QM_LogEvent(QM_FATAL, EA_GRID_RISK_EXCEEDED,
                  StringFormat("{\"reason\":\"worst_case_exceeds_cap\",\"worst_money\":%.2f,\"cap_money\":%.2f,\"cap_pct\":%.4f}",
                               worst, cap_money, cfg.worst_case_loss_cap_pct));
      return false;
     }
   return true;
  }

// Hardening 2026-07-07 (audit B5): reconstruct level state from open positions
// carrying this grid's magic+symbol, so a mid-cycle reload does not leave the
// drawdown guard blind. Positions are sorted by open time so reference_price
// (the level-0 anchor) is the earliest fill, matching the live-open ordering.
void QM_GridRebuildFromOpenPositions()
  {
   const int cap = g_qm_grid_state.cfg.max_levels;
   ulong  found_tickets[];
   double found_prices[];
   double found_lots[];
   datetime found_times[];
   int n = 0;
   ArrayResize(found_tickets, cap);
   ArrayResize(found_prices, cap);
   ArrayResize(found_lots, cap);
   ArrayResize(found_times, cap);

   for(int i = PositionsTotal() - 1; i >= 0 && n < cap; i--)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != g_qm_grid_state.cfg.magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != g_qm_grid_state.cfg.symbol)
         continue;
      found_tickets[n] = ticket;
      found_prices[n]  = PositionGetDouble(POSITION_PRICE_OPEN);
      found_lots[n]    = PositionGetDouble(POSITION_VOLUME);
      found_times[n]   = (datetime)PositionGetInteger(POSITION_TIME);
      n++;
     }
   if(n == 0)
      return;

   // Insertion-sort by open time ascending (n <= 10, trivial cost).
   for(int a = 1; a < n; a++)
      for(int b = a; b > 0 && found_times[b] < found_times[b - 1]; b--)
        {
         datetime tt = found_times[b]; found_times[b] = found_times[b-1]; found_times[b-1] = tt;
         ulong tk = found_tickets[b]; found_tickets[b] = found_tickets[b-1]; found_tickets[b-1] = tk;
         double tp = found_prices[b]; found_prices[b] = found_prices[b-1]; found_prices[b-1] = tp;
         double tl = found_lots[b]; found_lots[b] = found_lots[b-1]; found_lots[b-1] = tl;
        }

   for(int k = 0; k < n; k++)
     {
      g_qm_grid_state.level_tickets[k]      = found_tickets[k];
      g_qm_grid_state.level_entry_prices[k] = found_prices[k];
      g_qm_grid_state.level_lots[k]         = found_lots[k];
     }
   g_qm_grid_state.level_count     = n;
   g_qm_grid_state.reference_price = found_prices[0];
   QM_LogEvent(QM_WARN, "GRID_STATE_REBUILT_FROM_POSITIONS",
               StringFormat("{\"levels_recovered\":%d,\"reference_price\":%.8f}",
                            n, found_prices[0]));
  }

bool QM_GridInit(const string symbol,
                 const int magic,
                 const QM_OrderType direction,
                 const double base_lot,
                 const QM_GridSizingMode sizing_mode,
                 const int level_distance_pips,
                 const int max_levels,
                 const double worst_case_loss_cap_pct = 1.0,
                 const double linear_step = 0.0,
                 const double geo_multiplier = 1.0)
  {
   g_qm_grid_state.initialized = false;
   g_qm_grid_state.cfg.symbol                  = symbol;
   g_qm_grid_state.cfg.magic                   = magic;
   g_qm_grid_state.cfg.direction               = direction;
   g_qm_grid_state.cfg.base_lot                = base_lot;
   g_qm_grid_state.cfg.sizing_mode             = sizing_mode;
   g_qm_grid_state.cfg.linear_step             = linear_step;
   g_qm_grid_state.cfg.geo_multiplier          = geo_multiplier;
   g_qm_grid_state.cfg.max_levels              = max_levels;
   g_qm_grid_state.cfg.level_distance_pips     = level_distance_pips;
   g_qm_grid_state.cfg.worst_case_loss_cap_pct = worst_case_loss_cap_pct;
   g_qm_grid_state.cfg.starting_equity_snapshot = AccountInfoDouble(ACCOUNT_EQUITY);

   if(!QM_GridValidateConfig(g_qm_grid_state.cfg))
      return false;

   ArrayResize(g_qm_grid_state.level_tickets, max_levels);
   ArrayResize(g_qm_grid_state.level_entry_prices, max_levels);
   ArrayResize(g_qm_grid_state.level_lots, max_levels);
   for(int i = 0; i < max_levels; i++)
     {
      g_qm_grid_state.level_tickets[i] = 0;
      g_qm_grid_state.level_entry_prices[i] = 0.0;
      g_qm_grid_state.level_lots[i] = 0.0;
     }
   g_qm_grid_state.level_count = 0;
   g_qm_grid_state.reference_price = 0.0;
   g_qm_grid_state.worst_case_loss_money = QM_GridWorstCaseLossMoney(g_qm_grid_state.cfg);
   g_qm_grid_state.initialized = true;

   // Hardening 2026-07-07 (audit B5): grid level state is in-memory only, so an
   // EA reload mid-cycle (recompile, terminal restart, watchdog reboot) would
   // otherwise start with level_count=0 while real positions ride open — the
   // max-drawdown guard blind from restart, the 1% cap unenforced. Rebuild the
   // level state from the broker's own open positions for this magic.
   QM_GridRebuildFromOpenPositions();

   QM_LogEvent(QM_INFO, "GRID_INIT",
               StringFormat("{\"symbol\":\"%s\",\"magic\":%d,\"max_levels\":%d,\"sizing\":%d,\"worst_case_money\":%.2f,\"cap_pct\":%.4f}",
                            QM_LoggerEscapeJson(symbol), magic, max_levels,
                            (int)sizing_mode, g_qm_grid_state.worst_case_loss_money,
                            worst_case_loss_cap_pct));
   return true;
  }

// Strategy calls this when the grid's "open the next level" condition is true.
// The framework places the order and tracks it in the level-state array.
bool QM_GridOpenNextLevel(double &out_ticket_double)
  {
   out_ticket_double = 0.0;
   if(!g_qm_grid_state.initialized)
      return false;
   if(g_qm_grid_state.level_count >= g_qm_grid_state.cfg.max_levels)
     {
      QM_LogEvent(QM_WARN, "GRID_MAX_LEVELS_REACHED",
                  StringFormat("{\"levels_open\":%d,\"max\":%d}",
                               g_qm_grid_state.level_count, g_qm_grid_state.cfg.max_levels));
      return false;
     }

   const QM_GridConfig cfg = g_qm_grid_state.cfg;
   const bool is_buy = QM_OrderTypeIsBuy(cfg.direction);
   const double entry = is_buy ? SymbolInfoDouble(cfg.symbol, SYMBOL_ASK)
                               : SymbolInfoDouble(cfg.symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double lot = QM_GridLevelLot(cfg, g_qm_grid_state.level_count);
   const double norm_lot = QM_GridNormalizeVolume(cfg.symbol, lot);
   if(norm_lot <= 0.0)
     {
      QM_LogEvent(QM_WARN, "GRID_LEVEL_VOLUME_INVALID",
                  StringFormat("{\"level\":%d,\"lot\":%.4f}", g_qm_grid_state.level_count, lot));
      return false;
     }

   MqlTradeRequest req;
   ZeroMemory(req);
   req.action  = TRADE_ACTION_DEAL;
   req.symbol  = cfg.symbol;
   req.magic   = cfg.magic;
   req.volume  = norm_lot;
   req.type    = QM_OrderTypeToMT5(cfg.direction);
   req.price   = NormalizeDouble(entry, (int)SymbolInfoInteger(cfg.symbol, SYMBOL_DIGITS));
   req.deviation = 20;
   req.type_filling = QM_TradeContextResolveFilling(cfg.symbol); // audit F3
   req.type_time = ORDER_TIME_GTC;
   req.comment = StringFormat("qm_grid_level_%d", g_qm_grid_state.level_count);

   MqlTradeResult res;
   string err_class = "";
   if(!QM_TradeContextSend(req, res, err_class))
     {
      QM_LogEvent(QM_WARN, "GRID_LEVEL_OPEN_FAILED",
                  StringFormat("{\"level\":%d,\"err\":\"%s\"}",
                               g_qm_grid_state.level_count, err_class));
      return false;
     }
   const ulong ticket = (res.order > 0) ? res.order : res.deal;
   const int slot = g_qm_grid_state.level_count;
   g_qm_grid_state.level_tickets[slot]      = ticket;
   g_qm_grid_state.level_entry_prices[slot] = req.price;
   g_qm_grid_state.level_lots[slot]         = req.volume;
   if(slot == 0)
      g_qm_grid_state.reference_price = req.price;
   g_qm_grid_state.level_count++;

   out_ticket_double = (double)ticket;
   QM_LogEvent(QM_INFO, "GRID_LEVEL_OPENED",
               StringFormat("{\"level\":%d,\"ticket\":%I64u,\"price\":%.8f,\"lot\":%.4f}",
                            slot, ticket, req.price, req.volume));
   return true;
  }

// Compute current aggregate floating P/L across all open grid levels.
double QM_GridAggregateFloatingPnL()
  {
   if(!g_qm_grid_state.initialized)
      return 0.0;
   double total = 0.0;
   for(int i = 0; i < g_qm_grid_state.level_count; i++)
     {
      const ulong ticket = g_qm_grid_state.level_tickets[i];
      if(ticket == 0)
         continue;
      if(!PositionSelectByTicket(ticket))
         continue;
      total += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
     }
   return total;
  }

// Guard that the strategy must call on every tick: if floating loss exceeds
// the worst-case cap, close all grid levels immediately.
bool QM_GridMaxDrawdownGuard()
  {
   if(!g_qm_grid_state.initialized)
      return false;
   const double floating = QM_GridAggregateFloatingPnL();
   const double cap_money = g_qm_grid_state.cfg.starting_equity_snapshot *
                            (g_qm_grid_state.cfg.worst_case_loss_cap_pct / 100.0);
   if(floating >= -cap_money)
      return false;

   QM_LogEvent(QM_FATAL, EA_GRID_RISK_EXCEEDED,
               StringFormat("{\"reason\":\"floating_loss_exceeds_cap\",\"floating\":%.2f,\"cap_money\":%.2f}",
                            floating, cap_money));

   // Close every open grid level. Hardening 2026-07-07 (audit F6): a failed
   // close previously still cleared level_count=0, orphaning a live position
   // that the guard could then never see again (aggregate-PnL blind, guard
   // cannot re-fire). Now: only untrack slots whose close SUCCEEDED; keep the
   // rest tracked so the next tick re-attempts the flatten. The whole grid is
   // considered cleared only when no tracked position remains.
   int still_open = 0;
   for(int i = 0; i < g_qm_grid_state.level_count; i++)
     {
      const ulong ticket = g_qm_grid_state.level_tickets[i];
      if(ticket == 0)
         continue;
      if(!PositionSelectByTicket(ticket))
        {
         g_qm_grid_state.level_tickets[i] = 0; // already gone (SL/TP/manual)
         continue;
        }
      MqlTradeRequest req;
      MqlTradeResult res;
      ZeroMemory(req);
      req.action = TRADE_ACTION_DEAL;
      req.symbol = g_qm_grid_state.cfg.symbol;
      req.magic  = g_qm_grid_state.cfg.magic;
      req.position = ticket;
      req.volume = PositionGetDouble(POSITION_VOLUME);
      req.type = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
                  ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
      req.price = (req.type == ORDER_TYPE_BUY)
                  ? SymbolInfoDouble(g_qm_grid_state.cfg.symbol, SYMBOL_ASK)
                  : SymbolInfoDouble(g_qm_grid_state.cfg.symbol, SYMBOL_BID);
      req.deviation = 20;
      req.type_filling = QM_TradeContextResolveFilling(g_qm_grid_state.cfg.symbol); // audit F3
      req.comment = "qm_grid_cap_breach";
      string err_class = "";
      if(QM_TradeContextSend(req, res, err_class))
         g_qm_grid_state.level_tickets[i] = 0; // confirmed closed → untrack
      else
        {
         still_open++;
         QM_LogEvent(QM_ERROR, "GRID_CAP_CLOSE_FAILED",
                     StringFormat("{\"level\":%d,\"ticket\":%I64u,\"err\":\"%s\"}",
                                  i, ticket, QM_LoggerEscapeJson(err_class)));
        }
     }
   if(still_open == 0)
      g_qm_grid_state.level_count = 0; // fully flat — safe to reset for a new cycle
   return true;
  }

int QM_GridLevelCount()
  {
   return g_qm_grid_state.initialized ? g_qm_grid_state.level_count : 0;
  }

double QM_GridWorstCaseLossMoneyCached()
  {
   return g_qm_grid_state.initialized ? g_qm_grid_state.worst_case_loss_money : 0.0;
  }

#endif // QM_TM_GRID_MQH
