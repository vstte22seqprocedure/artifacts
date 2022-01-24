
event eMessage : MessageType;
event FirstMessage: FirstType;
event SecondMessage: SecondType;

event Config: (peers: set[machine], quorum: int, failurem: FailureModel);

type Value = int; // 0, 1, -1 = ?
type RequestId = int;
type Phase = int;
type Mbox = map[Phase, map[Round, set[MessageType]]];
type Timestamp = (phase: Phase, round: Round);
type Log = map[RequestId, any];

type MessageType = (phase: Phase, from: machine, payload: any);
type FirstType = (phase: Phase, from: machine, payload: Value);
type SecondType = (phase: Phase, from: machine, payload: (initial: Value, vote: Value));

enum Round { FIRST, SECOND }

machine Process {   
    var participants : set[machine];
    var quorum : int;
    var phase : Phase;
    var mbox : Mbox;
    var timer : Timer;
    var fm: FailureModel;

    var initial : Value;
    var vote : Value;
    var decide : Value;

    start state Init {
        defer FirstMessage, SecondMessage;
        
        entry {
            receive {
                case Config: (payload: (peers: set[machine], quorum: int, failurem: FailureModel)) { 
                    participants = payload.peers;
                    quorum = payload.quorum;
                    fm = payload.failurem;
                }
            }
            
            initial = choose(5);
            print(format("{0} start with ESTIMATE {1}", this, initial));
            vote = -1;
            decide = -1;

            timer = CreateTimer(this);
            init_phase(0);
            goto First;
        }
    }

    state First {
        defer SecondMessage;

        entry {
            BroadCast(fm, participants, FirstMessage, (phase=phase, from=this, payload = initial));
            StartTimer(timer);
        }

        on FirstMessage do (m : FirstType) {
            if(m.phase == phase){
                collectMessage(m, FIRST);
            }
        }

        on eTimeOut do {
            firstRound();
        }
    }

    fun firstRound() {
        var firstValues : set[Value];
        var i : int;

        if(sizeof(mbox[phase][FIRST]) == 0){
            init_phase(phase+1);
            goto First;
        }

        i = 0;
        while(i < sizeof(mbox[phase][FIRST])){
            firstValues += (mbox[phase][FIRST][i].payload as Value);
            i=i+1;
        }

        initial = smallest_value(firstValues);

        if(all_equal(firstValues)){
            vote = initial;
        }

        print(format("{0} new INITIAL {1}, VOTE {2} ", this, initial, vote));
        goto Second;
    }

    state Second {
        defer FirstMessage;

        entry { 
            BroadCast(fm, participants, SecondMessage, (phase=phase, from=this, payload = (initial=initial, vote=vote)));
            StartTimer(timer);
        }

        on SecondMessage do (m : SecondType) {
            if(m.phase == phase){
                collectMessage(m, SECOND);
            }
        }

        on eTimeOut do {
            secondRound();
        }
    }

    fun secondRound() {
        var val : Value;
        var secondValues : set[Value];
        var sv : (initial: Value, vote: Value);
        var i : int;

        if(sizeof(mbox[phase][SECOND]) == 0){
            init_phase(phase+1);
            goto First;
        }

        val = get_valid_estimate(mbox[phase][SECOND] as set[SecondType]);

        print(format("{0} get_valid_estimate {1} in phase {2}", this, val, phase));

        if(val != -1){
            initial = val;
        }else{
            i = 0;

            while(i < sizeof(mbox[phase][SECOND])){
                sv = mbox[phase][SECOND][i].payload as (initial: Value, vote: Value);
                secondValues += (sv.initial);
                i=i+1;
            }

            initial = smallest_value(secondValues);

            print(format("{0} new initial {1} in phase {2}", this, initial, phase));
        }

        if(all_equal_vote(mbox[phase][SECOND] as set[SecondType])){
            sv = mbox[phase][SECOND][0].payload as (initial: Value, vote: Value);
            decide = sv.vote;
            print(format("{0} Decided {1} in phase {2}", this, sv.vote, phase));
            announce eMonitor_NewDecision, (id=this, decision=decide);
        }

        vote = -1;

        init_phase(phase+1);
        goto First;
        
    }

    fun collectMessage(m:MessageType, r: Round) {
        if(!(m.phase in mbox)){
            init_phase(m.phase);
        }
        
        mbox[m.phase][r] += (m);

        print(format("{0} collected message {1} {2} in phase, MAILBOX {3}", this, r, phase, mbox));
    }

    fun init_phase(p: Phase) {
        phase = p;

        mbox[phase] = default(map[Round, set[MessageType]]);

        mbox[phase][FIRST] = default(set[MessageType]);
        mbox[phase][SECOND] = default(set[MessageType]);
    }
}

fun smallest_value(v : set[Value]) : Value {
    var min : Value;
    var i : int;

    assert(sizeof(v) > 0);

    min = v[0];

    i = 0;

    while(i < sizeof(v)){
        if(v[i] < min){
            min = v[i];
        }
        i=i+1;
    }
    return min;
}

fun all_equal(v : set[Value]) : bool {
    var i : int;
    var val : Value;

    val = v[0];
    i = 0;

    while(i < sizeof(v)){
        if(v[i] != val){
            return false;
        }
        i=i+1;
    }

    return true;
}

fun all_equal_vote(msgs : set[SecondType]) : bool{
    var i : int;
    var v1, v2 : Value;

    v1 = msgs[0].payload.vote;

    i = 0;
    while(i < sizeof(msgs)){
        v2 = msgs[i].payload.vote;
        if(v2 != v1){
            return false;
        }
        i=i+1;
    }

    if(v1 == -1){
        return false;
    }

    return true;
}

fun get_valid_estimate(msgs : set[SecondType]) : Value {
    var i : int;

    print(format("get_valid_estimate {0}", msgs));

    i = 0;
    while(i < sizeof(msgs)){
        if(msgs[i].payload.vote != -1){
            return msgs[i].payload.vote;
        }
        i=i+1;
    }

    return -1;
}