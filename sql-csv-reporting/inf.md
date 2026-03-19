> [!IMPORTANT]
> pw.txt und check.php per htaccess sperren

> [!NOTE]
> [emty] füllen (rules.php index.php auto-download.php)
> pw.txt erstellen

> [!TIP]
> Beschreibbar machen:
```
sudo usermod -aG www-data [emty] #user
sudo chown -R [emty]:www-data [emty] #user #/var/ww/html/test/
sudo find [emty] -type d -exec chmod 770 {} \; #/var/ww/html/test/
sudo find [emty] -type f -exec chmod 660 {} \; #/var/ww/html/test/
```
