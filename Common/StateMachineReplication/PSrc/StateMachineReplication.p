enum FailureModel {ReliableNetwork, UnreliableNetwork, ReliableNetworkWithTimeouts, UnreliableNetworkWithTimeouts}

fun primary(phase: int, participants: set[machine]) : machine {
    var m : machine;
    m = roundrobin(phase, participants);

    return m;
}

fun roundrobin(phase: int, participants: set[machine]) : machine {
    assert sizeof(participants)>0, "Primary function received emptyset";
    return participants[modulo(phase, sizeof(participants))];
}

fun modulo(a : int, mod : int) : int{
    while(a >= mod){
        a = a-mod;
    }
    return a;
}

fun BroadCast(fm : FailureModel, ms: set[machine], ev: event, payload: any){
    if(fm == ReliableNetwork || fm == ReliableNetworkWithTimeouts){
        ReliableBroadCast(ms, ev, payload);
    }else if(fm == UnreliableNetwork || fm == UnreliableNetworkWithTimeouts){
        UnReliableBroadCast(ms, ev, payload);
    }
}

fun MaybeStartTimer(fm : FailureModel, timer: Timer)
{
    if(fm == ReliableNetworkWithTimeouts || fm == UnreliableNetworkWithTimeouts){
        StartTimer(timer);
    }
}

fun MaybeCancelTimer(fm : FailureModel, timer: Timer)
{
    if(fm == ReliableNetworkWithTimeouts || fm == UnreliableNetworkWithTimeouts){
        CancelTimer(timer);
    }
}

fun Send(fm : FailureModel, target: machine, message: event, payload: any){
    if(fm == ReliableNetwork || fm == ReliableNetworkWithTimeouts){
        send target, message, payload;
    }else{
        UnReliableSend(target, message, payload);
    }
}

// var threshold is the minimal size of the desired subset
fun NonDeterministicSubset(elements: set[any], threshold: int) : set[any]{
    var subsetSize : int;
    var element : any;
    var i : int;
    var subset : set[any];

    subsetSize = threshold + choose(sizeof(elements)-threshold+1);

    i = 0;
    while (i < subsetSize){
        element = choose(elements);
        elements -= (element);
        subset += (element);
        i = i+1;
    }

    assert(sizeof(subset) >= threshold);

    return subset;
}

fun sequenceIsPrefix(prefix: seq[any], longerseq: seq[any]) : bool {
    var i: int;

    assert(sizeof(longerseq) >= sizeof(prefix)), format("seq {0} is not longer than {1}, {2} vs {3}", longerseq, prefix, sizeof(longerseq), sizeof(prefix));

    i = 0;

    while(i < sizeof(prefix)){
        if (prefix[i] != longerseq[i]){
            return false;
        }
        i=i+1;
    }

    return true;
}