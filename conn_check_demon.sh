#!/bin/bash

# conn_check_demon v5 (2024/10/22)
# by donghoon_lee

##############################
# format: hostname threshold(ms) sleep(s) timeout(s) cycle(s)
# example: db1 300 1 30 2
##############################

cnt=0
host=$1
thold=$2
interval=$3
conn_timeout=$4
cycle=$5
repository_host="host"
repository_db="db"
chk_file="....../scripts/conn_check/chk_files/${host}_stderr"

while sleep $interval; do
	sttm=$(date +%s%3N)
	
	/usr/bin/mysql --login-path=remote --batch --wait --connect-timeout=${conn_timeout} --skip-reconnect --silent --host=${host} -e"\q" 1> /dev/null 2> ${chk_file}

    entm=$(date +%s%3N)
    diff=$(( entm - sttm ))
    date=$(date +%T)
 	chk=`cat ${chk_file} | awk -F ' ' '{print $11}'`
    
    # 호스트 정상
	# 사이클 체크: 임계초과시 cnt=cnt+1
	# 얼럿 체크: cnt==cycle 이면 얼럿 or cnt<cycle 이면 스킵
    if [ -z "${chk}" ]; then

		echo `date`
		echo ${host} "-" ${diff} "ms"
		#디비 적재 중단함
		#/usr/bin/mysql --login-path=remote --host=${repository_host} --database=${repository_db} -e"INSERT INTO db_response.db_response (dttm, svr, rpt, thold, sleeptime, timeout, cycle, cnt) VALUES (NOW(), '${host}', ${diff}, ${thold}, ${interval}, ${conn_timeout}, ${cycle}, ${cnt});"
        
		# 임계 초과시 카운트+1
		if [ "$diff" -gt "$thold" ]; then
			cnt=$((cnt+1))
            
			# 사이클 도달 체크, 도달시 얼럿
			if [ "$cnt" -eq "$cycle" ]; then
                #slack webhook url...
                #teams webhook url...

				#디비 적재 중단함
				#/usr/bin/mysql --login-path=remote --host=${repository_host} --database=${repository_db} -e"INSERT INTO db_response.db_response (dttm, svr, rpt, thold, sleeptime, timeout, cycle, cnt) VALUES (NOW(), '${host}', ${diff}, ${thold}, ${interval}, ${conn_timeout}, ${cycle}, ${cnt});"
				# 얼럿시 카운트 초기화
				cnt=0
			else
				# 사이클 이하시 얼럿 스킵, 카운트 유지
				echo "... count/cycle = "${cnt}"/"${cycle}
		    fi

		# 임계 이하시 카운트 초기화
		else
			cnt=0
        fi
       
    # 호스트 응답없음
    elif [ "${chk}" = "(110)" ]; then
		echo "Socket errno 110 = Connection timed out"
		#디비 적재 중단함
		#/usr/bin/mysql --login-path=remote --host=${repository_host} --database=${repository_db} -e"INSERT INTO db_response.db_response (dttm, svr, note, thold, sleeptime, timeout, cycle, cnt) VALUES (NOW(), '${host}', '호스트 접근 불가', ${thold}, ${interval}, ${conn_timeout}, ${cycle}, ${cnt});"
		
		#slack webhook url...
		#teams webhook url...

    # mysqld 다운
    elif [ "${chk}" = "(111)" ]; then
		echo "Socker errno 111 = Connection refused"
		#디비 적재 중단함
		#/usr/bin/mysql --login-path=remote --host=${repository_host} --database=${repository_db} -e"INSERT INTO db_response.db_response (dttm, svr, note, thold, sleeptime, timeout, cycle, cnt) VALUES (NOW(), '${host}', 'MySQL 접근 불가', ${thold}, ${interval}, ${conn_timeout}, ${cycle}, ${cnt});"
		
		#slack webhook url...
		#teams webhook url...
    
	else
		echo "Unknown error"
		#slack webhook url...
		#teams webhook url...

	fi
	
	rm -rf ${chk_file}

done

exit 0
