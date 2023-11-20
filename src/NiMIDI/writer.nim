import std/[streams]

import types

proc toRawHeader(header: Header): RawHeader =
    result.length = (uint32)header.length
    result.format = (uint16)header.format
    result.tracks = header.tracks
    case header.division
    of Metrical:
        result.division = 0 shl 15
        result.division += header.ticks
    of TimeCode:
        result.division = 1 shl 7
        result.division += (uint16)header.negativeSMPTE
        result.division = result.division shl 8
        result.division += (uint16)header.ticks

proc writeFixedLength(file: FileStream, value: SomeInteger, length: int) =
    ## Writes a fixed length integer to a file, padding left to the given length
    var buffer = value
    var copy = value
    var bytes = 0
    while copy > 0:
        copy = copy shr 8
        inc bytes
    var padding = length - bytes
    while padding > 0:
        file.write(0'u8)
        padding -= 1
    while bytes > 0:
        let data = (buffer.uint shr ((bytes - 1) * 8)) and 0xff
        file.write(data.uint8)
        dec bytes

proc toVarLen(value: uint): uint =
    result = value and 0x7f
    var copy = value shr 7
    while (copy > 0):
        result = result shl 8
        result = result or 0x80
        result += copy and 0x7f
        copy = copy shr 7

proc writeVarLen(file: FileStream, value: uint) =
    var buffer = toVarLen(value)
    while true:
        file.write(buffer.uint8 and 0xff)
        if (buffer and 0x80) != 0:
            buffer = buffer shr 8
        else:
            break

proc writeHeader*(file: FileStream, header: Header) =
    file.write("MThd")
    var rawHeader = toRawHeader(header)
    file.writeFixedLength(rawHeader.length, 4)
    file.writeFixedLength(rawHeader.format, 2)
    file.writeFixedLength(rawHeader.tracks, 2)
    file.writeFixedLength(rawHeader.division, 2)

proc fromNoteOctave(note: NoteOctave): uint8 =
    var intermediate = note.note.int
    intermediate += (note.octave.int + 1) * 12
    result = intermediate.uint8

proc writeMIDI*(file: FileStream, midi: MIDIEvent, running: bool) =
    ## Write MIDI event to file

    ## Little hack using enum int values to avoid having to write same code
    ## for each case
    let bundle = (0x80 + midi.kind.int * 0x10) + midi.channel
    if not running:
        file.writeFixedLength(bundle, 1)
    case midi.kind:
    of NoteOff, NoteOn:
        let data = midi.note.fromNoteOctave()
        file.writeFixedLength(data, 1)
        file.writeFixedLength(midi.velocity, 1)
    of KeyPressure:
        let data = midi.note.fromNoteOctave()
        file.writeFixedLength(data, 1)
        file.writeFixedLength(midi.pressure, 1)
    of ControlChange:
        file.writeFixedLength(midi.controller, 1)
        file.writeFixedLength(midi.value, 1)
    of ProgramChange:
        file.writeFixedLength(midi.program, 1)
    of ChannelPressure:
        file.writeFixedLength(midi.channelPressure, 1)
    of PitchWheel:
        let firstByte = midi.pitchChange and 0x7f
        let secondByte = (midi.pitchChange shr 7) and 0x7f
        file.writeFixedLength(firstByte, 1)
        file.writeFixedLength(secondByte, 1)

proc writeMeta*(file: FileStream, meta: MetaEvent, running: bool) =
    file.writeFixedLength(0xff, 1)
    let status = fromMetaEvent(meta.event)
    file.writeFixedLength(status, 1)
    file.writeVarLen(meta.data.len.uint8)
    for byte in meta.data:
        file.writeFixedLength(byte, 1)

proc writeSysex*(file: FileStream, sysex: SysexEvent) =
    discard

proc writeTrack*(file: FileStream, track: Track) =
    file.write("MTrk")
    file.writeFixedLength(track.length, 4)
    var lastEvent = track.events[0]
    for event in track.events:
        file.writeVarLen(event.dt)
        case event.event
        of MIDI:
            var running = false
            if lastEvent.event == MIDI:
                running = event.midi.kind == lastEvent.midi.kind
                running = running and event.midi.channel == lastEvent.midi.channel
            file.writeMIDI(event.midi, running)
        of Sysex:
            file.writeSysex(event.sysex)
        of Meta:
            var running = false
            if lastEvent.event == Meta:
                running = event.meta.event == lastEvent.meta.event
            file.writeMeta(event.meta, running)
        lastEvent = event

proc writeMIDIFile*(file: FileStream, midi: MIDIFile) =
    file.writeHeader(midi.header)
    for track in midi.tracks:
        file.writeTrack(track)
