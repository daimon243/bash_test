#!/bin/bash

# 15 aug 2017 Дмитрий Тейковцев daimon243@gmail.com
# Пример скрипта типа скриптов в /etc/init.d но на чистом bash для тестового задания
# описание задания находится в файле read_notify_from_log.sh
# без сомнения данный скрипт лучше реализовывать готовыми инструментами в используемой ОС
# типа /sbin/openrc-run или /sbin/runscript но как пример скрипта на bash думаю вполне подойдет

configfile="/home/daimon/devel/PDFfiller/read_notify_from_log.conf"
programmfile="/home/daimon/devel/PDFfiller/read_notify_from_log.sh"

function usage(){
    echo "USAGE: $0 < start | stop | resume | suspend | chekcfg | debug > "
    exit
}

function getpids(){
    if [ -f ${pid} ] ; then
        mainpid=`cat ${pid}`
        children=`pgrep -P ${mainpid}`
    else
        echo "not found pid file "${pid}
        exit
    fi
}

function chekcfg(){
      # парсим параметры из конфигурационного файла и подготавливаем строку для запуска программы
      paramstring=""
      if [ -n "${filename}" ] ; then
        paramstring=${paramstring}" -f "${filename}
      else
        echo "need set parameter <filename> in configfile"
        exit
      fi

      if [ -n "${mailto}" ] ; then
        paramstring=${paramstring}" -m "${mailto}
      else
        echo "need set parameter <mailto> in configfile"
        exit
      fi

      if [ -n "${triggercount}" ] ; then
        paramstring=${paramstring}" -c "${triggercount}
      fi

      if [ -n "${triggervalue}" ] ; then
        paramstring=${paramstring}" -x "${triggervalue}
      fi

      if [ -n "${colnum}" ] ; then
        paramstring=${paramstring}" -n "${colnum}
      fi

      if [ -n "${log}" ] ; then
        paramstring=${paramstring}" -l "${log}
      fi

      if [ -n "${pid}" ] ; then
        paramstring=${paramstring}" -p "${pid}
      fi
}

# Инклудим конфигурационный файл
. ${configfile}

# если параметр не передан выводим справку
if [ $# -lt 1 ] ; then
    usage
fi

# обрабатываем параметр коммандной строки
case $1 in
    chekcfg)
        chekcfg
        echo "command line:"
        echo $programmfile $paramstring
        echo
        echo "parameters in script:"
        bash $programmfile $paramstring -v
    ;;
    start)
        chekcfg
        bash ./read_notify_from_log.sh $paramstring > /dev/null 2>&1 &
    ;;
    debug)
        chekcfg
        bash ./read_notify_from_log.sh $paramstring -d
    ;;
    resume)
        getpids
        kill -1 ${mainpid} ${children}
    ;;
    suspend)
        getpids
        kill -6 ${mainpid} ${children}
    ;;
    stop)
        getpids
        kill -15 ${mainpid} ${children}
    ;;
    *)
        usage
    ;;
esac

# end of file