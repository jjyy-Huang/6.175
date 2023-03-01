
- six stage without cache

    Benchmark tower
    Cycles = 63390
    Insts  = 4168
    Benchmark median
    Cycles = 71775
    Insts  = 4243
    Benchmark multiply
    Cycles = 323265
    Insts  = 20893
    Benchmark qsort
    Cycles = 2001330
    Insts  = 123496
    Benchmark vvadd
    Cycles = 36135
    Insts  = 2408

- six stage with blocking cache

    Benchmark tower
    Cycles = 19620
    Insts  = 4168
    Benchmark median
    Cycles = 7476
    Insts  = 4243
    Benchmark multiply
    Cycles = 25771
    Insts  = 20893
    Benchmark qsort
    Cycles = 204295
    Insts  = 123496
    Benchmark vvadd
    Cycles = 4030
    Insts  = 2408

- six stage without cache (sample)
    Benchmark tower
    Cycles = 35868
    Insts  = 4168
    Benchmark median
    Cycles = 30688
    Insts  = 2712
    Benchmark multiply
    Cycles = 234016
    Insts  = 26751
    Benchmark qsort
    Cycles = 111751
    Insts  = 11013
    Benchmark vvadd
    Cycles = 8288
    Insts  = 1034


- six stage with blocking cache (sample)
    Benchmark tower
    Cycles = 21608 -> 20470
    Insts  = 4171
    Benchmark median
    Cycles = 10398 -> 9447
    Insts  = 4243
    Benchmark multiply
    Cycles = 43331 -> 34086
    Insts  = 20893
    Benchmark qsort
    Cycles = 296599 -> 255414
    Insts  = 123496
    Benchmark vvadd
    Cycles = 5680 -> 4653
    Insts  = 2408