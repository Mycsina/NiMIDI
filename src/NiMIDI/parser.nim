import std/[streams]

import union, stew/byteutils

import macros, messages, types

proc byteArrToValue(buffer: openArray[byte], len: Natural): uint32 =
    for i in 0..<len:
        result = (result shl 8) + buffer[i]

proc readBytes(file: FileStream, len: Natural): uint64 =
    var buffer: array[8, byte]
    discard file.readData(addr(buffer), len)
    return byteArrToValue(buffer, len)

proc readBytesIntoArray(file: FileStream, len: Natural): seq[byte] =
    var buffer = newSeq[byte](len)
    discard file.readData(addr(buffer), len)
    return buffer

proc toVarLen(value: uint): uint =
    result = value and 0x7f
    var copy = value shr 7
    while (copy > 0):
        result = result shl 8
        result = result or 0x80
        result += copy and 0x7f
        copy = copy shr 7

proc varLenSize(value: uint): int =
    var size = 1
    var copy = value
    while copy > 0x7f:
        size += 1
        copy = copy shr 7
    return size

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
    if result shl 7 > 0:
        ## 7-0 bits
        result = result and 0x7F
        buffer = file.readBytes(1)
        ## append 7-0 bits
        result = result shl 7 + (buffer and 0x7F)
        while buffer shl 7 > 0:
            buffer = file.readBytes(1)
            result = result shl 7 + (buffer and 0x7F)

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

proc handleChannelVoice(event: var MIDIEvent, file: FileStream, data: byte): int =
    ## Handles channel voice messages. Returns number of bytes read
    let status = data and 0xF0
    event.channel = data and 0x0F
    event.firstData = (byte)file.readBytes(1)
    result = 2
    case status
    of 0x8:
        event.message = NoteOff
        event.secondData = (byte)file.readBytes(1)
    of 0x9:
        event.message = NoteOn
        event.secondData = (byte)file.readBytes(1)
    of 0xA:
        event.message = KeyPressure
        event.secondData = (byte)file.readBytes(1)
    of 0xB:
        event.message = ControlChange
        event.secondData = (byte)file.readBytes(1)
    of 0xC:
        event.message = ProgramChange
        result -= 1
    of 0xD:
        event.message = ChannelPressure
        result -= 1
    of 0xE:
        event.message = PitchWheel
        event.secondData = (byte)file.readBytes(1)
    else:
        raise newException(ObjectConversionDefect, "Could not parse channel voice event from given data")

proc handleMeta(event: var MetaEvent, file: FileStream): int =
    ## Handles meta messages. Returns number of bytes read
    let metaType = file.readBytes(1)
    result = 1
    case metaType
    of 0x00:
        event.event = SeqNumber
        event.data = file.readBytesIntoArray(2)
        result += 2
    of 0x01:
        event.event = Text
        let length = fromVarLen(file)
        event.data = file.readBytesIntoArray(length)
        result += varLenSize(length)
    of 0x02:
        event.event = CopyRight
        let length = fromVarLen(file)
        event.data = file.readBytesIntoArray(length)
        result += varLenSize(length)
    of 0x03:
        event.event = TrackName
        let length = fromVarLen(file)
        event.data = file.readBytesIntoArray(length)
        result += varLenSize(length)
    of 0x04:
        event.event = InstrumentName
        let length = fromVarLen(file)
        event.data = file.readBytesIntoArray(length)
        result += varLenSize(length)
    of 0x05:
        event.event = Lyric
        let length = fromVarLen(file)
        event.data = file.readBytesIntoArray(length)
        result += varLenSize(length)
    of 0x06:
        event.event = Marker
        let length = fromVarLen(file)
        event.data = file.readBytesIntoArray(length)
        result += varLenSize(length)
    of 0x07:
        event.event = CuePoint
        let length = fromVarLen(file)
        event.data = file.readBytesIntoArray(length)
        result += varLenSize(length)
    of 0x20:
        event.event = ChannelPrefix
        event.data = file.readBytesIntoArray(1)
        result += 1
    of 0x2F:
        event.event = EndOfTrack
        result += 0
    of 0x51:
        event.event = SetTempo
        event.data = file.readBytesIntoArray(3)
        result += 3
    of 0x54:
        event.event = SMPTEOffset
        event.data = file.readBytesIntoArray(5)
        result += 5
    of 0x58:
        event.event = TimeSignature
        event.data = file.readBytesIntoArray(4)
        result += 4
    of 0x59:
        event.event = KeySignature
        event.data = file.readBytesIntoArray(2)
        result += 2
    of 0x7F:
        event.event = SequencerSpecific
        let length = fromVarLen(file)
        event.data = file.readBytesIntoArray(length)
        result += varLenSize(length)
    else:
        event.event = Unknown
        let length = fromVarLen(file)
        event.data = file.readBytesIntoArray(length)
        result += varLenSize(length)

proc readTrack(file: FileStream): Track =
    var chunkName = file.readStr(4)
    echo chunkName
    if chunkName != "MTrk":
        raise newException(ObjectConversionDefect, "Unexpected header chunk read")
    result.length = file.readBytes(4)
    var bytesRead = 0
    while bytesRead < int(result.length) - 1:
        var event: Event
        var deltaTime = fromVarLen(file)
        bytesRead += varLenSize(deltaTime)
        var status = (byte)file.readBytes(1)
        bytesRead += 1
        ## Handle channel voice messages
        if int(status and 0xF0) in 0x8..0xE:
            var midi: MIDIEvent
            bytesRead += handleChannelVoice(midi, file, status)
            event.event <- midi
        elif status == 0xFF:
            ## Handle meta messages
            var meta: MetaEvent
            bytesRead += handleMeta(meta, file)
            event.event <- meta
        else:
            echo status
            echo "Ignoring unknown event"
        result.events.add(event)


proc parseFile(file: FileStream) =
    let rawHeader = readHeader(file)
    let header = parseHeader(rawHeader)
    var tracks = newSeq[Track](header.numTracks)
    for i in 0..<int(header.numTracks):
        tracks[i] = readTrack(file)
    echo tracks[0]
## TODO: expand macros type exporting bug

let handle = openFileStream("print_h_5.mid")
parseFile(handle)
