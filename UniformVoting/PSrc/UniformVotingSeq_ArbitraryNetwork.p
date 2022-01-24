type Messages = map[machine, Mbox];

machine UniformVotingSeq_ArbitraryNetwork
{
    var PHASE : Phase;
    var quorum : int;
    var participants : set[machine];
    var messages : Messages;
    var roundSuccessful : map[machine, map[Phase, map[Round, bool]]];

    var i, j: int; 
    var p, from, dst: machine;

    var initial : map[machine,Value];
    var vote : map[machine,Value];
    var decide : map[machine,Value];  

    start state Init{
        entry (config: (peers: set[machine], quorum: int)){
            
            participants = config.peers;
            quorum = config.quorum;

            init_phase(0);

            i = 0;
            while (i < sizeof(participants)){
                p = participants[i];
                
                initial[p] = choose(5);
                print(format("{0} start with ESTIMATE {1}", p, initial));
                vote[p] = -1;
                decide[p] = -1;

                i=i+1;
            }

            goto First;
        }
    
    }

    state First{
        defer eMessage;

        entry{
            var firstValues : set[Value];
            var k : int;

            i = 0;
            while (i < sizeof(participants)){
                from = participants[i];

                j = 0;
                while (j < sizeof(participants)){

                    dst = participants[j];

                    print(format("{0} send FirstMessage message {1} to {2}", from, (phase = PHASE, from=from, payload=initial[from]), dst));

                    if(choose(2) == 1){
                        messages[dst][PHASE][FIRST] += ((phase = PHASE, from=from, payload=initial[from]));
                        print(format("{0} received FIRST initial {1} in phase {2} from {3}", dst, initial[from], PHASE, from));
                    }else{
                        print("message dropped");
                    }                        
                

                    j = j + 1;
                }
                
                i = i + 1;
            }

            i = 0;
            while (i < sizeof(participants)){
                p = participants[i];

                if(sizeof(messages[p][PHASE][FIRST]) > 0){
        
                    k = 0;
                    while(k < sizeof(messages[p][PHASE][FIRST])){
                        firstValues += (messages[p][PHASE][FIRST][k].payload as Value);
                        k=k+1;
                    }

                    initial[p] = smallest_value(firstValues);

                    if(all_equal(firstValues)){
                        vote[p] = initial[p];
                    }

                    roundSuccessful[p][PHASE][FIRST] = true;

                    print(format("{0} new INITIAL {1}, VOTE {2} ", p, initial[p], vote[p]));

                }
                
                i = i + 1;
            }

            goto Second;
        }

    }

    state Second{
        defer eMessage;

        entry{
            var val : Value;
            var secondValues : set[Value];
            var sv : (initial: Value, vote: Value);
            var k : int;

            i = 0;
            while (i < sizeof(participants)){
                from = participants[i];
                
                if(roundSuccessful[from][PHASE][FIRST]){ 
                    j = 0;
                    while (j < sizeof(participants)){

                        dst = participants[j];

                        print(format("{0} send SECOND message {1} to {2}", from,  (phase = PHASE, from=from, payload=(initial=initial[p], vote=vote[p])), dst));
                        if(choose(2) == 1){
                            messages[dst][PHASE][SECOND] += ((phase = PHASE, from=from, payload=(initial=initial[p], vote=vote[p])));
                            print(format("{0} received SECOND {1} in phase {2}", dst, (initial=initial[from], vote=vote[from]), PHASE));
                        }
                        
                        j = j + 1;
                    }
                }

                i = i + 1;
            }

            i = 0;
            while (i < sizeof(participants)){
                p = participants[i];
  
                if(roundSuccessful[from][PHASE][FIRST]){

                    if(sizeof(messages[p][PHASE][SECOND]) > 0){

                        val = get_valid_estimate(messages[p][PHASE][SECOND] as set[SecondType]);

                        print(format("{0} get_valid_estimate {1} in phase {2}", p, val, PHASE));

                        if(val != -1){
                            initial[p] = val;
                        }else{
                            k = 0;

                            while(k < sizeof(messages[p][PHASE][SECOND])){
                                sv = messages[p][PHASE][SECOND][k].payload as (initial: Value, vote: Value);
                                secondValues += (sv.initial);
                                k=k+1;
                            }
                            initial[p] = smallest_value(secondValues);

                            print(format("{0} new initial {1} in phase {2}", p, initial[p], PHASE));
                        }

                        if(all_equal_vote(messages[p][PHASE][SECOND] as set[SecondType])){
                            sv = messages[p][PHASE][SECOND][0].payload as (initial: Value, vote: Value);
                            decide[p] = sv.vote;
                            print(format("{0} Decided {1} in phase {2}", p, decide[p], PHASE));
                            announce eMonitor_NewDecision, (id=p, decision=decide[p]);
                        }

                        vote[p] = -1;

                    }

                }
                
                i=i+1;
            }

            init_phase(PHASE+1);
            goto First;
            
        }
    }

    fun init_phase(phase: Phase)
    {
        var i: int; 
        var p: machine;

        PHASE = phase;
        
        i = 0;
       
        messages = default(Messages);
        roundSuccessful = default(map[machine, map[Phase, map[Round, bool]]]);
        
        while (i < sizeof(participants)) {
            p = participants[i];
            roundSuccessful[p] = default(map[Phase, map[Round, bool]]);
            roundSuccessful[p][phase] = default(map[Round, bool]);
            roundSuccessful[p][phase][FIRST] = false;
            roundSuccessful[p][phase][SECOND] = false;
            
            messages[p] = default(Mbox);
            messages[p][phase] = default(map[Round, set[MessageType]]);

            messages[p][phase][FIRST] = default(set[FirstType]);
            messages[p][phase][SECOND] = default(set[SecondType]);

            i = i+1;
        }
    }
}
