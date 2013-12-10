#!/bin/bash
if [ ! -x mysqlparse ]; then
  flex -Cf -8 mysql.flex
  gcc lex.yy.c -ll -o mysqlparse
fi

./mysqlparse sql_backup/databases/MySQL.sql

mkdir sql_backup/databases/toobig/

mv sql_backup/databases/cart* sql_backup/databases/toobig
mv sql_backup/databases/events* sql_backup/databases/toobig

cd sql_backup/databases/
for f in *.tsv; do
  mysql -uroot olook_development -e "load data local infile '$f' replace into table $(echo $f | sed 's/.tsv//g');" -vvv;
done

