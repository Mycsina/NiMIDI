type
    Message* = enum
        NoteOff,
        NoteOn,
        KeyPressure,
        ControlChange,
        ProgramChange,
        ChannelPressure,
        PitchWheel
    MessageType* = enum
        ChannelVoice,
        SysCommon,
        SysRealTime
