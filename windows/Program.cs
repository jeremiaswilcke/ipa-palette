// IPA-Palette für Windows: schwebendes Fenster, das IPA-Zeichen ins zuletzt aktive Programm tippt.
// Oberfläche = dieselben Web-Dateien wie das Word-Add-in (taskpane.html), hier in WebView2.
using System.Diagnostics;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Text.Json;
using Microsoft.Web.WebView2.Core;
using Microsoft.Web.WebView2.WinForms;
using Microsoft.Win32;

namespace IPAPalette;

static class Program
{
    [STAThread]
    static void Main(string[] args)
    {
        using var single = new Mutex(true, "Askalon.IPAPalette", out bool first);
        if (!first) { Native.PostMessage(Native.HWND_BROADCAST, Native.WM_SHOWME, 0, 0); return; }
        ApplicationConfiguration.Initialize();
        Application.Run(new PaletteForm(args));
    }
}

sealed class PaletteForm : Form
{
    readonly WebView2 web = new() { Dock = DockStyle.Fill };
    readonly NotifyIcon tray = new();
    readonly string dataDir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "IPA-Palette");
    readonly string[] args;
    IntPtr target = IntPtr.Zero;       // zuletzt aktives fremdes Fenster
    IntPtr hook;
    Native.WinEventDelegate? hookProc;  // Referenz halten, sonst sammelt der GC den Rückruf ein
    bool quitting;
    const int HotKeyId = 1;

    public PaletteForm(string[] args)
    {
        this.args = args;
        Text = "IPA-Palette";
        FormBorderStyle = FormBorderStyle.SizableToolWindow;
        TopMost = true;
        ShowInTaskbar = false;
        StartPosition = FormStartPosition.Manual;
        MinimumSize = new Size(300, 340);
        Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath);
        LoadBounds();
        Controls.Add(web);
        BuildTray();
    }

    void Log(string msg)
    {
        try { Directory.CreateDirectory(dataDir); File.AppendAllText(Path.Combine(dataDir, "log.txt"), $"{DateTime.Now:HH:mm:ss.fff} {msg}\r\n"); } catch { }
    }

    protected override async void OnLoad(EventArgs e)
    {
        base.OnLoad(e);
        if (Array.IndexOf(args, "--hidden") >= 0) BeginInvoke(Hide);   // Autostart: nur ins Infobereich
        try { await Init(); }
        catch (Exception ex)
        {
            Log("Start fehlgeschlagen: " + ex);
            bool noWebView = ex is WebView2RuntimeNotFoundException;
            MessageBox.Show(noWebView
                ? "Für die IPA-Palette fehlt die „Microsoft Edge WebView2 Runtime“.\n\nBitte installieren: https://go.microsoft.com/fwlink/p/?LinkId=2124703\n(oder das Setup der IPA-Palette erneut ausführen)"
                : "Die IPA-Palette konnte nicht starten:\n\n" + ex.Message + "\n\nProtokoll: " + Path.Combine(dataDir, "log.txt"),
                "IPA-Palette", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            quitting = true; Close();
        }
    }

    async Task Init()
    {
        var fg = Native.GetForegroundWindow();   // Programm, aus dem die Palette gestartet wurde
        if (fg != IntPtr.Zero && fg != Handle) { Native.GetWindowThreadProcessId(fg, out uint fpid); if (fpid != (uint)Environment.ProcessId) target = fg; }
        hookProc = OnForegroundChanged;
        hook = Native.SetWinEventHook(Native.EVENT_SYSTEM_FOREGROUND, Native.EVENT_SYSTEM_FOREGROUND, IntPtr.Zero, hookProc, 0, 0, Native.WINEVENT_OUTOFCONTEXT);
        Native.RegisterHotKey(Handle, HotKeyId, Native.MOD_CONTROL | Native.MOD_ALT | Native.MOD_NOREPEAT, (uint)Keys.I);

        string webDir = ExtractWeb();
        var env = await CoreWebView2Environment.CreateAsync(null, Path.Combine(dataDir, "WebView2"));
        await web.EnsureCoreWebView2Async(env);
        var core = web.CoreWebView2;
        core.Settings.AreDevToolsEnabled = false;
        core.Settings.IsStatusBarEnabled = false;
        core.Settings.AreDefaultContextMenusEnabled = false;
        core.SetVirtualHostNameToFolderMapping("ipa.palette", webDir, CoreWebView2HostResourceAccessKind.Allow);
        core.WebMessageReceived += OnWebMessage;
        core.Navigate("https://ipa.palette/taskpane.html");
        Log($"bereit, Ziel={target}");

        if (Array.IndexOf(args, "--wrap") >= 0) After(2000, () => Wrap("[", "]"));   // Testpfad Klammern
        int i = Array.IndexOf(args, "--type");   // Testpfad: nach 2 s ins aktive Programm tippen
        if (i >= 0 && i + 1 < args.Length)
        {
            string text = args[i + 1];
            var t = new System.Windows.Forms.Timer { Interval = 2000 };
            t.Tick += (_, _) => { t.Stop(); Insert(text, 0); };
            t.Start();
        }
    }

    /// Web-Dateien liegen eingebettet in der .exe und werden je Version einmal ausgepackt.
    string ExtractWeb()
    {
        string version = Assembly.GetExecutingAssembly().GetName().Version?.ToString() ?? "0";
        string dir = Path.Combine(dataDir, "web-" + version);
        if (Directory.Exists(dir)) return dir;
        var asm = Assembly.GetExecutingAssembly();
        foreach (string name in asm.GetManifestResourceNames())
        {
            if (!name.StartsWith("web/")) continue;
            string rel = name.Substring(4).Replace('\\', '/');
            string path = Path.Combine(dir, rel.Replace('/', Path.DirectorySeparatorChar));
            Directory.CreateDirectory(Path.GetDirectoryName(path)!);
            using var src = asm.GetManifestResourceStream(name)!;
            using var dst = File.Create(path);
            src.CopyTo(dst);
        }
        return dir;
    }

    void OnForegroundChanged(IntPtr h, uint ev, IntPtr hwnd, int idObj, int idChild, uint thread, uint time)
    {
        if (hwnd == IntPtr.Zero) return;
        Native.GetWindowThreadProcessId(hwnd, out uint pid);
        if (pid != (uint)Environment.ProcessId) target = hwnd;
    }

    void OnWebMessage(object? sender, CoreWebView2WebMessageReceivedEventArgs e)
    {
        using var doc = JsonDocument.Parse(e.WebMessageAsJson);
        var root = doc.RootElement;
        if (root.TryGetProperty("open", out var o) && root.TryGetProperty("close", out var c))
        {
            Wrap(o.GetString() ?? "", c.GetString() ?? "");
            return;
        }
        if (!root.TryGetProperty("text", out var t)) return;
        int back = root.TryGetProperty("back", out var b) && b.TryGetInt32(out int n) ? n : 0;
        Insert(t.GetString() ?? "", back);
    }

    /// Klammern um die Markierung im Zielprogramm; ohne Markierung leere Klammern mit Cursor dazwischen.
    /// Die Markierung wird per Strg+C geholt, die Zwischenablage danach wiederhergestellt.
    void Wrap(string open, string close)
    {
        if (target == IntPtr.Zero || !Native.IsWindow(target)) { Insert(open + close, close.Length); return; }
        IDataObject? saved = null;
        try { saved = Clipboard.GetDataObject(); } catch { }
        var copy = new DataObject();
        if (saved != null) foreach (string f in saved.GetFormats(false)) { try { copy.SetData(f, saved.GetData(f)); } catch { } }
        try { Clipboard.Clear(); } catch { }
        Native.SetForegroundWindow(target);
        After(60, () =>
        {
            Native.Chord(Native.VK_CONTROL, (ushort)Keys.C);
            After(200, () =>
            {
                string sel = "";
                try { if (Clipboard.ContainsText()) sel = Clipboard.GetText(); } catch { }
                try { if (saved != null) Clipboard.SetDataObject(copy, true); } catch { }
                if (sel.Length == 0 || sel.Length > 2000)
                {
                    Native.TypeUnicode(open + close);
                    for (int i = 0; i < close.Length; i++) Native.TapKey(Native.VK_LEFT);
                }
                else Native.TypeUnicode(open + sel + close);
            });
        });
    }

    static void After(int ms, Action a)
    {
        var t = new System.Windows.Forms.Timer { Interval = ms };
        t.Tick += (_, _) => { t.Stop(); t.Dispose(); a(); };
        t.Start();
    }

    void Insert(string text, int back)
    {
        Log($"Einfügen \"{text}\" Ziel={target} gültig={Native.IsWindow(target)}");
        if (target == IntPtr.Zero || !Native.IsWindow(target))
        {
            Clipboard.SetText(text);
            Toast("Kein Zielprogramm, kopiert: ", text);
            return;
        }
        Native.SetForegroundWindow(target);
        var t = new System.Windows.Forms.Timer { Interval = 60 };
        t.Tick += (_, _) =>
        {
            t.Stop();
            Native.TypeUnicode(text);
            for (int i = 0; i < back; i++) Native.TapKey(Native.VK_LEFT);
        };
        t.Start();
    }

    void Toast(string prefix, string text)
    {
        string json = JsonSerializer.Serialize(new[] { prefix, text });
        _ = web.CoreWebView2?.ExecuteScriptAsync($"window.ipaNativeToast && window.ipaNativeToast(...{json})");
    }

    // ---------------------------------------------------------------- Infobereich

    void BuildTray()
    {
        tray.Icon = Icon;
        tray.Text = "IPA-Palette (Strg+Alt+I)";
        tray.Visible = true;
        var menu = new ContextMenuStrip();
        menu.Items.Add("Palette ein-/ausblenden   Strg+Alt+I", null, (_, _) => TogglePalette());
        var autostart = new ToolStripMenuItem("Mit Windows starten");
        autostart.Click += async (_, _) => autostart.Checked = await SetAutostart(!autostart.Checked);
        menu.Opening += async (_, _) => autostart.Checked = await GetAutostart();
        menu.Items.Add(autostart);
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add("IPA-Palette beenden", null, (_, _) => { quitting = true; Close(); });
        tray.ContextMenuStrip = menu;
        tray.MouseClick += (_, e) => { if (e.Button == MouseButtons.Left) TogglePalette(); };
    }

    // Autostart: als Store-Paket über die StartupTask aus dem Manifest, sonst über den Run-Schlüssel.
    const string RunKey = @"Software\Microsoft\Windows\CurrentVersion\Run";
    const string StartupTaskId = "IPAPaletteStartup";

    static bool IsPackaged
    {
        get { try { return Windows.ApplicationModel.Package.Current != null; } catch { return false; } }
    }

    static async Task<bool> GetAutostart()
    {
        if (IsPackaged)
        {
            var task = await Windows.ApplicationModel.StartupTask.GetAsync(StartupTaskId);
            return task.State is Windows.ApplicationModel.StartupTaskState.Enabled or Windows.ApplicationModel.StartupTaskState.EnabledByPolicy;
        }
        using var k = Registry.CurrentUser.OpenSubKey(RunKey);
        return k?.GetValue("IPA-Palette") != null;
    }

    static async Task<bool> SetAutostart(bool on)
    {
        if (IsPackaged)
        {
            var task = await Windows.ApplicationModel.StartupTask.GetAsync(StartupTaskId);
            if (on) await task.RequestEnableAsync(); else task.Disable();
            return await GetAutostart();
        }
        using (var k = Registry.CurrentUser.CreateSubKey(RunKey))
        {
            if (on) k.SetValue("IPA-Palette", $"\"{Environment.ProcessPath}\" --hidden");
            else k.DeleteValue("IPA-Palette", false);
        }
        return on;
    }

    void TogglePalette()
    {
        if (Visible) Hide();
        else { Show(); Native.ShowWindow(Handle, Native.SW_SHOWNOACTIVATE); }
    }

    // ---------------------------------------------------------------- Fenster

    // Beim Anzeigen kein Fokus klauen: Zielprogramm bleibt aktiv.
    protected override bool ShowWithoutActivation => true;

    protected override void WndProc(ref Message m)
    {
        if (m.Msg == Native.WM_HOTKEY && (int)m.WParam == HotKeyId) TogglePalette();
        else if (m.Msg == Native.WM_SHOWME) { Show(); Native.ShowWindow(Handle, Native.SW_SHOWNOACTIVATE); }
        base.WndProc(ref m);
    }

    protected override void OnFormClosing(FormClosingEventArgs e)
    {
        SaveBounds();
        if (!quitting && e.CloseReason == CloseReason.UserClosing) { e.Cancel = true; Hide(); return; }
        Native.UnregisterHotKey(Handle, HotKeyId);
        if (hook != IntPtr.Zero) Native.UnhookWinEvent(hook);
        tray.Visible = false;
        base.OnFormClosing(e);
    }

    string BoundsFile => Path.Combine(dataDir, "fenster.txt");

    void LoadBounds()
    {
        var area = Screen.PrimaryScreen!.WorkingArea;
        Bounds = new Rectangle(area.Right - 380, area.Top + 80, 360, Math.Min(640, area.Height - 120));
        try
        {
            var p = File.ReadAllText(BoundsFile).Split(',').Select(int.Parse).ToArray();
            var r = new Rectangle(p[0], p[1], p[2], p[3]);
            if (Screen.AllScreens.Any(s => s.WorkingArea.IntersectsWith(r))) Bounds = r;
        }
        catch { }
    }

    void SaveBounds()
    {
        try
        {
            Directory.CreateDirectory(dataDir);
            var r = WindowState == FormWindowState.Normal ? Bounds : RestoreBounds;
            File.WriteAllText(BoundsFile, $"{r.X},{r.Y},{r.Width},{r.Height}");
        }
        catch { }
    }
}

static class Native
{
    public const uint EVENT_SYSTEM_FOREGROUND = 3, WINEVENT_OUTOFCONTEXT = 0;
    public const int WM_HOTKEY = 0x0312, SW_SHOWNOACTIVATE = 4;
    public const uint MOD_ALT = 1, MOD_CONTROL = 2, MOD_NOREPEAT = 0x4000;
    public const ushort VK_LEFT = 0x25, VK_CONTROL = 0x11;
    public static readonly IntPtr HWND_BROADCAST = 0xffff;
    public static readonly int WM_SHOWME = RegisterWindowMessage("Askalon.IPAPalette.Show");

    public delegate void WinEventDelegate(IntPtr hook, uint ev, IntPtr hwnd, int idObject, int idChild, uint thread, uint time);
    [DllImport("user32.dll")] public static extern IntPtr SetWinEventHook(uint min, uint max, IntPtr mod, WinEventDelegate proc, uint pid, uint tid, uint flags);
    [DllImport("user32.dll")] public static extern bool UnhookWinEvent(IntPtr hook);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hwnd);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr hwnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hwnd, int cmd);
    [DllImport("user32.dll")] public static extern bool RegisterHotKey(IntPtr hwnd, int id, uint mods, uint vk);
    [DllImport("user32.dll")] public static extern bool UnregisterHotKey(IntPtr hwnd, int id);
    [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr hwnd, int msg, int w, int l);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int RegisterWindowMessage(string name);
    [DllImport("user32.dll", SetLastError = true)] static extern uint SendInput(uint n, INPUT[] inputs, int size);

    [StructLayout(LayoutKind.Sequential)] struct INPUT { public uint type; public KEYBDINPUT ki; public long pad; }
    [StructLayout(LayoutKind.Sequential)] struct KEYBDINPUT { public ushort vk, scan; public uint flags, time; public IntPtr extra; }
    const uint INPUT_KEYBOARD = 1, KEYEVENTF_KEYUP = 2, KEYEVENTF_UNICODE = 4;

    /// Jede UTF-16-Einheit als Unicode-Tastendruck (Ersatzpaare gehen als zwei Einheiten durch).
    public static void TypeUnicode(string text)
    {
        var list = new List<INPUT>();
        foreach (char c in text)
        {
            list.Add(new INPUT { type = INPUT_KEYBOARD, ki = new KEYBDINPUT { scan = c, flags = KEYEVENTF_UNICODE } });
            list.Add(new INPUT { type = INPUT_KEYBOARD, ki = new KEYBDINPUT { scan = c, flags = KEYEVENTF_UNICODE | KEYEVENTF_KEYUP } });
        }
        SendInput((uint)list.Count, list.ToArray(), Marshal.SizeOf<INPUT>());
    }

    public static void Chord(ushort mod, ushort vk)
    {
        var a = new[]
        {
            new INPUT { type = INPUT_KEYBOARD, ki = new KEYBDINPUT { vk = mod } },
            new INPUT { type = INPUT_KEYBOARD, ki = new KEYBDINPUT { vk = vk } },
            new INPUT { type = INPUT_KEYBOARD, ki = new KEYBDINPUT { vk = vk, flags = KEYEVENTF_KEYUP } },
            new INPUT { type = INPUT_KEYBOARD, ki = new KEYBDINPUT { vk = mod, flags = KEYEVENTF_KEYUP } },
        };
        SendInput(4, a, Marshal.SizeOf<INPUT>());
    }

    public static void TapKey(ushort vk)
    {
        var a = new[]
        {
            new INPUT { type = INPUT_KEYBOARD, ki = new KEYBDINPUT { vk = vk } },
            new INPUT { type = INPUT_KEYBOARD, ki = new KEYBDINPUT { vk = vk, flags = KEYEVENTF_KEYUP } },
        };
        SendInput(2, a, Marshal.SizeOf<INPUT>());
    }
}
