machine BenOrSeq_ArbitraryNetwork
{
    var K : Phase;
    var quorum : int;
    var participants : set[machine];
    var estimate : map[machine, Value];
    var reported : map[machine, Value];
    var decided : map[machine, Value];
    var messages : Messages;
    var reportRoundSuccessful : map[machine, map[Phase, bool]];
    var currentRequest : RequestId;

    var i, j: int; 
    var p, from, dst: machine;
    var reachableProcesses : set[any];

    start state Init{
        entry (config: (peers: set[machine], quorum: int)){
            
            participants = config.peers;
            quorum = config.quorum;

            init_phase(0);

            i = 0;
            while (i < sizeof(participants)){
                p = participants[i];
                estimate[p] = choose(2);
                decided[p] = -1;
                print(format("{0} start with ESTIMATE {1}", p, estimate[p]));
                i=i+1;
            }

            goto Report;
        }
    
    }

    state Report{
        entry{
            // SEND
            i = 0;
            while (i < sizeof(participants)){
                dst = participants[i];

                j = 0;
                while (j < sizeof(participants)){ 
                    from = participants[j];

                    if(decided[from] != -1){
                        estimate[from] = decided[from];
                    }
                    
                    print(format("{0} send REPORT message {1} to {2}", from, (phase = K, from=from, payload=estimate[from]), dst));

                    // Arbitrary message omission
                    if($){
                        //send this, eMessage, (phase = K, from=from, payload=estimate[from]);
                        messages[dst][REPORT] += ((phase = K, from=from, payload=estimate[from]));
                        print(format("{0} received REPORT estimate {1} in phase {2} from {3}", dst, estimate[from], K, from));
                    }                        
                
                    j = j + 1;
                }
                
                i = i + 1;
            }

            // UPDATE
            i = 0;
            while (i < sizeof(participants)){
                p = participants[i];   

                reportRoundSuccessful[p][K] = true;
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
            var val : Value;

            i = 0;
            while (i < sizeof(participants)){
                dst = participants[i];

                j = 0;
            
                while (j < sizeof(participants)){
                    
                    from = participants[j];

                    if(reportRoundSuccessful[from][K]){

                        if(decided[from] != -1){
                            reported[from] = decided[from];
                        }
        
                        print(format("{0} send PROPOSAL message {1} to {2}", from, (phase = K, from=from, payload=reported[from]), dst));

                        // Arbitrary message omission
                        if($){
                            //send this, eMessage, (phase = K, from=from, payload=reported[from]);
                            messages[dst][PROPOSAL] += ((phase = K, from=from, payload=reported[from]));
                            print(format("{0} received PROPOSAL estimate {1} in phase {2}", dst, reported[from], K));
                        }
                    }
                    j = j + 1;
                }

                i = i + 1;
            }
            
            // UPDATE
            i = 0;
            while (i < sizeof(participants)){
                p = participants[i];
  
                if(reportRoundSuccessful[p][K]){

                    //assert(sizeof(messages[p][PROPOSAL]) >= quorum), format("{0} received {1} in phase {2} PROPOSAL", p, sizeof(messages[p][PROPOSAL]), K);

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
        reportRoundSuccessful = default(map[machine, map[Phase, bool]]);
        
        while (i < sizeof(participants)) {
            p = participants[i];
            reportRoundSuccessful[p] = default(map[Phase, bool]);
            reportRoundSuccessful[p][phase] = false;
            
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
}
