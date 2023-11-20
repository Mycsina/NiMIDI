import std/[streams, os]

import ../src/niMIDI/[parser, writer]

let t = parseFile("tests/res/test.mid")
writeMIDI("tests/res/test2.mid", t)

let t1 = openFileStream("tests/res/test.mid", fmRead)
let t2 = openFileStream("tests/res/test2.mid", fmRead)

while not t1.atEnd or not t2.atEnd:
    let byte1 = t1.readUint8()
    let byte2 = t2.readUint8()
    if byte1 != byte2:
        echo "byte1: ", byte1, " byte2: ", byte2
        echo t1.getPosition
        raise newException(Defect, "Files are not equal. Byte mismatch at position " & $t1.getPosition)
    removeFile("tests/res/test2.mid")
