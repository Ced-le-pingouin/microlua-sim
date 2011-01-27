-------------------------------------------------------------------------------
-- Debug window.
--
-- @class module
-- @name clp.mls.DebugWindow
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
require "wxstc"
local Class = require "clp.Class"

local M = Class.new()

--- Constructor.
--
-- @see _createWindow
function M:ctr()
    self._windowTitle = "Debug"
    self._width = 500
    self._height = 500
    
    local fontSize = wx.wxSize(12, 12)
    self._defaultFont = wx.wxFont.New(fontSize, wx.wxFONTFAMILY_MODERN)
    
    self:_createWindow()
    self:_createSourceTextBoxAndVariablesGrid()
    
    self._currentSourceFile = nil
end

function M:_createWindow()
    Mls.logger:debug("creating debug window", "gui")
    
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
    
    self._window:SetFont(self._defaultFont)
    
    --Mls.logger:debug("setting debug window icon", "gui")
    --if self._icon then self._window:SetIcon(self._icon) end
    
    self._topSizer = wx.wxBoxSizer(wx.wxVERTICAL)
end

function M:_createSourceTextBoxAndVariablesGrid()
    Mls.logger:debug("creating splitter on debug window", "gui")
    
    local splitter = wx.wxSplitterWindow(self._window, wx.wxID_ANY)
    self._topSizer:Add(splitter, 1, wx.wxEXPAND)
    self._splitter = splitter
    
    self:_createSourceTextBox()
    self:_createVariablesGrid()
    
    splitter:SplitHorizontally(self._sourceTextBox, self._variablesGrid)
end

function M:_createSourceTextBox()
    Mls.logger:debug("creating source file view on debug window", "gui")
    
    local textBox = wxstc.wxStyledTextCtrl(self._splitter, wx.wxID_ANY)
    self._sourceTextBox = textBox
    
    self:_configureSourceLexer()
    self:_configureSourceStyles()
end

-- this code comes from the sample editor.wx.lua in wxLua distribution
function M:_configureSourceLexer()
    local textBox = self._sourceTextBox
    
    textBox:SetLexer(wxstc.wxSTC_LEX_LUA)
    
    textBox:SetKeyWords(0,
        [[and break do else elseif end false for function if
        in local nil not or repeat return then true until while]]
    )
    textBox:SetKeyWords(1,
        [[_VERSION assert collectgarbage dofile error gcinfo loadfile 
        loadstring print rawget rawset require tonumber tostring type unpack]]
    )
    textBox:SetKeyWords(2,
        [[_G getfenv getmetatable ipairs loadlib next pairs pcall
        rawequal setfenv setmetatable xpcall
        string table math coroutine io os debug
        load module select]]
    )
    textBox:SetKeyWords(3,
        [[string.byte string.char string.dump string.find string.len 
        string.lower string.rep string.sub string.upper string.format 
        string.gfind string.gsub 
        table.concat table.foreach table.foreachi table.getn table.sort 
        table.insert table.remove table.setn 
        math.abs math.acos math.asin math.atan math.atan2 math.ceil math.cos 
        math.deg math.exp math.floor math.frexp math.ldexp math.log math.log10 
        math.max math.min math.mod math.pi math.pow math.rad math.random 
        math.randomseed math.sin math.sqrt math.tan 
        string.gmatch string.match string.reverse table.maxn math.cosh 
        math.fmod math.modf math.sinh math.tanh math.huge]]
    )
    textBox:SetKeyWords(4,
        [[coroutine.create coroutine.resume coroutine.status coroutine.wrap 
        coroutine.yield 
        io.close io.flush io.input io.lines io.open io.output io.read 
        io.tmpfile io.type io.write io.stdin io.stdout io.stderr 
        os.clock os.date os.difftime os.execute os.exit os.getenv os.remove 
        os.rename os.setlocale os.time os.tmpname 
        coroutine.running package.cpath package.loaded package.loadlib 
        package.path package.preload package.seeall io.popen 
        debug.debug debug.getfenv debug.gethook debug.getinfo debug.getlocal 
        debug.getmetatable debug.getregistry debug.getupvalue debug.setfenv 
        debug.sethook debug.setlocal debug.setmetatable debug.setupvalue 
        debug.traceback]]
    )
    
    local keywords = {}
    for key, value in pairs(wx) do
        table.insert(keywords, "wx."..key.." ")
    end
    table.sort(keywords)
    keywordsString = table.concat(keywords)
    textBox:SetKeyWords(5, keywordsString)
end

-- this code comes from the sample editor.wx.lua in wxLua distribution, but
-- I changed some stuff, added constants instead of magic numbers, etc.
function M:_configureSourceStyles()
    local textBox = self._sourceTextBox
    local font = self._defaultFont
    
    textBox:SetBufferedDraw(true)
    
    textBox:SetUseTabs(false)
    textBox:SetTabWidth(4)
    textBox:SetIndent(4)
    textBox:SetIndentationGuides(true)
    
    textBox:SetVisiblePolicy(wxstc.wxSTC_VISIBLE_SLOP, 3)
    --textBox:SetXCaretPolicy(wxstc.wxSTC_CARET_SLOP, 10)
    --textBox:SetYCaretPolicy(wxstc.wxSTC_CARET_SLOP, 3)
    
    textBox:SetFoldFlags(wxstc.wxSTC_FOLDFLAG_LINEBEFORE_CONTRACTED +
                         wxstc.wxSTC_FOLDFLAG_LINEAFTER_CONTRACTED)
    
    textBox:SetProperty("fold", "1")
    textBox:SetProperty("fold.compact", "1")
    textBox:SetProperty("fold.comment", "1")
    
    
    textBox:StyleClearAll()
    
    textBox:SetFont(font)
    for i = 0, wxstc.wxSTC_STYLE_LASTPREDEFINED do
        textBox:StyleSetFont(i, font)
    end
    
    textBox:StyleSetForeground(wxstc.wxSTC_LUA_DEFAULT,  wx.wxColour(128, 128, 128))
    
    textBox:StyleSetForeground(wxstc.wxSTC_LUA_COMMENT,  wx.wxColour(0,   127, 0))
    ---textBox:StyleSetFont(wxstc.wxSTC_LUA_COMMENT, fontItalic)
    --textBox:StyleSetUnderline(wxstc.wxSTC_LUA_COMMENT, false)
    textBox:StyleSetForeground(wxstc.wxSTC_LUA_COMMENTLINE,  wx.wxColour(0,   127, 0))
    ---textBox:StyleSetFont(wxstc.wxSTC_LUA_COMMENTLINE, fontItalic)
    --textBox:StyleSetUnderline(wxstc.wxSTC_LUA_COMMENTLINE, false)
    textBox:StyleSetForeground(wxstc.wxSTC_LUA_COMMENTDOC,  wx.wxColour(127, 127, 127))
    
    textBox:StyleSetForeground(wxstc.wxSTC_LUA_IDENTIFIER, wx.wxColour(0,   0,   0))
    
    textBox:StyleSetForeground(wxstc.wxSTC_LUA_WORD,  wx.wxColour(0,   0,   127))
    textBox:StyleSetBold(wxstc.wxSTC_LUA_WORD,  true)
    --textBox:StyleSetUnderline(wxstc.wxSTC_LUA_WORD, false)
    textBox:StyleSetForeground(wxstc.wxSTC_LUA_WORD2, wx.wxColour(0,   0,  95))
    textBox:StyleSetForeground(wxstc.wxSTC_LUA_WORD3, wx.wxColour(0,   95, 0))
    textBox:StyleSetForeground(wxstc.wxSTC_LUA_WORD4, wx.wxColour(127, 0,  0))
    textBox:StyleSetForeground(wxstc.wxSTC_LUA_WORD5, wx.wxColour(127, 0,  95))
    textBox:StyleSetForeground(wxstc.wxSTC_LUA_WORD6, wx.wxColour(35,  95, 175))
    textBox:StyleSetForeground(wxstc.wxSTC_LUA_WORD7, wx.wxColour(0,   127, 127))
    textBox:StyleSetBackground(wxstc.wxSTC_LUA_WORD7, wx.wxColour(240, 255, 255))
    textBox:StyleSetForeground(wxstc.wxSTC_LUA_WORD8, wx.wxColour(0,   127, 127))
    textBox:StyleSetBackground(wxstc.wxSTC_LUA_WORD8, wx.wxColour(224, 255, 255))
    
    textBox:StyleSetForeground(wxstc.wxSTC_LUA_NUMBER,  wx.wxColour(0,   127, 127))
    
    textBox:StyleSetForeground(wxstc.wxSTC_LUA_STRING,  wx.wxColour(127, 0,   127))
    textBox:StyleSetForeground(wxstc.wxSTC_LUA_CHARACTER,  wx.wxColour(127, 0,   127))
    textBox:StyleSetForeground(wxstc.wxSTC_LUA_LITERALSTRING,  wx.wxColour(0,   127, 127))
    textBox:StyleSetForeground(wxstc.wxSTC_LUA_STRINGEOL, wx.wxColour(0,   0,   0))
    textBox:StyleSetBackground(wxstc.wxSTC_LUA_STRINGEOL, wx.wxColour(224, 192, 224))
    textBox:StyleSetBold(wxstc.wxSTC_LUA_STRINGEOL, true)
    textBox:StyleSetEOLFilled(wxstc.wxSTC_LUA_STRINGEOL, true)
    
    textBox:StyleSetForeground(wxstc.wxSTC_LUA_PREPROCESSOR,  wx.wxColour(127, 127, 0))
    
    textBox:StyleSetForeground(wxstc.wxSTC_LUA_OPERATOR, wx.wxColour(0,   0,   0))
    --textBox:StyleSetBold(wxstc.wxSTC_LUA_OPERATOR, true)
    
    -- are these "magic numbers" styles really used?
    textBox:StyleSetForeground(20, wx.wxColour(0,   127, 127))
    textBox:StyleSetBackground(20, wx.wxColour(192, 255, 255))
    textBox:StyleSetForeground(21, wx.wxColour(0,   127, 127))
    textBox:StyleSetBackground(21, wx.wxColour(176, 255, 255))
    textBox:StyleSetForeground(22, wx.wxColour(0,   127, 127))
    textBox:StyleSetBackground(22, wx.wxColour(160, 255, 255))
    textBox:StyleSetForeground(23, wx.wxColour(0,   127, 127))
    textBox:StyleSetBackground(23, wx.wxColour(144, 255, 255))
    textBox:StyleSetForeground(24, wx.wxColour(0,   127, 127))
    textBox:StyleSetBackground(24, wx.wxColour(128, 155, 255))
    ----
    
    textBox:StyleSetForeground(wxstc.wxSTC_STYLE_DEFAULT, wx.wxColour(224, 192, 224))
    textBox:StyleSetBackground(wxstc.wxSTC_STYLE_LINENUMBER, wx.wxColour(192, 192, 192))
    
    textBox:StyleSetForeground(wxstc.wxSTC_STYLE_BRACELIGHT, wx.wxColour(0,   0,   255))
    textBox:StyleSetBold(wxstc.wxSTC_STYLE_BRACELIGHT, true)
    textBox:StyleSetForeground(wxstc.wxSTC_STYLE_BRACEBAD, wx.wxColour(255, 0,   0))
    textBox:StyleSetBold(wxstc.wxSTC_STYLE_BRACEBAD, true)
    
    textBox:StyleSetForeground(wxstc.wxSTC_STYLE_INDENTGUIDE, wx.wxColour(192, 192, 192))
    textBox:StyleSetBackground(wxstc.wxSTC_STYLE_INDENTGUIDE, wx.wxColour(255, 255, 255))
    
    
    textBox:SetCaretLineVisible(true)
    
    
    self.BREAKPOINT_MARKER = 1
    self.CURRENT_LINE_MARKER = 2
    textBox:MarkerDefine(self.BREAKPOINT_MARKER,   wxstc.wxSTC_MARK_ROUNDRECT, wx.wxWHITE, wx.wxRED)
    textBox:MarkerDefine(self.CURRENT_LINE_MARKER, wxstc.wxSTC_MARK_ARROW,     wx.wxBLACK, wx.wxGREEN)
    
    local grey = wx.wxColour(128, 128, 128)
    textBox:MarkerDefine(wxstc.wxSTC_MARKNUM_FOLDEROPEN,    wxstc.wxSTC_MARK_BOXMINUS, wx.wxWHITE, grey)
    textBox:MarkerDefine(wxstc.wxSTC_MARKNUM_FOLDER,        wxstc.wxSTC_MARK_BOXPLUS,  wx.wxWHITE, grey)
    textBox:MarkerDefine(wxstc.wxSTC_MARKNUM_FOLDERSUB,     wxstc.wxSTC_MARK_VLINE,    wx.wxWHITE, grey)
    textBox:MarkerDefine(wxstc.wxSTC_MARKNUM_FOLDERTAIL,    wxstc.wxSTC_MARK_LCORNER,  wx.wxWHITE, grey)
    textBox:MarkerDefine(wxstc.wxSTC_MARKNUM_FOLDEREND,     wxstc.wxSTC_MARK_BOXPLUSCONNECTED,  wx.wxWHITE, grey)
    textBox:MarkerDefine(wxstc.wxSTC_MARKNUM_FOLDEROPENMID, wxstc.wxSTC_MARK_BOXMINUSCONNECTED, wx.wxWHITE, grey)
    textBox:MarkerDefine(wxstc.wxSTC_MARKNUM_FOLDERMIDTAIL, wxstc.wxSTC_MARK_TCORNER,  wx.wxWHITE, grey)
    grey:delete()
    
    
    textBox:SetMarginWidth(0, textBox:TextWidth(32, "99999_")) -- line # margin
    
    textBox:SetMarginWidth(1, 16) -- marker margin
    textBox:SetMarginType(1, wxstc.wxSTC_MARGIN_SYMBOL)
    textBox:SetMarginSensitive(1, true)
    
    textBox:SetMarginWidth(2, 16) -- fold margin
    textBox:SetMarginType(2, wxstc.wxSTC_MARGIN_SYMBOL)
    textBox:SetMarginMask(2, wxstc.wxSTC_MASK_FOLDERS)
    textBox:SetMarginSensitive(2, true)
end

function M:_createVariablesGrid()
    local grid = wx.wxListCtrl(
        self._splitter, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize,
        wx.wxLC_REPORT + wx.wxLC_HRULES + wx.wxLC_VRULES
    )
    
    grid:InsertColumn(0, "Variable")
    grid:InsertColumn(1, "Type")
    grid:InsertColumn(2, "Value")
    
    self._variablesGrid = grid
end

--- Sets the main window to the correct size, centers it, then displays it.
function M:show()
    Mls.logger:debug("showing debug window", "gui")
    
    self._window:SetSizer(self._topSizer)
    --self._window:Center()
    self._window:Show()
end

function M:setSourceFile(filename)
    if filename ~= self._currentSourceFile then
        self._sourceTextBox:LoadFile(filename)
        --self._sourceTextBox:Colourise(0, -1)
        self._currentSourceFile = filename
    end
end

function M:setCurrentLineInSource(line)
    local textBox = self._sourceTextBox
    
    --textBox:GotoLine(line - 1 - 1) -- why the second "-1" ???
    textBox:ScrollToLine(line - 1)
end

function M:setGridVariables(variables)
    local grid = self._variablesGrid
    local variableIndexToVariableName = {}
    
    grid:DeleteAllItems()
    
    local i = 0
    for name, value in pairs(variables) do
        grid:InsertItem(i, name)
        grid:SetItem(i, 1, type(value))
        grid:SetItem(i, 2, tostring(value))
        grid:SetItemData(i, i)
        variableIndexToVariableName[i] = name
        
        i = i + 1
    end
    
    grid:SetColumnWidth(0, wx.wxLIST_AUTOSIZE)
    grid:SetColumnWidth(1, wx.wxLIST_AUTOSIZE)
    grid:SetColumnWidth(2, wx.wxLIST_AUTOSIZE)
    
    self._variables = variables
    self._variableIndexToVariableName = variableIndexToVariableName
end

function M:sortGridByColumn(column)
    self._variablesGrid:SortItems(function(itemData1, itemData2)
        -- each item data has been set to its index, which can give us its name
        local toName = self._variableIndexToVariableName
        
        if toName[itemData1] > toName[itemData2] then
            return 1
        elseif toName[itemData1] < toName[itemData2] then
            return -1
        else
            return 0
        end
    end, 0)
end

return M
