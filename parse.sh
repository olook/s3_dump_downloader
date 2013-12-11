#!/bin/bash
if [ ! -x mysqlparse ]; then
  flex -Cf -8 mysql.flex
  gcc lex.yy.c -ll -o mysqlparse
fi

./mysqlparse sql_backup/databases/MySQL.sql

mkdir sql_backup/databases/toobig/

mv sql_backup/databases/cart* sql_backup/databases/toobig
mv sql_backup/databases/events* sql_backup/databases/toobig

