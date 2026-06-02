
                         +----------------+
                         | TESTSTART (Start) |
                         +----------------+
                                |
                         V (1)
           +---------------------------------------------------+
           |                                                   |
   [TESTCLEAR] -> Clear Screen (ESC[2J) -> Cursor Home (ESC[H) -> PASS
           |                                                   |
           V                                                   V
    (Initial Setup)                            (Loop/Test Cycle)
           |                                                   |
           V                                                   V
   (Simple Status Display)                              (Advanced Tests)
           |                                                   |
           V
   (Wait for User Input)
           |
           V
       WAITKEY (Pause for Key)
           |
           V
+-----------+-----------------+--------------+-----------------+
| TESTCORNERS | (Test Complete) | TESTMIDDLE   | STATPR (Dynamic)  |
+-----------+-----------------+--------------+-----------------+
           \                      |                 /
            \-------------------+----------------/
                    |
                    V
       (Post-Test Actions)
           |
           V
+-----------+-----------+----------------+-----------------+
| WAITKEY   | (Wait for Key) | CLR2EOL        | OFFSTAT/Exit    |
+-----------+-----------+----------------+-----------------+
   |                                   |
   V                                   V
+---------------------------------------------------+
| Program Exits (WARMST to Flex) (End)             |
\---------------------------------------------------
