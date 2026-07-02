#ifndef QM_BASKET_EQUITY_STOP_MQH
#define QM_BASKET_EQUITY_STOP_MQH

struct QM_BasketEquityDecision
  {
   bool should_stop;
   bool should_take_profit;
   double stop_threshold;
   double take_threshold;
  };

void QM_BasketEquityStop_ResetDecision(QM_BasketEquityDecision &decision)
  {
   decision.should_stop = false;
   decision.should_take_profit = false;
   decision.stop_threshold = 0.0;
   decision.take_threshold = 0.0;
  }

bool QM_BasketEquityStop_Evaluate(const double floating_pnl,
                                  const double equity,
                                  const double stop_pct,
                                  const double take_profit_pct,
                                  QM_BasketEquityDecision &decision)
  {
   QM_BasketEquityStop_ResetDecision(decision);
   if(equity <= 0.0)
      return false;

   if(stop_pct > 0.0)
     {
      decision.stop_threshold = -equity * stop_pct / 100.0;
      decision.should_stop = (floating_pnl <= decision.stop_threshold);
     }

   if(take_profit_pct > 0.0)
     {
      decision.take_threshold = equity * take_profit_pct / 100.0;
      decision.should_take_profit = (floating_pnl >= decision.take_threshold);
     }

   return true;
  }

bool QM_BasketEquityStop_HasOwnedPositions()
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      const long magic = PositionGetInteger(POSITION_MAGIC);
      const string symbol = PositionGetString(POSITION_SYMBOL);
      if(QM_FrameworkOwnsMagicSymbol(magic, symbol))
         return true;
     }
   return false;
  }

double QM_BasketEquityStop_FloatingPnL()
  {
   double pnl = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      const long magic = PositionGetInteger(POSITION_MAGIC);
      const string symbol = PositionGetString(POSITION_SYMBOL);
      if(!QM_FrameworkOwnsMagicSymbol(magic, symbol))
         continue;
      pnl += PositionGetDouble(POSITION_PROFIT);
      pnl += PositionGetDouble(POSITION_SWAP);
     }
   return pnl;
  }

double QM_BasketEquityStop_OpenLots()
  {
   double lots = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      const long magic = PositionGetInteger(POSITION_MAGIC);
      const string symbol = PositionGetString(POSITION_SYMBOL);
      if(!QM_FrameworkOwnsMagicSymbol(magic, symbol))
         continue;
      lots += PositionGetDouble(POSITION_VOLUME);
     }
   return lots;
  }

int QM_BasketEquityStop_CloseAllOwned(const QM_ExitReason reason)
  {
   int closed = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      const long magic = PositionGetInteger(POSITION_MAGIC);
      const string symbol = PositionGetString(POSITION_SYMBOL);
      if(!QM_FrameworkOwnsMagicSymbol(magic, symbol))
         continue;
      if(QM_TM_ClosePosition(ticket, reason))
         ++closed;
     }
   return closed;
  }

int QM_BasketEquityStop_Enforce(const double stop_pct,
                                const double take_profit_pct,
                                QM_ExitReason &out_reason,
                                double &out_pnl,
                                double &out_threshold)
  {
   out_reason = QM_EXIT_STRATEGY;
   out_pnl = 0.0;
   out_threshold = 0.0;
   if(!QM_BasketEquityStop_HasOwnedPositions())
      return 0;

   const double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   out_pnl = QM_BasketEquityStop_FloatingPnL();
   QM_BasketEquityDecision decision;
   if(!QM_BasketEquityStop_Evaluate(out_pnl, equity, stop_pct, take_profit_pct, decision))
      return 0;

   if(decision.should_stop)
     {
      out_reason = QM_EXIT_KILLSWITCH;
      out_threshold = decision.stop_threshold;
      return QM_BasketEquityStop_CloseAllOwned(out_reason);
     }

   if(decision.should_take_profit)
     {
      out_reason = QM_EXIT_TP_HIT;
      out_threshold = decision.take_threshold;
      return QM_BasketEquityStop_CloseAllOwned(out_reason);
     }

   return 0;
  }

int QM_BasketEquityStop_EnforceUnitsPerLot(const double stop_pct,
                                           const double take_profit_units_per_lot,
                                           QM_ExitReason &out_reason,
                                           double &out_pnl,
                                           double &out_threshold,
                                           double &out_lots)
  {
   out_reason = QM_EXIT_STRATEGY;
   out_pnl = 0.0;
   out_threshold = 0.0;
   out_lots = 0.0;
   if(!QM_BasketEquityStop_HasOwnedPositions())
      return 0;

   const double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   out_pnl = QM_BasketEquityStop_FloatingPnL();
   out_lots = QM_BasketEquityStop_OpenLots();
   QM_BasketEquityDecision decision;
   QM_BasketEquityStop_ResetDecision(decision);

   if(equity > 0.0 && stop_pct > 0.0)
     {
      decision.stop_threshold = -equity * stop_pct / 100.0;
      decision.should_stop = (out_pnl <= decision.stop_threshold);
     }

   if(take_profit_units_per_lot > 0.0 && out_lots > 0.0)
     {
      decision.take_threshold = take_profit_units_per_lot * out_lots;
      decision.should_take_profit = (out_pnl >= decision.take_threshold);
     }

   if(decision.should_stop)
     {
      out_reason = QM_EXIT_KILLSWITCH;
      out_threshold = decision.stop_threshold;
      return QM_BasketEquityStop_CloseAllOwned(out_reason);
     }

   if(decision.should_take_profit)
     {
      out_reason = QM_EXIT_TP_HIT;
      out_threshold = decision.take_threshold;
      return QM_BasketEquityStop_CloseAllOwned(out_reason);
     }

   return 0;
  }

#endif // QM_BASKET_EQUITY_STOP_MQH
