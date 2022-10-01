#!/bin/bash
res=300
# Color or Gray. Lineart also, but it sucks.
mode=Gray
brightness=0
contrast=0
repeat="yes"
rotate="-rotate 90"
scanparams='--verbose --progress'

function usage() {
  echo 'Usage: $(basename $0) [-hRC] [-d {75|150|300|600}] [-b -100..100] [-c -100..100] [-n filename]'
  echo '
  -d    Scan resolution in dpi
  -C    Color scan mode (default is gray)
  -b    Scanner brightness
  -c    Scanner contrast
  -R    repeat scan until confirmed
  -n    filename (default is `date +%F-%T)
  -r    no-rotate (default is rotate 90, top is left on scanner)

  '
}


optstring=":hRCrd:b:c:n:"
while getopts ${optstring} arg; do
  case "${arg}" in
    h) 
      usage
      exit
      ;;
    d) res="${OPTARG}" ;;
    r) rotate="" ;;
    R) repeat="no" ;;
    C) mode="Color" ;;
    b) brightness="${OPTARG}" ;;
    c) contrast="${OPTARG}" ;;
    n) timestamp="${OPTARG}" ;;
    ?)
      echo "Invalid option: -${OPTARG}"
      usage
      exit 2
      ;;
  esac
done
if ! echo $res| grep -qE '^75$|^150$|^300$|^600$'; then 
  res=300; 
fi

if ! echo $mode|grep -qE '^Color$|^Gray$';then 
  mode="Gray";
fi

if [ "$mode" == "Color" ] && [ "$brightness" == "0" ]  && [ "$contrast" == "0" ]; then
  brightness=-60
  contrast=-20
fi

if [ "$mode" == "Gray" ] && [ "$brightness" == "0" ]  && [ "$contrast" == "0" ]; then
  brightness=-80
  contrast=20
fi


if [ -z "$timestamp" ]; then 
  timestamp="`date +%F-%T`"
fi

filename="$HOME/Pictures-scanner/raw/$timestamp.pnm"
unpapered="$HOME/Pictures-scanner/ready/$timestamp.pnm"
final="$HOME/Pictures-scanner/ready/$timestamp.png"
scanparams="$scanparams --brightness=$brightness --contrast=$contrast"
echo Scanning to $filename
echo Res: $res Mode: $mode
echo Bright: $brightness Contrast: $contrast
echo Scanparams: $scanparams




function podscan() {
  scanfile="$1"
  scanner=`lsusb | awk '/DSmobile 600/{print "/dev/bus/usb/"$2"/"substr($4,0,3)}'`
  scanparams="$scanparams --brightness $brightness --contrast $contrast"
  tempdir=`mktemp -d`
  podman run\
    --volume "$tempdir":/srv\
    --volume "$HOME/.sane/pentax-dsmobile-600.cal":/root/.sane.pentax-dsmobile-600.cal:ro\
    --device $scanner\
    --rm -it\
    localhost/genesys-scanner:latest\
    /srv/"scan.pnm" \
    -d genesys\
    --resolution $res\
    --mode $mode\
    --format=pnm $scanparams
  mv "$tempdir"/scan.pnm "$scanfile"
  rmdir "$tempdir"
}

function straighten() {
  unpaper --deskew-scan-direction left \
      --overwrite \
      --layout single \
      --sheet-background white \
      --verbose --blurfilter-intensity 0.01 \
      --grayfilter-size 3,3 --grayfilter-step 1,1 --grayfilter-threshold 0.8 \
      --blackfilter-scan-depth 1000,1000 "$1" "$2"
}
finished=0

while [ "$finished" == "0" ]; do
  podscan "$filename"

  if [ -e "$filename" ]; then
    # xloadimage "$filename"
    mogrify -normalize -contrast -enhance $rotate -bordercolor black -border 20 -fuzz 10% -trim +repage "$filename"
    xloadimage "$filename"
    straighten "$filename" "$unpapered"
    mogrify -fuzz 5% -trim +repage "$unpapered"
    xloadimage "$unpapered" "$filename"
    while true; do
      read -p "Keep this scan? (Raw/Yes/No/Cancel)" i
      case "$i" in
        y|Y)
          if convert "$unpapered" +dither -colors 256 -density "$res" -units PixelsPerInch PNG8:"$final"; then
            rm "$unpapered" "$filename";
          fi
          ls -lh "$final"
          exit
          ;;
        n|N) 
          rm "$filename" "$unpapered"
          if [ "$repeat" == "no" ]; then
            exit
          fi
          break
          ;;
        r|R) 
          if convert "$filename" +dither -colors 256 -density "$res" -units PixelsPerInch "$final"; then
            rm "$unpapered" "$filename";
          fi
          ls -lh "$final"
          exit
          ;;
        c|C)
          rm "$unpapered" "$filename";
          exit
          ;;
      esac
    done
  else
    echo "No file scanned"
    exit 1
  fi
done
