#!/bin/bash

ORACLE_SID=$1
# Check whether ORACLE_SID is passed on
if [ "$ORACLE_SID" == "" ]; then
  ORACLE_SID=ORCLCDB
fi;

HAS_PDB=$2
if [ "$HAS_PDB" == "" ]; then
  HAS_PDB=false
fi;

ORACLE_PDB=$3
# Check whether ORACLE_PDB is passed on
if [ "$ORACLE_PDB" == "" ]; then
  ORACLE_PDB=ORCLPDB1
fi;

# Set PASSWORD for SYS SYSTEM
ORACLE_PWD="changeit"
echo "ORACLE AUTO GENERATED PASSWORD FOR SYS, SYSTEM AND PDBAMIN: $ORACLE_PWD";

# Replace place holders in response file
cp $ORACLE_BASE/$CONFIG_RSP $ORACLE_BASE/dbca.rsp
sed -i -e "s|###ORACLE_SID###|$ORACLE_SID|g" $ORACLE_BASE/dbca.rsp
sed -i -e "s|###HAS_PDB###|$HAS_PDB|g" $ORACLE_BASE/dbca.rsp
sed -i -e "s|###ORACLE_PDB###|$ORACLE_PDB|g" $ORACLE_BASE/dbca.rsp
sed -i -e "s|###ORACLE_PWD###|$ORACLE_PWD|g" $ORACLE_BASE/dbca.rsp

# Create network related config files (sqlnet.ora, tnsnames.ora, listener.ora)
mkdir -p $ORACLE_HOME/network/admin
echo "NAME.DIRECTORY_PATH= {TNSNAMES, EZCONNECT, HOSTNAME}" > $ORACLE_HOME/network/admin/sqlnet.ora

# Listener.ora
echo "LISTENER = 
(DESCRIPTION_LIST = 
  (DESCRIPTION = 
    (ADDRESS = (PROTOCOL = IPC)(KEY = EXTPROC1)) 
    (ADDRESS = (PROTOCOL = TCP)(HOST = 0.0.0.0)(PORT = 1521)) 
  ) 
) 

" > $ORACLE_HOME/network/admin/listener.ora

# Start LISTENER and run DBCA
lsnrctl start &&
dbca -silent -responseFile $ORACLE_BASE/dbca.rsp ||
 cat /opt/oracle/cfgtoollogs/dbca/$ORACLE_SID/$ORACLE_SID.log

echo "$ORACLE_SID=localhost:1521/$ORACLE_SID" >> $ORACLE_HOME/network/admin/tnsnames.ora
sqlplus / as sysdba << EOF
   ALTER SYSTEM SET control_files='$ORACLE_BASE/oradata/$ORACLE_SID/control01.ctl' scope=spfile;
EOF

if [ "$HAS_PDB" == "true" ]; then
	echo "$ORACLE_PDB= 
	(DESCRIPTION = 
	  (ADDRESS = (PROTOCOL = TCP)(HOST = 0.0.0.0)(PORT = 1521))
	  (CONNECT_DATA =
		(SERVER = DEDICATED)
		(SERVICE_NAME = $ORACLE_PDB)
	  )
	)" >> $ORACLE_HOME/network/admin/tnsnames.ora
	sqlplus / as sysdba << EOF
		ALTER PLUGGABLE DATABASE $ORACLE_PDB SAVE STATE;
EOF
																				
fi;

# Remove temporary response file
rm $ORACLE_BASE/dbca.rsp

