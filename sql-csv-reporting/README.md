<table width="100%">
  <tr valign="middle">
    <td align="left">
      <a href="https://github.com/florianthepro/script/releases/download/Final/dwl.zip">Sourcecode</a>
    </td>
    <td align="right">
      <a href="/README/01.md">Read →</a>
    </td>
  </tr>
</table>

> [!IMPORTANT]
> pw.txt und check.php per htaccess sperren

> [!NOTE]
> [emty] füllen (rules.php index.php auto-download.php)
> pw.txt erstellen

> [!TIP]
> Beschreibbar machen:
>```
>sudo usermod -aG www-data [emty] #user
>sudo chown -R [emty]:www-data [emty] #user #/var/ww/html/test/
>sudo find [emty] -type d -exec chmod 770 {} \; #/var/ww/html/test/
>sudo find [emty] -type f -exec chmod 660 {} \; #/var/ww/html/test/
>```
