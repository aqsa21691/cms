<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json");
include "db.php";

$teacher_id = $_GET['teacher_id'] ?? '';

if (!empty($teacher_id)) {
    // Filter by specific teacher
    $stmt = $conn->prepare("SELECT a.id, a.title, a.description, a.ucode, a.created_by, u.full_name as teacher_name 
                            FROM assessments a
                            JOIN users u ON a.created_by = u.bgnu_id
                            WHERE a.created_by = ?
                            ORDER BY a.id DESC");
    $stmt->bind_param("s", $teacher_id);
    $stmt->execute();
    $result = $stmt->get_result();
} else {
    // Fallback (or admin view): Show all
    $query = "SELECT a.id, a.title, a.description, a.ucode, a.created_by, u.full_name as teacher_name 
              FROM assessments a
              JOIN users u ON a.created_by = u.bgnu_id
              ORDER BY a.id DESC";
    $result = mysqli_query($conn, $query);
}

$assessments = [];

while ($row = mysqli_fetch_assoc($result)) {
    $assessments[] = $row;
}

echo json_encode([
    "status" => "success",
    "data" => $assessments
]);
?>
