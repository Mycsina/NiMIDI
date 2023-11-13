import std/[macros]

import union

import metaEvents
import macros
import messages

seeable:
    type
        FileFormat = enum
            SingleTrack,     # File has a single multi-channel track
            ConcurrentTrack, # File has 1+ simultaneous tracks of a sequence
            SequentialTrack, # File has 1+ sequential track patterns
        DivisionType = enum
            Metrical, TimeCode

showAll:
    type
        RawHeader = object
            length: uint32
            format: uint16
            numTrackChunks: uint16
            division: uint16
        Header = object
            length: uint8
            format: FileFormat
            numTracks: uint16
            division: DivisionType
            ticks: uint16
            negativeSMPTE: int
        MIDIEvent = object
            message: Message
            channel: uint8
            firstData: byte
            secondData: byte
        SysexEvent = object
            length: int8
            data: seq[byte]
        MetaEvent = object
            event: MetaEventType
            data: seq[byte]
        Event* = object
            dt*: uint
            event*: union(MIDIEvent | SysexEvent | MetaEvent)
        Track = object
            length: uint
            events: seq[Event]
