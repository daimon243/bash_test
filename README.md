# bash_test

###read_notify_from_log.sh

скрипт для анализа лог файла сервера и уведомления на почту по условию

read_notify_from_log.sh [options] < -f /path/to/read/file | --filename /path/to/read/file > < -m mail@one,mail@to | --mailto mail@one,mail@to>

options:

  [ -c # | --triggercount # ] количество значений встретившихся подряд, по умолчанию 3

  [ -x # | --triggervalue # ] значение с которым производим сравнение, по умолчанию 10

  [ -n # | --colnum # ] номер колонки из которой выбираем значение, по умолчанию 4

  [ -l /path/to/log/file | --log /path/to/log/file ] для контроля и статистики работы программы, по умолчанию /dev/null

  [ -p /path/to/pid/file | --pid /path/to/pid/file ] для контроля работы программы, по умолчанию /tmp/read_notify_from_log.pid

  [ -a | --about ] вывод информации по использованию

  [ -v | --verbose ] распарсиваем и выводим на консоль параменты командной строки для проверкии и выходим

  [ -d | --debug ] вывод в лог отладочной информации, лучше не включать :)

Программа читает в real-time постоянно обновляжшийся лог из < -f /path/to/read/file | --filename /path/to/read/file >
цифру из колонки [--column, default 4] и сравнивает ее со значением [--triggervalue, default 10]
если цифра из колонки была больше [--triggercount] раза подряд тогда посылаем
сообщение на e-mail <--mailto recipients separated by commas without spaces>
с темой сообщения 'NOTIFICATION: DOWN'. После этого если цифра из колонки была меньше либо равна [--triggervalue]
подряд [--triggercount] раз тогда посылаем сообщение на указанные e-mail с темой 'NOTIFICATION: UP'

###random_write_to_log.sh

программа для генерации лога для read_notify_from_log.sh

программу просто необходимо запустить в отдельной консоли для проверки работы read_notify_from_log.sh по окончанию
нажать контрол+с. При необходимости нужно изменить 3 строку, параметр filename для указания полного пути к месту 
расположения лог файла


###read_notify_from_log_init_d.sh 

скрипт для управления работой скрипта read_notify_from_log.sh путем передачи
управляющих сигнов и формирования командной строки на основании конфигурационного файла read_notify_from_log.conf

Варианты запуска:

read_notify_from_log_init_d.sh < start | stop | resume | suspend | chekcfg | debug >

Перед запуском необходимо откорректировать файл read_notify_from_log.conf указав правильный пути к файлам и почтовые адреса 
