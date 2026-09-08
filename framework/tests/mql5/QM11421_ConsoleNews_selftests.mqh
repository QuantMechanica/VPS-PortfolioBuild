#ifndef QM11421_CONSOLE_NEWS_SELFTESTS_MQH
#define QM11421_CONSOLE_NEWS_SELFTESTS_MQH

#include <QM/QM_ConsoleModel.mqh>

// The production helpers are extracted verbatim from EA11421 into the
// artifact-only no-trade harness. No EA OnInit/OnTick or news API is executed.
bool QM11421_NewsExpect(const bool condition,const string label,string &failure)
  {
   if(condition) return true;
   failure=label; return false;
  }

bool QM11421_ConsoleNewsSelfTest(string &failure)
  {
   failure=""; string reason="";
   const datetime now=D'2026.09.07 20:00:00';
   if(!QM11421_NewsExpect(QM11421_ConsoleNewsKeyMatches("EURUSD",now,3,2,"EURUSD",now,3,2),
      "complete_matching_cache_key",failure)) return false;
   if(!QM11421_NewsExpect(!QM11421_ConsoleNewsKeyMatches("EURUSD",now,3,2,"USDJPY",now,3,2),
      "foreign_symbol_key_rejected",failure)) return false;
   if(!QM11421_NewsExpect(!QM11421_ConsoleNewsKeyMatches("EURUSD",now,3,2,"EURUSD",now-86400,3,2),
      "old_bar_key_rejected",failure)) return false;
   if(!QM11421_NewsExpect(!QM11421_ConsoleNewsKeyMatches("EURUSD",0,3,2,"EURUSD",0,3,2),
      "missing_bar_key_rejected",failure)) return false;
   if(!QM11421_NewsExpect(!QM11421_ConsoleNewsKeyMatches("EURUSD",now,3,2,"EURUSD",now,4,2),
      "foreign_temporal_key_rejected",failure)) return false;
   if(!QM11421_NewsExpect(!QM11421_ConsoleNewsKeyMatches("EURUSD",now,3,2,"EURUSD",now,3,1),
      "foreign_compliance_key_rejected",failure)) return false;
   if(!QM11421_NewsExpect(QM11421_ConsoleNewsObservation(false,true,false,false,0,now,false,reason)==QM_GATE_OFF,
      "disabled_is_off_without_cache",failure)) return false;
   if(!QM11421_NewsExpect(QM11421_ConsoleNewsObservation(true,false,true,true,now,now,true,reason)==QM_GATE_WAIT,
      "unobserved_legacy_route_is_not_native_pass",failure)) return false;
   if(!QM11421_NewsExpect(QM11421_ConsoleNewsObservation(true,true,false,true,now,now,true,reason)==QM_GATE_WAIT,
      "missing_observation_is_wait_not_block",failure)) return false;
   if(!QM11421_NewsExpect(QM11421_ConsoleNewsObservation(true,true,true,true,0,now,true,reason)==QM_GATE_WAIT,
      "missing_timestamp_cannot_be_fresh",failure)) return false;
   if(!QM11421_NewsExpect(QM11421_ConsoleNewsObservation(true,true,true,false,now,now,true,reason)==QM_GATE_WAIT,
      "symbol_bar_or_axis_mismatch_is_unverified",failure)) return false;
   if(!QM11421_NewsExpect(QM11421_ConsoleNewsObservation(true,true,true,true,now-59,now,true,reason)==QM_GATE_PASS &&
      reason=="Last check clear","fresh_clear_cache_at_59_seconds",failure)) return false;
   if(!QM11421_NewsExpect(QM11421_ConsoleNewsObservation(true,true,true,true,now,now,false,reason)==QM_GATE_BLOCK &&
      reason=="Last check blocked" && StringFind(reason,"blackout")<0,
      "fresh_false_does_not_invent_blackout_cause",failure)) return false;
   if(!QM11421_NewsExpect(QM11421_ConsoleNewsObservation(true,true,true,true,now-60,now,true,reason)==QM_GATE_STALE,
      "ttl_60_is_stale_not_block",failure)) return false;
   if(!QM11421_NewsExpect(QM11421_ConsoleNewsObservation(true,true,true,true,now-600,now,false,reason)==QM_GATE_STALE,
      "old_false_is_not_current_block",failure)) return false;
   if(!QM11421_NewsExpect(QM11421_ConsoleNewsObservation(true,true,true,true,now+1,now,true,reason)==QM_GATE_STALE,
      "clock_reversal_is_unverified_not_block",failure)) return false;

   QM_ConsoleSnapshot state; state.Reset(); state.state=QM_CONSOLE_WAITING_SETUP;
   QM_ConsoleAddGate(state,"news","News","Last verdict expired",QM_GATE_STALE);
   QM11421_ConsoleGateAlerts(state);
   if(!QM11421_NewsExpect(state.state==QM_CONSOLE_WAITING_SETUP && state.alert_state==QM_GATE_STALE &&
      state.alert_reason!="","stale_keeps_waiting_headline_with_visible_warning",failure)) return false;
   state.gates[0].state=QM_GATE_WAIT; QM11421_ConsoleGateAlerts(state);
   if(!QM11421_NewsExpect(state.state==QM_CONSOLE_WAITING_SETUP && state.alert_state==QM_GATE_WAIT,
      "no_observation_keeps_waiting_headline",failure)) return false;
   QM_ConsoleAddGate(state,"kill","Kill switch","Halted",QM_GATE_BLOCK);
   QM11421_ConsoleGateAlerts(state);
   if(!QM11421_NewsExpect(state.state==QM_CONSOLE_BLOCKED && state.alert_state==QM_GATE_BLOCK &&
      StringFind(state.alert_reason,"Kill switch")==0,
      "real_kill_block_outranks_earlier_news_wait",failure)) return false;

   state.Reset(); state.state=QM_CONSOLE_POSITION_ACTIVE; state.positions=1;
   QM_ConsoleAddGate(state,"news","News","Last check blocked",QM_GATE_BLOCK);
   QM_ConsoleAddGate(state,"capacity","Capacity","Slot occupied",QM_GATE_BLOCK);
   QM11421_ConsoleGateAlerts(state);
   if(!QM11421_NewsExpect(state.state==QM_CONSOLE_POSITION_ACTIVE && state.alert_state==QM_GATE_BLOCK &&
      StringFind(state.alert_reason,"Entry warning: News")==0,
      "position_headline_preserved_with_block_warning",failure)) return false;
   state.gates[0].state=QM_GATE_STALE; QM11421_ConsoleGateAlerts(state);
   if(!QM11421_NewsExpect(state.state==QM_CONSOLE_POSITION_ACTIVE && state.alert_state==QM_GATE_STALE &&
      StringFind(state.alert_reason,"Entry check: News")==0,
      "position_headline_preserved_with_stale_observation",failure)) return false;

   state.Reset(); state.state=QM_CONSOLE_WAITING_TRIGGER; state.pending_orders=1;
   QM_ConsoleAddGate(state,"execution","Execution","Permission off",QM_GATE_BLOCK);
   QM11421_ConsoleGateAlerts(state);
   if(!QM11421_NewsExpect(state.state==QM_CONSOLE_WAITING_TRIGGER && state.alert_state==QM_GATE_BLOCK,
      "pending_headline_preserved_with_permission_warning",failure)) return false;
   state.Reset(); state.state=QM_CONSOLE_WAITING_SETUP;
   QM_ConsoleAddGate(state,"spread","Spread","No valid quote",QM_GATE_WARN);
   QM11421_ConsoleGateAlerts(state);
   if(!QM11421_NewsExpect(state.state==QM_CONSOLE_WAITING_SETUP && state.alert_state==QM_GATE_WARN,
      "missing_quote_remains_separate_warning",failure)) return false;
   state.gates[0].state=QM_GATE_PASS; QM11421_ConsoleGateAlerts(state);
   if(!QM11421_NewsExpect(state.alert_reason=="" && state.alert_state==QM_GATE_NA,
      "fresh_pass_clears_old_warning",failure)) return false;
   return true;
  }

#endif
