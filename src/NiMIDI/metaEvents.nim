type
    MetaEventType* = enum
        SeqNumber,
        Text,
        Copyright,
        TrackName,
        InstrumentName,
        Lyric,
        Marker,
        CuePoint,
        ChannelPrefix,
        EndOfTrack,
        SetTempo,
        SMPTEOffset,
        TimeSignature,
        KeySignature,
        SequencerSpecific,
        Unknown

proc matchMetaEvent*(value: byte): MetaEventType =
    case value
    of 0x00:
        result = SeqNumber
    of 0x01:
        result = Text
    of 0x02:
        result = CopyRight
    of 0x03:
        result = TrackName
    of 0x04:
        result = InstrumentName
    of 0x05:
        result = Lyric
    of 0x06:
        result = Marker
    of 0x07:
        result = CuePoint
    of 0x20:
        result = ChannelPrefix
    of 0x2F:
        result = EndOfTrack
    of 0x51:
        result = SetTempo
    of 0x54:
        result = SMPTEOffset
    of 0x58:
        result = TimeSignature
    of 0x59:
        result = KeySignature
    of 0x7F:
        result = SequencerSpecific
    else:
        result = Unknown
