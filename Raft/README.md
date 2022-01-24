# Raft in the P language

## To compile

```
pc -proj:Raft.pproj
```
## Experiments ASYNC
```
pmc POutput/netcoreapp3.1/Raft.dll -m PImplementation.TestRaftAsync.Execute -i 10000
```

## Experiments SEQ
```
pmc POutput/netcoreapp3.1/Raft.dll -m PImplementation.TestRaftSeq.Execute -i 10000
```