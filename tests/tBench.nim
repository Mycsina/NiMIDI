import std/[streams, sequtils, times, strformat]

import ../src/niMIDI/[parser, writer]

let hdl = openFileStream("tests/res/test.mid", fmRead)
let start = getTime()
let t = parseFile(hdl)
let stop = getTime()
var events = 0
for track in t.tracks:
  events += track.events.len
echo fmt"Parsed {events} events in {stop - start}"
echo fmt"Events per second: {events / (stop - start).inMilliseconds * 1000}"
