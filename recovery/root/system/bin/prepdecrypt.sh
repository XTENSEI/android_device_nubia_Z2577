#!/sbin/sh
# Signal crypto readiness so init starts keymint/gatekeeper for FBE decrypt
setprop crypto.ready 1
