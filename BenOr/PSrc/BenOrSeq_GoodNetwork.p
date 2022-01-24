machine BenOrSeq_GoodNetwork
{
    var K : Phase;
    var quorum : int;
    var participants : set[machine];
    var estimate : map[machine, Value];
    var reported : map[machine, Value];
    var decided : map[machine, Value];
    var messages : Messages;
    var currentRequest : RequestId;

    var i, j: int; 
    var p, from, dst: machine;
    var reachableProcesses : set[any];
    var nondetset: map[machine, set[machine]];

    start state Init{
        entry (config: (peers: set[machine], quorum: int)){
            
            participants = config.peers;
            quorum = config.quorum;

            init_phase(0);

            i = 0;
            while (i < sizeof(participants)){
                p = participants[i];
                estimate[p] = input_estimate(i);
                decided[p] = -1;
                print(format("{0} start with ESTIMATE {1}", p, estimate[p]));
                i=i+1;
            }

            goto Report;
        }
    
    }

    state Report{
        entry{
            var rand : int;
            // SEND
            i = 0;
            while (i < sizeof(participants)){
                dst = participants[i];

                reachableProcesses = NonDeterministicSubset(participants, quorum);
                //reachableProcesses = nondetset[dst];
                rand = choose(3);

                j = 0;
                while (j < sizeof(participants)){ 
                    from = participants[j];

                    if(decided[from] != -1){
                        estimate[from] = decided[from];
                    }
                    
                    print(format("{0} send REPORT message {1} to {2}", from, (phase = K, from=from, payload=estimate[from]), dst));

                    // Network assumption holds
                    //if(from in reachableProcesses){
                    //if(j != rand){
                    if(nonDeterministicBool(K,i,j)){
                        //send this, eMessage, (phase = K, from=from, payload=estimate[from]);
                        messages[dst][REPORT] += ((phase = K, from=from, payload=estimate[from]));
                        print(format("{0} received REPORT estimate {1} in phase {2} from {3}", dst, estimate[from], K, from));
                    }else{
                        print(format("REPORT MESSAGE LOST FROM {0} TO {1} in phase {2}", from, dst, K));
                    }                        
                
                    j = j + 1;
                }
                
                i = i + 1;
            }

            // UPDATE
            i = 0;
            while (i < sizeof(participants)){
                p = participants[i];   

                assert(sizeof(messages[p][REPORT]) >= quorum), format("{0} received {1} in phase {2} REPORT", p, sizeof(messages[p][REPORT]), K);

                reported[p] = mayority_value(messages[p][REPORT], quorum);
                print(format("{0} REPORT mayority {1} in phase {2}, mailbox: {3}, size {4}", p, reported[p], K, messages[p], sizeof(messages[p][REPORT])));
                        
                i = i + 1;
            }

            goto Proposal;
        }

    }

    state Proposal{
        entry{
            // SEND
            var rand : int;
            var val : Value;

            i = 0;
            while (i < sizeof(participants)){
                dst = participants[i];

                reachableProcesses = NonDeterministicSubset(participants, quorum);
                //reachableProcesses = nondetset[dst];
                rand = choose(3);

                j = 0;
                
                while (j < sizeof(participants)){
                    
                    from = participants[j];

                    if(decided[from] != -1){
                        reported[from] = decided[from];
                    }
    
                    print(format("{0} send PROPOSAL message {1} to {2}", from, (phase = K, from=from, payload=reported[from]), dst));

                    // Network assumption holds
                    //if(from in reachableProcesses){
                    //if(j != rand){
                    if(nonDeterministicBool(K,i,j)){
                        //send this, eMessage, (phase = K, from=from, payload=reported[from]);
                        messages[dst][PROPOSAL] += ((phase = K, from=from, payload=reported[from]));
                        print(format("{0} received PROPOSAL estimate {1} in phase {2}", dst, reported[from], K));
                    }else{
                        print(format("PROPOSAL MESSAGE LOST FROM {0} TO {1} in phase {2}", from, dst, K));
                    }
                    
                    j = j + 1;
                }

                i = i + 1;
            }
            
            // UPDATE
            i = 0;
            while (i < sizeof(participants)){
                p = participants[i];

                assert(sizeof(messages[p][PROPOSAL]) >= quorum), format("{0} received {1} in phase {2} PROPOSAL", p, sizeof(messages[p][PROPOSAL]), K);

                print(format("{0} received enough PROPOSAL messages in phase {1}, {2}", p, K, messages[p][PROPOSAL]));

                val = mayority_value(messages[p][PROPOSAL], quorum);

                if(val != -1){
                    // decide value
                    print(format("{0} Decided {1} in phase {2}", p, val, K));

                    announce eMonitor_NewDecision, (id=p, decision=val);

                    //decided[p] = val; //BUG, add this line to fix

                }else if(get_valid_estimate(messages[p][PROPOSAL]) != -1){

                    // We try again a new phase proposing a valid value
                    estimate[p] = get_valid_estimate(messages[p][PROPOSAL]);
                    print(format("{0} changed estimate to {1} in phase {2}", p, estimate[p], K));
                    
                }else{
                    estimate[p] = choose(2); // 0 or 1 randomly
                    print(format("{0} Flip a coin {1}", p, estimate[p]));
                }
                
                
                i=i+1;
            }

            init_phase(K+1);
            goto Report;
            
        }
    }

    fun init_phase(phase: Phase)
    {
        var i: int; 
        var p: machine;

        K = phase;
        
        i = 0;
       
        messages = default(Messages);
        
        while (i < sizeof(participants)) {
            p = participants[i];
            
            messages[p] = default(map[Round, set[MessageType]]);

            messages[p][REPORT] = default(set[ReportType]);
            messages[p][PROPOSAL] = default(set[ProposalType]);

            i = i+1;
        }
    }

    fun receiveMessageBlocking(pdest: machine, r : Round)
    {
        receive {
            case eMessage: (m: MessageType) { 
                messages[pdest][r] += (m); 
            }
        }
    }

    fun nonDeterministicBool(phase: Phase, i: int,j: int) : bool {
        var decisions: set[(int, int)];

        if(phase == 0){
            decisions = default(set[(int, int)]);
            decisions += ((0,1));
            decisions += ((0,0));
            decisions += ((1,0));
            decisions += ((1,1));

            decisions += ((2,0));
            decisions += ((2,1));
            return (i,j) in decisions;
        }else{
            decisions = default(set[(int, int)]);
            decisions += ((2,1));
            decisions += ((1,2));
            decisions += ((1,1));
            decisions += ((2,2));

            decisions += ((0,1));
            decisions += ((0,2));
            return (i,j) in decisions;
        }
    }

    fun input_estimate(i: int) : int{
        return choose(2);
        // if(i < sizeof(participants)-quorum){
        //     return 0;
        // }else{
        //     return 1;
        // }
    }
}
