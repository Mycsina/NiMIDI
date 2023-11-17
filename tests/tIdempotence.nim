import std/[streams, sequtils]

import ../src/NiMIDI/[parser, writer]

let hdl = openFileStream("tests/res/test.mid", fmRead)
let t = parseFile(hdl)
hdl.close()
let write = openFileStream("tests/res/test2.mid", fmWrite)
write.writeMIDIFile(t)
write.close()

let t1 = openFileStream("tests/res/test.mid", fmRead)
let t2 = openFileStream("tests/res/test2.mid", fmRead)

while not t1.atEnd or not t2.atEnd:
    let byte1 = t1.readUint8()
    let byte2 = t2.readUint8()
    if byte1 != byte2:
        echo "byte1: ", byte1, " byte2: ", byte2
        echo t1.getPosition
        break
