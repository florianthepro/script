<?php
// von stackoverflow
// check.php
session_start();

// Passwort-Datei (nur Passwort drin, keine Ausgabe, nicht web-zugänglich machen)
define('PW_FILE', __DIR__ . '/pw.txt');

function require_login() {
    if (!is_readable(PW_FILE)) {
        // Harte Fehlermeldung, damit klar ist, was los ist
        http_response_code(500);
        echo "Fehler: Passwortdatei nicht lesbar.";
        exit;
    }

    // Wenn schon eingeloggt: einfach zurück
    if (!empty($_SESSION['auth_ok']) && $_SESSION['auth_ok'] === true) {
        return;
    }

    $realPw = trim(file_get_contents(PW_FILE));
    $inputPw = $_POST['pw'] ?? '';

    // Wenn Formular abgeschickt wurde, prüfen
    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        if (hash_equals($realPw, $inputPw)) {
            $_SESSION['auth_ok'] = true;

            // Zur selben Seite zurück (oder auf index.php)
            $target = $_SESSION['login_target'] ?? 'index.php';
            header('Location: ' . $target);
            exit;
        } else {
            $error = "Falsches Passwort.";
        }
    }

    // Zielseite merken (für Redirect nach Login)
    if (empty($_SESSION['login_target'])) {
        $_SESSION['login_target'] = $_SERVER['PHP_SELF'] ?? 'index.php';
    }

    // Ab hier: Login-Form anzeigen und abbrechen
    ?>
    <!doctype html>
    <html lang="de">
<head>
<meta charset="utf-8">
<title>Login</title>
<link rel="icon" type="image/svg+xml" href='icon.svg' />
<style>
body{font-family:Arial,Helvetica,sans-serif;margin:18px}
.box{max-width:320px;margin:60px auto;border:1px solid #ddd;padding:16px;border-radius:4px}
label{display:block;margin-bottom:8px}
input[type=password]{width:100%;padding:6px 8px;margin-bottom:12px;box-sizing:border-box}
button{padding:6px 12px;cursor:pointer}
.error{color:#900;margin-bottom:8px}
</style>
</head>
<body>
<div class="box">
<h2>Geschützter Bereich</h2>
<?php if (!empty($error)): ?>
<div class="error"><?php echo htmlspecialchars($error, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8'); ?></div>
<?php endif; ?>
<form method="post" action="check.php">
<label for="pw">Passwort:</label>
<input type="password" id="pw" name="pw" required>
<button type="submit">Login</button>
</form>
</div>
</body>
</html>
<?php exit;
}
if (basename(__FILE__) === basename($_SERVER['SCRIPT_FILENAME'] ?? '')) {
    require_login();
}
