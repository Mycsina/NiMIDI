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
    result.tracks = (uint16)(file.readBytes(2))
    result.division = (uint16)(file.readBytes(2))

proc parseHeader(raw: RawHeader): Header =
    result.length = (uint8)(raw.length)
    result.format = (FileFormat)(raw.format)
    result.tracks = raw.tracks
    # If MSB 1
    if (raw.division and 0x8000) == 1:
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
    let kind = matchMIDIEvent(status)
    let channel = int(data and 0x0F)
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
    if chunkName != "MTrk":
        raise newException(ObjectConversionDefect, "Couldn't find track chunk")
    result.length = file.readBytes(4)
    var start = file.getPosition
    while file.getPosition - start < int(result.length) - 1:
        var event: Event
        var deltaTime = fromVarLen(file)
        var status = (byte)file.readBytes(1)
        if status < 0x80:
            ## Handle running status
            var midi: MIDIEvent
            event = Event(event: MIDI, dt: deltaTime)
            midi = result.events[^1].midi
            # These messages can't use running status
            assert midi.kind != ProgramChange and midi.kind != ChannelPressure
            midi = newMIDIEvent(midi.kind, midi.channel, status, (byte)file.readBytes(1))
            event.midi = midi
        elif (int(status) and 0xF0) in 0x80..0xE0:
            ## Handle channel voice messages
            event = Event(event: MIDI, dt: deltaTime)
            event.midi = handleChannelVoice(file, status)
        elif status == 0xF0 or status == 0xF7:
            ## TODO: Handle sysex messages
            ## Handle system exclusive messages
            discard
        elif status == 0xFF:
            ## Handle meta messages
            event = Event(event: Meta, dt: deltaTime)
            event.meta = handleMeta(file)
        else:
            echo "Unsupported message found. Will try to continue parsing."
            let length = fromVarLen(file)
            var iter = 0'u
            while iter < length:
                discard file.readUint8()
                inc iter
        result.events.add(event)


proc parseFile*(file: FileStream): MIDIFile =
    let rawHeader = readHeader(file)
    result.header = parseHeader(rawHeader)
    result.tracks = newSeq[Track](int(result.header.tracks))
    for i in 0..<int(result.header.tracks):
        result.tracks[i] = readTrack(file)
