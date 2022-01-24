event eMonitor_Initialize: int;
event eMonitor_NewLog: (id: machine, newlog: seq[any]);

spec LogConsistency observes eMonitor_NewLog
{
    var logs: map[machine, Log];

    start state Init {
        on eMonitor_NewLog do (payload: (id: machine, newlog: seq[any]))
        {
            var loge : any;

            logs[payload.id] = payload.newlog;

            print(format("LOGS {0}", logs));

            logsArePrefix();
            
        }
    }

    fun logsArePrefix() {
        var i, j, k, maxindex: int;
        var currentLogs : seq[Log];
        var longLog, shortLog: Log;

        currentLogs = values(logs);
        
        i = 0;
        j = 0;

        while(i < sizeof(currentLogs)){
            while(j < sizeof(currentLogs)){

                if(sizeof(currentLogs[i]) > sizeof(currentLogs[j])){
                    maxindex = sizeof(currentLogs[j]);
                    longLog = currentLogs[i];
                    shortLog = currentLogs[j];
                }else{
                    maxindex = sizeof(currentLogs[i]);
                    shortLog = currentLogs[i];
                    longLog = currentLogs[j];
                }

                k=0;
                while(k < maxindex){
                    assert (shortLog[k] == longLog[k]), format("Log {0} is not a prefix of {1}", shortLog, longLog);
                    k=k+1;
                }
                
                j=j+1;
            }
            i=i+1;
        }
    }
}