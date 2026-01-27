<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
header("Access-Control-Allow-Methods: POST");
header("Content-Type: application/json");

include "db.php";

// 🔴 VERY IMPORTANT
$raw = file_get_contents("php://input");

if (!$raw) {
    echo json_encode([
        'success' => false,
        'error' => 'Raw input empty'
    ]);
    exit;
}

$data = json_decode($raw, true);

if (json_last_error() !== JSON_ERROR_NONE) {
    echo json_encode([
        'success' => false,
        'error' => 'Invalid JSON'
    ]);
    exit;
}

if (empty($data['assessment_id']) || empty($data['student_roll'])) {
    echo json_encode([
        'success' => false,
        'error' => 'Missing parameters'
    ]);
    exit;
}

$assessment_id = (int)($data['assessment_id'] ?? 0);
$student_roll = $data['student_roll'] ?? '';
$evaluation_id = (int)($data['evaluation_id'] ?? 0);

if ($evaluation_id <= 0 && (empty($assessment_id) || empty($student_roll))) {
    echo json_encode([
        'success' => false,
        'error' => 'Missing parameters: evaluation_id OR (assessment_id AND student_roll) required'
    ]);
    exit;
}

/* ---------- HEADER ---------- */
$sql = "
SELECT 
    e.evaluation_of as student_roll,
    e.evaluated_by,
    e.created_at,
    a.id as assessment_id,
    a.title AS assessment_name
FROM evaluations e
JOIN assessments a ON a.id = e.assessment_id
";

if ($evaluation_id > 0) {
    $sql .= " WHERE e.id = ? ";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("i", $evaluation_id);
} else {
    $sql .= " WHERE e.evaluation_of = ? AND e.assessment_id = ? ORDER BY e.created_at DESC LIMIT 1";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("si", $student_roll, $assessment_id);
}

$stmt->execute();
$header = $stmt->get_result()->fetch_assoc();

if (!$header) {
    echo json_encode(['success' => false, 'error' => 'No report found']);
    exit;
}

$session_date = $header['created_at'];
$final_student_roll = $header['student_roll'];
$final_assessment_id = $header['assessment_id'];

/* ---------- DETAILS ---------- */
// Get all evaluation items for this specific student, assessment AND timestamp (session)
$sql = "
SELECT 
    ad.category AS category_name,
    ad.marks AS total_marks,
    e.marks AS marks_obtained,
    e.comment
FROM evaluations e
LEFT JOIN assessment_details ad ON ad.id = e.category_id
WHERE e.evaluation_of = ?
AND e.assessment_id = ?
AND e.created_at = ?
";

$stmt = $conn->prepare($sql);
$stmt->bind_param("sis", $final_student_roll, $final_assessment_id, $session_date);
$stmt->execute();
$res = $stmt->get_result();

$categories = [];
$total = 0;
$obtained = 0;

while ($row = $res->fetch_assoc()) {
    $categories[] = $row;
    $total += (int)$row['total_marks'];
    $obtained += (int)$row['marks_obtained'];
}

echo json_encode([
    'success' => true,
    'report' => [
        'evaluation_id' => $evaluation_id,
        'student_roll' => $header['student_roll'],
        'evaluated_by' => $header['evaluated_by'],
        'created_at' => $header['created_at'],
        'assessment_name' => $header['assessment_name'],
        'total_marks' => $total,
        'obtained_marks' => $obtained,
        'categories' => $categories
    ]
]);
