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

proc fromMetaEvent*(value: MetaEventType): byte =
    case value
    of SeqNumber:
        result = 0x00
    of Text:
        result = 0x01
    of CopyRight:
        result = 0x02
    of TrackName:
        result = 0x03
    of InstrumentName:
        result = 0x04
    of Lyric:
        result = 0x05
    of Marker:
        result = 0x06
    of CuePoint:
        result = 0x07
    of ChannelPrefix:
        result = 0x20
    of EndOfTrack:
        result = 0x2F
    of SetTempo:
        result = 0x51
    of SMPTEOffset:
        result = 0x54
    of TimeSignature:
        result = 0x58
    of KeySignature:
        result = 0x59
    of SequencerSpecific:
        result = 0x7F
    else:
        result = 0x00