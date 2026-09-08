#ifndef QM_CONSOLEDATA_SELFTESTS_MQH
#define QM_CONSOLEDATA_SELFTESTS_MQH

#include <QM/QM_ConsoleData.mqh>

// Deterministic no-trade fixtures. No account history is read or changed.
void QM_ConsoleFixtureDeal(QMPanelDeal &deals[],const ulong position_id,
                          const long magic,const datetime when,const ENUM_DEAL_ENTRY entry,
                          const double profit=0.0,const double commission=0.0,
                          const double swap=0.0,const double fee=0.0)
  {
   const int i=ArraySize(deals); ArrayResize(deals,i+1);
   deals[i].position_id=position_id; deals[i].magic=magic; deals[i].when=when;
   deals[i].entry=entry; deals[i].reason=DEAL_REASON_CLIENT;
   deals[i].profit=profit; deals[i].commission=commission;
   deals[i].swap=swap; deals[i].fee=fee;
  }

bool QM_ConsoleDataExpect(const bool condition,const string name,string &failure)
  {
   if(condition) return true;
   failure=name; return false;
  }

bool QM_ConsoleDataNear(const double actual,const double expected)
  { return MathAbs(actual-expected)<0.0000001; }

bool QM_ConsoleDataSelfTest(string &failure)
  {
   failure="";
   const long magic=114210000;
   const datetime now=D'2026.09.07 12:00:00'; // Monday, broker time.
   QMPanelDeal deals[]; ulong open_ids[]; QMPanelPerformance stats;
   if(!QM_ConsoleDataExpect(QM_PanelAggregatePerformance(deals,open_ids,magic,now,now,100000.0,stats) &&
      stats.valid && stats.closed_total==0 && stats.today_net==0.0 &&
      QM_PanelProfitFactorText(stats)=="N/A" && QM_PanelWinRateText(stats)=="N/A",
      "empty_history_has_no_statistical_sample",failure)) return false;

   // Put the foreign exit before its entry in the fixture: ownership is a
   // separate pass and is not dependent on fixture traversal order.
   QM_ConsoleFixtureDeal(deals,1,0,D'2026.09.07 09:00:00',DEAL_ENTRY_OUT,100.0,-2.0,-3.0,-1.0);
   QM_ConsoleFixtureDeal(deals,1,magic,D'2026.09.04 18:00:00',DEAL_ENTRY_IN,0.0,-2.0,0.0,-1.0);
   // A foreign entry closed by this magic is NOT this EA's position.
   QM_ConsoleFixtureDeal(deals,2,777,D'2026.09.07 08:00:00',DEAL_ENTRY_IN,0.0,-1.0);
   QM_ConsoleFixtureDeal(deals,2,magic,D'2026.09.07 10:00:00',DEAL_ENTRY_OUT,1000.0,-1.0);
   if(!QM_ConsoleDataExpect(QM_PanelAggregatePerformance(deals,open_ids,magic,now,
      D'2026.09.07 10:00:00',100000.0,stats) && stats.closed_total==1 &&
      stats.closed_today==1 && stats.closed_week==1 && stats.closed_since_attach==0 &&
      QM_ConsoleDataNear(stats.net_profit,91.0) && QM_ConsoleDataNear(stats.today_net,94.0) &&
      QM_ConsoleDataNear(stats.week_net,94.0) && QM_ConsoleDataNear(stats.today_gross,100.0) &&
      QM_ConsoleDataNear(stats.week_gross,100.0) && QM_PanelProfitFactorText(stats)=="INF",
      "entry_ownership_foreign_exit_and_deal_time_costs",failure)) return false;

   ArrayResize(deals,0); ArrayResize(open_ids,1); open_ids[0]=3;
   QM_ConsoleFixtureDeal(deals,3,magic,D'2026.09.06 22:00:00',DEAL_ENTRY_IN,0.0,-2.0);
   QM_ConsoleFixtureDeal(deals,3,0,D'2026.09.07 09:00:00',DEAL_ENTRY_OUT,40.0,-1.0);
   if(!QM_ConsoleDataExpect(QM_PanelAggregatePerformance(deals,open_ids,magic,now,now,100000.0,stats) &&
      stats.closed_total==0 && stats.closed_today==0 && QM_ConsoleDataNear(stats.today_net,39.0) &&
      stats.net_profit==0.0 && stats.max_drawdown_money==0.0 && QM_PanelProfitFactorText(stats)=="N/A",
      "partial_exit_cashflow_without_closed_position",failure)) return false;
   ArrayResize(open_ids,0);
   QM_ConsoleFixtureDeal(deals,3,555,D'2026.09.07 11:00:00',DEAL_ENTRY_OUT_BY,60.0,-1.0);
   if(!QM_ConsoleDataExpect(QM_PanelAggregatePerformance(deals,open_ids,magic,now,
      D'2026.09.07 10:00:00',100000.0,stats) && stats.closed_total==1 &&
      stats.closed_since_attach==1 && QM_ConsoleDataNear(stats.net_profit,96.0) &&
      QM_ConsoleDataNear(stats.today_net,98.0) && QM_ConsoleDataNear(stats.week_net,98.0),
      "final_exit_counts_once_and_keeps_entry_cost",failure)) return false;

   ArrayResize(deals,0); ArrayResize(open_ids,1); open_ids[0]=4;
   QM_ConsoleFixtureDeal(deals,4,magic,D'2026.09.07 11:00:00',DEAL_ENTRY_IN,0.0,-2.0,0.0,-0.5);
   if(!QM_ConsoleDataExpect(QM_PanelAggregatePerformance(deals,open_ids,magic,now,now,100000.0,stats) &&
      stats.closed_total==0 && QM_ConsoleDataNear(stats.today_net,-2.5) && stats.today_gross==0.0,
      "entry_cost_today_with_zero_closed_positions",failure)) return false;

   ArrayResize(deals,0); ArrayResize(open_ids,0);
   QM_ConsoleFixtureDeal(deals,101,magic,D'2026.09.07 08:00:00',DEAL_ENTRY_IN);
   QM_ConsoleFixtureDeal(deals,103,magic,D'2026.09.07 08:00:00',DEAL_ENTRY_IN);
   QM_ConsoleFixtureDeal(deals,102,magic,D'2026.09.07 08:00:00',DEAL_ENTRY_IN);
   QM_ConsoleFixtureDeal(deals,103,0,D'2026.09.07 12:00:00',DEAL_ENTRY_OUT,-60.0);
   QM_ConsoleFixtureDeal(deals,101,0,D'2026.09.07 10:00:00',DEAL_ENTRY_OUT,100.0);
   QM_ConsoleFixtureDeal(deals,102,0,D'2026.09.07 11:00:00',DEAL_ENTRY_OUT,-50.0);
   if(!QM_ConsoleDataExpect(QM_PanelAggregatePerformance(deals,open_ids,magic,now,now,1000.0,stats) &&
      stats.closed_total==3 && stats.wins==1 && stats.losses==2 &&
      stats.current_loss_streak==2 && stats.longest_loss_streak==2 &&
      QM_ConsoleDataNear(stats.net_profit,-10.0) && QM_ConsoleDataNear(stats.max_drawdown_money,110.0) &&
      QM_ConsoleDataNear(stats.max_drawdown_percent,11.0) && QM_ConsoleDataNear(stats.last_trade,-60.0),
      "closed_curve_chronology_drawdown_and_streaks",failure)) return false;

   ArrayResize(deals,0);
   QM_ConsoleFixtureDeal(deals,5,magic,D'2026.09.07 08:00:00',DEAL_ENTRY_IN);
   QM_ConsoleFixtureDeal(deals,5,0,D'2026.09.07 10:00:00',DEAL_ENTRY_OUT,-20.0);
   if(!QM_ConsoleDataExpect(QM_PanelAggregatePerformance(deals,open_ids,magic,now,now,0.0,stats) &&
      stats.wins==0 && stats.losses==1 && !stats.profit_factor_infinite && stats.profit_factor==0.0 &&
      QM_ConsoleDataNear(stats.average_loss,-20.0),"losses_only_is_real_zero_profit_factor",failure)) return false;
   deals[1].profit=0.0;
   if(!QM_ConsoleDataExpect(QM_PanelAggregatePerformance(deals,open_ids,magic,now,now,100000.0,stats) &&
      stats.closed_total==1 && stats.wins==0 && stats.losses==0 && stats.expectancy==0.0 &&
      QM_PanelProfitFactorText(stats)=="N/A","break_even_is_a_trade_but_no_profit_factor",failure)) return false;

   ArrayResize(deals,0);
   QM_ConsoleFixtureDeal(deals,6,magic,D'2026.09.07 08:00:00',DEAL_ENTRY_IN);
   QM_ConsoleFixtureDeal(deals,6,777,D'2026.09.07 09:00:00',DEAL_ENTRY_IN);
   QM_ConsoleFixtureDeal(deals,6,0,D'2026.09.07 10:00:00',DEAL_ENTRY_OUT,200.0);
   if(!QM_ConsoleDataExpect(!QM_PanelAggregatePerformance(deals,open_ids,magic,now,now,100000.0,stats) &&
      !stats.valid && stats.error=="N/A (mixed-magic netting history)" && stats.closed_total==0,
      "mixed_entry_magic_cannot_be_attributed",failure)) return false;

   ArrayResize(deals,0);
   QM_ConsoleFixtureDeal(deals,7,magic,D'2026.08.31 08:00:00',DEAL_ENTRY_IN,0.0,-1.0);
   QM_ConsoleFixtureDeal(deals,7,0,D'2026.09.06 10:00:00',DEAL_ENTRY_OUT,20.0,-1.0);
   // Future data is ignored even in synthetic snapshots.
   QM_ConsoleFixtureDeal(deals,8,magic,D'2026.09.07 08:00:00',DEAL_ENTRY_IN);
   QM_ConsoleFixtureDeal(deals,8,0,D'2026.09.07 10:00:00',DEAL_ENTRY_OUT,1000.0);
   if(!QM_ConsoleDataExpect(QM_PanelAggregatePerformance(deals,open_ids,magic,
      D'2026.09.06 12:00:00',D'2026.09.06 00:00:00',100000.0,stats) &&
      stats.closed_total==1 && stats.closed_week==1 && QM_ConsoleDataNear(stats.week_net,18.0) &&
      QM_ConsoleDataNear(stats.today_net,19.0),"sunday_week_starts_previous_monday",failure)) return false;
   if(!QM_ConsoleDataExpect(!QM_PanelAggregatePerformance(deals,open_ids,magic,0,0,100000.0,stats) &&
      !stats.valid,"missing_broker_clock_is_unavailable",failure)) return false;

   return true;
  }

#endif
