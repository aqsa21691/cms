<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
header("Access-Control-Allow-Methods: POST, GET");
header("Content-Type: application/json");

include "db.php";

$teacher_id = "";

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $raw = file_get_contents("php://input");
    $data = json_decode($raw, true);
    $teacher_id = $data['teacher_id'] ?? "";
} else {
    $teacher_id = $_GET['teacher_id'] ?? "";
}

if (empty($teacher_id)) {
    echo json_encode(['success' => false, 'error' => 'Missing teacher_id']);
    exit;
}

// Select evaluations for assessments created by this teacher
// Also get student name for display
$sql = "
    SELECT 
        MAX(e.id) as id,
        e.assessment_id,
        e.evaluation_of, 
        e.evaluated_by,
        MAX(e.created_at) as created_at,
        a.title as assessment_title,
        u.full_name as student_name
    FROM evaluations e
    JOIN assessments a ON e.assessment_id = a.id
    LEFT JOIN users u ON e.evaluation_of = u.bgnu_id
    WHERE TRIM(a.created_by) = ?
    GROUP BY e.assessment_id, e.evaluation_of, e.evaluated_by, e.created_at, a.title, u.full_name
    ORDER BY created_at DESC, id DESC
";

$stmt = $conn->prepare($sql);
$tid = trim($teacher_id);
$stmt->bind_param("s", $tid);
$stmt->execute();
$result = $stmt->get_result();

$history = [];
while ($row = $result->fetch_assoc()) {
    // Standardize key for frontend
    $row['student_roll'] = $row['evaluation_of']; // For display compatibility
    $history[] = $row;
}

echo json_encode([
    'success' => true,
    'data' => $history
]);
?>
