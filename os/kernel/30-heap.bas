'The heap: the only allocator, with handles and compaction.

'---------------------------------------------------------------------------
'The heap. One array, blocks packed from word 0 with no gaps. A block is used
'through its handle (1 to HeapMax), so the heap can move it: a free slides every
'block above it down. There is no separate collection pass.
'---------------------------------------------------------------------------
'A block of n words of a kind, zeroed, owned by a window. Returns its handle.
'When the heap or the handles are full it returns 0 and sets OomFlag.
'@api Heap | A zeroed block of `n` words of a kind (KData for app data) owned by a window. Returns its handle, 0 and OomFlag when full.
FUNCTION MemAlloc (owner, kind, n)
MemAlloc = 0
IF n < 1 THEN EXIT FUNCTION
IF HeapTop + n <= HeapWords + 1 THEN
        FOR h = 1 TO HeapMax
                IF HSize(h) = 0 THEN
                        HBase(h) = HeapTop
                        HSize(h) = n
                        HOwner(h) = owner
                        HKind(h) = kind
                        FOR i = HeapTop TO HeapTop + n - 1
                                Heap(i) = 0
                        NEXT
                        HeapTop = HeapTop + n
                        MemAlloc = h
                        EXIT FUNCTION
                END IF
        NEXT
END IF
OomFlag = -1
END FUNCTION

'@api Heap | Free one block and close the gap.
SUB MemFree (h)
n = HSize(h)
IF n = 0 THEN EXIT SUB
b = HBase(h)
FOR i = b TO HeapTop - n - 1
        Heap(i) = Heap(i + n)
NEXT
FOR k = 1 TO HeapMax
        IF HSize(k) > 0 AND HBase(k) > b THEN HBase(k) = HBase(k) - n
NEXT
HeapTop = HeapTop - n
HSize(h) = 0
HKind(h) = 0
HText(h) = ""
END SUB

'Word f of a window or control block, and set it. No range check: the kernel
'knows its own blocks. An app goes through MemGet and MemSet.
FUNCTION HGet (h, f)
HGet = Heap(HBase(h) + f)
END FUNCTION

SUB HSet (h, f, v)
Heap(HBase(h) + f) = v
END SUB

'Free every block a window owns (what closing an instance does).
'@api Heap | Free every block a window owns.
SUB MemFreeAll (owner)
FOR h = 1 TO HeapMax
        IF HSize(h) > 0 AND HOwner(h) = owner THEN MemFree h
NEXT
END SUB

'Word i of a block. An index outside the block reads 0 and writes nothing.
'@api Heap | Word `i` of a block (0 when out of range).
FUNCTION MemGet (h, i)
MemGet = 0
IF h >= 1 AND h <= HeapMax THEN IF i >= 0 AND i < HSize(h) THEN MemGet = Heap(HBase(h) + i)
END FUNCTION

'@api Heap | Set word `i` of a block (ignored when out of range).
SUB MemSet (h, i, v)
IF h >= 1 AND h <= HeapMax THEN IF i >= 0 AND i < HSize(h) THEN Heap(HBase(h) + i) = v
END SUB
