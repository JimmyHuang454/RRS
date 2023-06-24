quit(){
  echo $1
  exit 1
}

download_lastest_RRS_to() {
  DOWNLOAD_LINK="https://github.com/JimmyHuang454/RRS/releases/latest/download/RRS_Linux.zip"
  echo "Downloading from: $DOWNLOAD_LINK"
  if ! curl -R -H 'Cache-Control: no-cache' -o "$1"  "$DOWNLOAD_LINK"; then
    quit 'error: Download failed! Please check your network or try again.'
  fi
}

decompression() {
  if ! unzip -q "$1" ; then
    quit 'error: decompression failed.'
  fi
}

download_lastest_RRS_to "./step1.zip"
decompression "./step1.zip"
ls disk
