import lkml
from time import time_ns
from rich import print
FILE_PATH = "/Users/ladvien/rusty_looker/src/test.lkml"

with open(FILE_PATH, "r") as f:
    lookml = f.read()

startTime = time_ns() // 1_000_000 

result = lkml.load(lookml)

executionTime = (time_ns() // 1_000_000) - startTime
print('Execution time in seconds: ' + str(executionTime))
print([item for item in result["views"] if item.keys(0) == "dimensions"])