#!/usr/bin/expect
set timeout -1
spawn ssh root@91.132.49.137 "cat /etc/nginx/sites-available/adminpanel"
expect {
  "*yes/no*" { send "yes\r"; exp_continue }
  "*?assword:*" { send "Furkan2626.\r" }
  eof
}
