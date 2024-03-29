-------------------------------------------------------------------------------
-- GUI management, using wxWidgets.
--
-- @class module
-- @name clp.mls.Gui
-- @author Ced-le-pingouin <Ced.le.pingouin@gmail.com>
-------------------------------------------------------------------------------

--  Copyright (C) 2009-2011 Cédric FLOQUET
--
--  This file is part of Micro Lua DS Simulator.
--
--  Micro Lua DS Simulator is free software: you can redistribute it and/or modify
--  it under the terms of the GNU General Public License as published by
--  the Free Software Foundation, either version 3 of the License, or
--  (at your option) any later version.
--
--  Micro Lua DS Simulator is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--  GNU General Public License for more details.
--
--  You should have received a copy of the GNU General Public License
--  along with Micro Lua DS Simulator.  If not, see <http://www.gnu.org/licenses/>.

require "wx"
local Class = require "clp.Class"
local Sys = require "clp.mls.Sys"

local M = Class.new()

M.MENU_OPEN  = wx.wxID_OPEN
M.MENU_EXIT  = wx.wxID_EXIT
M.MENU_ABOUT = wx.wxID_ABOUT
M.MENU_SHOW_KEY_BINDINGS = wx.wxNewId()

--- Constructor.
--
-- Creates the main window, the status bars, and the surface representing the 
-- screens, but does NOT AUTOMATICALLY SHOW THE WINDOW, so you have to call 
-- showWindow() later, preferably after having created the menus, so the 
-- vertical size would be correct
--
-- @param width (number) The width of the SCREEN SURFACE (not the window, which 
--                       will ultimately be adapted around the screen
-- @param height (number) The height of the SCREEN SURFACE (not the window, 
--                        which will ultimately be adapted around the screen)
-- @param windowTitle (string) The title to be displayed in the main window 
--                             title bar
-- @param iconPath (string) The path to a PNG image file that will be converted
--                          to an icon for the main app window. MUST BE 32x32 or
--                          16x16 otherwise Windows doesn't like it.
--                          When nil, "icon.png" will be tried as well
-- @param path (string) An optional directory to search for the GUI icons
--
-- @see _createWindow
-- @see _createSurface
-- @see _createInfoLabels
-- @see _createStatusBar
function M:ctr(width, height, windowTitle, iconPath, path)
    self._width, self._height, self._windowTitle = width, height, windowTitle
    self._path = path or ""
    
    iconPath = iconPath or "icon.png"
    iconPath, found = Sys.getFileWithPath(iconPath, self._path)
    Mls.logger:debug("loading app icon "..iconPath, "gui")
    self._icon = found and wx.wxIcon(iconPath, wx.wxBITMAP_TYPE_PNG)
                        or nil
    
    self:_createWindow()
    
    self:_createSurface()
    self:_createInfoLabels()
    
    self:_createStatusBar()
end

--- Initializes the main app window.
function M:_createWindow()
    Mls.logger:debug("creating main window", "gui")
    
    self._window = wx.wxFrame(
        wx.NULL,                    -- no parent for toplevel windows
        wx.wxID_ANY,                -- don't need a wxWindow ID
        self._windowTitle,          -- caption on the frame
        wx.wxDefaultPosition,       -- let system place the frame
        wx.wxSize(self._width, self._height),   -- set the size of the frame
        wx.wxDEFAULT_FRAME_STYLE    -- use default frame styles
        --wx.wxCAPTION + wx.wxMINIMIZE_BOX + wx.wxCLOSE_BOX + wx.wxSYSTEM_MENU
        --+ wx.wxCLIP_CHILDREN
    )
    
    Mls.logger:debug("setting main window icon", "gui")
    if self._icon then self._window:SetIcon(self._icon) end
    
    self._topSizer = wx.wxBoxSizer(wx.wxVERTICAL)
end

--- Creates the surface that will represent the screens, which MLS will draw to.
function M:_createSurface()
    Mls.logger:debug("creating screens' drawing surface", "gui")
    
    local panel = wx.wxPanel(self._window, wx.wxID_ANY, wx.wxDefaultPosition,
                             wx.wxSize(self._width, self._height), 0)
    
    --panel:SetBackgroundColour(wx.wxBLACK)
    self._topSizer:Add(panel, 1, wx.wxSHAPED + wx.wxALIGN_CENTER)
    
    self._surface = panel
end

--- Creates the status bar, which will be used to display the current script 
--  status and timing info.
function M:_createStatusBar()
    Mls.logger:debug("creating status bar", "gui")
    
    self._statusBar = self._window:CreateStatusBar(2)
    self._statusBar:SetStatusWidths{ -1, -2 }
end

--- Creates zones to display information, because the status bar is too short.
function M:_createInfoLabels()
    Mls.logger:debug("creating additional information labels", "gui")
    
    self._scriptNameInfo = wx.wxStaticText(self._window, wx.wxID_ANY, "")
    
    self._topSizer:Add(self._scriptNameInfo, 0, wx.wxALIGN_CENTER_HORIZONTAL)
end

--- Creates a GUI text console.
--
-- It will try to give the focus back to the main window whenever it is 
-- activated, so it never looks "focused". This is hard because of OS and 
-- window managers differences
--
-- Also, the closing of the window won't destroy it, it'll only hide it
function M:_createConsole()
    Mls.logger:debug("creating logging console", "gui")
    
    local windowPos = self._window:GetScreenPosition()
    local windowSize = self._window:GetSize()
    local x, y = windowPos:GetX() + windowSize:GetWidth() + 20, windowPos:GetY()
    local w, h = windowSize:GetWidth() + 100, windowSize:GetHeight()
    
    self._console = wx.wxFrame(
        wx.NULL, --self._window,
        wx.wxID_ANY,
        self._windowTitle.." - Console",
        wx.wxPoint(x, y),
        wx.wxSize(w, h),
        wx.wxDEFAULT_FRAME_STYLE
    )
    
    self._console:SetIcon(self._icon)
    
    -- give back the focus immediately to the main window
    self._console:Connect(wx.wxEVT_ACTIVATE, function(event)
        -- only force focus on main window if we're *activating* the console
        if not event:GetActive() then
            event:Skip()
            return
        end
        
        -- if we do this in Windows, we can't even scroll the console
        if Sys.getOS() ~= "Windows" then self:focus() end
    end)
    
    -- prevent the closing of the window, hide it instead
    self._console:Connect(wx.wxEVT_CLOSE_WINDOW, function(event)
        if event:CanVeto() then
            event:Veto()
            self._console:Hide()
        else
            event:Skip()
        end
    end)
    
    local consoleSizer = wx.wxBoxSizer(wx.wxVERTICAL)
    
    self._consoleText = wx.wxTextCtrl(
        self._console, wx.wxID_ANY, "" , wx.wxDefaultPosition, wx.wxDefaultSize,
        wx.wxTE_READONLY + wx.wxTE_MULTILINE
    )
    consoleSizer:Add(self._consoleText, 1, wx.wxEXPAND)
    
    self._console:SetSizer(consoleSizer)
end

--- Initializes the main window menu bar.
--
-- @param menus (table) A list of menus and their items. Each entry is itself 
--                      a table with key/value entries, the two allowed keys 
--                      being "caption" (string, the menu caption with an "&" 
--                      character before the letter to be used as a shortcut) 
--                      and "items" (table).
--                      The latter is again a table of key/value entries, with 
--                      allowed keys "caption" (string, the item caption), "id"
--                      (number, with some predefined constants in this class 
--                      for standard actions), and "callback" (function, to be
--                      called whenever this menu item is chosen)
function M:createMenus(menus)
    Mls.logger:debug("creating menus", "gui")
    
    local menuBar = wx.wxMenuBar()
    
    for _, menu in ipairs(menus) do
        local wxMenu = wx.wxMenu()
        for _, item in ipairs(menu.items) do
            self:_setDefaultShortcut(item)
            wxMenu:Append(item.id, item.caption)
            self._window:Connect(item.id, wx.wxEVT_COMMAND_MENU_SELECTED,
                                 item.callback)
        end
        menuBar:Append(wxMenu, menu.caption)
    end
    
    self._window:SetMenuBar(menuBar)
    self._menuBar = menuBar
end

--- Sets the main window to the correct size, centers it, then displays it.
function M:showWindow()
    Mls.logger:debug("showing main window", "gui")
    
    wx.wxGetApp():SetTopWindow(self._window)
    -- make client height of main window correct (menu + screens + status bar)
    self._window:SetSizerAndFit(self._topSizer)
    self._window:Center()
    self._window:Show()
    
    self:_createConsole()
    
    self:focus()
end

--- Increments the zoom factor (default = 1x) *if* fullscreen is disabled *and*
--  the screen area is large enough to display the GUI with the new zoom factor.
function M:incZoomFactor()
    if self._window:IsFullScreen() then return end
    
    local surfaceWidth, surfaceHeight = self._surface:GetSizeWH()
    local windowWidth, windowHeight = self._window:GetSizeWH()
    local decorationWidth = windowWidth - surfaceWidth
    local decorationHeight = windowHeight - surfaceHeight
    
    -- zoom factor is based on width only, because aspect ratio is kept anyway
    local zoomFactor = math.floor(surfaceWidth / self._width)
    -- we increase zoom factor by integer for now (1x, 2x, ...)
    zoomFactor = zoomFactor + 1
    
    -- compute new width and height for the surface...
    local newSurfaceWidth = self._width * zoomFactor
    local newSurfaceHeight = self._height * zoomFactor
    
    -- ...and for the window
    local newWindowWidth = newSurfaceWidth + decorationWidth
    local newWindowHeight = newSurfaceHeight + decorationHeight
    
    --  get available "desktop" area
    local displayNum = wx.wxDisplay.GetFromWindow(self._window)
    local display = wx.wxDisplay(displayNum)
    local availableWidth = display:GetClientArea():GetWidth()
    local availableHeight = display:GetClientArea():GetHeight()
    
    -- if new width or height is larger than what's available, get back to 1x
    if newWindowWidth > availableWidth or newWindowHeight > availableHeight then
        newSurfaceWidth, newSurfaceHeight = self._width, self._height
        zoomFactor = 1
    end
    
    -- set min size for Layout, then Fit the window...
    self._surface:SetMinSize(wx.wxSize(newSurfaceWidth, newSurfaceHeight))
    self._window:Layout()
    wx.wxYield()
    self._window:Fit()
    wx.wxYield()
    -- ...but re-set min size to original after Layout/Fit
    self._surface:SetMinSize(wx.wxSize(self._width, self._height))
    
    Mls.logger:info("setting screens' zoom factor to "..zoomFactor, "gui")
end

function M:switchFullScreen()
    -- on wxLua, ShowFullScreen is only available on Windows
    if Sys.getOS() ~= "Windows" then return end
    
    self._window:ShowFullScreen(not self._window:IsFullScreen())
end

--- @return (wxWindow)
function M:getWindow()
    return self._window
end

--- Changes what the GUI views as the "screen surface".
--
-- @param (wxPanel|wxGLCanvas)
function M:setSurface(surface)
    -- hide the old surface so the sizer will layout correctly
    self._surface:Hide()
    
    -- add new surface to top sizer (autosizing and keeping ratio, centered)
    self._topSizer:Insert(0, surface, 1, wx.wxSHAPED + wx.wxALIGN_CENTER)
    
    -- apparently, Mac needs this to initially show the new surface (for GL)
    self._window:Fit()
    
    -- the new surface is now the one we reference
    self._surface = surface
    
    --[[
    ﻿self._surface:DragAcceptFiles(true)
	self._surface:Connect(wx.wxEVT_DROP_FILES, function(event) print(event:GetFiles()[1]) end)
	]]
end

--- @return (wxPanel|wxGLCanvas)
function M:getSurface()
    return self._surface
end

--- Writes a line of text in the GUI console
--
-- @param text (string)
function M:writeToConsole(text)
    self._consoleText:AppendText(tostring(text).."\n")
end

--- Clears the GUI console
function M:clearConsole()
    self._consoleText:Clear()
end

--- Creates a closure that allows other objects to call it, but still write 
-- to this instance of the console (useful for event handlers that don't have
-- any ref to this object).
function M:getConsoleWriter()
    return function(text) self:writeToConsole(text) end
end

--- Shows or hide the GUI console.
--
-- @param visibility (boolean) If given, sets the visibility of the console 
--                             accordingly (true = visible, false = hidden). 
--                             If nil, the console visibility is switched (i.e.
--                             shown if currently hidden, hidden if currently 
--                             visible)
function M:showOrHideConsole(visibility)
    if not self._console then return end
    
    local visible = visibility ~= nil and visibility
                                       or not self._console:IsShown()
    self._console:Show(visible)
    
    if visible then self:focus() end
end

--- Gives the focus back to the main window *and* the screens/surface.
function M:focus()
    local os = Sys.getOS()
    -- in GTK, a simple SetFocus on the window doesn't work, we need Raise(),
    -- but on Windows it has some unwanted side effects when dialogs overlap
    if os == "Unix" then
        self._window:Raise()
    -- this seems to have no effect on the Mac, so do it only in Windows
    elseif os == "Windows" then
        self._window:SetFocus()
    end
    
    self._surface:SetFocus()
end

--- Displays a text representing the script name at the right place in the GUI.
--
-- @param text (string)
function M:displayScriptName(text)
    self._scriptNameInfo:SetLabel(text or "<no script>")
    
    -- the line below is necessary otherwise the sizer does not re-center the 
    -- static text whenever its content changes
    self._topSizer:Layout()
end

--- Displays a text representing the script status at the right place in the 
--  GUI.
--
-- @param text (string)
function M:displayScriptState(text)
    self._statusBar:SetStatusText(text, 0)
end

--- Displays a text representing timing info (fps...) at the right place in the 
--  GUI.
--
-- @param text (string)
function M:displayTimingInfo(text)
    self._statusBar:SetStatusText(text, 1)
end

--- Displays the file selector dialog.
--
-- @param options (table) A key/value list of options. The allowed keys are:
--                        "caption" (string), "defaultPath" (string), 
--                        "defaultExt" (string), and "filters" (table).
--                        "filter" value must be a table of tables, the latter 
--                        containing key/value items where the key is a 
--                        wildcard such as "*.lua", and the value is an 
--                        associated string such as "Lua script files"
--
-- @return (string) The complete path of the selected file, or the empty string
--                  if file selection has been cancelled
function M:selectFile(options)
    local o = options
    local filters = {}
    
    for wildcard, caption in pairs(o.filters) do
        filters[#filters + 1] = caption.."|"..wildcard
    end
    filters = table.concat(filters, "|")
    
    return wx.wxFileSelector(o.caption, o.defaultPath, o.defaultFile, 
                             o.defaultExt, filters,
                             wx.wxFD_OPEN, self._window)
end

--- Displays the app about box.
--
-- @param appInfo (table) A key/value list of items describing the application,
--                        to be shown in the about box. The accepted keys are: 
--                        "icon" (png icon path), "name" (string, the app name),
--                        "version" (string), "description" (string), 
--                        "copyright" (string), "link" (table, a link to the app
--                        website), "license" (string, the application license)
--                        and "authors" (table, a list of authors as strings).
--                        If the icon is not given, "about.png" will be tried. 
--                        If it's not found either, the main window icon will be
--                        used
--                        The "link" table must have "url" (string) and 
--                        "caption" (string) keys
function M:showAboutBox(appInfo)
    Mls.logger:debug("showing About box", "gui")
    
    local iconPath = appInfo.icon or "about.png"
    iconPath, found = Sys.getFileWithPath(iconPath, self._path)
    local icon = found and wx.wxIcon(iconPath, wx.wxBITMAP_TYPE_PNG)
                        or self._icon
    
    local info = wx.wxAboutDialogInfo()
    if icon then info:SetIcon(icon) end
    info:SetName(appInfo.name)
    info:SetVersion(appInfo.version)
    info:SetDescription(appInfo.description)
    info:SetCopyright(appInfo.copyright)
    info:SetWebSite(appInfo.link.url, appInfo.link.caption)
    if appInfo.license then info:SetLicence(appInfo.license) end
    for _, author in ipairs(appInfo.authors) do
        info:AddDeveloper(author)
    end
    
    wx.wxAboutBox(info)
end

--- Shows a dialog with key bindings.
--
-- If the dialog doesn't exist yet, it is created.
--
-- @param keyBindings (array) The key bindings to display. Each one is itself an
--                            array of two items. The first one is a string 
--                            describing the action, the second one is a string
--                            representing the key bound to this action
function M:showKeyBindings(keyBindings)
    -- no key bindings dialog yet? Create it
    if not self._keyBindingsWindow then
        -- create the dialog and its sizer
        local dialog = wx.wxDialog(self._window, wx.wxID_ANY, 
                                   "MLS - Key bindings")
        local dialogSizer = wx.wxBoxSizer(wx.wxVERTICAL)
        
        -- create the grid, the rows/cols, labels, default sizes
        local grid = wx.wxGrid(dialog, wx.wxID_ANY)
        grid:CreateGrid(#keyBindings, 2)
        grid:SetRowLabelSize(0)
        grid:SetDefaultCellAlignment(wx.wxALIGN_CENTER, wx.wxALIGN_CENTER)
        grid:SetColLabelValue(0, "Action")
        grid:SetColLabelValue(1, "Key")
        
        -- fill the columns
        for i, binding in ipairs(keyBindings) do
            grid:SetCellValue(i - 1, 0, binding[1])
            grid:SetCellValue(i - 1, 1, binding[2])
        end
        
        -- decrease grid default fonts so it doesn't fill the whole screen
        -- (font size = 11 on Mac, 8 on Windows and Linux)
        local fontSize = Sys.getOS() == "Macintosh" and 11 or 8
        
        local labelFont = grid:GetLabelFont()
        labelFont:SetPointSize(fontSize)
        grid:SetLabelFont(labelFont)
        
        local cellFont = grid:GetDefaultCellFont()
        cellFont:SetPointSize(fontSize)
        grid:SetDefaultCellFont(cellFont)
        
        -- autosize the columns, then set both to the width of the largest one
        grid:AutoSize()
        local minColSize = math.max(grid:GetColSize(0), grid:GetColSize(1))
        grid:SetDefaultColSize(minColSize, true)
        
        -- the user won't be allowed to edit or resize the grid
        grid:EnableEditing(false)
        grid:EnableDragColSize(false)
        grid:EnableDragRowSize(false)
        grid:EnableDragGridSize(false)
        
        -- add the grid to the dialog sizer
        dialogSizer:Add(grid, 1, wx.wxEXPAND)
        
        -- creates and add a dialog button sizer
        local buttonSizer = dialog:CreateButtonSizer(wx.wxOK)
        dialogSizer:Add(buttonSizer, 0, wx.wxCENTER)
        
        -- make the window fit its content
        dialog:SetSizerAndFit(dialogSizer)
        dialog:Center()
        
        self._keyBindingsWindow = dialog
    end
    
    self._keyBindingsWindow:Show()
end

--- Sets the default shortcut (accelerator, in wxWidgets terminology) to a menu
--  item.
--
-- On Windows and Mac, Open seems to have no default shortcut, so we create one.
-- This doesn't seem to bother Linux. For Exit, Linux and Mac define one (Ctrl+Q
-- and Cmd+Q), and Windows has Alt+F4, so we're set
--
-- @param item (table) The menu item, as used by createMenus(), i.e. with at 
--                     least the id and caption (already containing an optional
--                     shortcut)
--
-- @see createMenus
function M:_setDefaultShortcut(item)
    if item.caption:find("\t", 1, true) then
        return
    end
    
    if item.id == M.MENU_OPEN then
        item.caption = item.caption .. "\tCTRL+O"
    elseif item.id == M.MENU_EXIT then
        item.caption = item.caption .. "\tCTRL+Q"
    elseif item.id == M.MENU_SHOW_KEY_BINDINGS then
        item.caption = item.caption .. "\tCTRL+K"
    end
end

--- Registers a function to call when the main app window is required to close.
--
-- @param callback (function)
function M:registerShutdownCallback(callback)
    self._window:Connect(wx.wxEVT_CLOSE_WINDOW, callback)
end

--- Asks the GUI to close the main window.
--
-- Please note that this does not immediately destroys the windows, since many
-- GUIs allow for callbacks before the window is actually destroys, and even 
-- prevent the closing of the window
function M:closeWindow()
    Mls.logger:debug("requesting main window to close", "gui")
    
    self._window:Close()
end

--- Performs the actual destruction of the main app window.
--
-- This usually happens after requesting the window closing
function M:shutdown()
    Mls.logger:debug("closing main window & shutting down", "gui")
    
    self._window:Destroy()
end

return M
