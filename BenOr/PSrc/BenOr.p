event eMessage : MessageType;

event ReportMessage: ReportType;
event ProposalMessage: ProposalType;

event Config: (peers: set[machine], quorum: int, failurem: FailureModel, i: int);

type Value = int; // 0, 1, -1 = ?
type RequestId = int;
type Phase = int;
type Mbox = map[Phase, map[Round, set[MessageType]]];
type Timestamp = (phase: Phase, round: Round);
type Log = map[RequestId, any];

type MessageType = (phase: Phase, from: machine, payload: any);
type ReportType = (phase: Phase, from: machine, payload: Value);
type ProposalType = (phase: Phase, from: machine, payload: Value);

enum Round { REPORT, PROPOSAL }

machine Process {   
    var participants : set[machine];
    var quorum : int;
    var K : Phase;
    var mbox : Mbox;
    var log : Log;
    var timer : Timer;
    var estimate : Value;
    var reported : Value;
    var currentRequest : RequestId;
    var fm: FailureModel;

    start state Init {
        defer ReportMessage, ProposalMessage;
        
        entry {
            receive {
                case Config: (payload: (peers: set[machine], quorum: int, failurem: FailureModel, i: int)) { 
                    participants = payload.peers;
                    quorum = payload.quorum;
                    fm = payload.failurem;
                    estimate = input_estimate(payload.i);
                    print(format("{0} start with ESTIMATE {1}", this, estimate));
                }
            }
            timer = CreateTimer(this);
            
            init_phase(0);
            goto Report;
        }
    }

    state Report {
        defer ProposalMessage;

        entry {
            BroadCast(fm, participants, ReportMessage, (phase=K, from=this, payload = estimate));
            MaybeStartTimer(fm, timer);
        }

        on ReportMessage do (m : ReportType) {
            
            if(m.phase == K){
                collectMessage(m, REPORT);
                
                if(sizeof(mbox[K][REPORT]) >= quorum){
                    print(format("{0} reached report in phase {1}", this, K));
                    MaybeCancelTimer(fm, timer);
                    reported = mayority_value(mbox[K][REPORT], quorum);
                    goto Proposal;
                }

            }
            
        }

        on eShutDown do {
            raise halt;
        }

        on eTimeOut do {
            timeout();
            //goto Report;
        }
    }

    state Proposal {
        defer ReportMessage;

        entry { 
            BroadCast(fm, participants, ProposalMessage, (phase=K, from=this, payload = reported));
            MaybeStartTimer(fm, timer);   
        }

        on ProposalMessage do (m : ProposalType) {
            var val : Value;
            var coin_toss : int;

            if(m.phase == K){
                collectMessage(m, PROPOSAL);

                if(sizeof(mbox[K][PROPOSAL]) >= quorum){
                    
                    MaybeCancelTimer(fm, timer);
                    val = mayority_value(mbox[K][PROPOSAL], quorum);

                    if(val != -1){
                        
                        // decide value
                        print(format("{0} Decided {1} in phase {2}", this, val, K));
                        //estimate = val; // BUG, add this line to fix
                        announce eMonitor_NewDecision, (id=this, decision=val);

                    }else if(get_valid_estimate(mbox[K][PROPOSAL]) != -1){

                        // We try again a new phase proposing a valid value
                        estimate = get_valid_estimate(mbox[K][PROPOSAL]);
                        print(format("{0} got valid estimate {1} in phase {2}", this, estimate, K)); 

                    }else{

                        estimate = choose(2); // 0 or 1 randomly
                        print(format("{0} Flip a coin {1}", this, estimate));
                        
                    }

                    init_phase(K+1);
                    goto Report;
                }

            }
            
        }

        on eShutDown do {
            raise halt;
        }

        on eTimeOut do {
            timeout();
        }
    }

    fun collectMessage(m:MessageType, r: Round) {
        if(!(m.phase in mbox)){
            init_phase(m.phase);
        }
        
        mbox[m.phase][r] += (m);

        //print(format("{0} collected message {1} {2} in phase, MAILBOX {3}", this, r, K, mbox));
    }

    fun init_phase(phase: Phase) {
        K = phase;

        mbox[phase] = default(map[Round, set[MessageType]]);

        mbox[phase][REPORT] = default(set[MessageType]);
        mbox[phase][PROPOSAL] = default(set[MessageType]);
    }

    fun timeout(){
        init_phase(K+1);
        print(format("{0} timeouts! move to phase {1}", this, K));

        goto Report;
    }

    fun input_estimate(i: int) : int{
        //return choose(2);
        if(i < sizeof(participants)-quorum){
            return 0;
        }else{
            return 1;
        }
    }
}

fun mayority_value(msgs : set[MessageType], quorum: int) : Value {
    var count_zero : int;
    var count_one : int;
    var i : int;

    count_one = 0;
    count_one = 0;

    i = 0;

    while(i < sizeof(msgs)){
        if(msgs[i].payload == 0){
            count_zero=count_zero+1;
        }else if(msgs[i].payload == 1){
            count_one=count_one+1;
        }
        i=i+1;
    }

    if(count_zero >= quorum){
        return 0;
    }else if(count_one >= quorum){
        return 1;
    }else{
        return -1;
    }
}

fun all_decided(msgs : set[MessageType], numParticipants: int) : bool {
    var i : int;
    var val : Value;

    val = msgs[0].payload as Value;
    i = 0;

    print(format("sarasa {0} < {1}, {2}", sizeof(msgs), numParticipants, msgs));

    if(sizeof(msgs) < numParticipants){
        return false;
    }

    while(i < sizeof(msgs)){
        if(msgs[i].payload != val){
            return false;
        }
        i=i+1;
    }

    return true;
}

fun get_valid_estimate(msgs : set[MessageType]) : Value{
    var i : int;

    print(format("get_valid_estimate {0}", msgs));

    while(i < sizeof(msgs)){
        if(msgs[i].payload == 0){
            return 0;
        }else if(msgs[i].payload == 1){
            return 1;
        }
        i=i+1;
    }

    return -1;
}