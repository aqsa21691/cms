<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
header("Access-Control-Allow-Methods: POST, GET");
header("Content-Type: application/json");

include "db.php";

// Handle GET or POST for student_roll
$student_roll = "";

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $raw = file_get_contents("php://input");
    $data = json_decode($raw, true);
    $student_roll = $data['student_roll'] ?? "";
} else {
    $student_roll = $_GET['student_roll'] ?? "";
}

if (empty($student_roll)) {
    echo json_encode(['success' => false, 'error' => 'Missing student_roll']);
    exit;
}

$sql = "
    SELECT 
        MAX(e.id) as id,
        e.assessment_id,
        e.student_roll,
        e.evaluated_by,
        MAX(e.created_at) as created_at,
        a.title as assessment_title,
        u.full_name as teacher_name
    FROM evaluations e
    JOIN assessments a ON e.assessment_id = a.id
    LEFT JOIN users u ON e.evaluated_by = u.bgnu_id
    WHERE e.evaluation_of = ? OR e.evaluated_by = ?
    GROUP BY e.assessment_id, e.evaluation_of, e.evaluated_by, e.created_at, a.title, u.full_name
    ORDER BY id DESC
";

$stmt = $conn->prepare($sql);
// We need to bind the student_roll parameter TWICE because there are two ? placeholders
$stmt->bind_param("ss", $student_roll, $student_roll);
$stmt->execute();
$result = $stmt->get_result();

$history = [];
while ($row = $result->fetch_assoc()) {
    // Map evaluation_of back to student_roll for frontend consistency if needed
    $row['student_roll'] = $row['evaluation_of']; 
    $history[] = $row;
}

echo json_encode([
    'success' => true,
    'data' => $history
]);
?>
