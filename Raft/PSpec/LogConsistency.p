event eMonitor_NewLog: (id: machine, newlog: Log);

spec LogConsistency observes eMonitor_NewLog
{
    var lastLog: Log;

    start state Init {
        on eMonitor_NewLog do (payload: (id: machine, newlog: Log))
        {
            print(format("NEW LOG {0} COMMITED BY {1}, COMMITED LOGS {2}", payload.newlog, payload.id, lastLog));
                    
            assert validExtendedLog(lastLog, payload.newlog), format("lastLog {0} is not a prefix of {1} commited by {2}", lastLog, payload.newlog, payload.id);

            lastLog = payload.newlog;
                  
        }
    }

    fun validExtendedLog(oldlog: Log, newlog: Log) : bool {
        var i: int;

        if(sizeof(newlog) < sizeof(oldlog)){
            return false;
        }

        i = 0;

        while(i < sizeof(oldlog)){
            if (oldlog[i].logentry != newlog[i].logentry){
                return false;
            }
            i=i+1;
        }

        return true;
    }
}

