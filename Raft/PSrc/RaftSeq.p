type Messages = map[machine, Mbox];

machine RaftSeq
{
    var messages : Messages;

    var globalservers : set[machine];
    var PHASE : Phase;
    var logs : map[machine, Log];
    var acks : map[machine, bool];
    var commits : map[machine, bool];
    var newservers : map[machine, SeqServer];

    var i, j: int; 
    var p, from, dst: machine;
    var msg : MessageType;
    var initialconfig : ConfigEntry;

    start state Init{
        entry (serverconfig: set[machine]){

            globalservers = serverconfig;

            i = 0;
            while (i < sizeof(serverconfig)){
                p = globalservers[i];
                logs[p] = default(Log);
                logs[p] = add_to_log(logs[p], serverconfig, true);
                i = i + 1;
            }

            initialconfig = serverconfig;
            
            PHASE = 0;
            init_phase();
            
            goto Propose;
        }
    }

    state Propose{

        entry{
            var lastconfig : ConfigEntry;

            // INIT 2
            i = 0;
            while (i < sizeof(globalservers)) {
                p = globalservers[i];

                if(p == primary(PHASE, initialconfig)){

                    lastconfig = get_last_config(logs[p]);

                    // Only create one server per primary
                    if(!(p in newservers)){
                        newservers[p] = new SeqServer();
                        init_server(newservers[p]);
                        globalservers += (newservers[p]);
                        print(format("{0} CREATES SERVER {1}", p, newservers[p]));

                        // add commited log
                        logs[newservers[p]] = logs[p];

                        // extend log with new server not commited
                        lastconfig += (newservers[p]);
                        logs[p] = add_to_log(logs[p], lastconfig, false);
                        logs[p] = add_to_log(logs[newservers[p]], lastconfig, false);
                    }                 
                }
            
                i=i+1;
            }

            // SEND / RECEIVE
            i = 0;
            while (i < sizeof(globalservers)) {
                p = globalservers[i];

                if(p == primary(PHASE, initialconfig)){
                    lastconfig = get_last_config(logs[p]);

                    BroadCast(lastconfig, ProposeMessage, (phase=PHASE, from=p, payload=logs[p]));
                    acks[p] = true;
                }
            
                i=i+1;
            }

            // UPDATE
            i = 0;
            while (i < sizeof(globalservers)) {
                p = globalservers[i];

                if(sizeof(messages[p][PHASE][PROPOSE]) > 0){
                    msg = messages[p][PHASE][PROPOSE][0];

                    if(validExtendedLog(logs[p], msg.payload as Log)){
                        acks[p] = true;
                    }else{
                        acks[p] = false;
                    }
                    print(format("SERVER {0} ACK? {1}", p, validExtendedLog(logs[p], msg.payload as Log)));
                    print(format("SERVER ACK {0} {1} ", logs[p], msg.payload as Log));
                }
                
                i=i+1;
            }

            goto Ack;
        }
    }

    state Ack{

        entry{
            var lastconfig : ConfigEntry;

            // SEND / RECEIVE
            i = 0;
            while (i < sizeof(globalservers)) {
                p = globalservers[i];

                if(acks[p]){
                    Send(primary(PHASE, initialconfig), AckMessage, (phase=PHASE, from=p, payload=logs[p]));
                }
            
                i=i+1;
            }

            // UPDATE
            i = 0;
            while (i < sizeof(globalservers)) {
                p = globalservers[i];

                if(p == primary(PHASE, initialconfig)){
                    lastconfig = get_last_config(logs[p]);

                    if(sizeof(messages[p][PHASE][ACK]) >= sizeof(lastconfig)/2 + 1){
                        print(format("{0} HAS ACK QUORUM {1}", p, messages[p][PHASE][ACK]));
                        commits[p] = true;
                    }
                }
                
                i=i+1;
            }

            goto Commit;
        }
    }

    state Commit{

        entry{
            var msg: MessageType;
            var lastconfig: ConfigEntry;

            // SEND / RECEIVE
            i = 0;
            while (i < sizeof(globalservers)) {
                p = globalservers[i];

                if(p == primary(PHASE, initialconfig) && commits[p]){
                    lastconfig = get_last_config(logs[p]);
                    
                    BroadCast(lastconfig, CommitMessage, (phase=PHASE, from=p, payload=logs[p]));
                }
            
                i=i+1;
            }

            // UPDATE
            i = 0;
            while (i < sizeof(globalservers)) {
                p = globalservers[i];

                if(sizeof(messages[p][PHASE][COMMIT]) > 0){
                    msg = messages[p][PHASE][COMMIT][0];
                    logs[p] = msg.payload as Log;
                    commit_log(logs[p]);
                    announce eMonitor_NewLog, (id=p, newlog=logs[p]);
                }
                
                i=i+1;
            }

            PHASE = PHASE+1;
            init_phase();

            // FORCE BUG
            // if(PHASE > 2){
            //     raise halt;
            // }

            goto Propose;
        }
    }

    fun init_phase()
    {
        var i: int; 
        var s: machine;
        
        print(format("STARTING PHASE {0}", PHASE));
        i = 0;

        messages = default(Messages);

        while (i < sizeof(globalservers)) {
            s = globalservers[i];
            init_server(s);

            i = i+1;
        }
    }

    fun init_server(p: machine){
        acks[p] = false;
        commits[p] = false;
        
        messages[p] = default(Mbox);
        messages[p][PHASE] = default(map[Round, set[MessageType]]);

        messages[p][PHASE][PROPOSE] = default(set[ProposeMessageType]);
        messages[p][PHASE][ACK] = default(set[AckMessageType]);
        messages[p][PHASE][COMMIT] = default(set[CommitMessageType]);
    }

    fun BroadCast(ms: set[machine], ev: event, payload: MessageType){
        var receiver : machine;
        var i : int;

        i=0;
        while (i < sizeof(ms)){
            receiver = ms[i];
            Send(receiver, ev, payload);
                        
            i = i + 1;
        }
    }

    fun Send(target: machine, message: event, msg: MessageType){
        var round : Round;
        var lastconfig: ConfigEntry;

        lastconfig = get_last_config(logs[target]);

        if(message == ProposeMessage){
            round = PROPOSE;
        }else if(message == AckMessage){
            round = ACK;
        }else{
            round = COMMIT;
        }

        if(nonDeterministicChoice(msg, target, round)){
            messages[target][PHASE][round] += (msg);
        }else{
            print(format("MESSAGE {0} SENT TO {1} LOST", msg, target));
        }
    }

    fun logs_equal(msgs: set[MessageType]) : bool {
        var i: int;
        var l1, l2: Log;

        l1 = msgs[0].payload as Log;

        i = 0;

        while(i < sizeof(msgs)){
            l2 = msgs[i].payload as Log;

            if (l1 != l2){
                return false;
            }
            i=i+1;
        }

        return true;
    } 
    
    fun nonDeterministicChoice(msg: MessageType, target: machine, round: Round) : bool{
        if(msg.from == target || $){
            if(msg.from in get_last_config(logs[target])){
                return true;
                print(format("MESSAGE {0} RECEIVED TO {1}", msg, target));
            }else{
                return false;
                print(format("MESSAGE {0} FROM UNKNOWN SENDER TO {1}", msg, target));
            }
        }else{
            return false;
        }
    }   

    fun primary(phase: int, participants: set[machine]) : machine {
        var candidates : set[machine];
        var m : machine;
       
        candidates += (participants[0]);
        candidates += (participants[1]);

        m = roundrobin(phase, candidates);

        return m;
    }

    // fun nonDeterministicChoice(msg: MessageType, target: machine, round: Round) : bool{
    //     var decisions : set[(from: machine, dst: machine)];
    //     decisions = default(set[(from: machine, dst: machine)]);

    //     if(PHASE == 0){
    //         if(round == PROPOSE){
    //             decisions += ((from=globalservers[0], dst=globalservers[4]));
    //             decisions += ((from=globalservers[0], dst=globalservers[3]));
    //             decisions += ((from=globalservers[0], dst=globalservers[0]));
    //         }
    //         if(round == ACK){
    //             decisions += ((from=globalservers[4], dst=globalservers[0]));
    //             decisions += ((from=globalservers[3], dst=globalservers[0]));
    //             decisions += ((from=globalservers[0], dst=globalservers[0]));
    //         }
    //         if(round == COMMIT){
    //             decisions += ((from=globalservers[0], dst=globalservers[4]));
    //             decisions += ((from=globalservers[0], dst=globalservers[0]));
    //         } 
    //     }

    //     if(PHASE == 1){
    //         if(round == PROPOSE){
    //             decisions += ((from=globalservers[1], dst=globalservers[1]));
    //             decisions += ((from=globalservers[1], dst=globalservers[2]));
    //             decisions += ((from=globalservers[1], dst=globalservers[5]));
    //         }
    //         if(round == ACK){
    //             decisions += ((from=globalservers[5], dst=globalservers[1]));
    //             decisions += ((from=globalservers[2], dst=globalservers[1]));
    //             decisions += ((from=globalservers[1], dst=globalservers[1]));
    //         }
    //         if(round == COMMIT){
    //             decisions += ((from=globalservers[1], dst=globalservers[1]));
    //             decisions += ((from=globalservers[1], dst=globalservers[2]));
    //             decisions += ((from=globalservers[1], dst=globalservers[5]));
    //         } 
    //     }

    //     if(PHASE == 2){
    //         if(round == PROPOSE){
    //             decisions += ((from=globalservers[0], dst=globalservers[0]));
    //             decisions += ((from=globalservers[0], dst=globalservers[1]));
    //             decisions += ((from=globalservers[0], dst=globalservers[2]));
    //             decisions += ((from=globalservers[0], dst=globalservers[3]));
    //             decisions += ((from=globalservers[0], dst=globalservers[4]));
    //             decisions += ((from=globalservers[0], dst=globalservers[5]));
    //         }
    //         if(round == ACK){
    //             decisions += ((from=globalservers[0], dst=globalservers[0]));
    //             decisions += ((from=globalservers[1], dst=globalservers[0]));
    //             decisions += ((from=globalservers[2], dst=globalservers[0]));
    //             decisions += ((from=globalservers[3], dst=globalservers[0]));
    //             decisions += ((from=globalservers[4], dst=globalservers[0]));
    //             decisions += ((from=globalservers[5], dst=globalservers[0]));
    //         }
    //         if(round == COMMIT){
    //             decisions += ((from=globalservers[0], dst=globalservers[0]));
    //             decisions += ((from=globalservers[0], dst=globalservers[1]));
    //             decisions += ((from=globalservers[0], dst=globalservers[2]));
    //             decisions += ((from=globalservers[0], dst=globalservers[3]));
    //             decisions += ((from=globalservers[0], dst=globalservers[4]));
    //             decisions += ((from=globalservers[0], dst=globalservers[5]));
    //         } 
    //     }

    //     //print(format("MESSAGE {0} IN DECISIONS {1}? {2}", (from=msg.from, dst=target), decisions, (from=msg.from, dst=target) in decisions));

    //     if((from=msg.from, dst=target) in decisions){
    //         print(format("MESSAGE {0} RECEIVED TO {1}", msg, target));
    //         return true;
    //     } 

    //     return false;
    // }

    // fun primary(phase: int, participants: set[machine]) : machine {
    //     if(phase == 0 || phase == 2){
    //         return participants[0];
    //     }else{
    //         return participants[1];
    //     }
    // }


}
