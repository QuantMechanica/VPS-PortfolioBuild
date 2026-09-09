// Binding slot deliberately unissued. A reviewed immutable contract must replace
// this function under a separately bound source generation before native use.
// Do not populate account identity, policy hashes or OWNER ratification at runtime.
bool QM11421_BoundContract(QM_RuntimeExecutionContract &contract,long &generation)
  {
   generation=0;
   Print("CANARY_BINDING_UNISSUED: native account and policy proof required");
   return false;
  }
