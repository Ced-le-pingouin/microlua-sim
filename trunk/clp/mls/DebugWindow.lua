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
local Class = require "clp.Class"

local M = Class.new()

--- Constructor.
--
-- @see _createWindow
function M:ctr()
    self._windowTitle = "Debug"
    self._width = 500
    self._height = 500
    
    self:_createDefaultStyles()
    self:_createWindow()
    self:_createSourceTextBox()
    self:_createVariablesGrid()
    
    self._currentSourceFile = nil
end

function M:_createDefaultStyles()
    local size = wx.wxSize(10, 10)
    
    local defaultFont = wx.wxFont.New(size, wx.wxFONTFAMILY_MODERN)
    local defaultFontStyle = wx.wxTextAttr()
    defaultFontStyle:SetFont(defaultFont)
    
    self._defaultFont = defaultFont
    self._defaultFontStyle = defaultFontStyle
    
    local lineNumberFont = wx.wxFont(defaultFont)
    local lineNumberFontStyle = wx.wxTextAttr()
    lineNumberFontStyle:SetFont(lineNumberFont)
    lineNumberFontStyle:SetTextColour(wx.wxBLUE)
    
    self._lineNumberFontStyle = lineNumberFontStyle
    
    local normalBackgroundStyle = wx.wxTextAttr()
    normalBackgroundStyle:SetFont(defaultFont)
    normalBackgroundStyle:SetBackgroundColour(wx.wxWHITE)
    self._normalBackgroundStyle = normalBackgroundStyle
    
    local highlightBackgroundStyle = wx.wxTextAttr()
    highlightBackgroundStyle:SetFont(defaultFont)
    highlightBackgroundStyle:SetBackgroundColour(wx.wxGREEN)
    self._highlightBackgroundStyle = highlightBackgroundStyle
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
    
    --Mls.logger:debug("setting debug window icon", "gui")
    --if self._icon then self._window:SetIcon(self._icon) end
    
    self._topSizer = wx.wxBoxSizer(wx.wxVERTICAL)
end

function M:_createSourceTextBox()
    Mls.logger:debug("creating source file view on debug window", "gui")
    
    local textBox = wx.wxTextCtrl(
        self._window, wx.wxID_ANY, "" , wx.wxDefaultPosition, wx.wxDefaultSize,
        wx.wxTE_READONLY + wx.wxTE_MULTILINE + wx.wxTE_DONTWRAP
    )
    
    self._topSizer:Add(textBox, 1, wx.wxEXPAND)
    --self._topSizer:Add(textBox, 1, wx.wxSHAPED + wx.wxALIGN_CENTER)
    
    self._sourceTextBox = textBox
end

function M:_createVariablesGrid()
    local grid = wx.wxGrid(self._window, wx.wxID_ANY)
    
    grid:CreateGrid(2, 3)
    grid:SetRowLabelSize(0)
    grid:SetDefaultCellAlignment(wx.wxALIGN_CENTER, wx.wxALIGN_CENTER)
    grid:SetColLabelValue(0, "Variable")
    grid:SetColLabelValue(1, "Type")
    grid:SetColLabelValue(2, "Value")
    
    grid:SetLabelFont(self._defaultFont)
    grid:SetDefaultCellFont(self._defaultFont)
    
    self._topSizer:Add(grid, 1, wx.wxEXPAND)
    
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
        local text = self:_loadSourceFileWithLineNumbers(filename)
        self._sourceTextBox:SetValue(text)
        
        self:_resetSourceTextBoxFontStyle()
        
        self._currentSourceFile = filename
    end
end

function M:_loadSourceFileWithLineNumbers(filename)
    local lines = {}
    local lineNum = 1
    local file = io.open(filename, "r")
    
    for line in file:lines() do
        table.insert(lines, string.format("%4d %s", lineNum, line))
        lineNum = lineNum + 1
    end
    
    file:close()
    
    return table.concat(lines, "\n")
end

function M:_resetSourceTextBoxFontStyle()
    local textBox = self._sourceTextBox
    local numLines = textBox:GetNumberOfLines()
    
    for i = 0, numLines - 1 do
        local startPos = textBox:XYToPosition(0, i)
        local endPos = startPos + textBox:GetLineLength(i)
        
        textBox:SetStyle(startPos, startPos + 4, self._lineNumberFontStyle)
        textBox:SetStyle(startPos + 4, endPos, self._defaultFontStyle)
    end
end

function M:setCurrentLineInSource(line)
    line = self:_validateLine(line)
    
    local textBox = self._sourceTextBox
    local previousLine = self._previousLine
    local startPos, endPos
    
    if previousLine then
        startPos = textBox:XYToPosition(0, previousLine - 1)
        endPos = startPos + textBox:GetLineLength(previousLine - 1)
        textBox:SetStyle(startPos + 4, endPos, self._normalBackgroundStyle)
    end
    
    startPos = textBox:XYToPosition(0, line - 1)
    endPos = startPos + textBox:GetLineLength(line - 1)
    textBox:SetStyle(startPos + 4, endPos, self._highlightBackgroundStyle)
    
    self._previousLine = line
    
    self:moveToLineInSource(line)
end

function M:moveToLineInSource(line)
    line = line + 10
    line = self:_validateLine(line)
    
    local textBox = self._sourceTextBox
    local pos = textBox:XYToPosition(0, line - 1)
    
    textBox:ShowPosition(pos)
end

function M:_validateLine(line)
    local maxLine = self._sourceTextBox:GetNumberOfLines()
    
    if line < 1 then
        line = 1
    elseif line > maxLine then
        line = maxLine
    end
    
    return line
end

function M:setGridVariables(variables)
    local grid = self._variablesGrid
    
    grid:BeginBatch()
    
    local numRows = grid:GetNumberRows()
    grid:DeleteRows(0, numRows)
    
    local rowNum = 0
    for name, value in pairs(variables) do
        grid:AppendRows(1)
        
        grid:SetCellValue(rowNum, 0, tostring(name))
        grid:SetReadOnly(rowNum, 0)
        
        grid:SetCellValue(rowNum, 1, type(value))
        grid:SetReadOnly(rowNum, 1)
        
        grid:SetCellValue(rowNum, 2, tostring(value))
        grid:SetReadOnly(rowNum, 2)
        
        rowNum = rowNum + 1
    end
    
    grid:EndBatch()
    
    self._variables = variables
end

function M:sortGridByColumn(colNum)
    local grid = self._variablesGrid
    local numRows = grid:GetNumberRows()
    
    grid:BeginBatch()
    
    repeat
        local permutationOccured = false
        
        for i = 0, numRows - 1 - 1  do
            if grid:GetCellValue(i, colNum) > grid:GetCellValue(i + 1, colNum)
            then
                local numCols = grid:GetNumberCols()
                for j = 0, numCols - 1 do
                    local firstRowSavedValue = grid:GetCellValue(i, j)
                    grid:SetCellValue(i, j, grid:GetCellValue(i + 1, j))
                    grid:SetCellValue(i + 1, j, firstRowSavedValue)
                end
                
                permutationOccured = true
            end
        end
    until not permutationOccured
    
    grid:EndBatch()
end

return M
