#!/bin/bash

filename="/home/daimon/devel/PDFfiller/abuba.log"

echo "generate log file like as:"
echo "  10/20/2017   673   7873   8     788222"
echo "  10/20/2017   679   7873   17    788222"
echo "  10/20/2017   687   7873   3     788222"
echo
echo "data saved to ${filename}"
echo "Press CTRL+C to break"

while ( true ) do
    value=$(( ( RANDOM % 15 )  + 3 ))
    echo "10/20/2017    673     7873    ${value}    788222" >> ${filename}
    sleep 1
done

# end of file