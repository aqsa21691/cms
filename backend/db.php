<?php
$host = "localhost";
$user = "devnrvku_aqsaS";        // apna db username
$password = "AQSAaqsa@#S";        // apna db password
$database = "devnrvku_lms10";     // apna database name

$conn = mysqli_connect($host, $user, $password, $database);

if (!$conn) {
    die("Database connection failed");
}
?>
