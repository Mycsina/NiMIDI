import std/[streams]

import types

proc byteArrToValue(buffer: openArray[byte], len: Natural): uint32 =
    for i in 0..<len:
        result = (result shl 8) + buffer[i]

proc readBytes(file: FileStream, len: Natural): uint64 =
    var buffer: array[8, byte]
    var iter = 0
    while iter < len:
        buffer[iter] = file.readUint8
        inc iter
    return byteArrToValue(buffer, len)

proc readBytesIntoArray(file: FileStream, len: Natural): seq[byte] =
    var buffer = newSeq[byte](len)
    var iter = 0
    while iter < len:
        buffer[iter] = file.readUint8
        inc iter
    return buffer

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
        file.writeData(addr(buffer), 1)
        if (buffer and 0x80) == 1:
            buffer = buffer shr 8
        else:
            break

proc fromVarLen(file: FileStream): uint =
    var buffer: uint
    result = file.readBytes(1)
    if (result and 0x80) > 0:
        ## 7-0 bits
        result = result and 0x7F
        buffer = file.readBytes(1)
        ## append 7-0 bits
        result = (result shl 7) + (buffer and 0x7F)
        while (buffer and 0x80) > 0:
            buffer = file.readBytes(1)
            result = (result shl 7) + (buffer and 0x7F)

proc readHeader(file: FileStream): RawHeader =
    var chunkName = file.readStr(4)
    if chunkName != "MThd":
        raise newException(ObjectConversionDefect, "MIDI file must start with header")
    result.length = (uint32)(file.readBytes(4))
    if result.length != 6:
        raise newException(ObjectConversionDefect, "MThd length should be 6")
    result.format = (uint16)(file.readBytes(2))
    result.numTrackChunks = (uint16)(file.readBytes(2))
    result.division = (uint16)(file.readBytes(2))

proc parseHeader(raw: RawHeader): Header =
    result.length = (uint8)(raw.length)
    result.format = (FileFormat)(raw.format)
    result.numTracks = raw.numTrackChunks
    # If MSB 1
    if (raw.division and 0x80) == 1:
        # 14-8 bits
        let value = (int)raw.division and 0x7F80
        case value
        of -24, -25, -29, -30:
            result.division = TimeCode
            result.negativeSMPTE = value
            # 7-0 bits
            result.ticks = raw.division and 0xFF
        else:
            raise newException(ObjectConversionDefect, "Invalid SMPTE format")

    else:
        result.division = Metrical
        ## 14-0 bits
        result.ticks = raw.division and 0x7FFF

proc handleChannelVoice(file: FileStream, data: byte): MIDIEvent =
    ## Handles channel voice messages. Returns number of bytes read
    let status = data and 0xF0
    var kind: Message
    var channel = int(data and 0x0F)
    case status
    of 0x80:
        kind = NoteOff
    of 0x90:
        kind = NoteOn
    of 0xA0:
        kind = KeyPressure
    of 0xB0:
        kind = ControlChange
    of 0xC0:
        kind = ProgramChange
    of 0xD0:
        kind = ChannelPressure
    of 0xE0:
        kind = PitchWheel
    else:
        raise newException(ObjectConversionDefect, "Could not parse channel voice event from given data")
    if kind == ProgramChange or kind == ChannelPressure:
        return newMIDIEvent(kind, channel, (byte)file.readBytes(1), 0)
    else:
        return newMIDIEvent(kind, channel, (byte)file.readBytes(1), (byte)file.readBytes(1))

proc handleMeta(file: FileStream): MetaEvent =
    ## Handles meta messages. Returns number of bytes read
    var event: MetaEvent
    let metaType = (byte)file.readBytes(1)
    var length: uint
    event.event = matchMetaEvent(metaType)
    length = fromVarLen(file)
    event.data = file.readBytesIntoArray(length)
    return event

proc readTrack(file: FileStream): Track =
    var chunkName = file.readStr(4)
    echo chunkName
    if chunkName != "MTrk":
        raise newException(ObjectConversionDefect, "Couldn't find track chunk")
    result.length = file.readBytes(4)
    var start = file.getPosition
    while file.getPosition - start < int(result.length) - 1:
        var event: Event
        var deltaTime = fromVarLen(file)
        var status = (byte)file.readBytes(1)
        ## Handle channel voice messages
        if (int(status) and 0xF0) in 0x80..0xE0:
            event = Event(event: MIDI, dt: deltaTime)
            event.midi = handleChannelVoice(file, status)
        elif status == 0xFF:
            ## Handle meta messages
            event = Event(event: Meta, dt: deltaTime)
            event.meta = handleMeta(file)
        elif status < 0x80:
            ## Handle running status
            var midi: MIDIEvent
            midi = result.events[^1].midi
            # These messages can't use running status
            assert midi.kind != ProgramChange and midi.kind != ChannelPressure
            midi = newMIDIEvent(midi.kind, midi.channel, status, (byte)file.readBytes(1))
            event.midi = midi
        else:
            echo "Unsupported message found. Will try to continue parsing."
            if status == 0xF0 or status == 0xF7:
                let length = fromVarLen(file)
                var iter = 0'u
                while iter < length:
                    discard file.readUint8()
                    inc iter
            else:
                raise newException(Defect, "Couldn't get the message length, quitting.")
        result.events.add(event)


proc parseFile(file: FileStream) =
    let rawHeader = readHeader(file)
    let header = parseHeader(rawHeader)
    var tracks = newSeq[Track](header.numTracks)
    for i in 0..<int(header.numTracks):
        tracks[i] = readTrack(file)
        echo tracks[i]
## TODO: expand macros type exporting bug

let handle = openFileStream("Test_-_test1.mid")
#let handle = openFileStream("print_h_5.mid")
parseFile(handle)
