#! /bin/sh
### BEGIN INIT INFO
# Provides: smrtlink
# Required-Start: $remote_fs $syslog
# Required-Stop: $remote_fs $syslog
# Default-Start: 2 3 4 5
# Default-Stop: 0 1 6
# Short-Description: PacBio SMRTLink server
# Description: This file checks, starts, and stops the SMRTLink server
# 
### END INIT INFO

export SMRT_ROOT=/opt/pacbio/smrtlink
export SMRT_USER=smrtanalysis

case "$1" in
 status)
   su ${SMRT_USER} -c ${SMRT_ROOT}/admin/bin/services-status
   ;;
 start)
   su ${SMRT_USER} -c ${SMRT_ROOT}/admin/bin/services-start
   ;;
 stop)
   su ${SMRT_USER} -c ${SMRT_ROOT}/admin/bin/services-stop
   sleep 10
   ;;
 restart)
   su ${SMRT_USER} -c ${SMRT_ROOT}/admin/bin/services-stop
   sleep 20
   su ${SMRT_USER} -c ${SMRT_ROOT}/admin/bin/services-start
   ;;
 *)
   echo "Usage: smrtlink {start|stop|restart}" >&2
   exit 3
   ;;
esac
