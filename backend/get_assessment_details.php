<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json");
include "db.php";

$assessment_id = $_GET['assessment_id'] ?? '';

if (empty($assessment_id)) {
    echo json_encode(["status" => "error", "message" => "Assessment ID is mandatory"]);
    exit;
}

$query = "SELECT category, marks, is_comment FROM assessment_details WHERE assessment_id = ?";
$stmt = $conn->prepare($query);
$stmt->bind_param("i", $assessment_id);
$stmt->execute();
$result = $stmt->get_result();

$details = [];
while ($row = $result->fetch_assoc()) {
    $details[] = $row;
}

echo json_encode([
    "status" => "success",
    "data" => $details
]);
?>
