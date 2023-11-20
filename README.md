niMIDI is a library for parsing and writing MIDI files. Very much a work in progress, so function names and types are subject to change.

## Installation
```bash
nimble install niMIDI
```

## Usage
```nim
import niMIDI

let midi = parseFile("test.mid")
echo midi.header
```
`
(length: 6, format: ConcurrentTrack, tracks: 5, division: Metrical, ticks: 480, negativeSMPTE: 0)
`
```nim
writeMIDI("test.mid", midi)
```


## TODO
- [ ] Add support for sysex messages
- [ ] Fix visibility macros
- [ ] Make it easier to manipulate the parsed MIDI data