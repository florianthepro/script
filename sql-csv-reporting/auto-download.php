<?php
$localFile = '/var/www/html/test/operationslist.csv'; #/var/www/html/test/csv.csv
$remoteUrl = 'http://minkowski.tcsoc.net/reporting/operationticketquality.php'; #https://sql.com/abfragezucsv.php -> csv.csv
$postField = 'downloadBtn';
$postValue = '1';
$timeout = 20;
$ua = 'Mozilla/5.0 (TicketlistDownloader/1.0)';
$dir = dirname($localFile);
if (!is_dir($dir) || !is_writable($dir)) {
    http_response_code(500);
    echo "Fehler: Zielverzeichnis nicht beschreibbar: {$dir}\n";
    exit;
}
$tmp = tempnam($dir, 'ticketlist_tmp_');
if ($tmp === false) {
    http_response_code(500);
    echo "Fehler: temporäre Datei konnte nicht erstellt werden\n";
    exit;
}
$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, $remoteUrl);
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_POSTFIELDS, [$postField => $postValue]);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
curl_setopt($ch, CURLOPT_MAXREDIRS, 5);
curl_setopt($ch, CURLOPT_CONNECTTIMEOUT, $timeout);
curl_setopt($ch, CURLOPT_TIMEOUT, $timeout);
curl_setopt($ch, CURLOPT_USERAGENT, $ua);
$data = curl_exec($ch);
$errNo = curl_errno($ch);
$errMsg = curl_error($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
$contentType = curl_getinfo($ch, CURLINFO_CONTENT_TYPE);
curl_close($ch);
if ($errNo !== 0) {
    @unlink($tmp);
    http_response_code(502);
    echo "Fehler beim Abrufen: cURL ({$errNo}) {$errMsg}\n";
    exit;
}
if ($httpCode < 200 || $httpCode >= 300) {
    @unlink($tmp);
    http_response_code(502);
    echo "Fehler: Remote returned HTTP {$httpCode}\n";
    exit;
}
if ($data === false || $data === '') {
    @unlink($tmp);
    http_response_code(502);
    echo "Fehler: Leere Antwort vom Remote\n";
    exit;
}
$written = file_put_contents($tmp, $data, LOCK_EX);
if ($written === false) {
    @unlink($tmp);
    http_response_code(500);
    echo "Fehler beim Schreiben der temporären Datei\n";
    exit;
}
$isCsv = false;
$head = substr($data, 0, 512);
if ($contentType !== null && stripos($contentType, 'csv') !== false) {
    $isCsv = true;
} elseif (preg_match('/^ID,Ticket/i', trim($head))) {
    $isCsv = true;
}
if (! $isCsv) {
    @unlink($tmp);
    http_response_code(502);
    echo "Fehler: Unerwarteter Inhalt (kein CSV). Content-Type: {$contentType}\n";
    exit;
}
@chmod($tmp, 0644);
if (file_exists($localFile)) {
    @unlink($localFile);
}
if (!@rename($tmp, $localFile)) {
    if (!@copy($tmp, $localFile)) {
        @unlink($tmp);
        http_response_code(500);
        echo "Fehler beim Verschieben der Datei nach {$localFile}\n";
        exit;
    }
    @unlink($tmp);
}
$log = $dir . '/update_log.txt';
//@file_put_contents($log, date('Y-m-d H:i:s') . " - Ticketliste aktualisiert\n", FILE_APPEND | LOCK_EX);
$timestamp = strtotime('+1 hour'); // aktuelle Zeit + 1 Stunde
file_put_contents(
    $log,
    date('Y-m-d H:i:s', $timestamp) . " - Ticketliste aktualisiert\n",
    FILE_APPEND | LOCK_EX
);
echo '<h3>CSV wurde automatisch aktualisiert.</h3>' . "\n";
