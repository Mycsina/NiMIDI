type
    Note* = enum
        C,
        CSharp,
        D,
        DSharp,
        E,
        F,
        FSharp,
        G,
        GSharp,
        A,
        ASharp,
        B
    Octave* = enum
        MinusOne = -1,
        Zero,
        One,
        Two,
        Three,
        Four,
        Five,
        Six,
        Seven,
        Eight,
        Nine
    NoteOctave* = tuple[note: Note, octave: Octave]

proc parseToNoteOctave*(data: byte): NoteOctave =
    let value = data.int
    let note = Note(value mod 12)
    let octave = Octave(value div 12 - 1)
    return (note, octave)
