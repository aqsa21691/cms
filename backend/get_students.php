<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json");
include "db.php";

$query = "SELECT bgnu_id, full_name FROM users WHERE designation = 'Student'";
$result = mysqli_query($conn, $query);

$students = [];
while ($row = mysqli_fetch_assoc($result)) {
    $students[] = $row;
}

echo json_encode([
    "status" => "success",
    "data" => $students
]);
?>
