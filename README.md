````markdown
# Resynthesizer for GIMP 3.2 (Apple Silicon / macOS Native)

This repository provides step-by-step instructions (and pre-compiled binaries) for building and running the **Resynthesizer** plugin (Heal Selection) natively on Apple Silicon.

### Target Environment

- **OS:** macOS 12 Monterey (and later Apple Silicon releases)
- **Architecture:** ARM64 (Apple M1/M2/M3)
- **Target Application:** GIMP 3.2.4 Beta

## The macOS Build Challenge

Compiling Resynthesizer on macOS requires bypassing three fatal errors:

1. **No `gimptool`:** macOS lacks a `libgimp-3.0-dev` package to generate dependencies.
2. **The "Double-Lib" Glitch:** Meson stamps a broken internal search path (`rpath` as `lib/libgimp...`), causing instant load crashes.
3. **The Pointer Mismatch:** Apple's internal `glib` dictionary lacks modern `_pointer` initializers found in MacPorts, causing a fatal "Split Brain" `Symbol not found` crash during execution.

---

# Zero-to-Hero Compilation Guide

## Phase 1: Foundation & Package Managers

### 1. Install Apple Command Line Tools

```bash
xcode-select --install
```

### 2. Install Homebrew

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### 3. Install MacPorts

Download and install the `.pkg` for your macOS version from:

https://www.macports.org/install.php

Then update MacPorts:

```bash
sudo port -v selfupdate
```

---

## Phase 2: Dependencies & Staging

### 1. Install Build Systems (Homebrew)

```bash
brew install meson ninja pkg-config
```

### 2. Install Graphics Libraries (MacPorts)

```bash
sudo port install glib2 cairo pango harfbuzz gdk-pixbuf2
```

### 3. Create the Workspace

```bash
mkdir -p ~/PhotoApps/pkgconfig
cd ~/PhotoApps
```

---

## Phase 3: Forging the Blueprint & Compiling

### 1. Download Source Code

```bash
git clone https://github.com/bootchk/resynthesizer.git resynthesizer3
cd resynthesizer3
```

### 2. Forge the Translation Blueprint (`gimp-3.0.pc`)

We manually map dependencies and inject `-alias` flags into the linker to solve the `glib` pointer mismatch.

```bash
cat << 'EOF' > ~/PhotoApps/pkgconfig/gimp-3.0.pc
prefix=/Applications/GIMP.app/Contents/Resources
exec_prefix=${prefix}
libdir=${prefix}/lib
includedir=/Applications/GIMP.app/Contents/Resources/include

Name: gimp-3.0
Description: GIMP 3.2 Beta Override
Version: 3.2.4

Requires: glib-2.0 gobject-2.0

Cflags: -I${includedir} \
-I/opt/local/include/cairo \
-I/opt/local/include/pango-1.0 \
-I/opt/local/include/gdk-pixbuf-2.0 \
-I/opt/local/include/babl-0.1 \
-I/opt/local/include/gegl-0.4

Libs: -L${libdir} \
-lgimp-3.0 \
-lgimpbase-3.0 \
-lgimpcolor-3.0 \
-lgimpui-3.0 \
-lgimpwidgets-3.0 \
-lgegl-0.4 \
-lbabl-0.1 \
-Wl,-alias,_g_once_init_enter,_g_once_init_enter_pointer \
-Wl,-alias,_g_once_init_leave,_g_once_init_leave_pointer
EOF
```

### 3. Compile the Engine

```bash
PKG_CONFIG_PATH="${HOME}/PhotoApps/pkgconfig:/opt/local/lib/pkgconfig" meson setup builddir

cd builddir

ninja
```

---

## Phase 4: Injection & DNA Rewrite

This master script:

- copies the C engine and Scheme scripts
- fixes the `rpath` glitch
- severs MacPorts dependencies
- clears Gatekeeper quarantine restrictions

Run this block from the `resynthesizer3` folder:

```bash
cd ~/PhotoApps/resynthesizer3

PLUGIN_BASE="/Applications/GIMP.app/Contents/Resources/lib/gimp/3.0/plug-ins"

sudo mkdir -p \
"$PLUGIN_BASE/resynthesizer" \
"$PLUGIN_BASE/plug-in-heal-selection" \
"$PLUGIN_BASE/plug-in-heal-transparency"

# 1. Copy Frontend & Backend
sudo cp outerPlugins/plug-in-heal-selection.scm \
"$PLUGIN_BASE/plug-in-heal-selection/"

sudo cp outerPlugins/plug-in-heal-transparency.scm \
"$PLUGIN_BASE/plug-in-heal-transparency/"

sudo cp builddir/enginePlugin/resynthesizer \
"$PLUGIN_BASE/resynthesizer/"

# Variables for rewrite
ENGINE="$PLUGIN_BASE/resynthesizer/resynthesizer"
BUNDLE="/Applications/GIMP.app/Contents/Resources"
MACPORTS="/opt/local"

# 2. Sever MacPorts & Map to Core
sudo install_name_tool -change \
${MACPORTS}/lib/libglib-2.0.0.dylib \
${BUNDLE}/lib/libglib-2.0.0.dylib \
"$ENGINE"

sudo install_name_tool -change \
${MACPORTS}/lib/libgobject-2.0.0.dylib \
${BUNDLE}/lib/libgobject-2.0.0.dylib \
"$ENGINE"

sudo install_name_tool -change \
${MACPORTS}/lib/libbabl-0.1.0.dylib \
${BUNDLE}/lib/libbabl-0.1.0.dylib \
"$ENGINE"

sudo install_name_tool -change \
${MACPORTS}/lib/libgegl-0.4.0.dylib \
${BUNDLE}/lib/libgegl-0.4.0.dylib \
"$ENGINE"

# 3. Fix the "lib/lib" double path glitch
sudo install_name_tool -rpath \
/Applications/GIMP.app/Contents/Resources/lib \
/Applications/GIMP.app/Contents/Resources \
"$ENGINE"

# 4. Set execution rights, sign, and clear quarantine
sudo chmod +x \
"$ENGINE" \
"$PLUGIN_BASE/plug-in-heal-selection/plug-in-heal-selection.scm" \
"$PLUGIN_BASE/plug-in-heal-transparency/plug-in-heal-transparency.scm"

sudo codesign --force --sign - "$ENGINE"

sudo xattr -cr /Applications/GIMP.app
```

- Heal Selection will now appear under **Filters > Enhance**
- "Heal Transparency" may throw an `Unknown Error` if executed on a flat layer without an Alpha Channel

---

# Portability & Troubleshooting (The `dylib` Danger Zone)

These compiled binaries are highly custom and not universally portable.

Requirements:

- Apple Silicon (ARM64)
- `/Applications/GIMP.app` path unchanged
- compatible GIMP internal library versions

## Common Errors

| Error Signature | Cause | The Fix |
| --- | --- | --- |
| `dyld: Library not loaded: ... (no such file)` | GIMP moved internal libraries or the app was renamed | Use `otool -L [engine_path]` then `install_name_tool -change` |
| `dyld: Symbol not found: (_g_once_init...)` | Missing `-alias` linker translation flags | Add the `-Wl,-alias...` flags and recompile |
| `Unknown Error` (GIMP GUI) | The C engine crashed silently | Launch GIMP from Terminal to inspect logs |
| `Killed: 9` (Terminal) | Gatekeeper blocked execution | Run `sudo xattr -cr /Applications/GIMP.app` and re-sign the binary |

## Useful Debugging Commands

Inspect linked libraries:

```bash
otool -L /Applications/GIMP.app/Contents/Resources/lib/gimp/3.0/plug-ins/resynthesizer/resynthesizer
```

Launch GIMP via Terminal:

```bash
/Applications/GIMP.app/Contents/MacOS/gimp
```

Clear Gatekeeper quarantine:

```bash
sudo xattr -cr /Applications/GIMP.app
```
````
