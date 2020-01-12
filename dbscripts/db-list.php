<?php
$db = new SQLite3('/data/coldstake.db');
if(!$db){ die ($db->lastErrorMsg()); }
  
//$sql =<<<EOF
//UPDATE WHITELIST set Whitelisted = 0 where ID=1;
//EOF;

//$sql =<<<EOF
//DELETE from WHITELIST where ID = 2;
//EOF;

//$sql =<<<EOF
//INSERT INTO WHITELIST (DelegatorAddress,ExpiryDate,ColdStakingAddress,InvoiceID,Price,Whitelisted)
//VALUES ('XX', '2020-010-11', 'YY', 'INV1', 2.10, 1 );
//EOF;

//$result = $db->exec($sql);

//$sql =<<<EOF
//SELECT * from WHITELIST;
//EOF;

$sql =<<<EOF
SELECT * from WHITELIST;
EOF;
echo $sql;

$result = $db->query($sql);

while($row = $result->fetchArray(SQLITE3_ASSOC) ) {
echo "ID = ". $row['ID'] . "\n";
echo "DelegatorAddress = ". $row['DelegatorAddress'] ."\n";
echo "ExpiryDate = ". $row['ExpiryDate'] ."\n";
echo "ColdStakingAddress = ".$row['ColdStakingAddress'] ."\n";
echo "InvoiceID = ".$row['InvoiceID'] ."\n";
echo "Price = ".$row['Price'] ."\n";
echo "Whitelisted = ".$row['Whitelisted'] ."\n\n";
}

$db->close();
?>