<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json");
include "db.php";

$assessment_id = $_GET['assessment_id'] ?? '';

if (empty($assessment_id)) {
    echo json_encode(["status" => "error", "message" => "Assessment ID is mandatory"]);
    exit;
}

try {
    // Get assessment basic info
    $query = "SELECT * FROM assessments WHERE id = ?";
    $stmt = $conn->prepare($query);
    $stmt->bind_param("i", $assessment_id);
    $stmt->execute();
    $assessment_result = $stmt->get_result();
    $assessment = $assessment_result->fetch_assoc();
    
    if (!$assessment) {
        echo json_encode(['status' => 'error', 'message' => 'Assessment not found']);
        exit;
    }
    
    // Get assessment categories
    $query = "SELECT * FROM assessment_details WHERE assessment_id = ?";
    $stmt = $conn->prepare($query);
    $stmt->bind_param("i", $assessment_id);
    $stmt->execute();
    $categories_result = $stmt->get_result();
    $categories = [];
    while ($row = $categories_result->fetch_assoc()) {
        $categories[] = $row;
    }
    
    // Get all evaluations for this assessment with student details
    // Get all evaluations for this assessment grouped by student
    $query = "
        SELECT 
            e.evaluation_of as student_id,
            u.full_name as student_name,
            e.evaluated_by,
            MAX(e.created_at) as created_at
        FROM evaluations e
        LEFT JOIN users u ON e.evaluation_of = u.bgnu_id
        WHERE e.assessment_id = ?
        GROUP BY e.evaluation_of, u.full_name, e.evaluated_by
        ORDER BY created_at DESC
    ";
    $stmt = $conn->prepare($query);
    $stmt->bind_param("i", $assessment_id);
    $stmt->execute();
    $evaluations_result = $stmt->get_result();
    
    $evaluations = [];
    while ($eval = $evaluations_result->fetch_assoc()) {
        // Get evaluation details for each student
        $detail_query = "
            SELECT 
                ad.category,
                ad.is_comment,
                ad.marks as total_marks,
                ev.marks,
                ev.comment
            FROM evaluations ev
            JOIN assessment_details ad ON ev.category_id = ad.id
            WHERE ev.assessment_id = ? AND ev.evaluation_of = ?
        ";
        $detail_stmt = $conn->prepare($detail_query);
        $detail_stmt->bind_param("is", $assessment_id, $eval['student_id']);
        $detail_stmt->execute();
        $details_result = $detail_stmt->get_result();
        
        $evaluation_details = [];
        while ($detail = $details_result->fetch_assoc()) {
            $evaluation_details[] = [
                'category' => $detail['category'],
                'is_comment' => $detail['is_comment'],
                'total_marks' => $detail['total_marks'],
                'value' => $detail['is_comment'] ? $detail['comment'] : $detail['marks']
            ];
        }
        
        $eval['details'] = $evaluation_details;
        $evaluations[] = $eval;
    }
    
    echo json_encode([
        'status' => 'success',
        'assessment' => $assessment,
        'categories' => $categories,
        'evaluations' => $evaluations
    ]);
    
} catch (Exception $e) {
    echo json_encode(['status' => 'error', 'message' => $e->getMessage()]);
}
?>