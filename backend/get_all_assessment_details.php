<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json");
include "db.php";

$query = "SELECT assessment_id, category, marks, is_comment FROM assessment_details";
$result = mysqli_query($conn, $query);

$details = [];
while ($row = mysqli_fetch_assoc($result)) {
    $details[] = $row;
}

echo json_encode([
    "status" => "success",
    "data" => $details
]);
?>
