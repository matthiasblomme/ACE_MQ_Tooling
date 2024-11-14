#print
echo "dis ql(*)" | runmqsc  | grep -oP "(?<=QUEUE\().*?(?=\))" | awk '{printf "ALTER QL(%s) MAXDEPTH(9999)\n",$1}'

#print with double quotes
echo "dis ql(*)" | runmqsc qmd01 | grep -oP '(?<=QUEUE\().*?(?=\))' | grep BACKOUT | awk '{printf "ALTER QL(%s) CUSTOM('"'"'CAPEXPRY(123)'"'"')\n",$1}' |runmqsc qmd01