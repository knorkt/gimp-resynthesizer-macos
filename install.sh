#!/bin/bash

# Resynthesizer 3.x.x for GIMP 3.2.x (macOS Apple Silicon)
# Post-Compile Injection & DNA Rewrite Script
# Run this from the root of the resynthesizer source directory after running 'ninja'

PLUGIN_BASE="/Applications/GIMP.app/Contents/Resources/lib/gimp/3.0/plug-ins"
sudo mkdir -p "$PLUGIN_BASE/resynthesizer" "$PLUGIN_BASE/plug-in-heal-selection" "$PLUGIN_BASE/plug-in-heal-transparency"

echo "1/5: Copying Scheme scripts and C binary into GIMP..."
sudo cp outerPlugins/plug-in-heal-selection.scm "$PLUGIN_BASE/plug-in-heal-selection/"
sudo cp outerPlugins/plug-in-heal-transparency.scm "$PLUGIN_BASE/plug-in-heal-transparency/"
sudo cp builddir/enginePlugin/resynthesizer "$PLUGIN_BASE/resynthesizer/"

ENGINE="$PLUGIN_BASE/resynthesizer/resynthesizer"
BUNDLE="/Applications/GIMP.app/Contents/Resources"
MACPORTS="/opt/local"

echo "2/5: Severing MacPorts dependencies and linking to GIMP core..."
sudo install_name_tool -change ${MACPORTS}/lib/libglib-2.0.0.dylib ${BUNDLE}/lib/libglib-2.0.0.dylib "$ENGINE"
sudo install_name_tool -change ${MACPORTS}/lib/libgobject-2.0.0.dylib ${BUNDLE}/lib/libgobject-2.0.0.dylib "$ENGINE"
sudo install_name_tool -change ${MACPORTS}/lib/libbabl-0.1.0.dylib ${BUNDLE}/lib/libbabl-0.1.0.dylib "$ENGINE"
sudo install_name_tool -change ${MACPORTS}/lib/libgegl-0.4.0.dylib ${BUNDLE}/lib/libgegl-0.4.0.dylib "$ENGINE"

echo "3/5: Fixing the double-lib rpath glitch..."
sudo install_name_tool -rpath /Applications/GIMP.app/Contents/Resources/lib /Applications/GIMP.app/Contents/Resources "$ENGINE"

echo "4/5: Applying execution permissions and forging local signature..."
sudo chmod +x "$ENGINE" "$PLUGIN_BASE/plug-in-heal-selection/plug-in-heal-selection.scm" "$PLUGIN_BASE/plug-in-heal-transparency/plug-in-heal-transparency.scm"
sudo codesign --force --sign - "$ENGINE"

echo "5/5: Clearing Apple Quarantine flag..."
sudo xattr -cr /Applications/GIMP.app

echo "SUCCESS: Resynthesizer is natively installed."
