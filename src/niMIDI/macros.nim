import std/[macros]

macro seeable*(stmtlist: typed) =
    for typeSection in stmtlist:
        for typeDef in typeSection:
            if typeDef[0].kind != nnkPostfix:
                var prototype = newNimNode(nnkPostfix, typeDef[0])
                prototype.add ident("*")
                prototype.add typeDef[0]
                typeDef[0] = prototype
    return stmtlist


macro public*(stmtlist: typed) =
    ## Makes all types defined inside it have public variables.
    ##
    ## ```
    ## public:
    ##   type
    ##     A = object
    ##       a*: int
    ##       b: int
    ## ```
    ##  is transformed into
    ## ```
    ## type
    ##   A = object
    ##     a*: int
    ##     b*: int
    for typeSection in stmtlist:
        for typeDef in typeSection:
            let objTy = typeDef[2]
            objTy.expectKind(nnkObjectTy)
            let recList = objTy[2]
            recList.expectKind(nnkRecList)
            for iDefs in recList:
                if iDefs[0].kind != nnkPostfix:
                    var prototype = newNimNode(nnkPostfix, iDefs[0])
                    prototype.add ident("*")
                    prototype.add iDefs[0]
                    iDefs[0] = prototype
    return stmtlist

# TODO: make above macros compoundable
macro showAll*(stmtlist: typed) =
    for typeSection in stmtlist:
        for typeDef in typeSection:
            if typeDef[0].kind != nnkPostfix:
                var prototype = newNimNode(nnkPostfix, typeDef[0])
                prototype.add ident("*")
                prototype.add typeDef[0]
                typeDef[0] = prototype
            let objTy = typeDef[2]
            objTy.expectKind(nnkObjectTy)
            let recList = objTy[2]
            recList.expectKind(nnkRecList)
            for iDefs in recList:
                if iDefs[0].kind != nnkPostfix:
                    var prototype = newNimNode(nnkPostfix, iDefs[0])
                    prototype.add ident("*")
                    prototype.add iDefs[0]
                    iDefs[0] = prototype
    return stmtlist
