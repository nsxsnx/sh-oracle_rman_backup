#!/bin/sh
# Oracle database backup with RMAN
# This script must be run by oracle owner
if [ ! $# -eq 2 ]
then 
    echo -e "Usage: $0 \033[4mSID\033[0m \033[4mcommand\033[0m"
    echo -e "    \033[4mSID\033[0m is Oracle SID"
    echo -e "    \033[4mcommand\033[0m is one of the following:"
    echo "         full       - create a full database backup"
    echo "         full_cold  - shutdown database and create a full database backup"
    echo "         archivelog - create an archivelog backup"
    echo "         delete     - delete an expired backupsets"
    exit
fi 

. ~/.bash_profile
ORACLE_SID=$1
COMMAND=$2
BACKUP_PATH=/u01/backup/${ORACLE_SID}/
LOG_PATH=${BACKUP_PATH}log/
RETENTION_PERIOD="7 days"

BACKUP_PATH=`echo ${BACKUP_PATH} | sed "s/\/[\\t ]*$//"`
LOG_PATH=`echo ${LOG_PATH} | sed "s/\/[\\t ]*$//"`
LOG_PATH=${LOG_PATH}/${COMMAND}_`date "+%y%m%d_%H%M%S"`.log

rman_configure()
{
    rman target / nocatalog msglog "${LOG_PATH}" << EOF_1
    run {
    CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF ${RETENTION_PERIOD};
    CONFIGURE CONTROLFILE AUTOBACKUP ON;
    CONFIGURE CONTROLFILE AUTOBACKUP FORMAT FOR DEVICE TYPE DISK TO '${BACKUP_PATH}/${ORACLE_SID}_ctl_%F';
    CONFIGURE DEVICE TYPE DISK BACKUP TYPE TO COMPRESSED BACKUPSET;
    CONFIGURE CHANNEL DEVICE TYPE DISK FORMAT '${BACKUP_PATH}/${ORACLE_SID}_%U';
    }
    exit;
EOF_1
}

rman_full()
{
    rman target / nocatalog msglog "${LOG_PATH}" << EOF_2
    run {
    backup
    spfile format '${BACKUP_PATH}/${ORACLE_SID}_spfile_%U'
    database include current controlfile plus archivelog delete input;
    }
    exit;
EOF_2
}

rman_full_cold()
{
    rman target / nocatalog msglog "${LOG_PATH}" << EOF_3
    run {
    shutdown immediate;
    startup mount;
    backup
    spfile format '${BACKUP_PATH}/${ORACLE_SID}_spfile_%U'
    database include current controlfile plus archivelog delete input;
    alter database open; 
    }
    exit;
EOF_3
}

rman_archivelog()
{
    rman target / nocatalog msglog "${LOG_PATH}" << EOF_4
    run {
    backup as compressed backupset archivelog all delete input;
    }
    exit;
EOF_4
}

rman_delete()
{
    rman target / nocatalog msglog "${LOG_PATH}" << EOF_5
    run {
    crosscheck backup;
    crosscheck archivelog all;
    report obsolete;
    delete noprompt obsolete;
    }
    exit;
EOF_5
}

rman_configure
if [ ${COMMAND} = "full" ]
then 
    rman_full
    exit
elif [ ${COMMAND} = "full_cold" ]
then
    rman_full_cold
    exit
elif [ ${COMMAND} = "archivelog" ]
then
    rman_archivelog
    exit
elif [ ${COMMAND} = "delete" ]
then
    rman_delete
    exit
else
    echo "wrong command given"
    exit
fi

