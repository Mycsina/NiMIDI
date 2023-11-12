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
