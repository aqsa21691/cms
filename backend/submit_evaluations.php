<?php
// Allow requests from any origin (or replace * with your Flutter web URL)
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

// Handle preflight request
if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    exit(0);
}
?>

<?php

header('Content-Type: application/json');
include 'db.php'; // ✅ Include your DB connection

// ---------------- Get JSON Input ----------------
$input = json_decode(file_get_contents('php://input'), true);

if (!$input || !isset($input['assessment_id'], $input['student_roll'], $input['evaluated_by'], $input['data'])) {
    echo json_encode([
        "status" => false,
        "message" => "Invalid JSON input"
    ]);
    exit;
}

// ---------------- Prepare Data ----------------
$assessment_id = intval($input['assessment_id']);
$student_roll  = $input['student_roll'];
$evaluated_by  = $input['evaluated_by'];
$data          = $input['data'];

// ---------------- Insert Each Category ----------------
$errors = [];

foreach ($data as $c) {
    $category_id   = intval($c['category_id']);
    $category_name = $c['category'];
    $marks         = intval($c['marks']);
    $comment       = $c['comment'];
    $is_comment    = intval($c['is_comment']);

    $stmt = $conn->prepare("INSERT INTO evaluations 
        (assessment_id, student_roll, evaluated_by, category_id, category_name, marks, comment, is_comment) 
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)"
    );

    if (!$stmt) {
        $errors[] = "Prepare failed: " . $conn->error;
        continue;
    }

    $stmt->bind_param(
        "isssiisi",
        $assessment_id,
        $student_roll,
        $evaluated_by,
        $category_id,
        $category_name,
        $marks,
        $comment,
        $is_comment
    );

    if (!$stmt->execute()) {
        $errors[] = "Execute failed for category '{$category_name}': " . $stmt->error;
    }

    $stmt->close();
}

// ---------------- Response ----------------
if (empty($errors)) {
    echo json_encode([
        "status" => true,
        "message" => "Data uploaded successfully"
    ]);
} else {
    echo json_encode([
        "status" => false,
        "message" => "Some errors occurred",
        "errors" => $errors
    ]);
}

$conn->close();
?>
