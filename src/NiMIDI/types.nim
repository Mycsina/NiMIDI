import macros

import types/[metaEvents, messages, notes]

export messages
export metaEvents
export notes

seeable:
    type
        FileFormat = enum
            SingleTrack,     # File has a single multi-channel track
            ConcurrentTrack, # File has 1+ simultaneous tracks of a sequence
            SequentialTrack, # File has 1+ sequential track patterns
        DivisionType = enum
            Metrical, TimeCode
        EventType = enum
            MIDI, Sysex, Meta

showAll:
    type
        RawHeader = object
            length: uint32
            format: uint16
            tracks: uint16
            division: uint16
        Header = object
            length: uint8
            format: FileFormat
            tracks: uint16
            division: DivisionType
            ticks: uint16
            negativeSMPTE: int
        SysexEvent = object
            length: int8
            data: seq[byte]
        MetaEvent = object
            event: MetaEventType
            data: seq[byte]

## TODO make showAll compatible with this
type
    MIDIEvent* = object
        channel*: int
        case kind*: Message
        of NoteOff, NoteOn:
            note*: NoteOctave
            velocity*: uint8
        of KeyPressure:
            notePressure*: NoteOctave
            pressure*: uint8
        of ControlChange:
            controller*: uint8
            value*: uint8
        of ProgramChange:
            program*: uint8
        of ChannelPressure:
            channelPressure*: uint8
        of PitchWheel:
            pitchChange*: int16
    Event* = object
        dt*: uint
        case event*: EventType
        of MIDI:
            midi*: MIDIEvent
        of Sysex:
            sysex*: SysexEvent
        of Meta:
            meta*: MetaEvent
    Track* = object
        length*: uint
        events*: seq[Event]
    MIDIFile* = object
        header*: Header
        tracks*: seq[Track]

proc newMIDIEvent*(kind: Message, channel: int, firstData: byte, secondData: byte): MIDIEvent =
    result = MIDIEvent(kind: kind, channel: channel)
    case kind
    of NoteOff, NoteOn:
        result.note = parseToNoteOctave(firstData)
        result.velocity = secondData
    of KeyPressure:
        result.notePressure = parseToNoteOctave(firstData)
        result.pressure = secondData
    of ControlChange:
        result.controller = firstData
        result.value = secondData
    of ProgramChange:
        result.program = firstData
    of ChannelPressure:
        result.channelPressure = firstData
    of PitchWheel:
        result.pitchChange = int16(firstData) or (int16(secondData) shl 7)


proc `$`*(t: Track): string =
    # pretty print a track
    for event in t.events:
        result.add $event.dt
        result.add ": "
        case event.event
        of MIDI:
            result.add $event.midi
        of Sysex:
            result.add $event.sysex
        of Meta:
            result.add $event.meta
        result.add "\n"
