<?php
header("Content-Type: application/json");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST");
header("Access-Control-Allow-Headers: Content-Type");

ini_set('display_errors', 1);
error_reporting(E_ALL);

// include DB
require_once "db.php";   // ✅ same folder ho to OK
// agar folder different ho to:
// require_once "../db.php";

if (!isset($conn)) {
    echo json_encode([
        "status" => false,
        "message" => "Database connection variable not found"
    ]);
    exit;
}

// Read JSON input
$data = json_decode(file_get_contents("php://input"), true);

// Check if assessment_id is provided, else fetch all
$assessment_id = $data['assessment_id'] ?? 0;

if ($assessment_id == 0) {
    // Fetch ALL categories
    $sql = "SELECT id, assessment_id, category, marks, is_comment
            FROM assessment_details";
    $stmt = $conn->prepare($sql);
} else {
    // Fetch specific assessment categories
    $sql = "SELECT id, assessment_id, category, marks, is_comment
            FROM assessment_details
            WHERE assessment_id = ?";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("i", $assessment_id);
}

$stmt = $conn->prepare($sql);

if (!$stmt) {
    echo json_encode([
        "status" => false,
        "message" => "SQL prepare failed",
        "error" => $conn->error
    ]);
    exit;
}

if ($assessment_id != 0) {
    $stmt->bind_param("i", $assessment_id);
}
$stmt->execute();

$result = $stmt->get_result();

$dataArr = [];

while ($row = $result->fetch_assoc()) {
    $dataArr[] = [
        "id" => (int)$row['id'],
        "assessment_id" => (int)$row['assessment_id'],
        "category" => $row['category'],
        "marks" => (int)$row['marks'],
        "is_comment" => (int)$row['is_comment']
    ];
}

echo json_encode([
    "status" => true,
    "count" => count($dataArr),
    "data" => $dataArr
]);

$stmt->close();
$conn->close();
