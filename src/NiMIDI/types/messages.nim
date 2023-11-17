type
    Message* = enum
        NoteOff,
        NoteOn,
        KeyPressure,
        ControlChange,
        ProgramChange,
        ChannelPressure,
        PitchWheel

proc matchMIDIEvent*(value: byte): Message =
    case value
    of 0x80:
        result = NoteOff
    of 0x90:
        result = NoteOn
    of 0xA0:
        result = KeyPressure
    of 0xB0:
        result = ControlChange
    of 0xC0:
        result = ProgramChange
    of 0xD0:
        result = ChannelPressure
    of 0xE0:
        result = PitchWheel
    else:
        raise newException(ObjectConversionDefect, "Could not parse channel voice event from given data")
