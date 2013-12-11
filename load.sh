#!/bin/bash

cd sql_backup/databases/
for f in *.tsv; do
  mysql -uroot olook_development -e "load data local infile '$f' into table $(echo $f | sed 's/.tsv//g');" -vvv;
done

