#!/bin/bash
# Mailmon v1.0 by Kyle Claisse
# This script reads in an email in text form and executes certain functions based on the content of the message.
#
# This bash script was cobbled together quickly with no thought to how anyone else would use it so its not the best.
# I rewrote this in python which is much easier to work with if you know python. See mailmon2.py

## Kyle originally wrote a very efficient and elegant script,
## which I have now stolen, modified, and bloated out to perform a similar job.
## modifications made by Tyler Francis on 2016-10-25
## mod version 1.8


## Identify yourself to an aging IT department
SCRIPTPATH=`pwd -P`/drhelpful.sh
hostname=`hostname`
username=`whoami`

## Path to where the mail.txt is being written
dPATH=~

## If I'm already running: don't run again, but instead warn a human that I might not be good at my job.
## Where should this email be sent?
adminEmail=tyler.francis@jelec.com
## How many times should this script try to run before giving up for a day?
failAfterIteration=5

lockout=false
## If a lock file exists, a previous iteration is taking longer than it should. Let's create or iterate a fail counter
if test -e "drhelpful.lock"
then
        lockout=true
        if ((`cat drhelpful.lock` > 0))
        then
                lockoutCount=`cat drhelpful.lock`
                echo "$lockoutCount + 1" | bc | tee drhelpful.lock
        else
                printf 1 > drhelpful.lock
        fi
else
        ## If it doesn't already exist, let's create a lock file to fail any future iterations of this script that try to run while this iteration runs.
        touch drhelpful.lock
fi

## Don't bother running if this script failed a lot within 24 hours.
# if (( ((`cat drhelpful.rest_until` + 86400)) <= `date +%s`))
# then
#       exit 1
# fi
if $lockout
then
        if ((`cat drhelpful.lock` >= $failAfterIteration))
        then
                printf `date +%s` > drhelpful.rest_until
                rm -f drhelpful.lock
                exit 1
        fi

        if ((`cat drhelpful.lock` < $failAfterIteration))
        then
                printf "I don't mean to cause a fuss, but I'm trying to run again while another copy of me is already running. This might mean that I'm not good at my job, or that there's been a recent flood of email I'm having trouble parsing, or I don't have enough hardware resources at my disposal to perform my job, or who knows.\n\nFYI, here's my schedule:\n`crontab -l | grep $SCRIPTPATH` \nPlease SSH into $username@$hostname and do what you can.\nI don't want to innatate you with email, so if I have this problem $failAfterIteration times in a row, I'm going to stop trying for a day." | mail -s "I refuse to run, since I might be broken" $adminEmail
                echo "I have failed to run less than five times in a row. If I fail more than 5 times in a row, I'll quit trying for 24 hours."
                exit 1
        fi
        ## If it's not greater than, less than, or equal to a number: it probably isn't a number and may instead be empty or non-existent
        ## Therefore we'll assume this script hasn't failed recently, 
fi


## To increase readability and reduce size, here's a bunch of words I would normally have to repeat in most email conditions.
usualSteps="\n -Open the Hyper-V Manager MMC Snap-In and connect to OMITTED\n -Right-click the machine you want to resurrect, and select Settings...\n -Under IDE Controller 0 click Browse... and replace the VHD with the newest VHD as created by Disk2VHD\n -Under IDE Controller 1 click Browse... and replace the VHD with the second-newest VHD as created by UrBackup. Depending on when this machine died, urBackup might have been in the middle of its backup. Don't use the latest one, it might be unfinished. Use the penultimate VHD instead\n -Change its Network Adapter to OMITTED\n -click OK, and then Start on the right\n -Consider logging into the server once it's booted to disable and stop the UrBackup client service from services.msc and the disk2vhd task from the Windows Task Scheduler"


## clean up in case an old session didn't clean up after itself
rm -f $dPATH/out.txt
rm -f $dPATH/mail.txt


## manually check for new email
fetchmail -d0 -k pop.gmail.com > /dev/null


## copy mail to temporary working area
cp /var/mail/$username $dPATH/mail.txt


## don't waste my time if you haven't received any email
if [[ $(find $dPATH/mail.txt -type f -size +2c 2>/dev/null) ]]
then
        ## Apparently mail.txt is not empty
        for line in `cat $dPATH/mail.txt`
        do
                ## Find out who sent the message so you can reply to them, but make sure you're not mailing the SMTP server's postmaster
                from=$(cat $dPATH/mail.txt | grep From: | grep -v Message-ID | grep -v Return-Path:| egrep "[a-zA-Z0-9_.-]+@([a-zA-Z0-9-]+\.){1,}([a-z]){2,4}" -o|grep -v "mahgmailusername\|googlemail.com\|internaldomainname.tld")
                # TODO: Maybe move the from variable establishment out of this for loop so I'm not greping the entire file five times for every line in that file.
                case $line in

			uptime|Uptime )
				UP=$(uptime | egrep "([0-9][0-9]:?){3}.up.[0-9]{1,4}.days?" -o)
				echo $UP > $dPATH/out.txt
			;;

                        Nagios ) if cat $dPATH/mail.txt | grep "Notification Type: PROBLEM"; then
                                        ## Nagios just sent an email about a problem.
                                        ## Let's find out which server died, so we can give more specific advice.
                                        ## TODO: throw some pipes into the above CASE-and-GREP business to include other alerts.
                                        for deadservers in `cat $dPATH/mail.txt`
                                        do
                                                case $deadservers in

                                                ONESERVER|oneserver ) printf "oneserver is down! \n\nIn addition to the normal Hyper-V faffery, you'll have to:\n -Boot up the oneserver VM\n -do some other stuff\n -and more still\n" >> $dPATH/out.txt
                                                        ;;

                                                TWOSERVER|twoserver|TwoServer|RedServer|redserver|Redserver|REDSERVER ) printf "Ach! A server is down! There are no unusual steps involved in starting the backup VM. Only the usual steps like: $usualSteps\n" >> $dPATH/out.txt
                                                        ;;

                                                Blueserver|blueserver|BlueServer|BLUESERVER ) printf "BlueServer is down!\n\nGood news : there are no unusual steps involved in starting the backup VM. Bad news : the fish is delish, but makes a small dish. \n\nHere's the usual backup VM startup procedure, if you want it: $usualSteps\n" >> $dPATH/out.txt
                                                        ;;

                                                NEDSERVER|nedserver|Nedserver|NedServer ) printf "NedServer is down!\n\nGood news : there are no unusual steps involved in starting the backup VM. Bad news : He doesn't like his little bed. \n\nAnyway, if you want the usual VM startup steps, here you go: $usualSteps\n" >> $dPATH/out.txt
                                                        ;;

                                                BedServer|bedserver|BEDSERVER ) printf "BedServer is down!\n\nThe BedServer VM's OS works fine and will boot right up if you follow the usual steps, but some other stuff won't work\n" >> $dPATH/out.txt
                                                        ;;

                                                ThreeServer|threeserver|THREESERVER ) printf "ThreeServer is down!\n\nThis is just off-the-cuff musings, here, I don't know if it'll work.\n" >> $dPATH/out.txt
                                                        ;;

                                                FourServer ) printf "An important VM is down!\n\nIt should be fine, but just in case...\n" >> $dPATH/out.txt
                                                ;;

                                                foo|bar ) printf "foobar is down!\n\n    \n\noh well\n" >> $dPATH/out.txt
                                                        ;;

                                                esac
					done
				else
					echo "must not be a problem" > /dev/null
				fi
			;;

			"hi" ) echo "Why hello to you too" >> $dPATH/out.txt
			;;

		esac
	done

	## mail me your variables for diagnostic purposes
# 	echo "$username" >> $dPATH/out.txt
# 	echo "$dPATH" >> $dPATH/out.txt



	## add some space at the end, before reminding a forgetful IT department who and where you are, in case they want to edit or end you.
	if [[ $(find $dPATH/out.txt -type f -size +2c 2>/dev/null) ]]
	then
		echo ""  >> $dPATH/out.txt
		echo ""  >> $dPATH/out.txt
		echo "This message has been sent by $SCRIPTPATH running on $hostname" >> $dPATH/out.txt

		## Actually mail out the work done above.
		mail -s "Robo Reply" tyler.francis@jelec.com $from < $dPATH/out.txt

        fi

        ## When you've read an email with GNU Mailutils (at least in version 2.99.99) it will remove that block of text from /var/mail/username and append it to ~/mbox which I find neat. Let's do the same here.
        cat /var/mail/$username >> ~/mbox
        echo "" > /var/mail/$username

        ## clean up after yourself.
        rm -f $dPATH/out.txt
        rm -f $dPATH/mail.txt
        rm -f drhelpful.lock

#       echo done
        exit 0
else
#       echo "no mail received"
        rm -f drhelpful.lock
        exit 0
fi



## I configured Exim4 to recieve mail with fetchmail
## and I configured fetchmail to recieve mail from Gmail using this guide:
## https://www.axllent.org/docs/view/gmail-pop3-with-fetchmail/
