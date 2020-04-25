#!/bin/bash

rm -rf AppIcon.appiconset

mkdir AppIcon.appiconset

function cut(){

sips -Z $1 1024.png --out ./AppIcon.appiconset/$2@$3x.png

}

cut 80 40 2

cut 180 60 3

cut 29 29 1

cut 58 29 2

cut 87 29 3

cut 80 40 2

cut 120 40 3

cut 57 57 1

cut 114 57 2

cut 120 60 2

cut 180 60 3

cut 20 20 1

cut 40 20 2

cut 29 29 1

cut 58 29 2

cut 40 40 1

cut 80 40 2

cut 76 76 1

cut 152 76 2

cut 167 83.5 2

cut 1024 1024 1

cut 120 60 2

cut 180 60 3

cut 48 24 2

cut 55 27.5 2

cut 58 29 2

cut 87 29 3

cut 40 40 1

cut 172 86 2

cut 196 98 2

cut 1024 1024 1

cut 60 20 3

cut 50 50 1

cut 100 50 2

cut 72 72 1

cut 144 72 2

cut 88 44 2

cut 216 108 2
