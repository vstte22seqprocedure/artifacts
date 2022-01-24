event eMonitor_NewDecision: (id: machine, decision: Value);

spec Agreement observes eMonitor_NewDecision
{
    var decision: Value;

    start state Init {

        entry {
            decision = -1;
        }

        on eMonitor_NewDecision do (payload: (id: machine, decision: Value))
        {

            if(decision != -1){
                assert (decision == payload.decision), format("Agreement failed by {0}, decided {1} but other decided {2}", payload.id, payload.decision, decision);
            }else{
                decision = payload.decision;
            }
            
        }
    }
}