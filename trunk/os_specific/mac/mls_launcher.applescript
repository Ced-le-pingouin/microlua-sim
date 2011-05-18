--- Does the real work for launching MLS (wxLua) with arguments.
--
-- @param (list) args
on launchApp(args)
    global debugMode
    set debugMode to false

    set appName to "mls.app"
    
    -- construct mls app absolute path, based on this script path
    set scriptPath to POSIX path of (path to me)
    do shell script "dirname " & scriptPath
    set appPath to result & "/" & appName
    
    -- I don't really understand, when there's no arguments given on the
    -- command line, and the script is run with osascript, args is an empty
    -- *list* and all is fine when we try to use it as a string; *BUT* when 
    -- the script is compiled into an app, then run "without arguments", 
    -- then args is of type (=class) *script*, so using it as a string will 
    -- cause an error ("cannot transform script into string")
    -- So we have to check if the (stringified) class of args is "script"; it 
    -- means we have no args so we set the variable to an empty string
    set classOfArgs to (class of args as string)
    if (classOfArgs is "script") then
        set args to ""
    end
    
    debugBox("appPath: " & appPath & "\nargs: " & args)
    
    -- open mls app, passing the arguments as environment variables
    -- (MLS has been modified to support it)
    do shell script "MLS_SCRIPT_PATH='" & args & "' open " & appPath
end

--- Runs the application, entry point on double click or the "open" command.
--
-- @param (list) args I think args can only be passed to applications
--                    since Mac OS X 10.6(.2?), with "open" only (of course
--                    not on double click
on run(args)
    launchApp(args)
end run

--- Entry point of the application when a file is dropped on its icon.
--
-- @param (alias) droppedFile The path of the file that as been dropped.
--                            WARNING: it's a Mac "alias", not a unix path
on open(droppedFile)
    set droppedFilePath to POSIX path of droppedFile
    
    launchApp(droppedFilePath)
end open

on debugBox(message)
    global debugMode
    
    if debugMode then
        messageBox(message)
    end if
end

on messageBox(message)
    tell application "System Events"
        activate
        display dialog message
    end tell
end messageBox
