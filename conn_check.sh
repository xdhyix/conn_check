#!/bin/bash

# conn_check v5 (2024/10/15)
# by donghoon_lee

PATH=/usr/local/bin/:/sbin:/bin:/usr/sbin:/usr/bin
pid_files=/home/tmon/scripts/conn_check/pid_files
hosts=/home/tmon/scripts/conn_check/conn_check.cnf

make_pid_file() {
   local file="$1"
   local pid="$2"

   # pid 파일이 존재하는지 체크
   if [ -f "$pid_files/$file" ]; then
      local old_pid=$(cat "$pid_files/$file")
	  # pid 파일이 존재하나 비어있는 경우
      if [ -z "$pid_files/$old_pid" ]; then
         echo "#### PID file $file already exists but it is empty ... ####"
         exit 1
	  # pid 파일이 비어있지 않은 경우
	  else
         kill -0 $old_pid 2>/dev/null
         if [ $? -eq 0 ]; then
			# 프로세스 존재, 기존 프로세스 kill 처리
            echo "#### PID file $file already exists and its PID ($old_pid) is being killed ... ####"
			kill -9 $old_pid 2>/dev/null
         else
		    # 프로세스 미존재
            echo "#### Overwriting PID file $file because its PID ($old_pid) is not running ... ####"
         fi
      fi
   fi

   echo "$pid" > "$pid_files/$file"
   echo "#### PID file $file ($pid) is created ... ####"
   if [ $? -ne 0 ]; then
      echo "#### Cannot create or write PID file $file .... ####"
   fi
}

remove_pid_file() {
   local file="$1"
   if [ -f "$pid_files/$file" ]; then
      rm "$pid_files/$file"
	  echo "#### pid file $file is deleted ... ####"
  else
	  echo "#### pid file $file doesn't exist ... ####"
  fi
}

remove_chk_file() {
   local file="$1"
   if [ -f "/home/tmon/scripts/conn_check/chk_files/${file}_stderr" ]; then
      rm /home/tmon/scripts/conn_check/chk_files/${file}_stderr
      echo "#### check file ${file}_stderr is deleted ... ####"
  else
      echo "#### check file ${file}_stderr doesn't exist ... ####"
  fi
}

start() {
	if [ "$1" != "all" ]; then
		local file="$1"
		local thold="$(grep "^${file}[[:space:]]" "$hosts" | awk '{print $2}')"
		local interval="$(grep "^${file}[[:space:]]" "$hosts" | awk '{print $3}')"
		local conn_timeout="$(grep "^${file}[[:space:]]" "$hosts" | awk '{print $4}')"
		local cycle="$(grep "^${file}[[:space:]]" "$hosts" | awk '{print $5}')"
		
		echo "#### Starting $file demon shell ... ####"
		nohup /home/tmon/scripts/conn_check/conn_check_demon.sh "$file" "$thold" "$interval" "$conn_timeout" "$cycle" >> /var/log/scripts/conn_check/conn_check_$file.log 2>&1 &
		make_pid_file "$file" $!
	else
		echo "#"
	fi	
}

stop() {
	local file="$1"
    echo "#### Stopping $file demon shell ... ####"
	
	if [ ! -f "$pid_files/$file" ]; then
		echo "#### pid file $file doesn't exist ... ####"
        exit 1
    else   
		local pid="$(cat "$pid_files/$file")"
		kill -0 $pid 2>/dev/null
		if [ $? -eq 0 ]; then
			echo "#### Killing pid ($pid) process ... ####"
			kill $pid
			remove_pid_file "$file"
			remove_chk_file "$file"
	    else
		    echo "#### pid ($pid) process is not running ... ####"
			exit 1
		fi
	fi
}

####################
# Main
####################
if [ -z "$1" ]; then
   echo "Usage.1: $0 [ hostname ] [ start | stop | restart ] or Usage.2: $0 [ startall | status | killall ]"
   exit 1

else
	# Usage.2
	if [ "$1" == "status" ]; then
		ps -ef | grep conn_check_demon | grep -v grep
    elif [ "$1" == "killall" ]; then
		echo "#### Killing all processes ... ####"
		killall -9 conn_check_demon.sh
		if [ -z "$(ls -A /home/tmon/scripts/conn_check/pid_files/)" ]; then
		    echo "#### pid file does not exist, skipping delete ... ####"
		else
			rm /home/tmon/scripts/conn_check/pid_files/*
			echo "#### pid files are deleted ... ####"
		fi
		if [ -z "$(ls -A /home/tmon/scripts/conn_check/chk_files/)" ]; then
		    echo "#### stderr chk file does not exist, skipping delete ... ####"
		else
		    rm /home/tmon/scripts/conn_check/chk_files/*
			echo "#### chk files are deleted ... ####"
		fi
    elif [ "$1" == "startall" ]; then
		if [ "0" != "$(ps -ef | grep conn_check_demon | grep -v grep | wc -l)" ]; then
            echo "#### Processes are running! Use ./conn_check.sh status ... ####"
			exit 1
		fi
		cat conn_check.cnf | grep -v ^[[:space:]]*$ | grep -v "^#" | awk '{print $1}' > conn_check_tmp_list
        for t in $(cat conn_check_tmp_list)
		do 
			echo "#### Starting all hosts ... ####"
			start "$t"
			echo "#### $t Started! ... ####"
            sleep 0.2
		done	
		rm conn_check_tmp_list
	else
		# Usage.1
		hostchk="$(grep -w "^${1}" "${hosts}" | awk '{print $1}' | grep "^${1}$")"
		echo "hostname: "$hostchk
		if [ -z $hostchk ]; then
			echo "#### hostname is invalid ... ####"
			exit 1
		fi
		case "$2" in
			start)
			start "$1"
			;;
			stop)
			stop "$1"
			;;
			restart)
			echo "feature not yet implemented."
			;;
			*)
			echo "Usage: $0 [ hostname ] [ start | stop | restart ] or Usage: $0 [ startall | status | killall ]"
			exit 1
			;;
		esac
	fi
fi
exit 0
