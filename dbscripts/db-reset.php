<?php
// Create local folder with permissions for DB
$output = `rm -rf /data`;
$output = `[ ! -f /data/coldstake.db ] && mkdir /data && touch /data/coldstake.db && chown www-data:www-data /data -R && chmod 770 /data -R`;

// Open/Create databas & whitelist table 
class MyDB extends SQLite3 {
      function __construct() {
         $this->open('/data/coldstake.db');
      }
   }
   $db = new MyDB();
   if(!$db) {
      echo $db->lastErrorMsg();
   } else {
      echo "Opened database successfully\n";
   }

   $sql =<<<EOF
      CREATE TABLE IF NOT EXISTS WHITELIST
      ( ID                       INTEGER PRIMARY KEY  AUTOINCREMENT,
        DelegatorAddress         TEXT                 NOT NULL,
        ExpiryDate               TEXT                 NOT NULL,
        ColdStakingAddress       TEXT                 NOT NULL,
        InvoiceID                TEXT,
        InvoiceStatus            TEXT,
        InvoiceExceptionStatus   TEXT,
        Price                    FLOAT,
        PaidPrice                    FLOAT,
        Whitelisted              INT                  NOT NULL);
EOF;

   $ret = $db->exec($sql);
   if(!$ret){
      echo $db->lastErrorMsg();
   } else {
      echo "Table created successfully\n";
   }
   $db->close();