event eMonitor_Initialize: set[machine];
event eMonitor_NewLeader: (phase: Phase, leader: machine);

spec LeadersConsistencyInvariant observes eMonitor_Initialize, eMonitor_NewLeader
{
    
    var leaders: map[Phase, machine];

    start state Init {

        on eMonitor_Initialize goto WaitForEvents with (participants: set[machine]) {

        }
    }

    state WaitForEvents {

        on eMonitor_NewLeader do (payload: (phase: Phase, leader: machine))
        {
            var newleader : machine;
            newleader = payload.leader;

            if(payload.phase in leaders){
                assert (newleader == leaders[payload.phase]), format("Leader mismatch {0} vs {1}", newleader, leaders[payload.phase]);
            }else{
                leaders[payload.phase] = newleader;
            }
            
            
        }
 
    }
}