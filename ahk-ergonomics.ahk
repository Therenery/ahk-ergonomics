#Requires AutoHotkey v2.0
if not A_IsAdmin {
    try Run '*RunAs "' A_ScriptFullPath '"'
    ExitApp
}
#SingleInstance Force

; ===== 终端配置 =====
; 终端里跑的 shell。装了 PowerShell 7 用 pwsh.exe；只有系统自带的 5.1 就改成 powershell.exe
global terminalShell := "pwsh.exe"

; ===== 按住左 Win 600ms（或 400ms 内双击后按住）打开终端 =====
; 依赖脚本本身已通过 #Requires 段落自动提权
; 若手势开始时焦点在资源管理器窗口，终端直接在该窗口当前文件夹打开
global lwinArmed := false
global lwinLastUp := 0
global lwinFg := 0
global lwinOrigin := 0   ; 手势第一下按下时的前台窗口
global lwinPriorKey := "" ; 按下 Win 之前最后按过的键，用来判断按住期间有没有按别的键

~LWin:: {
    global lwinArmed, lwinLastUp, lwinFg, lwinOrigin, lwinPriorKey
    lwinArmed := false
    lwinFg := WinExist("A")
    lwinPriorKey := A_PriorKey
    if (lwinLastUp > 0 && A_TickCount - lwinLastUp < 400)
        SetTimer(OpenTerminal, -450)
    else {
        ; 手势的第一下：记下此刻的前台窗口。
        ; 双击时第一下松开会弹出开始菜单，第二下按住时前台可能已不是原窗口，
        ; 所以第二下不更新 lwinOrigin，判断资源管理器时用这里记录的窗口
        lwinOrigin := lwinFg
        SetTimer(OpenTerminal, -600)
    }
}

~LWin Up:: {
    global lwinLastUp, lwinArmed
    lwinLastUp := A_TickCount
    if (!lwinArmed)
        SetTimer(OpenTerminal, 0)
}

OpenTerminal() {
    global lwinArmed, lwinFg, lwinOrigin, lwinPriorKey, terminalShell
    if (lwinArmed || !GetKeyState("LWin", "P"))
        return
    ; 按住 Win 期间按过其它键（空格、方向键等），说明是在用组合键，别抢
    if (A_PriorKey != lwinPriorKey)
        return
    ; 按住 Win 期间前台变了，说明是在用 Win+某键，别抢
    if (WinExist("A") != lwinFg)
        return
    lwinArmed := true

    ; 焦点在资源管理器：在当前文件夹打开；否则保持原行为
    cmd := "wt.exe " terminalShell
    dir := GetExplorerPath(lwinOrigin)
    if (dir != "") {
        dir := StrReplace(dir, ";", "\;")   ; wt 用分号分隔子命令，路径里的分号要转义
        if (SubStr(dir, -1) = "\")          ; 盘符根目录以 \ 结尾，会把后面的引号转义掉，补成 \\
            dir .= "\"
        cmd := 'wt.exe -d "' dir '" ' terminalShell
    }

    ; 记录打开前已有的终端窗口，便于之后定位新窗口
    before := Map()
    for hwnd in WinGetList("ahk_exe WindowsTerminal.exe")
        before[hwnd] := true

    try Run(cmd, EnvGet("USERPROFILE"))

    ; 冷启动可能要几秒，给足 10 秒
    newHwnd := 0
    Loop 100 {
        Sleep(100)
        for hwnd in WinGetList("ahk_exe WindowsTerminal.exe") {
            if (!before.Has(hwnd)) {
                newHwnd := hwnd
                break
            }
        }
        if (newHwnd)
            break
    }
    ; 没等到新窗口（WT 设成开新标签页了），退一步激活现有的
    if (!newHwnd) {
        list := WinGetList("ahk_exe WindowsTerminal.exe")
        if (list.Length = 0)
            return
        newHwnd := list[list.Length]
    }

    ; 松开 Win 的瞬间系统会弹开始菜单，先按 Esc 关掉再抢前台
    KeyWait("LWin", "T3")
    Sleep(120)
    Send("{Esc}")
    Loop 8 {
        WinRestore("ahk_id " newHwnd)
        WinActivate("ahk_id " newHwnd)
        if (WinActive("ahk_id " newHwnd))
            break
        Sleep(120)
    }
}

; 返回资源管理器窗口当前所在的文件夹路径（支持 Win11 多标签页）
; 窗口不是资源管理器，或当前位置不是真实文件夹（此电脑、回收站、库、搜索结果等）时返回空字符串
GetExplorerPath(hwnd) {
    static IID_IShellBrowser := "{000214E2-0000-0000-C000-000000000046}"
    try {
        if (!hwnd || !WinExist("ahk_id " hwnd))
            return ""
        if (WinGetClass("ahk_id " hwnd) != "CabinetWClass")
            return ""

        ; Win11 多个标签页共用同一个顶层窗口，先找出当前激活的标签页
        activeTab := 0
        try activeTab := ControlGetHwnd("ShellTabWindowClass1", "ahk_id " hwnd)

        for w in ComObject("Shell.Application").Windows {
            if (w.HWND != hwnd)
                continue
            if (activeTab) {
                sb := ComObjQuery(w, IID_IShellBrowser, IID_IShellBrowser)
                thisTab := 0
                ComCall(3, sb, "Ptr*", &thisTab)   ; IOleWindow::GetWindow
                if (thisTab != activeTab)
                    continue
            }
            path := w.Document.Folder.Self.Path
            return DirExist(path) ? path : ""
        }
    }
    return ""
}

; ===== 全局标记与配置 =====
capsUsed := false
xbtn1Used := false
xbtn2Used := false
xbtnChord := false   ; 上下侧键同时按住时置位，两个键都松开才复位

; ===== 虚拟桌面循环配置 =====
global totalDesktops := 6   ; 修改为你实际使用的虚拟桌面总数
global currentDesktop := 3  ; 启动脚本时，默认停留在第 3 个桌面

MarkCapsUsed() {
    global capsUsed
    capsUsed := true
}

; ===== CapsLock 松发切换 =====
CapsLock:: {
    global capsUsed
    capsUsed := false
}

CapsLock Up:: {
    global capsUsed
    if (!capsUsed)
        SetCapsLockState(!GetKeyState("CapsLock", "T"))
}

; ===== CapsLock 组合键 =====
CapsLock & q:: {
    MarkCapsUsed()
    Send("!{F4}")
}

CapsLock & e:: {
    MarkCapsUsed()
    SavedClip := ClipboardAll()
    A_Clipboard := ""
    Send("^{c}")
    if ClipWait(0.3)
    {
        Run("msedge.exe https://www.bing.com/search?q=" . UrlEncode(A_Clipboard))
    }
    else
    {
        Run("msedge.exe")
    }
    Sleep(200)
    A_Clipboard := SavedClip
}

CapsLock & w:: {
    MarkCapsUsed()
    Send("{Blind}{Up}")
}

CapsLock & s:: {
    MarkCapsUsed()
    Send("{Blind}{Down}")
}

CapsLock & a:: {
    MarkCapsUsed()
    Send("{Blind}{Left}")
}

CapsLock & d:: {
    MarkCapsUsed()
    Send("{Blind}{Right}")
}

CapsLock & m:: {
    MarkCapsUsed()
    WinMinimize("A")
}

CapsLock & f:: {
    MarkCapsUsed()
    WinMaximize("A")
}

; ===== 下侧键 XButton1 =====
; 单独按：松开时发送原生 XButton1（后退）
; 按住 + 滚轮：切换桌面（上滚左切，下滚右切），支持循环切换
; 按住 + 中键：任务视图
; 按住 + 左键：回车 Enter
; 按住 + 右键：退格 Backspace
; 与上侧键同时按住：截图（Win+Shift+S）
XButton1:: {
    global xbtn1Used, xbtn2Used, xbtnChord
    ; 上侧键已按住且没被用于其它手势：判定为双键和弦
    if (GetKeyState("XButton2", "P") && !xbtn2Used && !xbtnChord) {
        xbtnChord := true
        xbtn1Used := true
        xbtn2Used := true
        Send("#+s")
        return
    }
    xbtn1Used := false
}

XButton1 Up:: {
    global xbtn1Used, xbtnChord
    if (!GetKeyState("XButton2", "P"))
        xbtnChord := false
    if (!xbtn1Used)
        Send("{XButton1}")
}

; 和弦触发后本层失效，避免按住侧键时把截图浮层的左键吞成回车
#HotIf GetKeyState("XButton1", "P") && !xbtnChord
WheelUp:: {
    global xbtn1Used, currentDesktop, totalDesktops
    xbtn1Used := true
    if (currentDesktop > 1) {
        currentDesktop--
        Send("#^{Left}")
    } else {
        ; 到达最左端，循环跳到最右端
        currentDesktop := totalDesktops
        Loop (totalDesktops - 1) {
            Send("#^{Right}")
            Sleep(40) ; 增加微小延迟，防止 Windows 动画吞键
        }
    }
}

WheelDown:: {
    global xbtn1Used, currentDesktop, totalDesktops
    xbtn1Used := true
    if (currentDesktop < totalDesktops) {
        currentDesktop++
        Send("#^{Right}")
    } else {
        ; 到达最右端，循环跳到最左端
        currentDesktop := 1
        Loop (totalDesktops - 1) {
            Send("#^{Left}")
            Sleep(40)
        }
    }
}

MButton:: {
    global xbtn1Used
    xbtn1Used := true
    Send("#{Tab}")     ; 任务视图
}

LButton:: {
    global xbtn1Used
    xbtn1Used := true
    Send("{Enter}")
}

RButton:: {
    global xbtn1Used
    xbtn1Used := true
    Send("{Backspace}")
}
#HotIf


; ===== 上侧键 XButton2 =====
; 单独按：松开时发送原生 XButton2（前进）
; 按住 + 左键单击：有选中则复制；没选中则全选，不复制
; 按住 + 右键：松开右键粘贴
; 与下侧键同时按住：截图（Win+Shift+S）
XButton2:: {
    global xbtn1Used, xbtn2Used, xbtnChord
    ; 下侧键已按住且没被用于其它手势：判定为双键和弦
    if (GetKeyState("XButton1", "P") && !xbtn1Used && !xbtnChord) {
        xbtnChord := true
        xbtn1Used := true
        xbtn2Used := true
        Send("#+s")
        return
    }
    xbtn2Used := false
}

XButton2 Up:: {
    global xbtn2Used, xbtnChord
    if (!GetKeyState("XButton1", "P"))
        xbtnChord := false
    if (!xbtn2Used)
        Send("{XButton2}")
}

; 和弦触发后本层失效，避免按住侧键时把截图浮层的左键吞成复制
#HotIf GetKeyState("XButton2", "P") && !xbtnChord
LButton:: {
    global xbtn2Used
    xbtn2Used := true
    ; 屏蔽原生左键点击，避免单击清除已选中的内容
}
LButton Up:: {
    global xbtn2Used
    xbtn2Used := true
    CopySelectionOrSelectAll()
}
RButton:: {
    global xbtn2Used
    xbtn2Used := true
}
RButton Up:: {
    global xbtn2Used
    xbtn2Used := true
    Send("^{v}")
}
#HotIf


; ===== CapsLock + 鼠标/方向键 =====
CapsLock & ,:: {
    MarkCapsUsed()
    Click("Left")
}

CapsLock & .:: {
    MarkCapsUsed()
    Click("Right")
}


CapsLock & Up:: {
    MarkCapsUsed()
    Click("WheelUp")
}

CapsLock & Down:: {
    MarkCapsUsed()
    Click("WheelDown")
}

CapsLock & PgUp:: {
    MarkCapsUsed()
    Click("X1")
}

CapsLock & PgDn:: {
    MarkCapsUsed()
    Click("X2")
}

CapsLock & LButton:: {
    MarkCapsUsed()
    Send("^#{Left}")
}

CapsLock & RButton:: {
    MarkCapsUsed()
    Send("^#{Right}")
}

; ===== 有选中内容则复制；没有选中则只全选，不复制 =====
CopySelectionOrSelectAll() {
    SavedClip := ClipboardAll()
    A_Clipboard := ""
    Send("^{c}")

    if ClipWait(0.2) {
        ; 有选中内容，Ctrl+C 成功，保留复制结果
        return
    }

    ; 没有复制到内容：恢复原剪贴板，然后只全选，不复制
    A_Clipboard := SavedClip
    Send("^{a}")
}

; ===== URL 编码函数 =====
UrlEncode(str) {
    len := StrPut(str, "UTF-8")
    buf := Buffer(len)
    StrPut(str, buf, "UTF-8")
    out := ""
    Loop len - 1 {
        b := NumGet(buf, A_Index - 1, "UChar")
        if ((b >= 0x41 && b <= 0x5A) || (b >= 0x61 && b <= 0x7A) || (b >= 0x30 && b <= 0x39) || b = 0x2D || b = 0x5F || b = 0x2E || b = 0x7E)
            out .= Chr(b)
        else
            out .= Format("%{:02X}", b)
    }
    return out
}