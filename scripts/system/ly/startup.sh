#!/bin/sh
# Palette for the 16-color scientific-monitor Ly theme.
# Linux virtual consoles support a programmable 16-color palette, not 24-bit RGB.
case "${TERM:-linux}" in
    linux|vt*)
        set -- \
            00005F 873A3A 3A755F 87784F \
            3A5675 784F78 5F87AF D7E7FF \
            000000 FF5F5F 87D7AF FFD75F \
            87AFD7 D787AF AFD7FF FFFFFF
        index=0
        for color do
            printf '\033]P%x%s' "$index" "$color"
            index=$((index + 1))
        done
        printf '\033[2J\033[H'
        ;;
esac
