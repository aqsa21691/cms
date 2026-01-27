<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json");
include "db.php";

$query = "SELECT id, title, description, UCode as code 
          FROM assessment_details 
          ORDER BY id DESC";

$result = mysqli_query($conn, $query);

$assessments = [];

while ($row = mysqli_fetch_assoc($result)) {
    $assessments[] = $row;
}

echo json_encode([
    "status" => true,
    "data" => $assessments
]);
?>
