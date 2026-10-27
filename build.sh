#!/bin/sh
set -e
cd "$(dirname "$0")"
swiftc -O -o DesktopMJ mj.swift
echo "Built ./DesktopMJ"
