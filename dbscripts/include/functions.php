<?php

class phpFunctions_Wallet
{
    public function rpc($command, $params = null)
    {
        require('/var/secure/keys.php');
        require('/home/pivx-web/pivx-coldstake.co.in/include/config.php');
        $rpcpass=$WalletPassword;
        $rpcuser=$WalletName;
        $url = $scheme . '://' . $server_ip . ':' . $api_port . '/';
        $request = '{"jsonrpc": "1.0", "$rpcuser":"$rpcpass", "method": "' . $command . '", "params": [' . $params . '] }';
        $ch = curl_init($url);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_BINARYTRANSFER, true);
        curl_setopt($ch, CURLOPT_USERPWD, "$rpcuser:$rpcpass");
        curl_setopt($ch, CURLOPT_HTTPHEADER, array(
            "accept: application/json",
            "content-type: application/json-patch+json",
        ));
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_POSTFIELDS, $request);
        curl_setopt($ch, CURLOPT_POSTFIELDS, $request);
        
        $response = curl_exec($ch);
        $response = json_decode($response, true);
        $result=$response['result'];
        $error=$response['error'];

        if ( isset($error) ) {
            return $error;
        } else {
            return $result;
        }
        curl_close($ch);
    }

}
