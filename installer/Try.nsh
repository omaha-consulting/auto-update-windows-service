!macro _Try Fn
    Call ${Fn}
    ; ${IfNot} ${Errors} instead of ${If} ${Errors} ... ${Else} would be nicer.
    ; But ${Errors} clears the error flag and then we wouldn't be able to check
    ; for errors in _OnError below.
    ${If} ${Errors}
        SetErrors
    ${Else}
!macroend
!define Try `!insertmacro _Try`

!macro _OnError Rollback
    ${EndIf}
    ${If} ${Errors}
        Call ${Rollback}
        SetErrors
    ${EndIf}
!macroend
!define OnError `!insertmacro _OnError`

!macro _AbortIfErrors
    ${If} ${Errors}
        Pop $0
        DetailPrint $0
        Abort "Installation failed."
    ${EndIf}
!macroend
!define AbortIfErrors `!insertmacro _AbortIfErrors`