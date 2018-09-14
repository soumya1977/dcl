$ ! QUOTA.COM
$ !------------------------------------------------------------------
$ !
$ ! This command file prompts the user for a process ID, and displays
$ ! information about that process, including quotas, remainingquotas
$ ! Image activations, Pagefile usage aproximations, page faults and
$ ! process state.  Any quota that falls below 50% will be highlighted
$ ! in the display.
$ !
$ !------------------------------------------------------------------
$ on control_y then exit
$ on error then exit
$ on warning then exit
$ margin       = "   "
$ gap          = " |   "
$ threshold    = 90
$ bar_line     = f$fao("!80*-")
$ blank_line   = f$fao("!80* ")
$ margin_line  = margin+f$fao("!36* ")+"|"+f$fao("!10* ")
$ heading      = "Resource    Unused   Quota %Remain "
$ esc[0,8]=27
$ start_screen = "''esc'"+"[2J"
$ cursor_dwell = "''esc'"+"[21;0H"
$ highlight    = "''esc'"+"[7m"
$ lights_off   = "''esc'"+"[0m"
$ ws = "write sys$output"
$ if p1 .EQS. "" then inquire/nopunc p1 "Please enter process id : "
$ pid          = p1
$ xyzxyz = f$getjpi(pid,"USERNAME") ! catches if PID is valid
$ on control_y then goto the_end
$ on error then goto the_end
$ on warning then goto the_end
$ ws start_screen
$ !
$ ! START MAIN PROGRAM
$ !
$ start_new_display:
$ esc[0,8]=27
$ ws "''esc'[0;0H''bar_line'"
$ ws " PROCESS MONITOR"+f$fao("!52* ")
$ ws blank_line
$ ws "''margin'       Process Name ''f$getjpi(pid,""PRCNAM"")'" + -
      "           Process Id ''pid'"
$ ws "''margin'       Images Invoked so far " + -
      f$fao("!#(#AS)",1,17,"''f$getjpi(pid,""IMAGECOUNT"")'") + -
         "Username   ''f$getjpi(pid,""USERNAME"")'"
$ ws blank_line
$ ws "Current image "+f$fao("!#(#AS)",1,60,f$getjpi(pid,"IMAGNAME"))
$ ws blank_line
$ ws "''margin'       Time ''f$time()'        Process State    "+ -
      f$getjpi(pid,"STATE") + "     "
$ ws "''margin'       Page faults "+f$fao("!#(#AS)",1,24,-
         "''f$getjpi(pid,""PAGEFLTS"")'")+"Pages Available "+f$fao("!#(#AS)",1,10,-
         "''f$getjpi(pid,""FREPTECNT"")'")
$ ws bar_line
$ ws "PROCESS RESOURCE QUOTAS"
$ ws "''margin'''heading'''gap'''heading'"
$ ws margin_line
$ set message /nofac/noid/notext/nosev
$ call do_line -
           "CPU limit " "CPUTIM" "CPULIM" "+" "Direct I/O" "DIOCNT" "DIOLM" "+"
$ call do_line -
           "Byte limit" "BYTCNT" "BYTLM"  "+" "Buff I/O  " "BIOCNT" "BIOLM" "+"
$ call do_line -
           "Timer Q   " "TQCNT"  "TQLM"   "+" "File Lim  " "FILCNT" "FILLM" "+"
$ call do_line "Page file " -
           "PAGFILCNT" "PGFLQUOTA"        "+" "Sub-proc's" "PRCCNT" "PRCLM" "-"
$ call do_line -
           "Enqueue   " "ENQCNT" "ENQLM"  "+" "AST limit" "ASTCNT" "ASTLM" "+"
$ call do_line "WS Current" "WSSIZE" "WSAUTHEXT" "-" "x"
$ set message /fac/id/text/sev
$ ws margin_line
$ ws bar_line
$ ws cursor_dwell
$ wait 00:00:02.00
$ goto start_new_display
$ ! the place for the cleanup of the terminal
$ the_end:
$ set message /fac/id/text/sev
$ set term/inq
$ ws cursor_dwell
$ exit
$ ! thats it !
$ ! SUBROUTINE to catch a quota and put into character string
$ get_1_quota:
$ SUBROUTINE
$ on error then exit 2
$ on warning then exit 2
$ on control_y then exit 2
$ spaces =    "                   "
$ if p1 .EQS. "x" then goto its_blank
$ remain =    f$getjpi(pid,"''p2'")
$ quota  =    f$getjpi(pid,"''p3'")
$ if p4 .EQS. "-" then remain = quota - remain
$ if quota  .NE. 0 then percent = (remain * 100)/quota
$ remain  = f$extract(0,8-F$length("''remain'"),"''spaces'")+"''remain'"
$ quota   = f$extract(0,8-F$length("''quota'"),"''spaces'")+"''quota'"
$ percent =f$extract(0,5-F$length("''percent'"),"''spaces'")+"''percent'"
$ message = "''p1'" + f$extract(0,10-F$length("''p1'"),"''spaces'")
$ alarm = lights_off
$ if percent .LT. threshold then alarm = highlight
$ if quota .EQ. 0 then alarm = lights_off
$ if quota .EQ. 0 then percent = "  ---"
$ return_string == -
      "''alarm'''message'''remain'''quota'''percent'%''lights_off'   "
$ exit
$ its_blank:
$ return_string == f$fao("!37* ")
$ exit
$ ENDSUBROUTINE
$ !
$ ! subroutine to format two string into a line
$ do_line:
$ SUBROUTINE
$ on error then exit 2
$ on warning then exit 2
$ on control_y then exit 2
$ call get_1_quota "''p1'" "''p2'" "''p3'" "''p4'"
$ text_line = return_string
$ call get_1_quota "''p5'" "''p6'" "''p7'" "''p8'"
$ text_line = "''margin'''text_line'''gap'''return_string'"
$ ws text_line
$ exit
$ ENDSUBROUTINE
