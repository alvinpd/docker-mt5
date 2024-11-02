#!/bin/bash -eu

if [ ! "$#" -eq 1 ]; then
  echo "Usage: boot.sh [config.ini]"
  exit 1
fi

ln -s /mt5 $MT5
ln -s /configs configs

ls -l configs/

CONFIG=$1
#SCRIPT=$2
#COMMAND0=$3

#-----------------------------------------------------------------------

export DISPLAY SCREEN_NUM SCREEN_WHD

XVFB_PID=0
MT5_PID=0
CRON_PID=0

term_handler() {
    echo '########################################'
    echo 'SIGTERM signal received'

    # NOTE: 'wait' returns status of the killed process
    # NOTE: (with set -e this breaks the script)

    if ps -p $MT5_PID > /dev/null; then
        kill -SIGTERM $MT5_PID
        wait $MT5_PID || true
    fi

    # Wait end of all wine processes
    /docker/waitonprocess.sh wineserver

    if ps -p $XVFB_PID > /dev/null; then
        kill -SIGTERM $XVFB_PID
        wait $XVFB_PID || true
    fi

    if ps -p $CRON_PID > /dev/null; then
        kill -SIGTERM $CRON_PID
        wait $CRON_PID || true
    fi

    # SIGTERM comes from docker stop so treat it as normal signal
    exit 0
}

trap 'term_handler' SIGTERM

#-----------------------------------------------------------------------
# SSH Server

sudo /etc/init.d/ssh start

#-----------------------------------------------------------------------
# Nginx Server

#if ! sudo nginx -t; then
#  exit 1
#fi

#sudo /etc/init.d/nginx start

#-----------------------------------------------------------------------
# store

mklink() {
  SRC=$1
  DST=$2

  echo "$SRC -> $DST"

  rm   -rf "$DST"
  mkdir -p "$SRC"
  ln    -s "$SRC" "$DST"
}

echo "Mounting persistent storage directories..."
#mklink $STORE/mt5/logs      $MT5/logs
#mklink $STORE/mt5/MQL4/Logs $MT5/MQL4/Logs
#mklink $STORE/zorro/Cache   $ZORRO/Cache
#mklink $STORE/zorro/Data    $ZORRO/Data
#mklink $STORE/zorro/Log     $ZORRO/Log

MQL_LOG_FILE="$MT5/MQL5/Logs/$(date +%Y%m%d.log)"

logsha() {
  if [ -f "$MQL_LOG_FILE" ]; then
    sha1sum "$MQL_LOG_FILE"
  else
    echo "NA"
  fi
}

#-----------------------------------------------------------------------
# VNC Server

echo "(BOOT) Starting Xvfb..." >&2
Xvfb $DISPLAY -screen $SCREEN_NUM $SCREEN_WHD \
    +extension GLX \
    +extension RANDR \
    +extension RENDER \
    &> /tmp/xvfb.log &
XVFB_PID=$!

#sleep 2
echo "(BOOT) Starting fluxbox..." >&2
mkdir -p $HOME/.fluxbox
fluxbox -log $HOME/.fluxbox/log &

#sleep 2
echo "(BOOT) Starting x11vnc..." >&2
x11vnc -bg -nopw -rfbport 5900 -forever -xkb -o /tmp/x11vnc.log

#sleep 2

#-----------------------------------------------------------------------
# MT5

MQL_LOG_SHA="$(logsha)"

echo "(BOOT) Starting MT5..." >&2
wine ./mt5/terminal64.exe /config:"C:\\configs\\$CONFIG" /portable &
MT5_PID=$!

#-----------------------------------------------------------------------
# Zorro

#while [ "$MQL_LOG_SHA" = "$(logsha)" ]; do
#  echo "(BOOT) Waiting for MT5 Zorro Expert to initialize..." >&2
#  sleep 1
#done

#sleep 2 # give it just a little more
#echo "(BOOT) Waiting for MT5 Zorro Expert to initialize... OK" >&2

winedevice() {
  sudo ps aux | grep winedevice.exe | head -n1 | awk '{ print $2 }'
}

echo "(BOOT) Looking for winedevice.exe..." >&2

# TODO winedevice.exe uses a lot of cpu, need to figure out why
WINEDEVICE=$(winedevice)
while [ "" = "$WINEDEVICE" ]; do
  sleep 2
  echo "(BOOT) Looking for winedevice.exe..." >&2
  WINEDEVICE=$(winedevice)
done

echo "(BOOT) Found: $(sudo ps aux | grep $WINEDEVICE | grep -v grep)"
echo "(BOOT) Starting cpulimit for winedevice.exe (pid=$WINEDEVICE)..." >&2
sudo cpulimit -p $WINEDEVICE -l 1 &

#echo "(BOOT) Starting Zorro..." >&2
#wine ./zorro/zorro.exe -c "$MODE" -trade "$SCRIPT" -i "$COMMAND0"
#wine zorro/zorro.exe

#-----------------------------------------------------------------------
# Cleanup

# Wait end of mt5
wait $MT5_PID

# Wait end of all wine processes
/docker/waitonprocess.sh wineserver
# Wait end of Xvfb
wait $XVFB_PID
