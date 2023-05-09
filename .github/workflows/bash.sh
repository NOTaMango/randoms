#!/bin/bash

echo `date +"%Y/%m/%d %H:%M:%S"`
thisyear=`date +"%Y"`
SourcePath="/em2nymxf/stage/"
Threads="1"
files2send="/Applications/MAMP/htdocs/mxf/files2send"
files2sendlive="/Applications/MAMP/htdocs/mxf/files2sendlive"
files2sendclean="/Applications/MAMP/htdocs/mxf/files2sendclean"
em2_em_updatepromo="/Volumes/ifs/data/automation/em2_em_updatepromo"
em2_flexfile="/Volumes/ifs/data/automation/em2flexfile"
########################################################
# Lock file check, delete if older than 120 minutes    #
# Create a new lock file if it doesn't exist,          #
# if one exists already > 120 minutes old, exit script #
########################################################
NODE=`echo $RANDOM % $Threads + 1 | bc`
NODE="1"
	find ~/ -maxdepth 1 -iname "em2nymxf.send.lock.?" -type f -mmin +120 -delete

		if [ -e ~/em2nymxf.send.lock.$NODE ]
			then
				echo "em2nymxf job already running for node $NODE...exiting"
			exit 0
       		fi

	HOUR=`date +"%H"`
		if [ "$HOUR" -lt "9" ]; then
    			DATE=`date +"%Y/"`
		else
    			DATE=`date +"%Y/"`
		fi
			touch ~/em2nymxf.send.lock.$NODE


find /Applications/MAMP/htdocs/mxf/files2send ! -iname "._*" -iname "*.mxf" ! -iname "?chk_file*" ! -iname "?work_file*" -mmin +1 -print0 | while IFS= read -r -d $'\0' z; do
 y=`basename "$z" | xargs` 
 rr=`echo "${y%.*}" | xargs` 

	if [[ -f "$z" ]]; then
		echo "Working on spot for: $z..."
		status_update_record=`/usr/local/sbin/mysql -B -N --host server.com --port 3306 -u em2 -pword -D mf_log -e "SELECT id,col_date,col_filename,col_delivery_status FROM em2nymxf WHERE col_filename LIKE '%$y%' order by col_date DESC LIMIT 100"`
		status_update_id=`echo $status_update_record | grep ".mxf" | awk '{print $1}' | xargs`
		status_update_col=`echo $status_update_record | grep "$y" | awk '{print $5}' | xargs`	
		status_get_orig_filename=`/usr/local/sbin/mysql -B -N --host server.com --port 3306 -u em2 -pword -D mf_log -e "SELECT col_movfilename FROM em2nymxf WHERE id LIKE '$status_update_id' order by col_date DESC LIMIT 100"`
		status_get_col_filename=`/usr/local/sbin/mysql -B -N --host server.com --port 3306 -u em2 -pword -D mf_log -e "SELECT col_filename FROM em2nymxf WHERE id LIKE '$status_update_id' order by col_date DESC LIMIT 100"`
		shit="$status_get_orig_filename"	
		if [[ $status_update_col = "Queued" ]]; then
				echo "Locating and Linking $y to $em2_em_updatepromo/$y."
	 			find /Volumes/ifs/data/archive/spots/mxf/ -type f ! -iname "._*" -iname "$rr.mxf" ! -iname "?chk_file*" ! -iname "?work_file*" -size +1k -mmin +1 -print0 -exec ln {} "$em2_em_updatepromo/" \;
				echo "******************* Submitting info to SQL for $y *******************"
				/usr/local/sbin/mysql -B -N --host server.com --port 3306 -u em2 -pword -D mf_log -e "UPDATE em2nymxf SET col_delivery_status = 'Sending' WHERE id='${status_update_id}'";
				touch "/Volumes/ifs/data/automation/em2email/.updatepromo.sentemail.lock"
		fi
		status_update_record=`/usr/local/sbin/mysql -B -N --host server.com --port 3306 -u em2 -pword -D mf_log -e "SELECT id,col_date,col_filename,col_delivery_status FROM em2nymxf WHERE col_filename LIKE '%$y%' order by col_date DESC LIMIT 100"`
		status_update_id=`echo $status_update_record | grep ".mxf" | awk '{print $1}' | xargs`
		status_update_col=`echo $status_update_record | grep "$y" | awk '{print $5}' | xargs`	
		if [[ $status_update_col = "Sending" ]]; then
			check_dash=`find "$em2_em_updatepromo/" -iname "$y" -exec ls {} \; | grep "$y" | xargs basename | xargs`
			if ! [[ $check_dash = "$y" ]]; then
				echo "******************* Submitting info to SQL for $y *******************"
				/usr/local/sbin/mysql -B -N --host server.com --port 3306 -u em2 -pword -D mf_log -e "UPDATE em2nymxf SET col_delivery_status = 'Delivered' WHERE id='${status_update_id}'";
			fi
		fi
		status_update_record=`/usr/local/sbin/mysql -B -N --host server.com --port 3306 -u em2 -pword -D mf_log -e "SELECT id,col_date,col_filename,col_delivery_status FROM em2nymxf WHERE col_filename LIKE '%$y%' order by col_date DESC LIMIT 100"`
		status_update_id=`echo $status_update_record | grep ".mxf" | awk '{print $1}' | xargs`
		status_update_col=`echo $status_update_record | grep "$y" | awk '{print $5}' | xargs`	
		if [[ $status_update_col = "Delivered" ]]; then
		echo "******************* Cleanining up after $y *******************"
			rm -f "$files2send/$y"
			bash /usr/local/sbin/sendmail.sh "fromaddress.com" "Nathan.Ardoin@abc.com" "$status_get_col_filename file has been Shayred." "file $status_get_col_filename has been manually linked to Shayre for the UpdatePromo Workflow, via the myserver.com/mxf delivery system." "abctvrelay.swna.wdpr.disney.com"
			bash /usr/local/sbin/sendmail.sh "fromaddress.com" "Marty@Ikercreative.com" "$status_get_col_filename file has been Shayred." "file $status_get_col_filename has been manually linked to Shayre for the UpdatePromo Workflow, via the myserver.com/mxf delivery system." "abctvrelay.swna.wdpr.disney.com"
			bash /usr/local/sbin/sendmail.sh "fromaddress.com" "martyiker@gmail.com" "$status_get_col_filename file has been Shayred." "file $status_get_col_filename has been manually linked to Shayre for the UpdatePromo Workflow, via the myserver.com/mxf delivery system." "abctvrelay.swna.wdpr.disney.com"
			bash /usr/local/sbin/sendmail.sh "fromaddress.com" "Matt.Comeione@mpmisolutions.com" "$status_get_col_filename file has been Shayred." "file $status_get_col_filename has been manually linked to Shayre for the UpdatePromo Workflow, via the myserver.com/mxf delivery system." "abctvrelay.swna.wdpr.disney.com"
			bash /usr/local/sbin/sendmail.sh "fromaddress.com" "Chris.Monte@mpmisolutions.com" "$status_get_col_filename file has been Shayred." "file $status_get_col_filename has been manually linked to Shayre for the UpdatePromo Workflow, via the myserver.com/mxf delivery system." "abctvrelay.swna.wdpr.disney.com"
			bash /usr/local/sbin/sendmail.sh "fromaddress.com" "Christopher.Scott@disney.com" "$status_get_col_filename file has been Shayred." "file $status_get_col_filename has been manually linked to Shayre for the UpdatePromo Workflow, via the myserver.com/mxf delivery system." "abctvrelay.swna.wdpr.disney.com"
			bash /usr/local/sbin/sendmail.sh "fromaddress.com" "Stacey.A.Dennis@abc.com" "$status_get_col_filename file has been Shayred." "file $status_get_col_filename has been manually linked to Shayre for the UpdatePromo Workflow, via the myserver.com/mxf delivery system." "abctvrelay.swna.wdpr.disney.com"
			bash /usr/local/sbin/sendmail.sh "fromaddress.com" "Frank.Diaz@abc.com" "$status_get_col_filename file has been Shayred." "file $status_get_col_filename has been manually linked to Shayre for the UpdatePromo Workflow, via the myserver.com/mxf delivery system." "abctvrelay.swna.wdpr.disney.com"
			bash /usr/local/sbin/sendmail.sh "fromaddress.com" "kira.d.foltz@disney.com" "$status_get_col_filename file has been Shayred." "file $status_get_col_filename has been manually linked to Shayre for the UpdatePromo Workflow, via the myserver.com/mxf delivery system." "abctvrelay.swna.wdpr.disney.com"				
		fi
	fi
done
echo "done with files2send"

###########################################################################################################################################################################################
find /Applications/MAMP/htdocs/mxf/files2sendlive ! -iname "._*" -iname "*JKM*.mxf" ! -iname "?chk_file*" ! -iname "?work_file*" -mmin +1 -print0 | while IFS= read -r -d $'\0' zz; do
 yy=`basename "$zz" | xargs` 
 rrr=`echo "${yy%.*}" | xargs` 
#echo "Found: $yy"
#############/Volumes/ifs/data/automation/em2flexfile/out/$mxfname

	if [[ -f "$zz" ]]; then
		echo "Working on live spot for: $zz..."
		echo "rrr:$rrr"
		status_update_record=`/usr/local/sbin/mysql -B -N --host server.com --port 3306 -u em2 -pword -D mf_log -e "SELECT id,col_date,col_filename,col_delivery_status FROM em2nymxf WHERE col_filename LIKE '%$yy%' order by col_date DESC LIMIT 100"`
		status_update_id=`echo $status_update_record | grep ".mxf" | awk '{print $1}' | xargs`
		status_update_col=`echo $status_update_record | grep "$yy" | xargs`	
		status_get_orig_filename=`/usr/local/sbin/mysql -B -N --host server.com --port 3306 -u em2 -pword -D mf_log -e "SELECT col_movfilename FROM em2nymxf WHERE id LIKE '$status_update_id' order by col_date DESC LIMIT 100"`
		status_get_col_filename=`/usr/local/sbin/mysql -B -N --host server.com --port 3306 -u em2 -pword -D mf_log -e "SELECT col_filename FROM em2nymxf WHERE id LIKE '$status_update_id' order by col_date DESC LIMIT 100"`
		shit="$status_get_orig_filename"
		echo "SUI:$status_update_id"
		echo "SUR:$status_update_record"
		echo "SUC:$status_update_col"
		echo "SGOF:$status_get_orig_filename"
		if echo "$status_get_orig_filename" | grep -q "_B_H"; then
			thisone=`echo "$shit" | awk -F_B_H '{print $0}' | sed 's/.mov/.mxf/g' |xargs`
			thisone=`echo "$thisone.mxf"`
		fi	
		if echo "$status_get_orig_filename" | grep -q "_E_H"; then
			thisone=`echo "$shit" | awk -F_E_H '{print $1}' | sed 's/.mov/.mxf/g' | xargs`
			thisone=`echo "$thisone"`
			E_H=`echo "_E_H.mxf"`
			thisonewithEH=`echo "$thisone$E_H"`
			echo "thisone:$thisone"
			echo "thisonewithEH:$thisonewithEH"
		fi	
		thisone=`echo $thisone | xargs`
		echo "this one: $thisone"
		
		if [[ $status_update_col = *"Queued Live"* ]]; then
				echo "Locating and Linking $yy to $em2_flexfile/out/$yy."
	 			find /Volumes/ifs/data/archive/spots/mxf/ -type f ! -iname "._*" -iname "$rrr.mxf" ! -iname "?chk_file*" ! -iname "?work_file*" -size +1k -mmin +1 -print0 -exec ln {} "$em2_flexfile/out" \;
				echo "******************* Submitting info to SQL for $yy *******************"
				/usr/local/sbin/mysql -B -N --host server.com --port 3306 -u em2 -pword -D mf_log -e "UPDATE em2nymxf SET col_delivery_status = 'Selenio Live' WHERE id='${status_update_id}'";
				touch "/Volumes/ifs/data/automation/em2email/.jkmlive.sentemail.lock"
				NODE="1"
				rm ~/em2nymxf.send.lock.$NODE
				exit 0
		
		fi
		if [[ $status_update_col = *"Selenio Live"* ]]; then
			if [ -f "$em2_flexfile/in/$yy" ]; then
				echo "Locating and Linking $yy to $em2_flexfile/in/$yy."
	 			find $em2_flexfile/in -type f ! -iname "._*" -iname "$rrr.mxf" ! -iname "?chk_file*" ! -iname "?work_file*" -size +1k -mmin +1 -print0 -exec ln {} "/Volumes/ifs/data/automation/em2dash/$thisonewithEH" \;
				echo "******************* Submitting info to SQL for $yy *******************"
				/usr/local/sbin/mysql -B -N --host server.com --port 3306 -u em2 -pword -D mf_log -e "UPDATE em2nymxf SET col_delivery_status = 'Sending Live' WHERE id='${status_update_id}'";
				NODE="1"
				rm ~/em2nymxf.send.lock.$NODE
				exit 0
			else
				echo "Waiting on Selenio for file $yy."
			fi				
		fi
		status_update_record=`/usr/local/sbin/mysql -B -N --host server.com --port 3306 -u em2 -pword -D mf_log -e "SELECT id,col_date,col_filename,col_delivery_status FROM em2nymxf WHERE col_filename LIKE '%$yy%' order by col_date DESC LIMIT 100"`
		status_update_id=`echo $status_update_record | grep ".mxf" | awk '{print $1}' | xargs`
		status_update_col=`echo $status_update_record | grep "$yy" | awk '{print $5}' | xargs`	
		if [[ $status_update_col = *"Sending Live"* ]]; then
			checkdash=`if find /Users/emtech/Library/Application\ Support/Gateway/index-v0.11.0.db/ -type f -iname "*.log" -exec strings {} \; | grep -q "$thisone"; then echo "YEAH"; fi`
			checkdash=`echo "$checkdash" | xargs` 
			echo "checkdash:$checkdash"
			if [[ $checkdash = "YEAH" ]]; then
				echo "******************* Submitting info to SQL for $yy *******************"
				/usr/local/sbin/mysql -B -N --host server.com --port 3306 -u em2 -pword -D mf_log -e "UPDATE em2nymxf SET col_delivery_status = 'Delivered Live' WHERE id='${status_update_id}'";
				NODE="1"
				rm ~/em2nymxf.send.lock.$NODE
				exit 0
			fi
		fi
		status_update_record=`/usr/local/sbin/mysql -B -N --host server.com --port 3306 -u em2 -pword -D mf_log -e "SELECT id,col_date,col_filename,col_delivery_status FROM em2nymxf WHERE col_filename LIKE '%$yy%' order by col_date DESC LIMIT 100"`
		status_update_id=`echo $status_update_record | grep ".mxf" | awk '{print $1}' | xargs`
		status_update_col=`echo $status_update_record | grep "$yy" | awk '{print $5}' | xargs`	
		
		if [[ $status_update_col = *"Delivered Live"* ]]; then
		echo "******************* Cleanining up after $yy *******************"
			rm -f "$files2sendlive/$yy"
			bash /usr/local/sbin/sendmail.sh "fromaddress.com" "me.com" "$status_get_col_filename file has been Shayred." "file $status_get_col_filename has been manually linked to Shayre for the Live Spot workflow, via the myserver.com/mxf delivery system." "abctvrelay.swna.wdpr.disney.com"
			bash /usr/local/sbin/sendmail.sh "fromaddress.com" "me.com" "$status_get_col_filename file has been Shayred." "file $status_get_col_filename has been manually linked to Shayre for the Live Spot workflow, via the myserver.com/mxf delivery system." "abctvrelay.swna.wdpr.disney.com"
			bash /usr/local/sbin/sendmail.sh "fromaddress.com" "me.com" "$status_get_col_filename file has been Shayred." "file $status_get_col_filename has been manually linked to Shayre for the Live Spot workflow, via the myserver.com/mxf delivery system." "abctvrelay.swna.wdpr.disney.com"
			bash /usr/local/sbin/sendmail.sh "fromaddress.com" "me.com" "$status_get_col_filename file has been Shayred." "file $status_get_col_filename has been manually linked to Shayre for the Live Spot workflow, via the myserver.com/mxf delivery system." "abctvrelay.swna.wdpr.disney.com"
			bash /usr/local/sbin/sendmail.sh "fromaddress.com" "me.com" "$status_get_col_filename file has been Shayred." "file $status_get_col_filename has been manually linked to Shayre for the Live Spot workflow, via the myserver.com/mxf delivery system." "abctvrelay.swna.wdpr.disney.com"
			bash /usr/local/sbin/sendmail.sh "fromaddress.com" "me.com" "$status_get_col_filename file has been Shayred." "file $status_get_col_filename has been manually linked to Shayre for the Live Spot workflow, via the myserver.com/mxf delivery system." "abctvrelay.swna.wdpr.disney.com"
			bash /usr/local/sbin/sendmail.sh "fromaddress.com" "me.com" "$status_get_col_filename file has been Shayred." "file $status_get_col_filename has been manually linked to Shayre for the Live Spot workflow, via the myserver.com/mxf delivery system." "abctvrelay.swna.wdpr.disney.com"
			bash /usr/local/sbin/sendmail.sh "fromaddress.com" "me.com" "$status_get_col_filename file has been Shayred." "file $status_get_col_filename has been manually linked to Shayre for the Live Spot workflow, via the myserver.com/mxf delivery system." "abctvrelay.swna.wdpr.disney.com"
			bash /usr/local/sbin/sendmail.sh "fromaddress.com" "me.com" "$status_get_col_filename file has been Shayred." "file $status_get_col_filename has been manually linked to Shayre for the Live Spot workflow, via the myserver.com/mxf delivery system." "abctvrelay.swna.wdpr.disney.com"				
		fi

done
echo "done with files2sendlive"

###########################################################################################################################################################################################
find /Applications/MAMP/htdocs/mxf/files2sendclean ! -iname "._*" -iname "*.mxf" ! -iname "?chk_file*" ! -iname "?work_file*" -mmin +1 -print0 | while IFS= read -r -d $'\0' zzz; do
 yyy=`basename "$zzz" | xargs` 
 rrrr=`echo "${yyy%.*}" | xargs` 
echo "Found: $yyy"
#############/Volumes/ifs/data/automation/em2flexfile/out/$mxfname

	if [[ -f "$zzz" ]]; then
		echo "Working on clean spot for: $zzz..."
		echo "rrrr:$rrrr"
		status_update_record=`/usr/local/sbin/mysql -B -N --host server.com --port 3306 -u em2 -pword -D mf_log -e "SELECT id,col_date,col_filename,col_delivery_status FROM em2nymxf WHERE col_filename LIKE '%$yyy%' order by col_date DESC LIMIT 100"`
		status_update_id=`echo $status_update_record | grep ".mxf" | awk '{print $1}' | xargs`
		status_update_col=`echo $status_update_record | grep "$yyy" | xargs`		
		status_get_orig_filename=`/usr/local/sbin/mysql -B -N --host server.com --port 3306 -u em2 -pword -D mf_log -e "SELECT col_movfilename FROM em2nymxf WHERE id LIKE '$status_update_id' order by col_date DESC LIMIT 100"`
		status_get_col_filename=`/usr/local/sbin/mysql -B -N --host server.com --port 3306 -u em2 -pword -D mf_log -e "SELECT col_filename FROM em2nymxf WHERE id LIKE '$status_update_id' order by col_date DESC LIMIT 100"`
		shit=`echo "$status_get_orig_filename" | xargs`
		echo "SUI:$status_update_id"
		echo "SUR:$status_update_record"
		echo "SUC:$status_update_col"
		echo "SGOF:$status_get_orig_filename"
		if echo "$status_get_orig_filename" | grep -q "_B_H"; then
			thisone=`echo "$shit" | awk -F_B_H '{print $0}' | sed 's/.mov/.mxf/g' |xargs`
			thisone=`echo "$thisone.mxf"`
		fi	
		if echo "$status_get_orig_filename" | grep -q "_E_H"; then
			thisone=`echo "$shit" | awk -F_E_H '{print $1}' | sed 's/.mov/.mxf/g' | xargs`
			thisone=`echo "$thisone"`
			E_H=`echo "_E_H.mxf"`
			thisonewithEH=`echo "$thisone$E_H"`
			echo "thisone:$thisone"
			echo "thisonewithEH:$thisonewithEH"
		fi	
		thisone=`echo $thisone | xargs`
		echo "this one: $thisone"
		
		if [[ $status_update_col = *"Queued Clean"* ]]; then
				echo "Locating and Linking $yyy to $em2_flexfile/out/$yyy."
	 			find /Volumes/ifs/data/archive/spots/mxf/ -type f ! -iname "._*" -iname "$rrrr.mxf" ! -iname "?chk_file*" ! -iname "?work_file*" -size +1k -mmin +1 -print0 -exec ln {} "$em2_flexfile/out" \;
				echo "******************* Submitting info to SQL for $yyy *******************"
				/usr/local/sbin/mysql -B -N --host server.com --port 3306 -u em2 -pword -D mf_log -e "UPDATE em2nymxf SET col_delivery_status = 'Selenio Clean' WHERE id='${status_update_id}'";
				touch "/Volumes/ifs/data/automation/em2email/.jkmlive.sentemail.lock"
				NODE="1"
				rm ~/em2nymxf.send.lock.$NODE
				exit 0
		
		fi
		if [[ $status_update_col = *"Selenio Clean"* ]]; then
				if [ -f "$em2_flexfile/in/$yyy" ]; then
					echo "Locating and Linking $yyy to $em2_flexfile/in/$yyy."
	 				find $em2_flexfile/in -type f ! -iname "._*" -iname "$rrrr.mxf" ! -iname "?chk_file*" ! -iname "?work_file*" -size +1k -mmin +1 -print0 -exec ln {} "/Volumes/ifs/data/automation/em2alternate/em2alternate/$rrrr.mxf" \;
					echo "******************* Submitting info to SQL for $yyy *******************"
					/usr/local/sbin/mysql -B -N --host server.com --port 3306 -u em2 -pword -D mf_log -e "UPDATE em2nymxf SET col_delivery_status = 'Sending Clean' WHERE id='${status_update_id}'";
					NODE="1"
					rm ~/em2nymxf.send.lock.$NODE
					exit 0
				else
					echo "Waiting on Selenio for file $yyy."
				fi
							
		fi
		status_update_record=`/usr/local/sbin/mysql -B -N --host server.com --port 3306 -u em2 -pword -D mf_log -e "SELECT id,col_date,col_filename,col_delivery_status FROM em2nymxf WHERE col_filename LIKE '%$yyy%' order by col_date DESC LIMIT 100"`
		status_update_id=`echo $status_update_record | grep ".mxf" | awk '{print $1}' | xargs`
		status_update_col=`echo $status_update_record | grep "$yyy" | awk '{print $5}' | xargs`	
		if [[ $status_update_col = *"Sending"* ]]; then
			checkdash=`if find /Users/emtech/Library/Application\ Support/Gateway/index-v0.11.0.db/ -type f -iname "*.log" -exec strings {} \; | grep -q "$thisone"; then echo "YEAH"; fi`
			checkdash=`echo "$checkdash" | xargs` 
			echo "checkdash:$checkdash"
			if [[ $checkdash = "YEAH" ]]; then
				echo "******************* Submitting info to SQL for $yyy *******************"
				/usr/local/sbin/mysql -B -N --host server.com --port 3306 -u em2 -pword -D mf_log -e "UPDATE em2nymxf SET col_delivery_status = 'Delivered Clean' WHERE id='${status_update_id}'";
				NODE="1"
				rm ~/em2nymxf.send.lock.$NODE
				exit 0
			fi
		fi
		status_update_record=`/usr/local/sbin/mysql -B -N --host server.com --port 3306 -u em2 -pword -D mf_log -e "SELECT id,col_date,col_filename,col_delivery_status FROM em2nymxf WHERE col_filename LIKE '%$yyy%' order by col_date DESC LIMIT 100"`
		status_update_id=`echo $status_update_record | grep ".mxf" | awk '{print $1}' | xargs`
		status_update_col=`echo $status_update_record | grep "$yyy" | awk '{print $5}' | xargs`	
		
		if [[ $status_update_col = "Delivered" ]]; then
		echo "******************* Cleanining up after $yyy *******************"
			rm -f "$files2sendclean/$yyy"
			bash /usr/local/sbin/sendmail.sh "fromaddress.com" "me.com" "$rrrr.mxf file has been Shayred." "file $rrrr.mxf has been manually linked to Shayre for the Clean spot workflow, via the myserver.com/mxf delivery system." "abctvrelay.swna.wdpr.disney.com"
			bash /usr/local/sbin/sendmail.sh "fromaddress.com" "me.com" "$rrrr.mxf file has been Shayred." "file $rrrr.mxf has been manually linked to Shayre for the Clean spot workflow, via the myserver.com/mxf delivery system." "abctvrelay.swna.wdpr.disney.com"
			bash /usr/local/sbin/sendmail.sh "fromaddress.com" "me.com" "$rrrr.mxf file has been Shayred." "file $rrrr.mxf has been manually linked to Shayre for the Clean spot workflow, via the myserver.com/mxf delivery system." "abctvrelay.swna.wdpr.disney.com"
			bash /usr/local/sbin/sendmail.sh "fromaddress.com" "me.com" "$rrrr.mxf file has been Shayred." "file $rrrr.mxf has been manually linked to Shayre for the Clean spot workflow, via the myserver.com/mxf delivery system." "abctvrelay.swna.wdpr.disney.com"
			bash /usr/local/sbin/sendmail.sh "fromaddress.com" "me.com" "$rrrr.mxf file has been Shayred." "file $rrrr.mxf has been manually linked to Shayre for the Clean spot workflow, via the myserver.com/mxf delivery system." "abctvrelay.swna.wdpr.disney.com"
			bash /usr/local/sbin/sendmail.sh "fromaddress.com" "me.com" "$rrrr.mxf file has been Shayred." "file $rrrr.mxf has been manually linked to Shayre for the Clean spot workflow, via the myserver.com/mxf delivery system." "abctvrelay.swna.wdpr.disney.com"
			bash /usr/local/sbin/sendmail.sh "fromaddress.com" "me.com" "$rrrr.mxf file has been Shayred." "file $rrrr.mxf has been manually linked to Shayre for the Clean spot workflow, via the myserver.com/mxf delivery system." "abctvrelay.swna.wdpr.disney.com"
			bash /usr/local/sbin/sendmail.sh "fromaddress.com" "me.com" "$rrrr.mxf file has been Shayred." "file $rrrr.mxf has been manually linked to Shayre for the Clean spot workflow, via the myserver.com/mxf delivery system." "abctvrelay.swna.wdpr.disney.com"
			bash /usr/local/sbin/sendmail.sh "fromaddress.com" "me.com" "$rrrr.mxf file has been Shayred." "file $rrrr.mxf has been manually linked to Shayre for the Clean spot workflow, via the myserver.com/mxf delivery system." "abctvrelay.swna.wdpr.disney.com"				
		fi  
	fi
	echo "##############################################################################"
done
echo "done with files2sendclean"
###########################################################################################################################################################################################
#########################################



rr=""
z=""
y=""
DATE=`echo "$DATE" | sed 's#/##g'`
echo "date:$DATE"
searchdate=`date +"%Y/%m"`
echo "searchdate:$searchdate"
find /Volumes/ifs/data/archive/spots/mxf/"$searchdate" -type f ! -iname "._*" \( -iname "*.mxf" -o -iname "*.xml" \) ! -iname "?chk_file*" ! -iname "?work_file*" -size +1k -mmin +1 -mmin -33333 -print0 | while IFS= read -r -d $'\0' z; do
z=`echo "$z" | sed 's#///#/#g' | sed 's#//#/#g'`
pathpath=`pwd "$z"`
y=`basename "$z"`
datepath=`echo "$z" | sed 's#/Volumes/ifs/data/archive/spots/mxf/##g'`
datepath=`echo "$datepath" | sed "s#$y##g"`
datepath=`echo "$datepath" | sed 's#///#/#g' | sed 's#//#/#g'`
y=`echo "$y" | sed 's#///#/#g' | sed 's#//#/#g'`
checkpathfile="/Volumes/ifs/data/automation/em2nymxf/$y"
    if ! [ -e "$checkpathfile" ]; then
    	echo "datepath:$datepath"

		ln "$z" "/Volumes/ifs/data/automation/em2nymxf/$y"
		echo linkting to "/Volumes/ifs/data/automation/em2nymxf/$y"
	fi
done
###################################################################################
#echo "$DATE"
# echo "3"
##########################################################################################################################
# Find all files in the /em2nymxf/stage directory (which is a symlink to emes2.wcntc.com:/ifs/data/automation/em2nymxf/) #
# emes2 needs to be setup in the automounts for nfs.                                                                 	 #
# for each file found create a symlink in the /em2nymxf/stage/ folder                                                 	 #
##########################################################################################################################

echo "Beginning ssearch of: /em2nymxf/stage/"
	find /em2nymxf/stage/ -type f -maxdepth 1 ! -iname "._*" \( -iname "*.mxf" -o -iname "*.xml" \) ! -iname "?chk_file*" ! -iname "?work_file*" -size +1k -mmin +1 -mmin -33366 -print0 | while IFS= read -r -d $'\0' x; do
	find /em2nymxf/ready/ -type f -maxdepth 1  ! -iname "?chk_file*" ! -iname "?work_file*" -iname "*ready*" -mmin +33367 -delete
x=`echo "$x" | sed 's#///#/#g' | sed 's#//#/#g'`
            y="$x"
			x=`basename "$x"`
			origname="${x//.mxf/}"
			xxx="$x"
			mailname="$xxx"
			mailname=`(basename "$mailname" .mxf)`
			xxx=$(basename "$xxx" .mov)
			set -- "/em2nymxf/ready/${x%.*}.ready"
	doesit="/em2nymxf/ready/$x.ready"
	if [ ! -e "$doesit" ]; then
                        ln -s /em2nymxf/stage/"$x" /em2nymxf/"Entertainment Marketing/$x"
                echo "******************* Creating links for file $x *******************"

######################################################################################################################

####################################
# Define variables for time checks #
####################################
	TASTYCAKES="$SourcePath$x"
	FILESIZE=$(stat -f%z "$TASTYCAKES")
	zero="0"
####################################


#######################################################################################################
# Send the damn file! but create the busy node file first, tells other nodes not to process this file #
# This will call an outside script to execute the scp transfer process and kill after 1200 seconds    #
#######################################################################################################
		if [ ! -e /em2nymxf/busy/$x.busy ]
			then
				touch /em2nymxf/"busy"/"$x.busy"
	                        starttime=$(date +%ss)
                	        finishtime=$(date +%ss)
				transfertype="hardlink"
		else
				echo "Skipping file $x as it looks like another node is sending it."
		fi

#######################################################################################################




#############################################################
# Send ready file after file has successfully been uploaded #
# With retry and timeout scripts							#
#############################################################
	touch /em2nymxf/"Entertainment Marketing"/"$x.ready"

#############################################################


##########################
# Cleanup after yourself #
##########################
	mv -f /em2nymxf/"Entertainment Marketing"/"$x.ready" /em2nymxf/ready/"$x.ready"
	rm -f /em2nymxf/"Entertainment Marketing/$x"
	rm -f /em2nymxf/busy/"$x.busy"
##########################

###################################################
# Clean up the data for mysql job info submission #
###################################################
# Fix time formatting #
starttimeN=`echo $starttime | sed 's/[^0-9]*//g'`
finishtimeN=`echo $finishtime | sed 's/[^0-9]*//g'`
totaltime=`expr $finishtimeN - $starttimeN`
now=`date '+%Y-%m-%d %H:%M:%S'`
me=`hostname`
fixedsize=`expr $FILESIZE / 1000000`

transferrate=""
###################################################



###################
# PHP lookup info #
###################
if ! [[ $FILESIZE -eq $zero ]]; then
	if [ -n ${FILESIZE} ]; then
	strippedx="${x//-SLATE/}"
	numericalname="${#strippedx}"
	if [ $numericalname -eq 17 ]; then 
		lookupname=`/bin/echo $x | /usr/bin/awk '{sub(/.{4}/,"&-")}1' | /usr/bin/awk '{sub(/.{10}/,"&-")}1' | /usr/bin/xargs`
	fi
	if [ $numericalname -eq 16 ]; then 
		lookupname=`/bin/echo $x | /usr/bin/awk '{sub(/.{4}/,"&-")}1' | /usr/bin/awk '{sub(/.{9}/,"&-")}1' | /usr/bin/xargs`
		lookupname2=`echo $lookupname | awk -F'-' '{print $2}'`
		echo "lookupname2:$lookupname2";
		numericalname2="${#lookupname2}"
		if [ $numericalname2 -eq 4 ]; then 
			lookupname=`/bin/echo $lookupname | /usr/bin/awk '{sub(/.{5}/,"&_")}1' | /usr/bin/xargs`
			 echo "fixed:$lookupname" 
			 fi
	fi
		echo "Formatted name for DSL Loookup is: $lookupname"
		if ! file --mime-type "$y" | grep -q xml$; then
  			echo "$y is not an xml."
			echo "dsl: dsl=/usr/bin/php /usr/local/sbin/lookupdsl.php '$lookupname'"
			lookup=`/usr/bin/php /usr/local/sbin/lookupdsl.php "$lookupname"`
			dsl=`echo "${lookup}"`
			echo "lookup:$lookup"
			dslspot_num=`/bin/echo "$dsl" | /usr/bin/grep -i 'SpotNum' | /usr/bin/awk -F'>' '{print $2}' | /usr/bin/xargs`
			movfilename="${dslspot_num// /_}"
			movfilename="${movfilename}.mov"
			prog_name=`/bin/echo "$dsl" | /usr/bin/grep -i 'prog_name' | /usr/bin/awk -F'>' '{print $2}' | /usr/bin/xargs`
			prog_season=`/bin/echo "$dsl" | /usr/bin/grep -i 'season' | /usr/bin/awk -F'>' '{print $2}' | /usr/bin/tr -dc '0-9' | /usr/bin/xargs`
			echo "prog_name=$prog_name"
			echo "prog_season=$prog_season"
			frame_size=`/usr/local/bin/ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "$y" | xargs`
			echo "frame_size=$frame_size"
			length=`echo "$movfilename" | awk -F'-' '{print $3}' | fold -w2 | paste -sd':' - | sed 's/^0*//'`
			echo "length=$length"
				basepromoid=`/bin/echo "$dsl" | /usr/bin/grep -i 'basepromoid' | /usr/bin/awk -F'>' '{print $2}' | /usr/bin/tr -dc '0-9' | /usr/bin/xargs`
				echo "basepromoid: $basepromoid"
				basepromofile=`curl -s "http://dsl-prod.media.disney.com/emshiplist/api/spots/$basepromoid" | jq | /usr/bin/grep -i '"SpotNum"' | /usr/bin/awk -F':' '{print $2}' |  /usr/bin/awk -F',' '{print $1}' | /usr/bin/xargs | sed 's/"//g' | sed 's/  /_/g' | sed 's/ /_/g' | /usr/bin/xargs`
				echo "basepromofile: $basepromofile"
				basepromofilepath=`find "/Volumes/ifs/data/archive/spots/fullres" -iname "$basepromofile*" -print -quit` 
				echo "basepromofilepath: $basepromofilepath"
				basepromofilepathsql=`basename "$basepromofilepath"`
		else
			echo "dsl: dsl=/usr/bin/php /usr/local/sbin/lookupdsl.php '$lookupname'"
			lookup=`/usr/bin/php /usr/local/sbin/lookupdsl.php "$lookupname"`
			dsl=`echo "${lookup}"`
			#echo "dsl_lookup: ${dsl}"
			dslspot_num=`/bin/echo "$dsl" | /usr/bin/grep -i 'SpotNum' | /usr/bin/awk -F'>' '{print $2}' | /usr/bin/xargs`
			movfilename="${dslspot_num// /_}"
			movfilename="${movfilename}.mov"
			prog_name=`/bin/echo "$dsl" | /usr/bin/grep -i 'prog_name' | /usr/bin/awk -F'>' '{print $2}' | /usr/bin/xargs`
			prog_season=`/bin/echo "$dsl" | /usr/bin/grep -i 'season' | /usr/bin/awk -F'>' '{print $2}' | /usr/bin/tr -dc '0-9' | /usr/bin/xargs`
			echo "prog_name=$prog_name"
			echo "prog_season=$prog_season"
  			echo "$y is an xml skipping probe."
  			length=""
  			frame_size=""
		fi
	fi
fi
###################


#############################
# Mysql Job info submission #
#############################
if ! [[ $FILESIZE -eq $zero ]]; then
	if [ -n ${FILESIZE} ]; then
		echo "******************* Submitting info to SQL for $x *******************"
		/usr/local/sbin/mysql --host server.com --port 3306 -u em2 -pword -D mf_log -e "insert into em2nymxf(col_date,col_host,col_url,col_prog_name,col_frame_size,col_length,col_filename,col_filesize,col_starttime,col_endtime,col_transfertime,col_transferrate,col_transfertype,col_failuretosend,col_failuretoarch,col_dslspotnum,col_movfilename,col_orig_filename,col_basepromoid,col_basepromofile) values('$now','$me','$SourcePath','$prog_name','$frame_size','$length','$x','$FILESIZE','$starttimeN','$finishtimeN','$totaltime','$transferrate','$transfertype','$failuretosend','$failuretoarch','$dslspot_num','$movfilename','$lookupname','$basepromoid','$basepromofilepathsql');" &
	fi
fi
#############################
echo "done"

  elif [ $# -gt 1 ]; then
    echo "for some reason I see $x more than once: " "$@"
  fi


#####################
# Cleanup variables #
#####################
starttime=""
finishtime=""
x=""
failuretosend=""
starttimeN=""
finishtimeN=""
totaltime=""
now=""
me=""
fixedsize=""
transferrate=""
TASTYCAKES=""
FILESIZE=""
#####################


done
echo "done with em2nymxf"; date
#########################################
#bash /usr/local/sbin/em2nymxf.proxy.sh
#bash /usr/local/sbin/em2nymxf.gfx.send.db.sh
###################
# remove job lock #
###################
NODE="1"
rm -f ~/em2nymxf.send.lock.$NODE
#rm -f ~/em2nymxf.send.lock.1
###################