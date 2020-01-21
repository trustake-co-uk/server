<?php
require ('functions.php');
$wallet = new phpFunctions_Wallet();

//Set the date
$today = date("Y-m-d") . " " . date("H:i:s") . ".000";

//Open the database.
$db = new SQLite3('/data/coldstake.db');
if (!$db) {
    die($db->lastErrorMsg());
}

$sql = <<<EOF
SELECT * from WHITELIST where ExpiryDate < Datetime('$today') and Whitelisted = 1;
EOF;

$dbselect = $db->query($sql);

while ($row = $dbselect->fetchArray(SQLITE3_ASSOC) ) {

    // Grab some variables
    $DelegatorAddress = $row['DelegatorAddress'];
    $ID = $row['ID'];
    $ExpiryDate = $row['ExpiryDate'];

    // flag as de-listed > switch whitelist to 0
    $sql = <<<EOF
UPDATE WHITELIST set Whitelisted = 0 where ID = $ID;
EOF;
    $setflag = $db->exec($sql);
    // De-whitelist the Delegator address
    $rpcresult = $wallet->rpc('delegatorremove', '"' . $DelegatorAddress . '"');
    if ($rpcresult == false) {
        echo "Something went wrong checking the node! \n\n";
    } else {
        //List what's been de-registered to screen
        echo $DelegatorAddress . " has been de-registered with expiry date of " . $ExpiryDate . "\n\n";
    }
}
$db->close();