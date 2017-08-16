#!/bin/bash

# 15 aug 2017 Тестовое задание для кандидата на вакансию DevOps в компанию PDFfiller Тейковцева Дмитрия mail:daimon243@gmail.com, skype:daimon.ukrain
#
# Задача по shell скрипту:
#
#
# 1. Написать программу которая читает в real-time постоянно обновляжшийся лог веб сервера
#    В логе пять колоноk. Нас интересует цифаа в 4й колонке.
#
# Пример формата лога:
#
# 10/20/2017   673   7873   8     788222
# 10/20/2017   679   7873   17    788222
# 10/20/2017   687   7873   3     788222
#
# Если эта цифра > 10 три раза подряд, то посылать email на любой аддресс с subject "NOTIFICATION: DOWN"
#
# после этого ждать пока эта цифра <=10 три раза подряд  и тогда посылать email с subject "NOTIFICATION: UP"
#
# 2. Добавить в скрипт функционал который бы печатал информацию о пользовании скриптом при передаче определенной опции:   
#    Например:    ./script.sh -about
#
# 3. Как дополнительный плюс добавить signal handler который бы останавливал скрипт при получение определенного сигнала от команды kill

# Для использования конкретных версий программ и для гибкости переноса между разными ОС
TAIL="/usr/bin/tail"
AWK="/usr/bin/awk"
SED="/bin/sed"
SLEEP="/usr/bin/sleep"
SENDMAIL="/usr/sbin/sendmail"

# объявляем внутренние переменные
# для выбота значения из указанной колонки
declare -i interestdigit=0
# счетчик для встретивщихся подряд значений более заданной величины (счетчик когда сервис DOWN)
declare -i counterdown=0
# счетчик для встретившихся подряд значений менее либо равной заданной величины (счетчик когда сервис UP)
declare -i counterup=0
# флаг было ли уведомление когда сервис DOWN
declare -i ifnotifydown=0
# флаг было ли уведомление когда сервис UP, выставлен в 1 для того чтобы не отсылать уведомление при старте программы
declare -i ifnotifyup=1
# переменная содержит сигнал от команды kill
declare -i ifexit=0
# для тела сообщения
message=""

# объявляем внешние(изменяемы из командной строки) переменные
# для имени файла который будем парсить
filename=""
# для списка почтовых адресов на которые шлем уведомления
mailto=""
# для вывода отладчной 
log="/dev/null"
# для пида процесса
pid="/tmp/read_notify_from_log"`date "+%s"`".pid"
# Номер колонки из которой берем данные
declare -i colnum=4
# количество полученных значений подряд превышающих (state DOWN) значение triggervalue либо <= для (state UP)
declare -i triggercount=3
# Значение относительно которого идет сравнение
declare -i triggervalue=10
# Выводить ли справку по работе с программой
declare -i about=0
# выводить ли на консоль как распарсились параметры командной строки (для проверки e-maul, UTF-8, пробеллов и т.д)
declare -i verbose=0
# уровень подробности для вывода лога
declare -i debug=0

function usage()
{
    echo "USAGE:"
    echo "  $0 [options] < -f /path/to/read/file | --filename /path/to/read/file > < -m mail@one,mail@to | --mailto mail@one,mail@to>"
    echo "options:"
    echo "  [ -c # | --triggercount # ] количество значений встретившихся подряд, по умолчанию 3"
    echo "  [ -x # | --triggervalue # ] значение с которым производим сравнение, по умолчанию 10"
    echo "  [ -n # | --colnum # ] номер колонки из которой выбираем значение, по умолчанию 4"
    echo "  [ -l /path/to/log/file | --log /path/to/log/file ] для контроля и статистики работы программы, по умолчанию /dev/null"
    echo "  [ -p /path/to/pid/file | --pid /path/to/pid/file ] для контроля работы программы, по умолчанию /tmp/read_notify_from_log.pid"
    echo "  [ -a | --about ] вывод информации по использованию"
    echo "  [ -v | --verbose ] распарсиваем и выводим на консоль параменты командной строки для проверкии и выходим"
    echo "  [ -d | --debug ] вывод в лог отладочной информации, лучше не включать :)"
    echo
    echo " Программа читает в real-time постоянно обновляжшийся лог из < -f /path/to/read/file | --filename /path/to/read/file >"
    echo " Пример формата лога:"
    echo "  10/20/2017   673   7873   8     788222"
    echo "  10/20/2017   679   7873   17    788222"
    echo "  10/20/2017   687   7873   3     788222"
    echo "цифру из колонки [--column, default 4] и сравнивает ее со значением [--triggervalue, default 10]"
    echo "если цифра из колонки была больше [--triggercount] раза подряд тогда посылаем"
    echo "сообщение на e-mail <--mailto recipients separated by commas without spaces>"
    echo "с темой сообщения 'NOTIFICATION: DOWN'. После этого если цифра из колонки была меньше либо равна [--triggervalue]"
    echo "подряд [--triggercount] раз тогда посылаем сообщение на указанные e-mail с темой 'NOTIFICATION: UP'"
}

# Парсим параметры переданные в коммандной строке --------- начало блока обработки параметров
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -f|--filename)
    filename="$2"
    shift # shift argument
    ;;
    -m|--mailto)
    mailto="$2"
    shift # shift argument
    ;;
    -c|--triggercount)
    triggercount="$2"
    shift # shift argument
    ;;
    -x|--triggervalue)
    triggervalue="$2"
    shift # shift argument
    ;;
    -n|--colnum)
    colnum="$2"
    shift # shift argument
    ;;
    -l|--log)
    log="$2"
    shift # shift argument
    ;;
    -p|--pid)
    pidfile="$2"
    shift # shift argument
    ;;
    -a|--about)
    about=1
    ;;
    -v|--verbose)
    verbose=1
    ;;
    -d|--debug)
    debug=1
    ;;
    *)
        # unknown option
    ;;
esac
shift # shift argument or value
done

# Если влючена опция вывода спавки по параметрам программы показываем и выходим
if [ ${about} -gt 0 ] ; then
    usage
    exit
fi

# Если не передан обязательный параметр имя файла нет источника показываем как пользоваться и выходим
if [ -z "${filename}" ] ; then
    usage
    exit
fi

# Если не передан обязательный параметр почтовый ящик нет кого уведомлять показываем как пользоваться и выходим
if [ -z "${mailto}" ] ; then
    usage
    exit
fi

mailto=`echo ${mailto} | ${SED} -e "s/,/ /g"`

# Если включена опция verbose выводим параметры и выходим
if [ ${verbose} -gt 0 ] ; then
  echo "filename=${filename}"
  echo "mailto=${mailto}"
  echo "colnum=${colnum}"
  echo "triggercount=${triggercount}"
  echo "triggervalue=${triggervalue}"
  echo "log=${log}"
  echo "pidfile=${pidfile}"
  exit
fi

# ------------------------------------------------------------ завершение блока работы с параметрами

# сохраняем пид в файл
echo $$ > ${pidfile}

# Описываем сигналы с которые будем обрабатывать
trap "ifexit=1" HUP # resume scaning file
trap "ifexit=2" INT # block signal
trap "ifexit=6" ABRT # suspend scaning file
trap "ifexit=15" TERM # program terminate
# это неблокируемый сигнал
#trap "ifexit=9" KILL


while ( true ) do

    # построчно читаем непрерывно обновляемый файл
    # параметр -s 0.1  это время между обращениями к файлу по умолчанию он равен 1.0 сек
    ${TAIL} -n0 -s 0.1 -f ${filename} 2>/dev/null | while read line
    do

      # выделяем из строки важные данные (в тесте указана 4 колонка)
      interestdigit=`echo ${line} | ${AWK} "{print \$ $colnum}"`

      # думаю для отчета на почту важная информация когда произошло событие выделяю для тела письма
      message="date: "`echo ${line} | $AWK '{print $1}'`

      if [ ${interestdigit} -gt ${triggervalue} ] ; then
          # Если важные данные больше чем значение для нормальной работы веб сервера (в задании указано число 10)
          # cчетчик подряд значений для восстанавливающегося веб сервера обнуляем
          counterup=0
          # а счетчик подряд значений падающего сервера увеличиваем
          counterdown=$((${counterdown} + 1))
      else
          # Если же важные данные меньше либо равны чем значение для нормальной работы веб сервера
          # тогда наоборот зануляем счетчик подряд значений падающего сервера
          counterdown=0
          # cчетчик подряд значений для восстанавливающегося веб сервера увеличиваем
          counterup=$((${counterup} + 1))
      fi

      # Проверяем набралось ли достаточно подряд значений чтобы оповестить что серверу стало плохо
      if [ ${counterdown} -ge ${triggercount} ] ; then
        # чтобы не испытывать счетчик и окружение на прочность и не наращиваеть его бесконечно фиксируем значение больше чем максимальное на 1
        counterdown=$((${triggercount} + 1))
        if [ ${ifnotifydown} -eq 0 ] ; then
          # если еще не уведомляли о том что серверу плохо, делаем это, и чтобы не делать это для каждой переданной с сервера строки
          # устанавливаем флаг о том что нотификация уже отослана, так же снимаем флаг для нотификации когда серверу станет хорошо
          ifnotifydown=1
          ifnotifyup=0
          echo -e "Subject: NOTIFICATION: DOWN\n\n${message}\n\n" | ${SENDMAIL} -f robot@myserver.mydomain ${mailto}
          # в этом месте есть небольшой оверхед это вывод в лог для отладки но в данном случае эти данные возможно использовать для мониторинга сервера
          # если в этом нет необходимости то строку нужно коментировать такая же ситуация и с такой же строкой в следующем блоке
          echo `date "+%y-%m-%d %H:%M:%S "`"mailto:${mailto} notify down" >> $log
        fi
      fi

      # Проверяем набралось ли достаточно подряд значений чтобы оповестить что серверу уже хорошо
      # В данном блоке все как и в предидущем только тут мы нотифицируем что серверу уже хорошо
      if [ ${counterup} -ge ${triggercount} ] ; then
        counterup=$((${triggercount} + 1))
        if [ ${ifnotifyup} -eq 0 ] ; then
          ifnotifydown=0
          ifnotifyup=1
          echo -e "Subject: NOTIFICATION: UP\n\n${message}\n\n" | ${SENDMAIL} -f robot@myserver.mydomain ${mailto}
          # коментировать тут:
          echo `date "+%y-%m-%d %H:%M:%S "`"mailto:${mailto} notify up" >> $log
        fi
      fi

      # Данная строка используется только для отладки и выводит состояние счетчиков для каждой полученной от веб сервера
      # строки в логах. По умолчанию переменная $log смотрит на /dev/null, но для продакшена весь этот блок можно закоментировать
      if [ ${debug} -gt 0 ] ; then
          echo `date "+%y-%m-%d %H:%M:%S "`"read $interestdigit counterdown=${counterdown} counterup=${counterup}" >> $log
      fi

    done

    # Данный блок для работы с сигналами 
    ifwait=true
    while ( ${ifwait} ) do
        # данный кусочек кода чтобы скипнуть блок ifs в случае если сигнал не поступал
        if [ $ifexit -gt 0 ] ; then
            # обрабатываем сигналы например такими действиями
            # если кильнуть c SIGTERM заканчиваем работу и выходим, прихватив пидфайл чтобы не замусоривать ФС
            if [ $ifexit -eq 15 ] ; then
                rm ${pidfile}
                echo `date "+%y-%m-%d %H:%M:%S "`"found kill signal=$ifexit. exit... " >> $log
                exit
            fi
            # если SIGHUP или SIGTERM тогда 
            # если мы ранее суспендили работу с логом сервера тогда выходим из этого цикла и возвращаемся
            # к работе с логом сервера, если же эти сигналы были отправлены во время нормальной работы просто игнорим их
            if [ $ifexit -eq 1 ] ; then
                echo `date "+%y-%m-%d %H:%M:%S "`"found kill signal=$ifexit. resume... " >> $log
                ifwait=false
            fi
            if [ $ifexit -eq 2 ] ; then
                echo `date "+%y-%m-%d %H:%M:%S "`"found kill signal=$ifexit. ignored for exit need TERM " >> $log
                ifwait=false
            fi
            # если SIGABRT то прекращаем работу с логом сервера типа суспендимся и ждем других сигналов
            if [ $ifexit -eq 6 ] ; then
                echo `date "+%y-%m-%d %H:%M:%S "`"found kill signal=$ifexit. suspend... " >> $log
            fi
            # приостанавливаемся на секунду чтобы не перегрелся процессор :)
            sleep 1
        fi
    done

done

# end of file