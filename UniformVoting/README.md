# UniformVoting in the P language

## To compile

```
pc -proj:UniformVoting.pproj
```

## Experiments ASYNC
```
pmc POutput/netcoreapp3.1/UniformVoting.dll -m PImplementation.TestAsync_ReorderDelaysTimeout.Execute -i 10000

pmc POutput/netcoreapp3.1/UniformVoting.dll -m PImplementation.TestAsync_ReorderDelaysTimeoutMessageDrop.Execute -i 10000

for i in {1..100}; do pmc POutput/netcoreapp3.1/UniformVoting.dll -m PImplementation.TestAsync_ReorderDelays.Execute -i 10000; done > experimentSeqArbitraryNetwork
```


## Experiments SYNC
```
pmc POutput/netcoreapp3.1/UniformVoting.dll -m PImplementation.TestSeq_ArbitraryNetwork.Execute -i 10000
```